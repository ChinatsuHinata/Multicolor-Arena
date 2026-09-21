from pathlib import Path
p=Path('tests/test_v013_rules.gd');s=p.read_text(encoding='utf-8').replace('character-mar-024','7').replace('character-mar-025','8');p.write_text(s,encoding='utf-8')
