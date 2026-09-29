"""Compare seat 0 on identical seeds, starting seats and deck/rule revisions."""
import argparse
import json
import math
from pathlib import Path

def summarize(data, keys):
    games=[g for g in data["games"] if (g["seed"],g["first"]) in keys]
    terminal=[g for g in games if g["status"]=="terminal"]
    wins=sum(g["winner"]==0 for g in terminal)
    draws=sum(g["winner"]==-1 for g in terminal)
    latencies=sorted(v for g in games for v in g.get("decision_milliseconds",[]))
    n=len(terminal)
    interval=None
    if n:
        p=wins/n;z=1.96;denom=1+z*z/n
        center=(p+z*z/(2*n))/denom
        radius=z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/denom
        interval=[max(0,center-radius),min(1,center+radius)]
    return {"games":len(games),"completed":n,"wins":wins,"losses":n-wins-draws,"draws":draws,
            "unfinished":len(games)-n,"win_rate":wins/n if n else None,"win_rate_95pct_wilson":interval,
            "decision_p95_ms":latencies[max(0,math.ceil(.95*len(latencies))-1)] if latencies else None,
            "decision_max_ms":max(latencies) if latencies else None,"elapsed_ms":sum(g["milliseconds"] for g in games)}

def compare(candidate, baseline):
    if any(d.get("schema")!="multicolor.ai.episodes.v1" for d in [candidate,baseline]):raise ValueError("Unsupported dataset schema")
    provenance=["rules_hash","deck_hash","opponent_hash"]
    missing=[k for k in provenance if k not in candidate or k not in baseline]
    mismatch=[k for k in provenance if k not in missing and candidate[k]!=baseline[k]]
    if mismatch:raise ValueError("Arena provenance mismatch: "+", ".join(mismatch))
    def index(data):
        result={(g["seed"],g["first"]):g for g in data["games"]}
        if len(result)!=len(data["games"]):raise ValueError("Duplicate paired game keys")
        return result
    c,b=index(candidate),index(baseline);keys=set(c)&set(b)
    pairs=[]
    for key in sorted(keys):
        pairs.append({"seed":key[0],"first":key[1],"candidate_winner":c[key]["winner"],"baseline_winner":b[key]["winner"],"candidate_status":c[key]["status"],"baseline_status":b[key]["status"]})
    return {"schema":"multicolor.ai.arena.v1","candidate":summarize(candidate,keys),"baseline":summarize(baseline,keys),"pairs":pairs,
            "unpaired_candidate":len(set(c)-keys),"unpaired_baseline":len(set(b)-keys),
            "warnings":(["Missing provenance for early smoke datasets: "+", ".join(missing)] if missing else [])+(["Too few independent seeds to establish playing strength."] if len({k[0] for k in keys})<100 else []),
            "promotion":"requires_separate_review"}

def main():
    p=argparse.ArgumentParser();p.add_argument("candidate",type=Path);p.add_argument("baseline",type=Path);p.add_argument("--output",type=Path,required=True);a=p.parse_args()
    try:report=compare(json.loads(a.candidate.read_text(encoding="utf-8")),json.loads(a.baseline.read_text(encoding="utf-8")))
    except ValueError as error:p.error(str(error))
    a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({k:report[k] for k in ["candidate","baseline","warnings"]},ensure_ascii=False))

if __name__=="__main__":main()
