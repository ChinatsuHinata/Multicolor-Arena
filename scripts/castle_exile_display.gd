extends RefCounted
## Exile remains the authoritative zone; these are public visual links only.
static func apply(table,descriptors: Dictionary):
 var exiled={}
 for player in table.duel.players:
  for card in player.exile:exiled[card.uid]=card
 var displayed={}
 for player in table.duel.players:
  for source in player.field:
   var source_key="card_"+str(source.uid)
   if not descriptors.has(source_key):continue
   var cards=[]
   for reference in source.get("castle_exiles",[])+source.get("catalogue_castle",[]):
    var card=exiled.get(reference.get("uid",0),{})
    if card.is_empty() or card.get("zone","")!="exile" or card.get("epoch",-1)!=reference.get("epoch",-2):continue
    if card.card_id=="back" or card.get("network_hidden",false) or displayed.has(card.uid):continue
    cards.append(card);displayed[card.uid]=true
   if cards.is_empty():continue
   var front=descriptors[source_key]
   var floor_height=front.at.y
   front.at.y+=table.LAYER_HEIGHT*cards.size()
   var side=1.0 if source.owner==table.local_seat else -1.0
   for index in range(cards.size()):
    var card=cards[index]
    var at: Vector3=front.at
    at.y=floor_height+table.LAYER_HEIGHT*index
    at.z+=(0.12+minf(index*0.08,0.4))*front.scale.x*side
    var under=table.description(card,at,front.scale.x)
    under.rotation=Vector3.ZERO;under.tapped=false;under.conditional=false
    under.castle_uid=source.uid
    under.caption=table.duel.cards[source.card_id].name+" · 暂时除外"
    descriptors[under.key]=under
