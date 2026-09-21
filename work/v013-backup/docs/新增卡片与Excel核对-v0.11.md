# 新增卡片入库与 Excel 核对 v0.11

日期：2026-09-19。用户授权导入新增卡片，并明确卡面文字有出入时以 Excel 为准；本轮继续包含卡牌效果的对战实现。

## 入库结果

- 两批共170张图片已从 `recourse/新增卡片` 移入 `recourse/数据库`。逐张SHA256核对，原始图片内容不变。
- 新增119条定义。当前251条定义：242张可构筑卡、9张衍生物。衍生物可由效果生成，不在普通组卡库中，不加入预组。
- 同名、同规则重印沿用稳定ID；异画和重复图保留在 `recourse/数据库/异画与重复/v0.11`。同名但有不同自机能力的SMM07早苗单独保留，原REI版本不覆盖。
- 待处理区的当前图片已全部处理，仅保留`.gdignore`。之后放入的图片不会自动导入。
- 六副原卡组及 `data/test_precons.json` 均逐字节未变，包含「预组-灵梦」和「预组-魔理沙」。不自动把新牌塞入原预组。

## 资料权威与差异处理

规则、颜色、费用、属性、完整牌名和自机能力采用本地《极彩全牌表 - （圣版可检索）25-12-17.xlsx》。新版牌表用于图片与牌名定位；本地爬虫缓存只用于图名与卡目编号匹配，没有联网查询。每份本轮处理的JSON含 `Excel来源`，记录文件、工作表、行、编号。共有153个不同ID完成原文逐字核对；未在本轮范围的旧定义保持原规则。

小町KMO-001行只写「吸血」，同一完整牌名的REC-013行明确写「吸血2」；本轮采用后者的明确数值，并将REC-013记入来源。相关说明已询问用户，尚无新回复，当前实现按这一明确Excel记录执行。

图片中的印刷文字不重画；游戏内预览、费用与结算使用Excel定义。例：本批爱丽丝普通能力为红色检索人偶，自机能力为黄色牺牲并回收；即使旧图上的能力顺序不同，仍按Excel。小径灵梦的「任意时机使用」同时保留为高速标记。2X费用记录倍率2，X=3时该颜色实际支付6点。

## 对战接入

新效果集中在 `scripts/rules/excel_abilities.gd`，通过JSON的 `roster` 实现绑定。包括多目标、分配伤害、费用追加弃牌、X及2X、减费、免费使用、墓地/除外使用、检索和排序、弃牌检查、临时控制、复制与生成物、正负指示物、触发/启动异能、时符与乐章、额外回合及立即结束回合。

法兰西人偶、动态增益和减益使用持续属性计算。状态检查先同时确定死亡对象，再处理死亡与后续持续效果变化；先制后的普通伤害保留独立窗口。百百世以-1/-1指示物替代单位伤害标记，双方伤害计算使用伤判开始时的攻击力，避免先执行的一方错误降低同时反击。

河童背包在对手能力完成目标声明后触发，对方选择支付任意颜色1点或不支付；付款成功才横置来源，不支付则反制原能力。神子选择X后，在必发入场能力中按每一点选择对象，同一个单位可以分得多点，结算时合计后一次造成相应伤害。此操作目前复用右侧分组选牌，尚非独立数字滑杆界面。

冈格尼尔只限制对手响应，仍会产生自己的使用符卡触发。心之箱每个自己的回合使用一次，时符进场后也保留之后入墓改除外的记录。额外弃牌是确认声明时才提交的费用，右键取消不会弃牌或横置颜色来源。

区域选牌采用卡面窗口，支持当前效果授权查看的对手手牌；复制品沿用原卡图，独立保存复制的规则和身份。没有专属图的小鬼、青蛙、御柱等运行时生成物使用可替换的统一SVG占位图，数值、颜色和关键词为实际效果数据。已有本批半灵原图已接入。

## 验证与维护

最终 1578 项数据库、规则与界面检查通过，16场完整自动对局正常结束（8场原预组、8场含两批新牌的混合卡组）。其中22项新界面检查另在真实图形模式下运行并查看截图。测试验证功能与流程，不代表人机强度或卡组平衡性结论。

| 测试 | 检查数 |
|---|---:|
| `test_v011_rules` | 188 |
| `test_v011_edges` | 81 |
| `test_v011_ucs` | 40 |
| `test_duel_rules` | 36 |
| `test_v09_rules` | 144 |
| `test_v095_rules` | 49 |
| `test_v096_rules` | 284 |
| `test_v098_rules` | 33 |
| `test_v010_rules` | 146 |
| `test_v010_ui` | 43 |
| `test_v011_ui` | 22 |
| `test_v097_database` | 512 |

日志位于 `work/v011/`，最终汇总为 `validation.json`，素材和来源审计为 `audit.json`。初始备份在 `work/v011-backup`；补充批图片与中间定义另保存在其中的 `supplement-input` 和 `supplement-definitions`。

`tools/import_excel_v011.py` 是本次审核批次的导入工具，不是任意图片自动识别器。后续新卡仍需要先匹配Excel、分配稳定ID、移动卡图、编写显式效果，再登记和测试。检查已有数据库使用 `tools/check_card_database.py`；只有核对通过后才加 `--write-index` 重建索引。

## 本次新增定义

| ID | 完整牌名 | Excel位置 | 能力实现 |
|---|---|---|---|
| `101` | 「妖恋谈」 | SOI-104 · SPELL （符卡） 行9 | leader_mark |
| `102` | 「万华ノ镜」 | SOI-105 · SPELL （符卡） 行10 | kaleidoscope |
| `103` | 「萤火ノ天」 | SOI-106 · SPELL （符卡） 行11 | grave_top |
| `104` | 禁忌「莱瓦汀」 | SOI-107 · SPELL （符卡） 行12 | destroy_any |
| `105` | 奇迹「白昼ノ客星」 | SOI-108 · SPELL （符卡） 行13 | tap_all |
| `107` | 「稻田姬ノ秋」 | UCS-086 · SPELL （符卡） 行126 | discard_draw |
| `109` | 神枪「冈格尼尔」 | SOI-112 · SPELL （符卡） 行17 | gungnir |
| `111` | 「缘起ノ幻想乡」 | SOI-114 · SPELL （符卡） 行19 | draw_x |
| `113` | 「活动记录」 | SOI-116 · SPELL （符卡） 行21 | activity |
| `114` | 「境界」 | UCS-079 · SPELL （符卡） 行125 | blink_two |
| `116` | 「太阳ノ花田」 | SOI-120 · SPELL （符卡） 行24 | sweep_three |
| `119` | 旧史「旧秘境史-古代史-」 | SOI-123 · SPELL （符卡） 行27 | history_exile |
| `12` | 冬之妖怪「蕾蒂·霍瓦特洛克」 | SOI-014 · CHARACTER (单位) 行15 | letty_freeze |
| `121` | 幻世「the world」 | SOI-125 · SPELL （符卡） 行29 | extra_turn |
| `122` | 「幻想风靡」 | SOI-126 · SPELL （符卡） 行30 | hand_army |
| `123` | 「天狗ノ防御」 | SOI-127 · SPELL （符卡） 行31 | counter_ability |
| `124` | 「废墟ノ梦」 | SOI-129 · SPELL （符卡） 行33 | counters_x |
| `125` | 本能「本我的解放」 | SOI-130 · SPELL （符卡） 行34 | unblock_reset |
| `126` | 「湖上」 | SOI-131 · SPELL （符卡） 行35 | lake_mill |
| `127` | 「九天ノ瀑布」 | SOI-132 · SPELL （符卡） 行36 | waterfall |
| `128` | 火水木金土符「贤者之石」 | SOI-133 · SPELL （符卡） 行37 | philosopher |
| `129` | 「宵暗ノ翼」 | SOI-135 · SPELL （符卡） 行39 | two_bats |
| `13` | 湖畔的住人「大妖精」 | SOI-015 · CHARACTER (单位) 行16 | dai_search |
| `132` | 「幽冥境」 | SOI-138 · SPELL （符卡） 行42 | ghost_imp |
| `134` | 「神ノ风」 | SOI-140 · SPELL （符卡） 行44 | destroy_item_field |
| `135` | 「夜ノ蝶」 | SOI-141 · SPELL （符卡） 行45 | exile_permanent |
| `136` | 「天ノ磐舟」 | SOI-142 · SPELL （符卡） 行46 | counter_targeting |
| `137` | 「百万鬼夜行」 | SOI-143 · SPELL （符卡） 行47 | gather_counters |
| `138` | 「天ノ羽衣」 | SOI-144 · SPELL （符卡） 行48 | bounce_small |
| `140` | 「审ノ视」 | SOI-146 · SPELL （符卡） 行50 | steal_turn |
| `142` | 「秋」 | SOI-148 · SPELL （符卡） 行52 | search_leader |
| `144` | 「深红ノ进击」 | SOI-150 · SPELL （符卡） 行54 | crimson_modes |
| `145` | 「静空」 | SOI-151 · SPELL （符卡） 行55 | quiet_modes |
| `146` | 「花ノ幻想」 | SOI-152 · SPELL （符卡） 行56 | grave_palette |
| `148` | 「今昔ノ花」 | SOI-154 · SPELL （符卡） 行58 | flower_damage |
| `149` | 「秘神ノ门扉」 | SOI-155 · SPELL （符卡） 行59 | door_reveal |
| `150` | 「风神的神德」 | SOI-156 · SPELL （符卡） 行60 | grace_reset |
| `151` | 土著神「小小青蛙不输风雨」 | SOI-157 · SPELL （符卡） 行61 | frogs_x |
| `152` | 「幻想ノ灵火」 | SOI-158 · SPELL （符卡） 行62 | fire_scry |
| `153` | 战符「小小军势」 | SOI-159 · SPELL （符卡） 行63 | doll_army |
| `154` | 要石「开天辟地ノ压」 | SOI-134 · SPELL （符卡） 行38 | tap_destroy |
| `155` | 「妖精ノ祭典」 | SOI-160 · SPELL （符卡） 行64 | fairy_festival |
| `156` | 冻符「完美冻结」 | SOI-161 · SPELL （符卡） 行65 | perfect_freeze |
| `157` | 想起「恐怖ノ回忆」 | SOI-162 · SPELL （符卡） 行66 | memory_cast |
| `158` | 幻想「花鸟风月、啸风弄月」 | SOI-163 · SPELL （符卡） 行67 | palette_army |
| `159` | 「永夜归返-子ノ刻-」 | SOI-164 · SPELL （符卡） 行68 | end_turn |
| `160` | 「游行圣」 | SOI-165 · SPELL （符卡） 行69 | untargetable |
| `161` | 妖怪「火焰ノ车轮」 | SOI-166 · SPELL （符卡） 行70 | wheel_modes |
| `17` | 甜蜜毒药「梅蒂欣·梅兰可莉」 | SOI-019 · CHARACTER (单位) 行20 | medicine_kill |
| `171` | 无名ノ丘 | SOI-104 · FIELD(结界) 行4 | annihilate_aura |
| `172` | 雾ノ湖 | SOI-105 · FIELD(结界) 行5 | mist_lake |
| `173` | 心ノ箱 | SOI-106 · FIELD(结界) 行6 | heart_grave |
| `175` | 冥界 | SMM-003 · FIELD(结界) 行8 | nether_ghost |
| `178` | 妖云「平安时代ノ黑云」 | SOI-183 · SPELL （符卡） 行75 | cloud_attack |
| `19` | 暗中的光虫「莉格露·奈特巴格」 | SOI-021 · CHARACTER (单位) 行22 | wriggle_evasion |
| `2` | 月之光「露娜·切露德」 | SOI-003 · CHARACTER (单位) 行4 | luna_life |
| `22` | 夜雀「米斯蒂娅·萝蕾拉」 | SOI-024 · CHARACTER (单位) 行25 | mystia_life |
| `24` | 式神「八云蓝」 | SOI-026 · CHARACTER (单位) 行27 | ran_discount |
| `25` | 念写记者「姬海棠果」 | UCS-EX03 · CHARACTER (单位) 行331 | hatate_return、hatate_replace |
| `26` | 三途川之引渡人「小野冢小町」 | SOI-028 · CHARACTER (单位) 行29 | komachi_exile |
| `27` | 水中工程师「河城荷取」 | SOI-029 · CHARACTER (单位) 行30 | nitori_ward |
| `3` | 三月精「斯塔·萨菲雅」 | SOI-005 · CHARACTER (单位) 行6 | star_destroy |
| `31` | 独臂有角的仙人「茨木华扇」 | SOI-033 · CHARACTER (单位) 行34 | kasen_ramp_stats |
| `32` | 秘神流雏「键山雏」 | SOI-034 · CHARACTER (单位) 行35 | hina_redirect |
| `34` | 地狱的妖精「克劳恩皮丝」 | SOI-036 · CHARACTER (单位) 行37 | clown_sweep |
| `42` | 无理非道的仙人「霍青娥」 | SOI-044 · CHARACTER (单位) 行45 | seiga_death |
| `43` | 漆黑的噬龙者「姬虫百百世」 | SOI-045 · CHARACTER (单位) 行46 | momoyo_wither |
| `44` | 幻想乡的记忆「稗田阿求」 | SOI-046 · CHARACTER (单位) 行47 | akyuu_counter |
| `45` | 孤援的造型神「埴安神袿姬」 | SOI-047 · CHARACTER (单位) 行48 | keiki_copy |
| `46` | 「橙」 | SOI-048 · CHARACTER (单位) 行49 | chen_counter |
| `47` | 恶魔的门番「红美铃」 | SOI-049 · CHARACTER (单位) 行50 | meiling_spell |
| `51` | 「魍魉」 | SOI-053 · CHARACTER (单位) 行54 | 关键词/基础属性 |
| `52` | 「高阶恶魔」 | SOI-054 · CHARACTER (单位) 行55 | 关键词/基础属性 |
| `55` | 「风元素」 | SOI-057 · CHARACTER (单位) 行58 | 关键词/基础属性 |
| `58` | 「大天狗」 | SOI-060 · CHARACTER (单位) 行61 | 关键词/基础属性 |
| `59` | 遗忘之伞「多多良小伞」 | SOI-061 · CHARACTER (单位) 行62 | kogasa_flash |
| `60` | 大海的正义「村纱水蜜」 | SOI-062 · CHARACTER (单位) 行63 | murasa_aura |
| `62` | 邪术仙人「霍青娥」 | SOI-064 · CHARACTER (单位) 行65 | seiga_imp |
| `63` | 探宝队员「纳兹琳」 | UCS-081 · CHARACTER (单位) 行167 | nazrin_draw |
| `66` | 回声山彦「幽谷响子」 | SOI-068 · CHARACTER (单位) 行69 | kyouko_shuffle |
| `67` | 问答无用「云居一轮&云山」 | SOI-069 · CHARACTER (单位) 行70 | 关键词/基础属性 |
| `7` | 「蓬莱人偶」 | UCS-083 · CHARACTER (单位) 行169 | hourai_ping |
| `73` | 紧闭的恋之瞳「古明地恋」 | SOI-074 · CHARACTER (单位) 行75 | koishi_coin、koishi_evasion |
| `74` | 永远鲜红的幼月「蕾米莉亚·斯卡蕾特」 | SOI-075 · CHARACTER (单位) 行76 | remilia_lifelink、remilia_aura |
| `76` | 第三只眼「古明地觉」 | SOI-078 · CHARACTER (单位) 行79 | satori_scry、satori_discard |
| `77` | 七色的人偶使「爱丽丝·玛格特洛依德」 | UCS-074 · CHARACTER (单位) 行163 | alice_search、alice_recycle |
| `8` | 「上海人偶」 | UCS-084 · CHARACTER (单位) 行170 | shanghai_draw |
| `80` | 湖上的冰精「琪露诺」 | SOI-082 · CHARACTER (单位) 行83 | cirno_aura、cirno_return |
| `82` | 八坂的神风「八坂神奈子」 | SOI-084 · CHARACTER (单位) 行85 | kanako_pillar、kanako_blast |
| `85` | 永远与须臾的罪人「蓬莱山辉夜」 | UCS-090 · CHARACTER (单位) 行173 | kaguya_end |
| `86` | 四季鲜花之主「风见幽香」 | UCS-EX01 · CHARACTER (单位) 行332 | yuuka_ramp |
| `9` | 祈风之人「东风谷早苗」 | SOI-011 · CHARACTER (单位) 行12 | 关键词/基础属性 |
| `90` | 百鬼夜行「伊吹萃香」 | UCS-089 · CHARACTER (单位) 行172 | suika_attack、suika_counter |
| `93` | 土著神之顶「洩矢诹访子」 | SOI-095 · CHARACTER (单位) 行98 | suwako_top、suwako_haste |
| `97` | 「妖精ノ嬉游」 | SOI-100 · SPELL （符卡） 行5 | fairy_revive |
| `98` | 「天狗ノ晴岚」 | SOI-101 · SPELL （符卡） 行6 | tengu_pair |
| `spell-smm-006` | 「小憩」 | SMM-006 · SPELL （符卡） 行88 | rest_life |
| `spell-kmo-005` | 「春雪」 | KMO-005 · SPELL （符卡） 行79 | snow_time |
| `spell-kmo-004` | 「血族的末裔」 | KMO-004 · SPELL （符卡） 行78 | survivors |
| `character-smm01` | 小人的后裔「少名针妙丸」 | SMM01 · CHARACTER (单位) 行114 | shinmy_cast、shinmy_counter |
| `character-kmo-001` | 彼岸的渡者「小野冢小町」 | REC-013 · CHARACTER (单位) 行208 | komachi_minus、komachi_coins |
| `spell-kmo-002` | 死神「彼岸归航」 | KMO-002 · SPELL （符卡） 行76 | death_return |
| `character-smm07` | 祭祀风之人「东风谷早苗」 | SMM07 · CHARACTER (单位) 行116 | sanae_end、sanae_search |
| `spell-ucs-011` | 「Subterranean Rose」 | UCS-011 · SPELL （符卡） 行98 | coin_anthem |
| `spell-ucs-008` | 「人神ノ黎明景」 | UCS-008 · SPELL （符卡） 行96 | all_counters |
| `item-ucs-012` | 「河童背包」 | UCS-012 · ITEM {道具} 行15 | backpack |
| `spell-ucs-029` | 人符「现世斩」 | UCS-029 · SPELL （符卡） 行107 | kill_small |
| `spell-ucs-026` | 四天王奥义「三步坏废」 | UCS-026 · SPELL （符卡） 行105 | palette_wipe |
| `character-ucs-032` | 小夜岚的女仆「十六夜咲夜」 | UCS-032 · CHARACTER (单位) 行137 | sakuya_timer |
| `character-ucs-072` | 山坂与湖水的化身「八坂神奈子」 | UCS-072 · CHARACTER (单位) 行161 | kanako_cast、kanako_ten |
| `spell-ucs-019` | 幻想「第一种永久机关」 | UCS-019 · SPELL （符卡） 行102 | free_anthem |
| `character-ucs-071` | 惊天动地的唐伞妖怪「多多良小伞」 | UCS-071 · CHARACTER (单位) 行160 | kogasa_scare、kogasa_boost |
| `character-ucs-038` | 旧地狱的宠物妖怪「火焰猫燐」 | UCS-038 · CHARACTER (单位) 行140 | orin_discard |
| `character-ucs-069` | 星降之处的道士「丰聪耳神子」 | UCS-069 · CHARACTER (单位) 行158 | miko_divide、miko_discount |
| `character-ucs-048` | 「法兰西人偶」 | UCS-048 · CHARACTER (单位) 行145 | france_doll |
| `character-ucs-042` | 绿眼的无间妒嫉「水桥帕露西」 | UCS-042 · CHARACTER (单位) 行142 | parsee_catchup |
| `spell-ucs-014` | 转世「一条归桥」 | UCS-014 · SPELL （符卡） 行99 | reset_four |
| `spell-ucs-027` | 非想「非想非非想ノ剑」 | UCS-027 · SPELL （符卡） 行106 | color_damage |
| `token-ucs-099` | 半灵 | UCS-099 · TOKEN (衍生物） 行10 | 衍生物/关键词 |
