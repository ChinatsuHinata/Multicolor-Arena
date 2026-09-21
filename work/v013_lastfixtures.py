from pathlib import Path
p=Path('tests/test_v091.gd');s=p.read_text(encoding='utf-8').replace('app.library.get_child_count()==Store.CARDS.size()','app.library.get_child_count()==Store.CARDS.values().filter(func(c):return c.constructible).size()');p.write_text(s,encoding='utf-8')
p=Path('tests/test_v013_contracts.gd');s=p.read_text(encoding='utf-8').replace('"character-fdn-038","82"]','"character-fdn-038","82","character-fdf-098"]');p.write_text(s,encoding='utf-8')
