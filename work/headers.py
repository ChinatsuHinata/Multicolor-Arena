exec(open(r'C:\Users\tzx20\Documents\test\work\read_cards.py',encoding='utf-8-sig').read().split('for s in w:')[0])
for s in w:
 if s.title.startswith(('CHARACTER','SPELL','ITEM','FIELD')):
  print(s.title)
  for row in list(s.values)[:4]: print(row)
  if s.title.startswith('SPELL'):
   for row in s.values:
    if '梦想封印' in str(row): print(row)
