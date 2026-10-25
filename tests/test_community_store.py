"""Permissions, reviewed publication and exactly-once announcement money."""
import concurrent.futures
import json
import sqlite3
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "relay"))
import account_store
import community_store as store
import tournament_store
import task_store


class CommunityTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.path=Path(self.temp.name)/"players.db"
        self.conn=account_store.database(self.path)
        self.people={}
        for name in ("bigcake","editor","reader","heixingboshi"):
            id=self.conn.execute("INSERT INTO players(username,nickname,password_salt,password_hash,created_at) VALUES(?,?,X'',X'',0)",(name,name)).lastrowid
            self.people[name]={"ok":True,"username":name,"player_id":id}
        self.conn.commit()

    def tearDown(self):
        self.conn.close();self.temp.cleanup()

    def call(self,action,user="bigcake",**data):
        return store.handle(self.conn,{"action":action,**data},self.people.get(user,{"ok":False}))

    def gift(self, user="bigcake", **data):
        payload={"target_username":"reader","coins":31,"request_id":"a"*32,**data}
        return self.call("grant_coins",user,**payload)

    def balance(self, user="reader"):
        row=self.conn.execute("SELECT coins FROM task_wallets WHERE player_id=?",(self.people[user]["player_id"],)).fetchone()
        return row[0] if row else 0

    def group_fixture(self, enabled):
        # Test-only database fixture: the API cannot assign the fixed super-admin group.
        if enabled:self.conn.execute("INSERT INTO community_roles VALUES('editor','super_admin')")
        else:self.conn.execute("DELETE FROM community_roles WHERE username='editor' AND role='super_admin'")
        self.conn.commit()

    def test_super_group_binding_migration_grant_and_revocation(self):
        self.assertIn({"username":"bigcake","role":"super_admin"},self.call("roles")["roles"])
        self.assertTrue(all(self.call("permissions")["permissions"].values()))
        self.assertFalse(self.call("set_role",username="BIGCAKE",role="super_admin",enabled=False)["ok"])
        self.conn.execute("DELETE FROM community_roles WHERE role='super_admin'");self.conn.commit()
        self.assertFalse(self.call("permissions")["permissions"]["super_admin"])
        self.conn.close();self.conn=account_store.database(self.path)
        self.assertTrue(self.call("permissions")["permissions"]["super_admin"])
        self.assertFalse(self.call("set_role","reader",username="reader",role="super_admin",enabled=True)["ok"])
        self.assertFalse(self.call("set_role",username="editor",role="super_admin",enabled=True)["ok"])
        self.group_fixture(True)
        self.assertTrue(all(self.call("permissions","editor")["permissions"].values()))
        self.assertTrue(self.gift("editor")["ok"])
        self.conn.close();self.conn=account_store.database(self.path)
        self.assertTrue(self.call("permissions","editor")["permissions"]["super_admin"])
        self.group_fixture(False)
        self.assertFalse(self.call("permissions","editor")["permissions"]["super_admin"])
        self.assertFalse(self.gift("editor",request_id="b"*32)["ok"])
        self.assertEqual(self.balance(),31)

    def test_super_group_retains_tutorial_announcement_and_tournament_privileges(self):
        self.group_fixture(True)
        self.assertTrue(self.call("roles","editor")["ok"])
        self.assertTrue(self.call("publish_announcement","editor",entry={"id":"group","version":"1","title":"Group","body":"Body"},coins=2)["ok"])
        document=json.loads(self.call("lesson",id="t1")["document_text"])
        self.assertTrue(self.call("submit_lesson",document=document,base_revision=1)["ok"])
        submission=self.call("submissions","editor")["submissions"][0]
        self.assertTrue(self.call("review_lesson","editor",id=submission["id"],approve=True)["ok"])
        created=tournament_store.handle(self.conn,{"action":"create","title":"Group test","start_at":int(time.time())+3600},self.people["bigcake"])
        self.assertTrue(created["ok"],created)
        answer=tournament_store.handle(self.conn,{"action":"update_rewards","id":created["tournament"]["id"],"rewards":{"champion":13,"runner_up":7,"semifinalist":3}},self.people["editor"])
        self.assertTrue(answer["ok"],answer)
        self.assertTrue(answer["tournament"]["super_admin"])
        self.group_fixture(False)
        self.assertFalse(tournament_store.can_manage(self.conn,self.people["editor"],self.people["bigcake"]["player_id"]))

    def test_gifts_require_group_membership_and_ignore_spoofed_fields(self):
        self.call("set_role",username="editor",role="tutorial_editor",enabled=True)
        self.conn.execute("UPDATE players SET nickname='bigcake' WHERE username='reader'");self.conn.commit()
        for user in ("anonymous","reader","editor","heixingboshi"):
            with self.subTest(user=user):
                answer=self.gift(user,username="bigcake",player_id=self.people["bigcake"]["player_id"],super_admin=True,permissions={"super_admin":True})
                self.assertFalse(answer["ok"],answer)
        forged_account={**self.people["reader"],"username":"bigcake"}
        self.assertFalse(store.is_super(forged_account,self.conn))
        self.assertEqual(self.balance(),0)
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM community_coin_grants").fetchone()[0],0)

    def test_gifts_create_and_add_wallets_by_account_or_numeric_id(self):
        answer=self.gift(target_username=" READER ",coins=31.0)
        self.assertTrue(answer["ok"],answer)
        self.assertEqual((answer["target_username"],answer["target_player_id"],answer["coins"],answer["balance"]),("reader",self.people["reader"]["player_id"],31,31))
        self.assertFalse(answer["already_granted"])
        second=self.call("grant_coins",target_player_id=float(self.people["reader"]["player_id"]),coins=19,request_id="b"*32)
        self.assertTrue(second["ok"],second)
        self.assertEqual(second["balance"],50)
        self.assertEqual(self.balance("bigcake"),0)
        self.assertEqual(self.balance("editor"),0)
        self.assertEqual(task_store.snapshot(self.conn,self.people["reader"]["player_id"])["coins"],50)
        self.conn.close();self.conn=account_store.database(self.path)
        self.assertEqual(self.balance(),50)
        self.assertEqual(self.conn.execute("SELECT operator_id,target_player_id,coins FROM community_coin_grants ORDER BY request_id").fetchall(),[(self.people["bigcake"]["player_id"],self.people["reader"]["player_id"],31),(self.people["bigcake"]["player_id"],self.people["reader"]["player_id"],19)])

    def test_gifts_reject_invalid_amounts_targets_and_request_ids(self):
        cases=[{"coins":value} for value in (None,True,False,0,-1,1.5,"12",1000001,float("inf"),float("nan"),[],{})]
        cases += [{"target_username":value} for value in (None,True,[],{},"","不存在","missing_player","bigcake' OR 1=1 --")]
        cases += [{"request_id":value} for value in (None,True,[],{},"","a"*31,"a"*33,"x"*32)]
        for data in cases:
            with self.subTest(data=data):self.assertFalse(self.gift(**data)["ok"])
        for value in (None,True,0,-1,1.5,"2",2**53,999999):
            with self.subTest(target_player_id=value):
                self.assertFalse(self.call("grant_coins",target_player_id=value,coins=1,request_id="a"*32)["ok"])
        self.assertFalse(self.gift(target_player_id=self.people["reader"]["player_id"])["ok"])
        self.assertFalse(self.call("grant_coins",coins=1,request_id="a"*32)["ok"])
        self.assertEqual(self.balance(),0)
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM community_coin_grants").fetchone()[0],0)
        self.assertTrue(self.gift(coins=1000000)["ok"])

    def test_gift_retry_is_persistent_and_cannot_change_target_amount_or_operator(self):
        self.assertTrue(self.gift()["ok"])
        self.conn.close();self.conn=account_store.database(self.path)
        self.assertTrue(self.gift()["already_granted"])
        self.assertFalse(self.gift(coins=32)["ok"])
        self.assertFalse(self.gift(target_username="editor")["ok"])
        self.group_fixture(True)
        self.assertFalse(self.gift("editor")["ok"])
        self.assertEqual(self.balance(),31)
        self.assertEqual(self.balance("editor"),0)
        self.assertTrue(self.gift(request_id="b"*32)["ok"])
        self.assertEqual(self.balance(),62)

    def test_gift_concurrent_retries_award_once_and_unique_requests_accumulate(self):
        def grant(request_id):
            conn=sqlite3.connect(self.path,timeout=10)
            try:
                return store.handle(conn,{"action":"grant_coins","target_username":"reader","coins":7,"request_id":request_id},self.people["bigcake"])
            finally:conn.close()
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
            answers=list(executor.map(grant,["a"*32]*12))
        self.assertTrue(all(result["ok"] for result in answers),answers)
        self.assertEqual(sum(not result["already_granted"] for result in answers),1)
        self.assertEqual(self.balance(),7)
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
            answers=list(executor.map(grant,[f"{index:032x}" for index in range(12)]))
        self.assertTrue(all(result["ok"] for result in answers),answers)
        self.assertEqual(self.balance(),91)
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM task_rewards WHERE category='admin_grant'").fetchone()[0],13)

    def test_gift_rollback_preserves_receipt_and_wallet_consistency(self):
        with patch.object(task_store,"award",side_effect=ValueError("TEST_ONLY simulated write failure")):
            self.assertFalse(self.gift()["ok"])
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM community_coin_grants").fetchone()[0],0)
        self.assertEqual(self.balance(),0)
        self.assertTrue(self.gift()["ok"])
        self.conn.execute("UPDATE task_wallets SET coins=? WHERE player_id=?",(2**53-1,self.people["reader"]["player_id"]));self.conn.commit()
        self.assertFalse(self.gift(request_id="b"*32)["ok"])
        self.assertEqual(self.balance(),2**53-1)
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM community_coin_grants").fetchone()[0],1)

    def test_permission_grants_revocations_and_restart(self):
        self.assertFalse(self.call("set_role","reader",username="reader",role="tutorial_editor",enabled=True)["ok"])
        self.assertTrue(self.call("set_role",username="editor",role="tutorial_editor",enabled=True)["ok"])
        self.assertTrue(self.call("permissions","editor")["permissions"]["tutorial_editor"])
        self.assertFalse(self.call("set_role",username="bigcake",role="tutorial_editor",enabled=False)["ok"])
        self.call("set_role",username="heixingboshi",role="tournament_admin",enabled=False)
        self.call("set_role",username="editor",role="tutorial_editor",enabled=False)
        self.conn.close();self.conn=account_store.database(self.path)
        self.assertFalse(self.call("permissions","heixingboshi")["permissions"]["tournament_admin"])
        self.assertFalse(self.call("submissions","editor")["ok"])

    def test_public_read_submission_review_and_stale_protection(self):
        original=self.call("lesson","anonymous",id="t1")
        self.assertTrue(original["ok"])
        document=json.loads(original["document_text"]);document["title"]="Reviewed title"
        self.assertFalse(self.call("submit_lesson","reader",document=document,base_revision=1)["ok"])
        self.call("set_role",username="editor",role="tutorial_editor",enabled=True)
        for _ in range(2):self.assertTrue(self.call("submit_lesson","editor",document=document,base_revision=1)["ok"])
        submissions=self.call("submissions")["submissions"]
        self.assertEqual(self.call("lesson","anonymous",id="t1")["document_text"],original["document_text"])
        self.assertFalse(self.call("review_lesson","editor",id=submissions[0]["id"],approve=True)["ok"])
        self.assertTrue(self.call("review_lesson",id=submissions[0]["id"],approve=True)["ok"])
        published=self.call("lesson","anonymous",id="t1")
        self.assertEqual(published["revision"],2)
        self.assertEqual(json.loads(published["document_text"])["title"],"Reviewed title")
        self.assertFalse(self.call("review_lesson",id=submissions[1]["id"],approve=True)["ok"])
        self.assertTrue(self.call("review_lesson",id=submissions[1]["id"],approve=False)["ok"])
        self.assertFalse(self.call("review_lesson",id=submissions[1]["id"],approve=True)["ok"])
        document["id"]="new_lesson"
        self.assertTrue(self.call("submit_lesson","editor",document=document,base_revision=0)["ok"])
        self.assertFalse(self.call("lesson","anonymous",id="new_lesson")["ok"])
        pending=self.call("submissions")["submissions"][0]
        self.call("review_lesson",id=pending["id"],approve=True)
        self.assertTrue(self.call("lesson","anonymous",id="new_lesson")["ok"])
        document["id"]="../escape"
        self.assertFalse(self.call("submit_lesson","editor",document=document,base_revision=0)["ok"])

    def test_announcement_concurrent_grants_ignore_client_amount_and_persist(self):
        entry={"id":"reward-test","version":"1.0","title":"Reward","body":"Coins"}
        self.assertFalse(self.call("publish_announcement","reader",entry=entry,coins=30)["ok"])
        self.assertTrue(self.call("publish_announcement",entry=entry,coins=30)["ok"])
        self.assertFalse(self.call("claim_announcement","anonymous",id="reward-test")["ok"])
        player=self.people["reader"]
        def claim(_):
            conn=sqlite3.connect(self.path,timeout=10)
            try:
                return store.handle(conn,{"action":"claim_announcement","id":"reward-test","coins":999999},player)
            finally:
                conn.close()
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
            results=list(executor.map(claim,range(12)))
        self.assertTrue(all(result["ok"] for result in results))
        self.assertEqual(self.conn.execute("SELECT coins FROM task_wallets WHERE player_id=?",(player["player_id"],)).fetchone()[0],30)
        self.call("publish_announcement",entry=entry,coins=70)
        self.assertTrue(self.call("claim_announcement","reader",id="reward-test")["ok"])
        self.assertEqual(self.conn.execute("SELECT coins FROM task_wallets WHERE player_id=?",(player["player_id"],)).fetchone()[0],30)
        self.assertTrue(next(e for e in self.call("announcements","reader")["announcements"] if e["id"]=="reward-test")["claimed"])


if __name__ == "__main__":unittest.main()
