"""Permissions, reviewed publication and exactly-once announcement money."""
import concurrent.futures
import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "relay"))
import account_store
import community_store as store


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
