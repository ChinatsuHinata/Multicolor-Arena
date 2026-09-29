import copy
import unittest
from compare_arena import compare

def fixture():
    return {"schema":"multicolor.ai.episodes.v1","rules_hash":"rules","deck_hash":"deck","opponent_hash":"opponent",
            "games":[{"seed":11,"first":0,"winner":0,"status":"terminal","milliseconds":100,"decision_milliseconds":[10,20]},
                     {"seed":11,"first":1,"winner":-2,"status":"action_limit","milliseconds":200,"decision_milliseconds":[30]}]}

class ArenaContract(unittest.TestCase):
    def test_unfinished_is_not_draw_or_loss(self):
        result=compare(fixture(),fixture())["candidate"]
        self.assertEqual((result["completed"],result["wins"],result["draws"],result["losses"],result["unfinished"]),(1,1,0,0,1))
        self.assertEqual(result["decision_p95_ms"],30)
        self.assertLess(result["win_rate_95pct_wilson"][0],1)

    def test_reject_different_rules_or_duplicate_pair(self):
        data=fixture();data["rules_hash"]="other"
        with self.assertRaisesRegex(ValueError,"provenance mismatch"):compare(data,fixture())
        data=fixture();data["games"].append(copy.deepcopy(data["games"][0]))
        with self.assertRaisesRegex(ValueError,"Duplicate"):compare(data,fixture())

    def test_unmatched_seeds_are_reported(self):
        data=fixture();data["games"][1]["seed"]=22
        result=compare(data,fixture())
        self.assertEqual(len(result["pairs"]),1)
        self.assertEqual(result["unpaired_candidate"],1)
        self.assertEqual(result["unpaired_baseline"],1)

if __name__=="__main__":unittest.main()
