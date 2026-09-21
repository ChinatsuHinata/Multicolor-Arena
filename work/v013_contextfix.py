from pathlib import Path
R=Path.cwd()
def edit(p,f):
 p=R/p;s=p.read_text(encoding='utf-8');p.write_text(f(s),encoding='utf-8')
def cat(s):
 s=s.replace('static func spell_resolve(e,t):return Spells.resolve(e,t) if t.card.card_id in SPELLS else false','static func spell_resolve(e,t):\n if t.card.card_id not in SPELLS:return false\n var previous=e.resolving_spell;var result=Spells.resolve(e,t);e.resolving_spell=previous;return result')
 s=s.replace('"spell-fdf-123","character-ucs-044"]:\n  for queued in e.triggers:','"spell-fdf-123","character-ucs-044"]:\n  var coalesced=false\n  for queued in e.triggers:')
 s=s.replace('    if t.effect in ["cat:god_damage","spell-fdf-123"]:queued.data.amount+=t.data.amount\n    return','    coalesced=true\n    if t.effect in ["cat:god_damage","spell-fdf-123"]:queued.data.amount+=t.data.amount\n  if coalesced:return')
 return s
edit('scripts/rules/catalogue_abilities.gd',cat)
def engine(s):
 old=''' if t.get("continuation",false):
  pending={}
  if not target.is_empty(): t.target=target; Extra.resolve_trigger(self,t)
  judge();damage_context={}
 else:'''
 new=''' if t.get("continuation",false):
  pending={}
  var previous_context=damage_context;var previous_spell=resolving_spell
  if not target.is_empty():
   t.target=target;damage_context={"source":t.source,"combat":false,"single":Pack.single_damage_target(t)}
   resolving_spell=t.get("kind","")=="card" and cards[t.source.card_id].kind=="符卡"
   Extra.resolve_trigger(self,t)
  judge();damage_context=previous_context;resolving_spell=previous_spell
 else:'''
 assert old in s;s=s.replace(old,new);return s
edit('scripts/rules/duel_engine.gd',engine)
p=R/'tests/test_v013_edges.gd';s=p.read_text(encoding='utf-8');at=s.index(' print("V013_EDGES:')
s=s[:at]+''' fresh();a=put("spell-fdf-123");a.timer=3;put("character-fdf-041");e.Cat.mill(e,1,4)
 expect(e.triggers.size()==2 and e.triggers.all(func(t):return t.data.amount==4),"Sakuya duplicated mill triggers both retain the full batch count")
 fresh();var aftermath=resolve_spell("spell-fdn-040");expect(not e.resolving_spell,"palette-return spell restores damage classification")
 fresh();a=put("character-fdn-042");a.plus_counters=5;resolve_spell("spell-fdn-003");e.damage_context={}
 t=choose_groups(e.pending.options,[[e.ref_target(a)],[e.ref_target(a)],[e.ref_target(a)],[e.ref_target(a)],[e.ref_target(a)]]);e.choose_effect(t)
 expect(a.get("noncombat_damage_turn",-1)==e.turn and a.spell_damage,"damage distribution retains original spell source after selection")
'''+s[at:];p.write_text(s,encoding='utf-8')
