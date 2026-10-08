# 当前功能测试

这里只保留验证当前游戏行为的专项测试。旧版本测试入口及配套 `.uid` 已清理，历史文档中的旧测试名称仅为当时的记录，不再作为验证命令。

测试按功能或卡牌命名。`support/` 保存规则、选牌、界面、响应与联机的公共辅助代码，不包含旧版本测试断言，也不单独运行。

常用入口：

| 功能 | 测试 |
| --- | --- |
| 房主加入提醒：局域网申请与观战、云端入座及重复握手／换座去重，双端音量设置、试听、静音和重启保存 | `test_room_join_sound.gd` |
| BO1 换备牌：赛前公开自机、最多换入三张、重复提交与重连防绕过、单局结算和重开；桌面／安卓编辑器及本机云端中转同步 | `test_bo1_sideboard.gd`、`test_bo1_sideboard_ui.gd`、`test_bo1_sideboard_cloud.gd`（云端测试先启动 `support/cloud_resume_relay.gd -- --test-resume --bind 127.0.0.1 --port 48035 --transport websocket`） |
| 无目标牺牲、结晶、颜色盘选牌、伤害分配及给予防避的结算选择；响应中候选变化、费用区别、联机与观战同步 | `test_resolution_choices.gd`、`test_resolution_choices_ui.gd` |
| 青花结算：桌面／安卓仅从堆叠点选符卡，无其他符卡（含仅剩能力或符卡已离开）时显示反制自身按钮及实际结算 | `test_blue_flower.gd`、`test_blue_flower_ui.gd` |
| 双端主菜单两列排序、设置内关于及返回、教程三分类筛选与分页、完成状态持久化与横屏安全区域 | `test_main_menu_tutorial.gd`、`test_android_menu.gd` |
| 教程逐步目录、已读与未读跳转门控、跨重启组卡／战场／随机状态与场景恢复、历史回看、双端目录点击及布局、发行版与安卓编辑器屏蔽 | `test_tutorial_directory.gd` |
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
| 自助修改密码：双端旧／新／确认表单门控、旧密码验证、服务端确认、过期及重放、错误次数限制、并发重置保护、双平台凭据清理及 64 位转义密码修改后重新登录 | `test_account_store.py`、`test_account_ui.gd`、`run_password_change.py`（仅回环地址和临时数据库） |
| 云端自动匹配固定官限、禁卡与限二卡登记／换备校验、近分优先、等待一分钟后逐步放宽、仅观战房间列表及座位释放、BO1 自机卡图与右键／原生长按详情、断线恢复、双方结算与私人 Elo 持久化、完成后房间清理、双端等待／取消界面 | `test_match_queue.gd`、`test_ranked_relay.gd`、`test_match_store.py`、`test_bo1_sideboard_ui.gd`、`test_matchmaking_ui.gd`、`run_cloud_matchmaking.py` |
| 六名不同 Elo 客户端同时排队、实际等待一分钟后扩大分差、三个仅观战匹配房间及双方成功提醒去重 | `run_cloud_matchmaking.py --simulation-only`（运行 `test_matchmaking_simulation.gd`） |
| 卡库加载 | `test_database_load.gd` |
| 组卡器卡牌排序与主副卡交换 | `test_deck_drag_order.gd` |
| 组卡双列无滚动菜单、战斗置顶弹窗、背景点击／触摸／快捷键隔离、测试工具入口与投降确认 | `test_menu_modal.gd` |
| 安卓图鉴两行四列八张完整卡面、顶部搜索／筛选、两侧翻页、颜色多选、原触控尺寸、高 DPI 安全区域与管理栏滚动 | `test_android_deck_gallery_layout.gd` |
| 安卓组卡翻页、搜索与筛选保留、长按详情、详情加牌／移除及余量、主副卡交换、卡组页拖动及返回菜单 | `test_android_deck_editor.gd` |
| PC 组卡器原有三栏布局、滚动卡库、横向颜色按钮、类型选项与搜索行为 | `test_desktop_ui_rollback.gd` |
| 安卓右侧主卡组上下滑动、慢速和斜向手势、滚动边界及短列表误拖拽 | `test_android_deck_scroll.gd` |
| 安卓所有牌长按 1 秒详情、触点圆环、轻触行动、滑动取消与记录排版 | `test_android_card_details.gd` |
| 安卓战斗中双方战场单位长按详情、普通／常驻／继承能力、2D／3D、先到的触摸模拟鼠标事件、单位边缘触摸容差、手指抖动、原生拖动排序及切换应用中止长按；有界面运行时保存截图 | `test_android_battle_unit_details.gd` |
| 卡牌别名、完整说明和能力文字检索、双端组卡器及各处搜索选牌 | `test_card_search_aliases.gd`、`test_card_search_aliases_ui.gd` |
| 对局规则 | `test_duel_rules.gd` |
| 对局记录点击详情、能力整批展示与同名副本、历史异画与隐藏牌保护、续接／重连／观战／录像保留、双端滚动及返回 | `test_battle_history.gd`、`test_battle_history_ui.gd` |
| 展示牌整批确认：能力／符卡与后续选择、双方操作锁定、确认权限与重复请求、隐藏牌快照、重连恢复、观战及桌面／安卓截图 | `test_reveal_review.gd`、`test_reveal_review_network.gd`、`test_reveal_review_ui.gd` |
| 双人赛制自动指定唯一对手、模式与可选目标保留、慧音吞食费用前的荷取保护检查、背包追加支付及联机校验 | `test_opponent_targeting.gd`、`test_opponent_targeting_ui.gd` |
| 伊吹瓢己方回合开始自动复原、对方回合保持横置、红绿付费重置及再次启动、费用不足不改变状态 | `test_ibuki_gourd.gd` |
| 安卓慧音大量牺牲与吞食的 2D／3D 表现恢复、独立堆叠、衍生物离场、展示顺序、隐藏牌及动画取消 | `test_keine_sacrifice_ui.gd` |
| 二重结界整回合光环：双方后续使用／效果／衍生物／批量进场、控制权变化、指示物与加成、回合恢复及联机／观战同步 | `test_double_barrier.gd` |
| 永久物范围、自机、时符与乐章，以及相关符卡的目标、清场、保护和离场触发 | `test_permanents.gd` |
| 先制伤害后的双方响应、堆叠结算与普通单位反击顺序 | `test_first_strike_response.gd` |
| 连挡伤害全部手动分配、确认按钮门控、观察与重建保留、零伤害及双端提交 | `test_combat_damage_assignment_ui.gd` |
| 双端展示／检索卡图网格、多选统一确认、同名与灵力合计限制、游戏外选牌、不足一行从左排列，以及梅莉／莲子收集歌曲必选现有每种各一张、三种去向可跳过和联机校验 | `test_card_art_selection_ui.gd`、`test_song_collection.gd` |
| 双端 X 手动输入、合法值与上限预计算、倍率／减费／代付／目标加费、重选及联机校验 | `test_variable_x.gd`、`test_variable_x_ui.gd` |
| 双端效果弹窗、左下隐藏与选择恢复、延迟回合结束设置及保存、主要阶段连续长按 2 秒及圆环取消／提交、关闭延迟或测试模式点按结束 | `test_battle_choice_hold.gd` |
| 常置阵双方全部单位（含未横置单位与自机）的目标合法性、横置历史与结算时检查、灵梦颜色盘回手，以及双端 2D/3D 隐藏／展开、空场菜单与目标取消、触摸重选和真实启动 | `test_standing_blast.gd`、`test_standing_blast_ui.gd` |
| 多项能力／效果居中等宽分列，长文字缩小与截断、常见选项免滚动，战场直接点选目标、右侧确认与双端小屏布局 | `test_battle_choice_placement.gd` |
| 颜色盘目标优先于支付资源、连续点选指示物与真实异能结算 | `test_card_name_target_picker_ui.gd` |
| 双端能力弹窗隐藏／展开按钮与堆叠卡牌、下方操作及菜单之间的避让，高密度安卓折叠后的堆叠可见性 | `test_battle_choice_overlap.gd` |
| 反制符卡与启动能力的堆叠避让、灵击展示后的堆叠点选、后续分组需要堆叠时提前避让 | `test_stack_interaction_popup.gd` |
| 双端连续触发及滚动后的箭头保留、赤蛙同时进场互相指定、小町死价双亡语的墓地检索标记、结算后续选择与联机／观战同步 | `test_stack_target_persistence.gd` |
| 叠放牌合并、要石首次/连续生成时立即合并、数量输入与批量牺牲、独立实体及被指定实体的交互 | `test_stackable.gd` |
| 全部复制效应的指示物、负指示物与白莲 X 费反制支付 | `test_copy_counters.gd`、`test_minus_counters.gd` |
| 衍生物独立种族、蝙蝠／幻象种族与牌面一致、袿姬复制保留原种族、种族效果及状态恢复 | `test_token_races.gd` |
| 云集雾散目标加费、冰之勇者横置、猫车消灭、妖梦决斗与支付界面 | `test_mist_target_tax.gd`、`test_mist_unit_abilities.gd`、`test_mist_target_tax_ui.gd` |
| 赤眼催眠重选目标、凤翼天翔使用时分配伤害、铃仙乐章幻象存活与名称提示 | `test_reisen.gd`、`test_reisen_ui.gd` |
| 摩多罗的牌库顶预览与自机牌颜色约束 | `test_okina_color_bypass.gd`、`test_okina_ui.gd` |
| 奇迹展示、留在手牌的响应窗口、弃置／反制／使用限制、结算时选目标、联机／观战与双端界面 | `test_miracle.gd`、`test_miracle_ui.gd` |
| 衍生物同时制造 | `test_token_creation.gd` |
| 秋静叶：符卡／能力制造红黄单位衍生物、实际颜色与复制、逐个进场触发、可选展示及战场容量 | `test_autumn_entry.gd` |
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
| 颜色盘诅咒任意减费、废线支付与联机校验 | `test_curse_discount.gd`、`test_curse_discount_ui.gd` |
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
| 安卓触控、返回及桌面差异 | `test_android_controls.gd` |
| 安卓墓地与除外区悬浮图标及点击区扩大 1.5 倍、原生边缘点击、长按 1 秒圆环后拖动、手指抖动／鼠标回声／取消、安全区、设置保存、黑洞左移、除外区双方切换及桌面隔离；有界面运行时保存效果图 | `test_android_zone_shortcuts.gd` |
| 安卓战斗选项空间、莉莉黑颜色选择与堆叠区避让底部操作 | `test_android_battle_choices.gd`、`test_android_battle_layout.gd` |
| 安卓右下角两至三个能力选项免滚动、帕秋莉符卡展示移除后的使用／不使用、原生触摸及高密度联机提示与堆叠避让 | `test_android_ability_options.gd` |
| 安卓战场／颜色盘移动视角、2D／3D 投影、手牌避让、敌方颜色盘查看、触摸切换、视角复原与桌面隔离；有界面运行时保存截图 | `test_android_camera_focus.gd` |
| 安卓凭依、结晶及付费自动聚焦我方，贫乏、破坏颜色盘与墓地能力选择聚焦敌方，退出还原位置和缩放，手动视角默认关闭及设置保存；有界面运行时保存截图 | `test_android_automatic_focus.gd` |
| 安卓皮丝、布都真实结算的敌方颜色盘选牌，五组分辨率／触摸密度下的 2D／3D 能力框避让、触摸确认、重选、隐藏／展开与视角还原；有界面运行时保存截图 | `test_android_palette_targets.gd` |
| 安卓使用牌区域入口、五种区域切换、慧音吞食对方牌的使用与支付取消、三种视角及高密度 2D／3D 避让、桌面页签保留；有界面运行时保存截图 | `test_android_cast_zones.gd` |
| 安卓弹窗容量、60 个长选项、40 项右侧菜单、联机堆叠避让及空颜色盘提示 | `test_android_popup_capacity.gd` |
| 联机状态保存与投影 | `test_network_state.gd` |
| 悔棋回到双方可操作的战况：跳过空响应阶段、保留合法高速或异能及主要阶段，双方同意／拒绝、观战同步与回放裁剪，桌面／安卓自动推进暂停 | `test_undo_checkpoints.gd`、`test_network_undo.gd`、`test_undo_ui.gd` |
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
