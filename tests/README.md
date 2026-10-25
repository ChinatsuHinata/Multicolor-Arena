# 当前功能测试

这里只保留验证当前游戏行为的专项测试。旧版本测试入口及配套 `.uid` 已清理，历史文档中的旧测试名称仅为当时的记录，不再作为验证命令。

测试按功能或卡牌命名。`support/` 保存规则、选牌、界面、响应与联机的公共辅助代码，不包含旧版本测试断言，也不单独运行。

常用入口：

绯红永夜模组扩充使用 `test_scarlet_moon.gd`：验证2黄2绿诵经妖怪的两种进场模式、墓地免费再用及过期、强制触发对手吸血鬼自机、时符复活与离场绑定、实际伤害与蝙蝠数量、额外准备阶段和神宝唯一性、道具极彩、搜寻及准备阶段结束回合。

| 功能 | 测试 |
| --- | --- |
| Limitless 快速导入、进行中赛事网页读取、账号 ID 保存与持久化、来源选手资格门控、管理员审核／拒绝／撤回、重复身份冲突与过期审核保护、桌面与安卓入口 | `test_limitless_admission.py`、`test_limitless_ui.gd`、`test_account_ui.gd`、`run_tournaments.py --limitless-only`（隔离临时数据库与回环中转；示例为好奇杯极彩十月月赛） |
| Limitless 来源签表与排名、用户账号对应、缺少上轮结果／下轮签表／完整选手／新鲜数据时禁止开轮、原桌号与签位、游戏结束等待来源确认、禁止本地裁定、异步同步与缓存持久化、限流和来源改签保护、来源最终排名奖励；历轮浏览和双端界面 | `test_limitless_tournaments.py`、`test_limitless_ui.gd`（离线临时数据；有界面运行时截图输出 `work/limitless-ui/`） |
| 桌面／安卓设置与对战内 60／120／自定义帧率档位、仅自定义可输入、无上下调节按钮、自定义数值记忆、0 不限帧、即时生效及保存重启 | `test_frame_rate_limit.gd`（有界面运行时保存截图） |
| 赛事创建与管理的自定义阶段表单、数值行文字换行与输入框高度、增删阶段及内容保留、桌面／安卓高 DPI 和安全区变化 | `test_tournament_layout.gd`（离线运行；有界面运行时截图输出 `work/tournament-layout-tests/`） |
| 多阶段瑞士／单败／双败／循环赛、BO5／BO2、大比分一致确认、积分提前晋级淘汰、跨阶段四强奖励及超管权限；线上教程提交审核与匿名同步、权限撤销、公告并发领取；bigcake 固定绑定超级管理员组、按账号／数字玩家 ID 赠予铜钱、越权拦截、金额校验、并发幂等与持久化、桌面鼠标／安卓触摸提交及余额同步、赠予离页后恢复重试不重复发放及账号隔离 | `test_competition_extensions.py`、`test_community_store.py`、`run_tournaments.py --formats-only`、`run_tournaments.py --community-only --render`（独立临时数据库与回环中转；截图输出 `work/tournament-tests/`） |
| 「永夜归还-待宵-」先确认双方套牌自机去向、完整复活名单、横置进场与结束阶段移除；夺取操控权、区域实例有效性、移除替代、衍生物及存档恢复 | `test_eternal_night_return.gd` |
| 颜色盘取消一张／多张选牌后重新分配已选牌颜色、合法替代牌与实际扣费、混色／减费备选费用、成对产色／红薯／保留色及双座位联机视图；桌面／安卓选目标与确认支付阶段 | `test_payment_reselection.gd`、`test_payment_reselection_ui.gd` |
| 自机表情五分饼图的桌面／安卓实际输入、响应权与弹框限制、十秒冷却、自机区／战场／离场锚点、双方座位的气泡方向、敌方未开通显示、投降及重复事件隔离、联机同步；真实第三方观战接收双方表情、双端两种视角显示全部台词及未开通的投降气泡，观战入口只读 | `test_leader_emotes.gd`、`test_leader_emotes_network.gd`、`test_leader_emotes_ui.gd`（有界面运行时保存截图） |
| 香霖堂开业酬宾醒目横幅、付费商品进入特价分类、商品图案右下角红色 5 折标、固定半价向上取整、北京时间 11 月 2 日零时自动结束、原价恢复与过期确认保护、账号购买与装备隔离、原子扣款与重复购买、灵梦入场与梦想妙珠免费领取及按座位播放、匿名授权及购买后联机发送 | `test_shop_store.py`、`test_shop_inventory.gd`、`test_shop_products.gd`、`test_shop_effects.gd`、`test_shop_ui.gd`、`test_shop_preview.gd`、`run_shop.py`（仅本机回环及临时数据库；商店 UI 有界面运行时保存截图） |
| 蕾米 AI 四个合法阻挡者停攻与夜王强化豁免、大量单位的阻挡组合上限、32／64 位移边界、双方共享截止时间、嵌套预算与模拟继承、80 单位真实决策及超时后的威吓阻挡回退 | `test_remilia_ai_budget.gd` |
| 辉光城两种卡牌的关押与释放：出鞘整批移除后释放、双方座位与单位控制方、满战场腾格、双方城堡同时离场、失效关押关系及普通离场进场触发；双端叠放显示与联机视角 | `test_castle_release.gd`、`test_castle_exile_display.gd` |
| 六根清净斩反制帕秋莉与其他分组目标能力、神奈子启动能力、分配伤害／多目标符卡、两种半灵、离场重进、六点伤害及双座位联机／存档；天ノ磐舟区分目标和费用 | `test_youmu_counter.gd` |
| 四费帕秋莉角色符触发的三点伤害受河童背包限制：双方座位的玩家／单位目标、支付与拒付、五色支付、零目标／己方目标、原符卡独立结算、联机支付权限及存档恢复；无目标符卡在普通／免费支付下拒付及双端“不支付”按钮 | `test_patchouli_backpack.gd`、`test_patchouli_backpack_ui.gd` |
| 双端樱花神社主题、经典主题切换与保存、安卓响应式设置保留、战斗背景及桌面紧凑堆叠 | `test_sakura_ui.gd`（有界面运行时保存截图） |
| 莲子梅莉梦违任意两点减费、空与海三黄／混色支付、推荐资源替换、双座位联机扣费、无效方案及来源限制、八云蓝叠加与额外加费 | `test_dream_discount.gd`、`test_dream_discount_ui.gd` |
| 朱鹭子首张道具任意减费、灵异珠改付蓝／黄／黑、双座位联机与支付界面、次数及来源条件、八云蓝／梦违叠加 | `test_tokiko_discount.gd`、`test_tokiko_discount_ui.gd` |
| 有顶ノ天、姬海棠果、妹红、吞食牌数、姐妹／木符的移除区授权及模组授权任意减费，验证全部颜色分配、草案与真实使用 | `test_any_color_discount.gd` |
| 魅力ノ四重结界搜寻四类牌、直接放入各类时符的计时、咲夜调整、杀人玩偶触发及其余牌入手 | `test_fourfold_barrier.gd` |
| 当前四种构筑规则集、官限限二、卡组代码与房间登记、已移除规则的本地及压缩代码迁移 | `test_deck_rule_sets.gd`、`test_deck_plaza_store.py`、`test_cloud_deck_store.py` |
| 幻想ノ秋司：官限构筑、卡图、红黄支付、自机区／额外自机与战场人类限制、颜色值不大于4的单位回拥有者手牌、目标失效、自机返回、响应／反制、联网查询与存档恢复、PC／安卓组卡预览 | `test_autumn_keeper.gd`、`test_autumn_keeper_ui.gd`（加 `-- --render` 保存截图） |
| 模组规则集与 BO1／BO1 换备牌／BO3 独立组合、组卡边界与代码、换备及再战、PC／安卓及局域网／云端选项、配置不一致拒绝玩家／观众／存档恢复、回环联机及重连 | `test_mod_importer.gd`、`test_mod_rule_sets.gd`、`test_mod_rooms.gd`、`test_mod_settings_ui.gd`（仅 127.0.0.1，临时存档在 work） |
| 可信模组接口：注册与第二卡包、组卡／支付／反制、可恢复多步结算、来源快照与复制、私密状态、双端界面、回环联机／观战及断线续接 | `test_mod_abilities.gd`、`test_mod_abilities_ui.gd`、`test_mod_abilities_network.gd`（仅 127.0.0.1，临时存档在 work） |
| 多个心之箱各自提供每回合一次墓地使用、声明失败／反制、来源离场与重新进场、时符移除替代及存档恢复 | `test_heart_box.gd` |
| 三费射命丸文自己及其他天狗回手制造新闻素材、多个来源各触发一次、自机返回区域选择、操控权及存档恢复 | `test_aya_news_material.gd` |
| 安卓仅供查看卡牌的原生点选、提示整行显示、卡牌说明及卡图空间、关闭保留草稿；无限制下点选全随机秘封自机 | `test_android_read_only_cards.gd`（加 `-- --render` 保存截图） |
| 全随机版梅莉／莲子自机的无限制及测试构筑、官限排除、规则切换、卡组代码、角色通配符及发现卡池隔离、广场上传校验 | `test_exploration_leader_construction.gd`、`test_deck_plaza_store.py` |
| 上次匹配卡组按账号／卡组 ID 跨重启记忆、删除或变为不合规时回退；双端挑战蕾米／其他卡组切换、内嵌卡组独立副本及不受本地 AI 卡组或打包源影响 | `test_match_deck_memory_and_challenge.gd` |
| 每账号十个私人云端槽、账号隔离、持久化、跨设备同步、编辑器保存及删除、旧设备冲突保护；双端卡图画廊、搜索与翻页、上传保留本地及草稿、独立下载；云端与广场下载仅在同名且卡牌构成完全相同时拒绝（忽略顺序及异画） | `test_cloud_deck_store.py`、`test_deck_downloads.gd`、`run_cloud_decks.py`（仅本机回环服务与临时账号数据库；加 `--render` 保存双端截图） |
| 断线归因：独立双向探测、房主／客人真实超时判负、单方伪造断线和控制帧隔离、同设备旧连接接替、重连不延长期限、服务器故障不误罚、恢复提示与结算证据持久化 | `test_match_recovery.gd`、`test_match_connection_timeout.gd`、`run_cloud_matchmaking.py --attribution-only`、`test_connection_resolution_store.py`、`test_gateway_connection_evidence.py`（仅本机回环连接与临时数据库） |
| 双端主菜单公告邮箱、未读红点及历史阅读、公告 ID 去重及补丁升级不重推、旧副本与已读记录迁移、跨版本历史保留、PCK 待重启隔离及安卓安全区域／返回 | `test_announcements.gd`（有界面运行时保存截图） |
| 公告铜钱实际鼠标／触摸领取、成功与超时反馈、失败重试、未登录、关闭后延迟回包及隐藏弹窗阻断回归 | `test_announcement_rewards_ui.gd`（有界面运行时保存截图到 `work/announcement-rewards-tests/`）、`run_tournaments.py --community-only`（真实加密领取、余额同步与公告关闭） |
| 比赛奖杯未读红点、分页检测、详情已读、账号隔离与重启保存、请求失败／退出账号及删除比赛、双端点击与布局 | `test_tournament_unread.gd`，通过 `run_tournaments.py --unread-only` 运行；加 `--render` 保存双端截图 |
| 探索幻想乡：双方固定 15／15／8／12 卡组、模式自机无原进场效果及说明、跨区域角色通配符、场上自机的拜访自机权重加成及离场恢复、四种发现牌的莉莉白颜色、梅莉／莲子／旅行包按实际颜色支付及减费模拟的余费保底（含道具、因幡帝黄绿成对支付、颜色盘与土豆，优先非 X，无符合条件非 X 时才保底 X；梅莉剩余 0 费时只按下回合预计费用保底，0 费单位仍保留普通抽选加成；梅莉剩余 6 费时保底 5／6 费各 1/2，剩余 7 费时保底 5／6／7 费分别为 1/6、1/2、1/3，先抽费用再抽卡，缺失费用按比例重分；莲子的探索剩余 7 费时也将可支付的 6 费牌纳入保底池）、俱乐部活动不保底、爆符／土符／小小军势／歌莉娅人形额外抽选权重 0.1 倍、雨夜怪谈 0.5 倍、宝永赤蛙／新幻想史 0.2 倍、其他限制级／终言维持原有权重、精确费用 4 倍与自机／高速／X 加成叠乘及三张同名去重、下回合总费／余费稀有权重、拒绝非法选择、存档恢复、人机全程让过及强制结算、试验 AI 隔离、桌面／安卓卡图点选及局域网双方同步／重开 | `test_gensokyo_exploration.gd`、`test_gensokyo_exploration_ui.gd`、`test_gensokyo_exploration_network.gd`（仅本机回环连接） |
| 天火人进场／死亡／攻击／阻挡的目标丢失、离场返回、防伤与来源离场；响子全部与部分目标丢失、至多一个目标继续结算、牺牲／弃牌费用隔离 | `test_ability_target_validity.gd` |
| 房主加入提醒：局域网申请与观战、云端入座及重复握手／换座去重，双端音量设置、试听、静音和重启保存 | `test_room_join_sound.gd` |
| BO1 换备牌：赛前公开自机、最多换入三张、重复提交与重连防绕过、单局结算和重开；桌面／安卓编辑器及本机云端中转同步 | `test_bo1_sideboard.gd`、`test_bo1_sideboard_ui.gd`、`test_bo1_sideboard_cloud.gd`（云端测试先启动 `support/cloud_resume_relay.gd -- --test-resume --bind 127.0.0.1 --port 48035 --transport websocket`） |
| 无目标牺牲、结晶、颜色盘选牌、伤害分配及给予防避的结算选择；响应中候选变化、费用区别、联机与观战同步 | `test_resolution_choices.gd`、`test_resolution_choices_ui.gd` |
| 红薯支付：桌面／安卓、2D／3D 及两种桌垫的真实点击、边缘容差、手指抖动、手牌开关避让、相邻卡牌优先与确认后消费 | `test_potato_payment_ui.gd`（加 `-- --android` 验证安卓界面；有界面运行时保存截图） |
| 青花结算：桌面／安卓仅从堆叠点选符卡，无其他符卡（含仅剩能力或符卡已离开）时显示反制自身按钮及实际结算 | `test_blue_flower.gd`、`test_blue_flower_ui.gd` |
| 双端主菜单两列排序、设置内关于及返回、教程三分类筛选与分页、完成状态持久化与横屏安全区域 | `test_main_menu_tutorial.gd`、`test_android_menu.gd` |
| 教程逐步目录、已读与未读跳转门控、跨重启组卡／战场／随机状态与场景恢复、历史回看、双端目录点击及布局、编辑器群组权限 | `test_tutorial_directory.gd` |
| 教程目录的动态卡牌定义持久化、末题青蛙已有记录恢复、法术衍生物与复制品、暂存场景恢复、损坏记录重读修复，以及目录跳题后的卡图与数值 | `test_tutorial_progress.gd`、`test_tutorial_tokens_and_surrender_ui.gd` |
| t1 蕾米莉亚课程：完整卡组、四张宵暗之翼与两张不夜城标红、讲解和答题卡图、颜色值 5 的答题及双端完成保存 | `test_tutorial_t1.gd` |
| 教学卡组自机／主卡组／副卡组 PC 右键、安卓原生长按详情与取消、关闭操作权限时的只读查看、普通对话无强制任务及显式任务门控 | `test_tutorial_interaction.gd` |
| 战场教程单步三种视角、双方墓地／移除区列表、真实卡牌红框、叠放实例区分、上一步与任务重置；覆盖双端 2D/3D 及两种教程入口 | `test_tutorial_battle_presentation.gd` |
| 教程人机条件阻挡：指定或多个单位、不阻挡、待选方与攻击者条件、威吓合法性、次数限制、讲解暂停、检查点与任务重置；兼容旧让过执行权规则 | `test_tutorial_opponent_block.gd`、`test_tutorial_lily_opponent.gd` |
| 教程人机条件出牌与启动能力：特定手牌实例或定义、能力键或序号、指定玩家／实例／堆叠／多组选牌与模式、真实支付及费用不足跳过、X 值、延迟选择、次数限制和重置恢复 | `test_tutorial_opponent_actions.gd` |
| 教程编辑器自动响应：默认开启／关闭与保存重开、显式规则优先及次数用尽回退、真实出牌／战斗与进场选择、玩家选择隔离、讲解／动画暂停和检查点恢复 | `test_tutorial_automatic_response.gd`、`test_tutorial_authoring_ui.gd` |
| 教程对话固定序列：双方凭依、出牌、能力、攻击和阻挡、预设投币／d6、途中检查点与原入口重播、双端自动隐藏及等待最终动画、重置演示按钮 | `test_tutorial_sequence.gd`、`test_tutorial_sequence_ui.gd` |
| 教程节点编辑器：节点增删、搜索、文字与失败跳转编辑，精简工具栏，当前四份 JSON 无损打开／保存，紧凑成败条件表单 | `test_tutorial_authoring.gd`、`test_tutorial_authoring_ui.gd` |
| 教程节点配图：明确选卡及异画版本、横竖卡筛选、多卡调序／逐项替换／移除、横排／纵排／网格及自定义图混排、草稿应用／取消、旧单图保留、内嵌 JSON 与原图删除后保存重开、非法配置校验、双端三种场景预览及逐图放大 | `test_tutorial_guide_image.gd` |
| 教程节点重命名：双击与按钮入口、回车确认／Esc 取消、重名和无效名称、中文名称、起点与跳转及嵌套条件引用修复、顺序与录制保留、撤销重做及保存重开 | `test_tutorial_node_rename.gd`、`test_tutorial_node_rename_ui.gd` |
| 教程初始配置：双方自机与有序牌库、卡牌搜索及批量增删、导入已保存卡组、别名和状态保留、主副卡组、取消与校验、课程保存及录制起点 | `test_tutorial_initial_scene_ui.gd` |
| 教程节点初始场面：双方全部区域 D 删除／C 复制、自机保护和副本保存、自机所在区域保存／重开／录制保留、颜色盘容量包含自机、右键初始血量、独立场景应用／取消、文本输入隔离、已有录制和起手调度保留 | `test_tutorial_setup_ui.gd`、`test_tutorial_recording.gd` |
| 教程顺序：实际阅读排序、上移／下移、长按拖拽及插入线、边缘滚动、过滤后的完整位置、起点与末尾同步、场景及录制保留、取消拖拽和排序保存 | `test_tutorial_order.gd`、`test_tutorial_order_ui.gd` |
| 桌面教程战场条件编辑：条件节点图、卡牌／玩家／区域箭头与点选修改，真实录制采样、局部条件替换、触发动作与对方响应重录，规则草稿应用／取消和已有录制隔离；攻击阻挡快捷设置、五种方案启用／排序、指定单位多选与保存重开 | `test_tutorial_condition_capture.gd`、`test_tutorial_condition_editor_ui.gd` |
| 教程攻击阻挡优先级：最大／最小、联合击杀、全体与指定单位、非法／不足回退、威吓与先制、防伤／不会被消灭、真实战斗、次数及检查点／任务重置 | `test_tutorial_block_priorities.gd` |
| 任务快捷对策：攻击者灵力最高／按对方单位数取前 x 名、增益与生成实例、动态数量、并列顺序、范围外自动放行、次数与检查点；界面切换、保存重开和取消 | `test_tutorial_attack_rank.gd`、`test_tutorial_condition_editor_ui.gd` |
| 桌面教程功能录制：真实组卡器、卡组查看与双方战斗，逐步生成节点，指定卡牌与区域检查，失败恢复；已有录制的流程箭头、步骤回溯、播放暂停、从中间重录、随机状态恢复和节点引用修复 | `test_tutorial_function_recording.gd`、`test_tutorial_recording.gd`、`test_tutorial_recording_history.gd`、`test_tutorial_recording_ui.gd` |
| 双端组卡、人机及局域网／云端卡组按钮、套牌画廊检索、翻页、取消与选择回填 | `test_deck_picker.gd` |
| 套牌广场登录、上传、异画、搜索、编辑器更新、所属玩家权限、下载；详情关注／取消关注、只看关注筛选及作者账号隐藏 | `test_deck_plaza.gd`、`test_deck_plaza_store.py` |
| 玩家账号初始 Elo 1000、已有账号迁移及重启保留、登录／自动登录传递、仅本人账号页展示及无改分接口 | `test_account_store.py`、`test_account_ui.gd` |
| 任务与铜钱：每日两初级一高级、嵌套等权抽签、06:00 北京时间换日、单次换新、手动领取与并发幂等、累计与最高值、赛季奖励；实际规则行为探针、双方证据一致确认、断线／旧端降级、平局重开与恢复；双端动态任务、红点、内存改值后同步恢复、账号隔离与安全区 | `test_tasks_store.py`、`test_task_probes.gd`、`test_task_relay.gd`、`test_task_network.gd`、`test_tasks_ui.gd`、`run_tasks.py`（本机回环与独立临时数据库；`--render` 输出到 `work/task-tests/`） |
| 比赛入口、登录返回、描述预览与自主报名、主办方修改描述和删除、必填比赛时间、到点关闭报名自动签到；五种指定对局赛制、BO3 两胜才回填、固定娱乐卡组、取消进行中比赛、不影响排位；瑞士轮与可选 2 / 4 / 8 / 16 强淘汰赛、种子编排、晋级与并列名次、双方确认结果、后台定时任务和双端布局 | `test_tournament_store.py`、`test_tournament_competition.py`、`test_tournaments.gd`、`test_tournament_rounds.gd`、`test_tournament_game_formats.gd`、`run_tournaments.py`（仅回环地址与临时数据库；`--rounds-only` 验证赛程，`--formats-only` 验证真实指定赛制，`--render` 输出双端截图到 `work/tournament-tests/`） |
| 自助修改密码：双端旧／新／确认表单门控、旧密码验证、服务端确认、过期及重放、错误次数限制、并发重置保护、双平台凭据清理及 64 位转义密码修改后重新登录 | `test_account_store.py`、`test_account_ui.gd`、`run_password_change.py`（仅回环地址和临时数据库） |
| 休闲／排位切换及保存、模式与队列人数隔离、无限制卡组登记／换备、双方重启恢复、观战结果、正常／断线结算与段位／星数／连胜／Elo 不变 | `test_match_queue.gd`、`test_ranked_relay.gd`、`test_match_store.py`、`test_matchmaking_ui.gd`、`run_cloud_matchmaking.py --casual-only`（运行 `test_casual_matchmaking.gd`） |
| 娱乐大模式与子模式选择、设置迁移／保存、PC／安卓及云端／局域网房间选择、房主切换权限与双方准备清除；探索幻想乡全随机版四种对应卡池等概率抽取、无费用或颜色筛选／保底／加权、三张同名去重及卡池不足处理、真实选牌及存档恢复 | `test_entertainment_modes_ui.gd`、`test_gensokyo_exploration_random.gd` |
| 娱乐玩法独立队列、不限段位、房主切换权限与双端同步、固定卡组开战、公开观战、双方重启恢复、真实投降结算及段位／星数／连胜／Elo 保持不变 | `test_match_queue.gd`、`run_cloud_matchmaking.py --exploration-only` 及加 `--random`（运行 `test_exploration_matchmaking.gd`） |
| 云端自动匹配固定官限、禁卡与限二卡登记／换备校验、同大段位全部级别立即匹配及优先、每 20 秒上下扩张一个大段位、仅观战房间列表及座位释放、BO1 自机卡图与右键／原生长按详情、匹配后赛前准备无退出入口、断线恢复、双方结算与私人 Elo 持久化、完成后房间清理、双端等待／取消界面 | `test_match_queue.gd`、`test_ranked_relay.gd`、`test_match_store.py`、`test_bo1_sideboard_ui.gd`、`test_matchmaking_ui.gd`、`run_cloud_matchmaking.py` |
| 排位段位升降与保护、晋级星数截断、贤者排名及持久化；入队前卡组锁定、队列人数、六边形头像、双端换备页对方段位／星数／贤者名次及重连保留、五段位图文规则弹窗及关闭后保留排队、安卓无滚动主页 | `test_rank_progression.py`、`test_matchmaking_ui.gd`、`test_android_menu.gd`、`run_cloud_matchmaking.py` |
| 匹配后离开／意外退出再入队、旧连接替换、断线及握手卡住 60 秒自动释放、重试／重启不重置期限、账户校验请求去重、结算完成后自动排队及取消清理 | `test_match_recovery.gd`、`test_match_connection_timeout.gd`、`run_cloud_matchmaking.py --recovery-only`（临时数据库与回环中转，运行 `test_match_recovery_network.gd`） |
| 桌面／安卓从对局返回云端自动连接、正常结束／房间失效后的直接返回、房主／玩家／观战位及手动／排位／休闲／探索模式、退出大厅关闭连接 | `test_match_room_exit_ui.gd` |
| 失效或超时匹配的桌面／安卓房主／客机退出、房间按钮及菜单返回清理、重新进入云端入口，以及未结算匹配的退出限制 | `test_match_room_exit_ui.gd` |
| 排位／休闲／探索匹配首次握手后的双方准备状态、双方选择权及桌面／安卓界面一致、不依赖观战刷新、实际先后手选择与开战 | `test_match_preparation_sync.gd`、`run_cloud_matchmaking.py`、`run_cloud_matchmaking.py --casual-only`、`run_cloud_matchmaking.py --exploration-only` |
| 匹配断线移除不再等待、客机／房主重启自动登录并恢复原战场、结算清理与账号隔离 | `test_disconnect_wait_ui.gd`、`run_cloud_matchmaking.py --restart-only`（临时数据库与回环中转，运行 `test_ranked_restart.gd`） |
| 探索幻想乡云端房间双方固定卡组、房主在一／二号位、观战回对战位及双方准备、桌面／安卓准备按钮与投骰结果 | `test_exploration_room_ui.gd`、`run_cloud_matchmaking.py --exploration-only`（包含手动房间与自动匹配） |
| 六名不同 Elo 客户端同时排队、实际等待 20 秒后扩张大段位范围、三个仅观战匹配房间及双方成功提醒去重 | `run_cloud_matchmaking.py --simulation-only`（运行 `test_matchmaking_simulation.gd`） |
| 卡库加载 | `test_database_load.gd` |
| 商店每页四件、上一页／下一页边界、搜索自机名／称号／ID、隐藏已购、我的商品搜索、购买后末页回退、键盘焦点及桌面／安卓触控布局；服务端原价购买、余额与重试、匿名授权及实际对战表情 | `test_shop_ui.gd`、`test_shop_store.py`、`test_shop_products.gd`、`run_shop.py`（本机回环及独立临时数据库） |
| 商店对话／入场／符卡预览、安卓详情入口、六种台词无冷却与投降隔离、特效单品循环与释放、模拟战场操作封锁、焦点与返回恢复、触摸与安全区；不改变购买、装备及任务状态 | `test_shop_preview.gd`（特效使用内存测试清单；有界面运行时保存双端截图） |
| 五费封兽的变形、失去防避及额外能力、妖精居所联动、指示物与数值保留、寅丸星独立下一次防伤、原单位详情、衍生物多色零费，以及存档／双端联机／观战显示 | `test_nue_transformation.gd`、`test_nue_transformation_ui.gd`（有界面运行时保存截图） |
| 组卡器卡牌排序与主副卡交换 | `test_deck_drag_order.gd` |
| 五种共享菜单上的提示／确认框、购买取消／确认／返回键、文件选择／下拉菜单／更新进度窗；桌面与安卓实际点击、触摸及截图像素验证 | `test_dialog_layers.gd`（有界面运行时截图输出到 `work/dialog-layer-tests/`） |
| 组卡双列无滚动菜单、战斗置顶弹窗、背景点击／触摸／快捷键隔离、测试工具入口与投降确认 | `test_menu_modal.gd` |
| 安卓图鉴两行四列八张完整卡面、顶部搜索／筛选、两侧翻页、颜色多选、原触控尺寸、高 DPI 安全区域与管理栏滚动 | `test_android_deck_gallery_layout.gd` |
| 安卓组卡翻页、搜索与筛选保留、长按详情、详情加牌／移除及右上角余量、主副卡交换、卡组页拖动及返回菜单 | `test_android_deck_editor.gd`、`test_android_deck_gallery_layout.gd` |
| 双端战场单位每六个一页、独立翻页／循环／末页离场回退、颜色盘十张分页及 2D／3D、双方聚焦、平移缩放、高 DPI 安全区域与确认面板下的翻页按钮可见性、占格数量提示、免占格与扩容及视角切换 | `test_battlefield_paging_ui.gd` |
| 安卓组卡大图详情在低分辨率／高 DPI／安全区域内完整显示、长说明原生滑动、加牌按钮可触摸、关闭／背景触摸／返回键及布局重建保留草稿 | `test_android_deck_details.gd`（`-- --render` 保存截图） |
| PC 组卡器原有三栏布局、滚动卡库、横向颜色按钮、类型选项与搜索行为 | `test_desktop_ui_rollback.gd` |
| 安卓右侧主卡组上下滑动、慢速和斜向手势、滚动边界及短列表误拖拽 | `test_android_deck_scroll.gd` |
| 安卓所有牌默认长按 0.5 秒详情、可调时长、触点圆环、轻触行动、滑动取消与记录排版 | `test_android_card_details.gd`、`test_android_preview_hold_setting.gd` |
| 安卓战斗中双方战场单位长按详情、普通／常驻／继承能力、2D／3D、先到的触摸模拟鼠标事件、单位边缘触摸容差、手指抖动、原生拖动排序及切换应用中止长按；有界面运行时保存截图 | `test_android_battle_unit_details.gd` |
| 卡牌别名、完整说明和能力文字检索、双端组卡器及各处搜索选牌 | `test_card_search_aliases.gd`、`test_card_search_aliases_ui.gd` |
| 对局规则 | `test_duel_rules.gd` |
| 审ノ视夺取套牌自机不自动授予自机能力、神社／自机指示物授予与归还、觉恋传递及探索角色通配；幽幽子按死亡前操控方触发，含衍生物、自机返回、同时死亡、每回合次数及存档恢复 | `test_leader_control.gd` |
| 自机从手牌、颜色盘、牌库、墓地及移除区移动的去向选择，真实凭依、抓牌、回合补盘、弃牌等待与存档恢复；桌面／安卓居中去向弹窗、隐藏恢复与小屏安全区域、非死亡返回二次确认、取消保留去向、死亡直接返回及过期选择隔离 | `test_leader_zone_moves.gd`、`test_leader_return_ui.gd` |
| 双方提交后统一起手调度、私密选择、重复提交、存档恢复及提交顺序一致；桌面／安卓双方预选后任一方确认、云端回执暂停与重复快照保留另一方选择，断线／新对局／手牌变化清理 | `test_mulligan.gd`、`test_mulligan_selection_ui.gd`、`run_cloud_matchmaking.py` |
| 桌面／安卓战后右下角返回、保存或不保存回放、匹配结算断线后的返回 | `test_battle_result_ui.gd` |
| 对局记录点击详情、能力整批展示与同名副本、历史异画与隐藏牌保护、续接／重连／观战／录像保留、双端滚动及返回 | `test_battle_history.gd`、`test_battle_history_ui.gd` |
| 展示牌整批确认：能力／符卡与后续选择、双方操作锁定、确认权限与重复请求、隐藏牌快照、重连恢复、观战及桌面／安卓截图 | `test_reveal_review.gd`、`test_reveal_review_network.gd`、`test_reveal_review_ui.gd` |
| 双人赛制自动指定唯一对手、模式与可选目标保留、慧音吞食费用前的荷取保护检查、背包追加支付及联机校验 | `test_opponent_targeting.gd`、`test_opponent_targeting_ui.gd` |
| 新幻想史－现代史：先检查移除区使用资格，慧音在场与自己的吞食指示物、木符／清兰授权，前两张豁免自机颜色和角色单位约束、免费使用、离场后提交重查及回合到期 | `test_new_history.gd` |
| 伊吹瓢己方回合开始自动复原、对方回合保持横置、红绿付费重置及再次启动、费用不足不改变状态 | `test_ibuki_gourd.gd` |
| 安卓慧音大量牺牲与吞食的 2D／3D 表现恢复、独立堆叠、衍生物离场、展示顺序、隐藏牌及动画取消 | `test_keine_sacrifice_ui.gd` |
| 二重结界整回合光环：双方后续使用／效果／衍生物／批量进场、控制权变化、指示物与加成、回合恢复及联机／观战同步 | `test_double_barrier.gd` |
| 永久物范围、自机、时符与乐章，以及相关符卡的目标、清场、保护和离场触发 | `test_permanents.gd` |
| 神ノ风、莱瓦汀、夜ノ蝶及神祭的己方道具支付／目标切换、支付已满时防误选、多目标与真实结算，桌面／安卓及 2D／3D | `test_item_payment_target_ui.gd` |
| 先制伤害后的双方响应、堆叠结算与普通单位反击顺序 | `test_first_strike_response.gd` |
| 连挡伤害全部手动分配、确认按钮门控、观察与重建保留、零伤害及双端提交 | `test_combat_damage_assignment_ui.gd` |
| 双端展示／检索卡图网格、多选统一确认、同名与灵力合计限制、游戏外选牌、不足一行从左排列，以及梅莉／莲子收集歌曲必选现有每种各一张、三种去向可跳过和联机校验 | `test_card_art_selection_ui.gd`、`test_song_collection.gd` |
| 双端 X 手动输入、合法值与上限预计算、倍率／减费／代付／目标加费、重选及联机校验；使用时完整 X 费用、使用触发／反制／复制／存档与双端堆叠及详情数值 | `test_variable_x.gd`、`test_variable_x_ui.gd` |
| 双端效果弹窗、左下隐藏与选择恢复、延迟回合结束设置及保存、主要阶段连续长按 2 秒及圆环取消／提交、关闭延迟或测试模式点按结束 | `test_battle_choice_hold.gd` |
| 常置阵双方全部单位（含未横置单位与自机）的目标合法性、横置历史与结算时检查、灵梦颜色盘回手，以及双端 2D/3D 隐藏／展开、空场菜单与目标取消、触摸重选和真实启动 | `test_standing_blast.gd`、`test_standing_blast_ui.gd` |
| 多项能力／效果居中等宽分列，长文字缩小与截断、常见选项免滚动，战场直接点选目标、右侧确认与双端小屏布局 | `test_battle_choice_placement.gd` |
| 颜色盘目标优先于支付资源、连续点选指示物与真实异能结算 | `test_card_name_target_picker_ui.gd` |
| 双端能力弹窗隐藏／展开按钮与堆叠卡牌、下方操作及菜单之间的避让，高密度安卓折叠后的堆叠可见性 | `test_battle_choice_overlap.gd` |
| 反制符卡与启动能力的堆叠避让、灵击展示后的堆叠点选、后续分组需要堆叠时提前避让 | `test_stack_interaction_popup.gd` |
| 双端连续触发及滚动后的箭头保留、赤蛙同时进场互相指定、小町死价双亡语的墓地检索标记、结算后续选择与联机／观战同步 | `test_stack_target_persistence.gd` |
| 同时触发的居中竖向列表、鼠标／原生触摸拖动及边缘滚动、整组确认与堆叠结算顺序、目标选择／存档恢复、联机权限与教程录制回放 | `test_trigger_order.gd`、`test_trigger_order_ui.gd` |
| 叠放牌合并、要石首次/连续生成时立即合并、数量输入与批量牺牲、独立实体及被指定实体的交互 | `test_stackable.gd` |
| 全部复制效应的指示物、负指示物与白莲 X 费反制支付 | `test_copy_counters.gd`、`test_minus_counters.gd` |
| 妖精们的居所：全部能力／关键词继承、同名妖精多份能力的独立触发与常驻叠加、来源离场、复制品、强制触发与存档恢复、双端详情及行动菜单份数 | `test_fairy_habitat.gd`、`test_fairy_habitat_keywords.gd`、`test_fairy_habitat_duplicates.gd`、`test_fairy_habitat_ui.gd`（加 `-- --android` 验证安卓界面） |
| 衍生物独立种族、蝙蝠／幻象种族与牌面一致、袿姬复制保留原种族、种族效果及状态恢复 | `test_token_races.gd` |
| 莉格露虫群在进场前具有全部种族：针妙丸／妖精叠奏曲／赤蛙进场触发、种族加成与保护、牺牲／选牌、满场进场及复制／存档恢复 | `test_wriggle_swarm.gd` |
| 御柱种族效果：莉格露虫群与御柱的偶像复制品可支付五费神奈子的牺牲费用；神明ノ威光按神／御柱种族授予追击，含真实战斗触发、离场与存档恢复 | `test_pillar_effects.gd` |
| 神子十二阶指定单位必定参战并与额外阻挡者连挡分伤／反击、威吓人数、先制与离场、死亡扣血、重置、存档／录像目标及芙兰直接攻击区别；桌面／安卓额外阻挡确认与分伤界面 | `test_twelve_ranks.gd`、`test_combat_damage_assignment_ui.gd` |
| 芙兰乐章：对方自机被消灭／移除后返回自机区或留在原去向、存档恢复、先制直接攻击与歼灭、同时死亡、离场前操控者、非死亡返回及回合结束加成清除 | `test_flandre_melody.gd` |
| 云集雾散目标加费、冰之勇者横置、猫车消灭、妖梦决斗与支付界面 | `test_mist_target_tax.gd`、`test_mist_unit_abilities.gd`、`test_mist_target_tax_ui.gd` |
| 赤眼催眠重选目标、凤翼天翔使用时分配伤害、铃仙乐章幻象存活与名称提示 | `test_reisen.gd`、`test_reisen_ui.gd` |
| 摩多罗的牌库顶预览与自机牌颜色约束 | `test_okina_color_bypass.gd`、`test_okina_ui.gd` |
| 奇迹展示、留在手牌的响应窗口、弃置／反制／使用限制、结算时选目标、联机／观战与双端界面 | `test_miracle.gd`、`test_miracle_ui.gd` |
| 衍生物同时制造 | `test_token_creation.gd` |
| 秋静叶：符卡／能力制造红黄单位衍生物、实际颜色与复制、逐个进场触发、可选展示及战场容量；手牌发动前私密选择、放弃不入堆叠或留下记录、双方／观战隐藏、存档恢复及同批选择 | `test_autumn_entry.gd` |
| 蕾米速攻专用 AI | `test_remilia_aggro_ai.gd` |
| AI 小蕾米回手、重新登场与死亡去向 | `test_remilia_return_ai.gd` |
| 蕾米前期凭依保留展开、结晶大单位与保护直伤 | `test_remilia_resource_ai.gd` |
| 不夜城小单位吸血、核心击杀线、灵梦对策协调与玩家斩杀 | `test_remilia_red_ai.gd` |
| 人类标注对应的 AI 决策与真实录像复现 | `test_ai_human_annotations.gd` |
| 可建模局面、真实动作环境、隐藏信息与条件神枪留费 | `test_ai_environment.gd` |
| 按对手自机分类、实验模型选择与通用回退 | `test_ai_matchups.gd`、`tools/ai/test_matchup_models.py` |
| 发行 AI 自机对策、灵梦封印留费／凭依夜王、系缚阵牺牲 | `test_release_counterplay.gd` |
| 灵梦小单位试探、实伤补枪与夜王兑换核心 | `test_reimu_probe_ai.gd` |
| 本机试验 AI 开关、实战调用与安装版禁用 | `test_experimental_ai.gd`、`test_experimental_ai_ui.gd` |
| 八云蓝减费开关 | `test_ran_discount.gd`、`test_ran_discount_ui.gd` |
| 杀人玩偶空场自动跳过开关、独立状态及联机同步 | `test_murder_dolls_skip.gd`、`test_murder_dolls_skip_ui.gd`（加 `-- --android` 验证安卓界面） |
| 颜色盘诅咒任意减费、四重结界混色支付、飞光虫之巢零费使用、界面与联机校验 | `test_curse_discount.gd`、`test_curse_discount_ui.gd` |
| 椛的宣称与支付限制 | `test_momiji.gd`、`test_momiji_ui.gd` |
| 符卡伤害预览 | `test_spell_damage_preview.gd`、`test_spell_damage_preview_ui.gd` |
| 永琳天人系谱：伤害排除自身、其他同名符卡与本次送墓计数、双方使用、选择恢复及符卡复制 | `test_heaven_genealogy.gd` |
| 游星弹幕与平安京卡图 | `test_wandering_barrage.gd`、`test_unknown_card_art_ui.gd` |
| 额外条件提示 | `test_card_condition_hints.gd`、`test_card_condition_hints_ui.gd` |
| 双端 PCK 补丁签名、基底版本、平台、内容校验及设置入口 | `test_pck_patch.gd`、`test_pck_patch_ui.gd` |
| 登录后 PCK 版本链选路、整批下载和原子安装、失败保留旧链、待重启去重及旧管理器兼容 | `test_pck_auto_update.gd`、`test_pck_patch.gd` |
| 隔离 HTTP 服务三段 PCK 连续下载、Windows／安卓平台校验、传输失败／损坏／断链回滚、重试及测试签名隔离 | `test_pck_download_chain.gd`（`--prepare/--run`；仅接受 `TEST_ONLY-` 目录和回环地址） |
| PCK 发布清单合并、同版本覆盖、历史依赖保护、云端清单并发变更及暂存哈希校验 | `test_pck_publish_chain.ps1`、`test_publish_pck_update.ps1`、`relay/test_update_gateway.py` |
| 阵雨与火的磨牌触发 | `test_rain_fire_mill.gd` |
| 测谎仪抓牌、低费使用与非抓牌入手 | `test_lie_detector.gd` |
| 响应与攻击快捷键 | `test_response_shortcut.gd`、`test_attack_shortcut.gd` |
| 每次响应 240 秒、最后 30 秒倒计时、选牌／支付／设置不重置；人机超时自动让过，联机超时整场判负、保留真实局分、清理恢复记录并释放连接／观战监听／房间；云端房主二号位、自建 BO3、排位 Elo 结算及立即重新匹配 | `test_response_timeout.gd`、`test_network_response_timeout.gd`、`run_cloud_matchmaking.py --response-timeout-only`（运行 `test_cloud_response_timeout.gd`，仅本机回环连接、临时数据库与存档） |
| 安卓触控、返回及桌面差异 | `test_android_controls.gd` |
| 安卓原生返回键拦截退出、等同取消、顶层弹窗优先、组卡草稿保留、出牌／攻击预览取消及桌面隔离 | `test_android_system_back.gd` |
| 安卓墓地与除外区悬浮图标及点击区扩大 1.5 倍、原生边缘点击、长按 1 秒圆环后拖动、手指抖动／鼠标回声／取消、安全区、设置保存、黑洞左移、除外区双方切换及桌面隔离；有界面运行时保存效果图 | `test_android_zone_shortcuts.gd` |
| 安卓战斗选项空间、莉莉黑颜色选择与堆叠区避让底部操作 | `test_android_battle_choices.gd`、`test_android_battle_layout.gd` |
| 安卓右下角两至三个能力选项免滚动、帕秋莉符卡展示移除后的使用／不使用、原生触摸及高密度联机提示与堆叠避让 | `test_android_ability_options.gd` |
| 安卓战场／颜色盘移动视角、2D／3D 投影、手牌避让、敌方颜色盘查看、触摸切换、视角复原与桌面隔离；有界面运行时保存截图 | `test_android_camera_focus.gd` |
| 安卓战场视角直接框住我方颜色盘：两种桌垫、2D／3D、五组分辨率下十张颜色盘不被手牌／状态条／临时提示遮挡且仍在取景框内、可点选，手牌 1／4／8 张变化，状态条与对局日志共用一行；有界面运行时保存截图 | `test_android_battlefield_palette.gd` |
| 安卓双方颜色盘与战场连续切换、动画中途复原、拥挤布局和临时一像素对焦区域的远距跳转回归，覆盖双方座位、2D／3D 与两种桌垫 | `test_android_camera_stability.gd` |
| 安卓凭依、结晶及付费自动聚焦我方，贫乏、破坏颜色盘与墓地能力选择聚焦敌方，退出还原位置和缩放，手动视角默认关闭及设置保存；有界面运行时保存截图 | `test_android_automatic_focus.gd` |
| 安卓皮丝、布都真实结算的敌方颜色盘选牌，五组分辨率／触摸密度下的 2D／3D 能力框避让、触摸确认、重选、隐藏／展开与视角还原；有界面运行时保存截图 | `test_android_palette_targets.gd` |
| 安卓使用牌区域入口、五种区域切换、慧音吞食对方牌的使用与支付取消、三种视角及高密度 2D／3D 避让、桌面页签保留；有界面运行时保存截图 | `test_android_cast_zones.gd` |
| 安卓弹窗容量、60 个长选项、40 项右侧菜单、联机堆叠避让及空颜色盘提示 | `test_android_popup_capacity.gd` |
| 联机状态保存与投影 | `test_network_state.gd` |
| 悔棋回到双方可操作的战况：主要阶段刚开始回到首次凭依前，之后的操作逐项回退、其他阶段保留合法响应；段位匹配每局双方总计五次请求（拒绝／取消也计数）、次数保存恢复与双端菜单、观战同步与回放裁剪、自动推进暂停 | `test_undo_checkpoints.gd`、`test_network_undo.gd`、`test_undo_ui.gd` |
| 回放双方完整手牌与结束后同步 | `test_replay_hands.gd`、`test_replay_hands_ui.gd` |
| 回放训练标注、文件与界面 | `test_replay_training.gd`、`test_replay_training_ui.gd` |
| 联机与断线恢复 | `test_network.gd`、`test_disconnect_wait_ui.gd` |
| 安卓应用暂停／恢复、前台心跳与排队包、云端房主／客机／观战位／房间列表自动恢复及战场状态保留 | `test_android_cloud_resume.gd`（先启动 `support/cloud_resume_relay.gd -- --test-resume --bind 127.0.0.1 --port 47974 --transport websocket`，仅使用回环地址和测试身份） |
| 双端移除网络聊天、旧聊天消息忽略及局域网／云端玩家和观战界面 | `test_network_chat_removed.gd`、`test_network_chat_removed_ui.gd` |
| 联机界面与主副卡组调整 | `test_network_ui.gd` |
| 联机画廊换组即时登记、取消准备、同组重选同步恢复、房主／客机双端新卡组开局与再来一场 | `test_network_deck_switch.gd`、`test_deck_picker.gd` |
| 自动更新下载进度、隐藏后恢复弹窗、更新期间及安装后云端入口限制 | `test_pck_download_ui.gd`、`test_pck_auto_update.gd` |

ECS 公网更新链可手动运行 `test_pck_ecs_update.gd`。测试从自动更新器的基底版本下载真实签名补丁到隔离的 `work/pck-ecs-update-test`，验证弹窗、进入限制、完整进度及安装，然后清理测试目录；需要允许访问公网更新网关。
| 卡组异画、选择界面与联机同步 | `test_alternate_art.gd`、`test_alternate_art_ui.gd`、`test_alternate_art_network.gd` |

任务条件的中途生成实例由 `test_tutorial_condition_capture.gd` 和 `test_tutorial_condition_editor_ui.gd` 覆盖：实际支付并生成两个同名衍生物、独立实例选择、全部卡牌条件求值、生成前与消失后的判定、录制回退、任务重置、保存重开及已有录制边界编辑。

场景触发器卡片、触发时机／条件／响应切换、直接选牌与目标、异能指定方式和 1600×900、1280×720、1280×600 布局由 `test_tutorial_condition_editor_ui.gd` 覆盖。`test_tutorial_authoring.gd`、`test_tutorial_authoring_ui.gd` 验证直接试玩选中任务、完成条件、当前任务重置、后续组卡任务后台还原、规则复制／删除／取消与文档隔离；`test_tutorial_recording_ui.gd` 验证既有录制在新试玩入口中正常执行。

在项目根目录选择与本次改动相关的入口运行，例如：

```powershell
& '.\.godot-toolchain\editor\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_ran_discount.gd
```

新增发行卡组补发：`test_bundled_deck_updates.gd` 覆盖旧目录、空卡组目录、已有改名/修改卡组、重复启动与主动删除；`test_card_search_aliases.gd`、`test_card_search_aliases_ui.gd` 覆盖转转、夜雀及烤八目鳗。`tools/check-release-package.ps1` 对实际 PCK 验证卡组、升级清单、AI 脚本加载与蕾米调度行动。

正式模板的卡组交付和人机界面检查使用 `tools/check-release-runtime.ps1 -ExePath <导出的EXE路径>`；它将 EXE 的原样副本与隔离验证入口放在 `work/release-deck-runtime/`，挂载未修改的游戏 PCK，执行 `test_release_deck_runtime.gd`，不读写玩家安装目录。

仅检查语法与加载关系时，在命令中加入 `--check-only`。不要批量运行历史版本测试，也不要为通过测试而恢复过时预期。

模组常驻、替代与外部卡包：`test_testmod.gd` 验证testmod卡、无前缀卡名与日文书名号／片假名ノ、参拜者多副本共存、融合炉选牌／即时免费使用／棒的进场与牌库除外触发／所有权和存档恢复、修正层和依赖；`test_mod_rooms.gd` 验证真实本机联机的配置一致性、观战和重连；`test_mod_settings_ui.gd` 验证桌面／安卓 ZIP 文件导入、新版自动替换与即时加载、同版与不规范包拒绝、删除确认／取消、房间内禁止修改、未应用勾选跨刷新保留、返回保存／放弃／取消与保存失败、设置选择、编辑器卡名、外部脚本加载及融合炉回收棒的多选交互。样例源在 `examples/testmod/`，导出时排除。

模组 ZIP 安装及删除：`test_mod_importer.gd` 验证根目录和单层目录包、本地 mod 路径、停用导入、数字／预发布版本比较、新版替换与保留启用状态、旧文件清理、同版／旧版拒绝、脚本和卡牌即时刷新、删除／重新安装、旧外部目录升级迁移及仅移除登记、缺失目录登记清理、清单／脚本／卡牌／图片、路径越界与大小写冲突、CRC／大小／加密／符号链接及安装／更新／删除时配置写入失败回滚。

安卓实测入口：独立测试应用的 Node 场景挂载 `support/mod_import_device.gd`，运行与 PC 相同的安装校验后打开安卓原生文件选择器；选择有效模组 ZIP，验证下载目录导入、应用本地 mod 安装及重复拒绝。测试包使用独立包名，避免改动正式游戏数据。

本次牌文修正：`test_testmod.gd` 覆盖融合炉洗回0–2张棒与即时免费使用、两根棒先抓后移除、指定伤害、红绿3/3/2御柱；`test_byakuren_target_tax.gd` 验证圣白莲对符卡及能力的目标附加费用；`test_purple_cloud.gd` 覆盖紫云之兆先付费后按最终X选符卡、可选加倍、无匹配无效果与存档恢复。联机和设置UI专项改为验证融合炉的选择与断线恢复。

模块化特效：`test_fx_module.gd` 只遍历 `fx/definitions/`，不启动对战也不加载卡牌库——校验清单（id 与文件名一致、品类合法、脚本必须在 `fx/modules/` 下）、每个模块独立建起／按预算收尾／释放 `holder` 不留节点、节点数上限、闪卡平面层高 `y ∈ [0.019, 0.055]`、模块源码不引用本体文件（`duel_table`、`duel_view`、`scripts/rules`、`CARD_SIZE`、`Time.get_ticks`），以及 `free`／已装备商品的启用判定。`-- --only=<id>` 只跑单个特效；`fx/fx_showcase.gd` 提供非 headless 的单特效预览截图。新增特效不需要改这份测试。

模块化特效接通：`test_fx_integration.gd` 真开一局验证本体三处接线——台面挂上 `FxStage`、清单零错误、单位入场只触发一次且重渲染不重播、卡面挂上闪卡且层高合法、符卡提交后落到 `FxLayer_spell` 并按预算自释放、单位离场后挂在其上的模块随节点失效、未装备的付费特效保持关闭。清单由 `support/fx_registry_fixture.gd` 在内存中提供，直接使用无视觉内容的品类基类，不在正式对局中注册测试特效；`test_fx_module.gd` 同时覆盖空清单不生成节点。改本体接线或 `fx/fx_*.gd`、`fx/categories/*` 时跑它；新增单个特效不必跑。
