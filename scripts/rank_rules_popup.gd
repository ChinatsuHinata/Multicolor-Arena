extends "res://scripts/modal_menu.gd"
## The rules share the same portraits and colours as the player's rank badge.
const RankBadge=preload("res://scripts/rank_badge.gd")
const LEVELS=["2 → 1 · 每级 3 星","3 → 1 · 每级 3 星","3 → 1 · 每级 3 星","3 → 1 · 每级 3 星","无级别 · 无星数"]
const LOSSES=["失败不掉星","失败掉星\n不会掉回毛玉级","失败掉星\n可掉回妖精级","失败掉星\n可掉回天狗级","保留贤者身份\n按 Elo 显示排名"]
const MATCH_RANGE_RULES="开始即可匹配同一大段位内所有级别，优先匹配同大段位玩家。任一方每等待满 20 秒，向上下各扩大 1 个大段位，最多上下各 4 个大段位。星数和贤者排名不影响匹配。"
var tiers: GridContainer
var sections: GridContainer

func build_rules(app):
 super.build(app,"排位规则",[])
 name="RankRulesPopup";panel.name="RankRulesPanel";scroll.name="RankRulesScroll"
 heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 panel.add_theme_stylebox_override("panel",host.style(host.INK,host.GOLD))
 var content=scroll.get_child(0)
 text(content,"五个大段位 · 由低到高",host.ui_metrics.body,host.MUTED).name="RankTierHeading"
 tiers=GridContainer.new();tiers.name="RankTierStyles";content.add_child(tiers)
 tiers.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 tiers.add_theme_constant_override("h_separation",int(host.ui_metrics.gap))
 tiers.add_theme_constant_override("v_separation",int(host.ui_metrics.gap))
 for tier in range(RankBadge.TITLES.size()):build_tier(tier)
 sections=GridContainer.new();sections.name="RankRuleSections";content.add_child(sections)
 sections.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 sections.add_theme_constant_override("h_separation",int(host.ui_metrics.gap))
 sections.add_theme_constant_override("v_separation",int(host.ui_metrics.gap))
 section("升星与晋级","胜利获得 1 星，三连胜起每胜获得 2 星。每段从最大数字升到 1，满 3 星立即晋级，多余星不带入下一级。失败中断连胜；需要掉星时，0 星会降一级并保留 2 星，段位保护按上图执行。","RankProgressionRules")
 section("匹配范围",MATCH_RANGE_RULES,"MatchmakingRangeRules")
 section("对局形式","固定官限 · 主卡组 50 张 · BO1 换备牌。入队时锁定卡组，配对后公开自机；赛前最多从备牌换入 3 张。每局双方合计最多请求悔棋 5 次，发起即计数，被拒绝或取消也计数；悔棋需对方同意。","RankFormatRules")
 section("贤者排名与结算","贤者按 Elo 从高到低排名，同分按账号创建顺序排列。段位、连胜与排名由账号服务统一结算；重复提交不会重复加星，取消的匹配不计胜负。","SageRankingRules")
 relayout()

func text(parent: Node,value: String,font: int,color: Color) -> Label:
 var label=Label.new();parent.add_child(label);label.text=value
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 label.add_theme_font_size_override("font_size",font)
 label.add_theme_color_override("font_color",color)
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 return label

func build_tier(tier: int):
 var tile=PanelContainer.new();tile.name="RankTier"+str(tier);tiers.add_child(tile)
 tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var color=RankBadge.COLORS[tier]
 var style=host.style(color.darkened(0.88),color)
 style.set_content_margin_all(maxf(12,host.ui_metrics.padding*0.65))
 tile.add_theme_stylebox_override("panel",style)
 var column=VBoxContainer.new();tile.add_child(column)
 column.add_theme_constant_override("separation",int(host.ui_metrics.gap*0.5))
 var center=CenterContainer.new();column.add_child(center)
 var badge=RankBadge.new();badge.name="RankTierImage"+str(tier);center.add_child(badge)
 badge.setup({"tier":tier,"level":1,"stars":0,"position":1},host.Store.CARDS)
 badge.custom_minimum_size=Vector2(124,136);badge.tooltip_text=RankBadge.TITLES[tier]
 var title=text(column,RankBadge.TITLES[tier],host.ui_metrics.body+4,color)
 title.name="RankTierTitle"+str(tier);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var levels=text(column,LEVELS[tier],host.ui_metrics.small,host.WHITE)
 levels.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var loss=text(column,LOSSES[tier],host.ui_metrics.small,host.MUTED)
 loss.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func section(title: String,value: String,node_name: String):
 var tile=PanelContainer.new();sections.add_child(tile)
 tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 tile.add_theme_stylebox_override("panel",host.ui_metrics.panel_style())
 var column=VBoxContainer.new();tile.add_child(column)
 column.add_theme_constant_override("separation",int(host.ui_metrics.gap*0.5))
 text(column,title,host.ui_metrics.body,host.GOLD)
 text(column,value,host.ui_metrics.small,host.WHITE).name=node_name

func relayout():
 if not is_instance_valid(panel):return
 var m=host.ui_metrics
 var safe=m.safe
 var extent=Vector2(minf(1280,safe.size.x),minf(760,safe.size.y))
 panel.size=extent;panel.position=safe.position+(safe.size-extent)*0.5
 if not is_instance_valid(tiers):return
 var content_width=extent.x-panel.get_theme_stylebox("panel").get_minimum_size().x-scroll.get_v_scroll_bar().get_combined_minimum_size().x
 var tile_width=maxf(195,m.small*7.5+m.padding*1.3)
 tiers.columns=5 if content_width>=tile_width*5+m.gap*4 else 3 if content_width>=tile_width*3+m.gap*2 else 2 if content_width>=tile_width*2+m.gap else 1
 if is_instance_valid(sections):sections.columns=2 if content_width>=maxf(760,m.small*26) else 1
