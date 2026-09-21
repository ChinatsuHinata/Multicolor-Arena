from pathlib import Path
p=Path('scripts/rules/expanded_abilities.gd');s=p.read_text(encoding='utf-8').replace('e.cards[entry.card.card_id].get("spell_type","")=="非符"','"非符" in e.cards[entry.card.card_id].get("spell_type","")');p.write_text(s,encoding='utf-8')
p=Path('scripts/rules/precon_abilities.gd');s=p.read_text(encoding='utf-8').replace('e.cards[c.card_id].character==name','e.Roster.character_matches(e.cards[c.card_id].character,name)');p.write_text(s,encoding='utf-8')
