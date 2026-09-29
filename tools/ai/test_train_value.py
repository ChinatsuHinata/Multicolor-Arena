"""Contract tests for the offline fitter; synthetic fixtures are not training evidence."""
import copy
import math
import unittest
from train_value import FEATURES, fit, sigmoid

def dataset():
    rows=[]
    for seed in [11, 1001]:
        for seat in [0, 1]:
            for turn in range(3):
                features=dict.fromkeys(FEATURES,0.0)
                features["life_margin"]=float(8 if seat==0 else -8)
                rows.append({"episode":f"{seed}:0:{seat}","seed":seed,"features":features,"outcome":1 if seat==0 else -1,"status":"terminal"})
    return {"schema":"multicolor.ai.episodes.v1","samples":rows,"games":[{"status":"terminal"},{"status":"action_limit"}]}

class TrainingContract(unittest.TestCase):
    def test_seed_split_and_raw_feature_weights(self):
        result=fit(dataset(),20)
        self.assertEqual(result["training"]["train_seeds"],[11])
        self.assertEqual(result["training"]["validation_seeds"],[1001])
        self.assertEqual(result["training"]["train"]["positions"],6)
        probability=sigmoid(result["weights"]["life_margin"]*8)
        self.assertGreater(probability,.5)
        self.assertAlmostEqual(-math.log(probability),result["training"]["validation"]["cross_entropy"])
        self.assertEqual(result["promotion"],"experimental_only")

    def test_unfinished_outcomes_never_train(self):
        data=dataset();expected=fit(data,15)
        row=copy.deepcopy(data["samples"][0]);row.update(status="action_limit",outcome=None)
        row["features"]["life_margin"]=1e9;data["samples"].append(row)
        self.assertEqual(expected["weights"],fit(data,15)["weights"])
        self.assertEqual(expected["training"]["excluded_games"],1)

    def test_reproducibility(self):
        self.assertEqual(fit(dataset(),20),fit(dataset(),20))

    def test_reject_single_label_or_single_seed(self):
        data=dataset()
        for row in data["samples"]:row["outcome"]=-1
        with self.assertRaisesRegex(ValueError,"both wins and losses"):fit(data)
        data=dataset();data["samples"]=[r for r in data["samples"] if r["seed"]==11]
        with self.assertRaisesRegex(ValueError,"two completed seed"):fit(data)

    def test_reject_invalid_features(self):
        for value in [math.nan,math.inf]:
            data=dataset();data["samples"][0]["features"]["life_margin"]=value
            with self.assertRaisesRegex(ValueError,"feature vector"):fit(data)

if __name__=="__main__":unittest.main()
