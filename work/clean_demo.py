from pathlib import Path
r=Path(r'C:\Users\tzx20\Documents\test');p=r/'scripts/main.gd';s=p.read_text(encoding='utf-8-sig')
s=s.replace(' if "--ui-test" in OS.get_cmdline_user_args(): call_deferred("run_ui_test")\n','').replace(' if "--visual-review" in OS.get_cmdline_user_args(): call_deferred("visual_review")\n','')
a=s.index('func draw_card(');b=s.index('func card_description(',a);s=s[:a]+s[b:]
a=s.index('func inspect_pile(');s=s[:a]
s=s.replace(' for i in range(10):\n  reimu.main.append_array(["165","164","70","100","170"])\n  marisa.main.append_array(["167","164","68","99","170"])',' for i in range(5):\n  reimu.main.append_array(["164","164","165","165","167","68","70","99","100","170"])\n  marisa.main.append_array(["164","164","165","167","167","68","70","99","100","170"])')
p.write_text(s,encoding='utf-8')
