extends RefCounted

static func ability(e,who: int=0,id: String="character-fdf-041",effect: String="character-fdf-041:self") -> Dictionary:
 for p in e.players:
  for zone in ["hand","deck","field","palette","grave","exile"]:p[zone]=[]
  p.mulligan_done=true;p.potato=false;p.turns=3
 e.phase="main";e.active=0;e.priority=0;e.turn=6;e.pending={};e.stack=[];e.triggers=[]
 e.presentation_events.clear();e.reveal_resolution={}
 var source=e.make_card(id,who,"field");source.leader=true;e.players[who].field.append(source)
 var shown=[]
 for card_id in ["spell-fdf-055","character-soi-006","121"]:
  var card=e.make_card(card_id,who,"deck");e.players[who].deck.append(card);shown.append(card)
 var entry={"owner":who,"effect":effect,"source":source.duplicate(true),"target":{"none":true},"roster":true,"extended":true,"optional":false,"name":e.cards[id].name}
 e.push_trigger(entry,{"none":true})
 return {"source":source,"shown":shown,"stack_id":e.stack.back().id}

static func resolve(e):
 e.pass_priority(e.priority);e.pass_priority(e.priority)

static func finish(e):
 var spec=e.pending.options[0]
 e.choose_effect({"selection_id":spec.get("selection_id",""),"picks":[[]]})
