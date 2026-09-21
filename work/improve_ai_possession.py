from pathlib import Path
p=Path(r'C:\Users\tzx20\Documents\test')
f=p/'scripts/rules/duel_engine.gd';s=f.read_text(encoding='utf-8-sig');a=s.index('func ai_possession(who: int=1):')
s=s[:a]+'''func ai_position_score(who: int) -> int:
 # Evaluate only our own hand, available resources and public permanents.
 var score=0
 var colors=[]
 for permanent in players[who].field:
  for color in cards[permanent.card_id].colors:
   if color not in colors: colors.append(color)
 for color in ["红","蓝","黄"]:
  if payment(who,{color:1}).ways>0: score+=10
  if payment(who,{color:2}).ways>0: score+=12
 var options=players[who].hand.duplicate()
 if players[who].leader.zone=="leader" and players[who].leader.timer==0: options.append(players[who].leader)
 var evaluated=[]
 for c in options:
  if c.card_id in evaluated: continue
  evaluated.append(c.card_id)
  var info=cards[c.card_id]
  if is_unit(c):
   if units(who).any(func(u): return cards[u.card_id].title==info.title): continue
   if info.colors.any(func(color): return color not in colors): continue
  if not info.requires_character.is_empty() and not units(who).any(func(u): return cards[u.card_id].character==info.requires_character): continue
  if payment(who,info.cost).ways==0: continue
  var value=ai_card_score(c)
  if info.kind=="道具" and players[who].field.any(func(u): return u.card_id==c.card_id): value=15
  score+=value
 return score
func ai_possession(who: int=1):
 # Compare legal one-card exchanges without emitting an action or revealing opposing hidden cards.
 var hand=players[who].hand
 var palette=players[who].palette
 var best=ai_position_score(who)
 var best_palette=-1
 var best_hand=-1
 for pi in range(palette.size()):
  if palette[pi].tapped: continue
  for hi in range(hand.size()):
   var trial_hand=hand.duplicate()
   var trial_palette=palette.duplicate()
   trial_hand[hi]=palette[pi]
   trial_palette[pi]=hand[hi]
   players[who].hand=trial_hand
   players[who].palette=trial_palette
   var score=ai_position_score(who)
   if score>best:
    best=score; best_palette=palette[pi].uid; best_hand=hand[hi].uid
 players[who].hand=hand
 players[who].palette=palette
 possession(best_palette,best_hand)
'''
f.write_text(s,encoding='utf-8')
