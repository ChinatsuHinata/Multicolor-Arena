# AI 建模、最近对战数据与算法接入

本轮把最近录像转换成可训练数据，并建立可被 Python 算法实际操作的 Godot 环境。规则、付费、触发和胜负仍由 `duel_engine.gd` 执行。默认人机没有自动切换到实验模型。

本机从 Godot 源项目运行时，可在人机对战页勾选「使用试验 AI（仅本机测试端）」。开关默认关闭；启用后，对手主要阶段调用试验决策代理，调度、响应与其他选择沿用现有人机策略。默认加载 `work/ai-training/strategic-2026-09-27/matchups/preference-models.json` 分类偏好模型包，缺少此文件时使用内置试验评估。点击「选择模型…」可加载其他有效权重或分类模型包 JSON，包括单独的留出训练模型。无效或已删除的模型会阻止开局并提示重新选择。

手动控制双方时此开关不可用，联机与回放不调用试验 AI。安装版及其他导出模板隐藏开关和模型选择，并在运行入口拒绝启用或读取试验模型；开关与模型选择不写入玩家设置，训练模型仍按现有发布策略排除。

## 蕾米的训练目标

遵循牌手最新要求：主动压低对方血线，推进红魔馆、宵暗之翼与四蝙蝠路线；只有公开信息能够预测高风险单位即将合法登场时，才强制预留神枪的一红一黑。普通大单位已在场，不单独构成新算法的强制留费理由；当前威胁仍可主动解掉。

风险集合包含灵梦、小妖梦、能支付额外绿色并决斗的云山、自机芙兰及受神社赋予自机能力的芙兰，以及其他具有实际启用自机能力的核心。判断同时检查区域、计时、战场颜色、战场格、费用和神枪能否击杀。候选身份只来自公开自机、已宣布的单位和已公开手牌记忆。下一张成长牌只作为一张可能的任意颜色资源，不代表已知牌库顶，也不保证对手会出该牌。

历史“未知云山可能在手中，所以强行留费”的偏好，在没有公开高风险登场预测、对照是红魔馆/蝙蝠展开时，由本次用户指令覆盖。覆盖只发生在派生语料；原人工标注、录像及实际胜负保留。

操作偏好模型对对手生命使用非正权重，对光环蝙蝠伤害、可支付的组合与必要神枪留费使用非负权重，对无预测威胁的留费使用非正权重。原始终局价值模型保留实际胜负监督。按牌手目标生成的比较单独标记为 `user_directed_weak_teacher`，不能冒充人类审核或获胜路线。

## 局面表示

`scripts/ai/strategic_features.gd` 增加 27 项特征，连同原有 9 项共 36 项：

| 范围 | 表示 |
| --- | --- |
| 战场与资源 | 原有生命差、场面差、手牌差、即时威胁；颜色来源最少数量与冗余、空战场格、当前资源下可使用的手牌数 |
| 清场压力 | 按当前剩余血量估算受到 1/2 点伤害后的颜色条件；这不是包含防伤、恢复与亡语的完整清场模拟 |
| 自机 | 剩余血量、计时、当前资源下可重拍、极光/文恢复入口与恢复牌库存；文回手入口不等于已证明能当回合重拍 |
| 解牌 | 硬解与神枪库存、神枪可支付、对方核心与普通小单位的区别 |
| 速攻计划 | 永久与到期衍生物的即时灵力、红魔馆、四蝙蝠组合费用、光环下临时单位的伤害、对手生命 |
| 条件留费 | 即将登场的公开高风险威胁、必要留费、无需强制留费 |

特征只读取己方手牌与公开区域；对手隐藏身份和双方牌库顺序不进入特征。所有新系数使用 `multicolor.ai.value.v2`，旧九特征参数仍可加载。训练时的尺度只由训练集计算；导出的系数已经换算为原始特征单位，Godot 与 Python 的评分一致。

## 对战集

入口 `tools/ai/replay_dataset.gd` 冻结自 2026-09-26 23 时起的最近录像清单，并记录 SHA-256 与代码指纹。

- 终局样本取每个全局回合最初、最后的公开主阶段状态及既有审核位置；有完整己方手牌的双方分别导出，重复位置不重复计数。
- 旧录像没有完整决策标记时，只用于真实终局价值样本，不生成动作示范。
- 行为样本只从明确记录的主阶段决策点提取紧接着的实际操作。保留动作、目标、模式和当时动作菜单。
- 实际支付方案没有完整录制，因此行为标签接受所有具有相同操作、目标与模式的支付变体，不伪造唯一支付教师标签。
- 偏好使用真实引擎验证的两条假设端点，不将其虚构成已获胜的轨迹；不完整端点不参与偏好训练。
- 完整录像的双方、全部回合、行为和假设分支进入同一分组；最新三份录像留出，不随机拆分相邻局面。

本轮数据、模型、分项验证与具体数值位于 `work/ai-training/strategic-2026-09-27/`。`training-results.json` 同时报告九特征基线与扩展模型，并区分历史审核偏好和按牌手目标生成的弱教师偏好。已经审阅过的历史验证案例影响了特征设计，不能声称它们是完全未见测试。局面分类/排序准确率不等于对局胜率。

### 本轮结果

15 份完整录像导出 865 个带真实胜负标签的局面、474 个决策记录、14 个既有审核位置和 60 组比较。60 组中，54 组是按用户目标生成的弱教师，5 组沿用审核偏好，1 组由最新指令覆盖旧留费偏好。训练为前 12 场、651 个局面、38 组偏好；最后 3 场为 214 个局面、22 组偏好。35 个缺少完整己方手牌的位置被跳过，4 次无法执行的实际操作被排除；142 个行为菜单达到预算限制，并显式保留 `truncated` 标记。

| 模型 | 训练命中 | 留出命中 | 留出交叉熵 |
| --- | --- | --- | --- |
| 九特征终局 | 74.7% | 49.1% | 0.756 |
| 36 特征终局 | 80.0% | 41.1% | 1.185 |
| 九特征偏好 | 35/38 | 22/22 | 0.402 |
| 36 特征偏好 | 38/38 | 21/22 | 0.105 |

扩展偏好模型留出分项为弱教师 19/20、既有审核 1/1、最新指令覆盖 1/1。偏好交叉熵改善，终局泛化变差；不能据此声称更多特征或开源接口已提高实战胜率，因此模型保持实验状态。固定样本只有 15 场，独立审核比较尤其少。

865 个局面中，159 个存在公开高风险登场预测，其中 17 个同时持有可支付神枪。偏好模型学到对手生命系数约 -0.309、必要留费系数约 +1.391；光环蝙蝠伤害、组合就绪及无需留费三项受符号约束后的系数暂为 0。红魔馆/蝙蝠探索优先级还依靠明确的用户策略先验，不能声称全部路线已经从录像中自动学出。

实际算法演示使用 36 特征偏好模型，在真实 Godot 状态上进行 24 次隐藏世界采样、最多 4 步搜索，涉及 20 个信息集树节点及 5 个根动作，约 7.3 秒，无搜索错误；选择的动作由真实引擎接受。该延时只是离线演示结果，尚未满足交互对战要求。原录像校验、终局样本、分组、模型加载、Python/Godot 评分、偏好端点复现及抽查动作共通过 5495 项检查。

环境专项 94 项、AI 基础 24 项、原蕾米逻辑回归 437 项及 Python 22 个测试均通过。自对战记录入口另验证 4 个局面含完整 36 特征、2 场达到动作上限时胜负仍为 null。汇总保存在 `validation-suite.json`。

## 按对手自机分类训练

发行人机现在也复用相同分类，选择独立的手写对策库 `data/release_counterplay.json`，运行入口为 `scripts/ai/release_counterplay.gd`。这不加载实验训练参数；具体规则、灵梦留费和凭依夜王、系缚阵牺牲以及回退条件见 [发行 AI 自机对策库](发行AI自机对策库.md)。

实验模型现在先通过 `scripts/ai/matchup.gd` 识别公开的双方自机，再由 `matchup_models.gd` 选择参数。分类依据是卡牌 ID，保留版本区别；异画、区域、控制权变化不改变分类，复制及妖精栖息地使用原身份。双自机按排序后的完整组合分类，不当作单自机。观察结果、自对战采样、终局样本、偏好与行为记录都带有分类信息。类别同时限定己方自机，防止把蕾米视角参数用到对手视角。

`train_replay_corpus.py` 在训练通用模型后自动调用 `train_matchups.py`，在 `matchups/` 下生成分类数据、分类报告及 `outcome-models.json`、`preference-models.json` 两个模型包。模型包内包含完整通用参数及可用的分类参数。遇到新自机、未知身份、没有分类模型或分类参数损坏时回退通用参数；不足的分类仍留在报告和数据中，后续新增录像即可继续训练。

每类至少需要两份独立训练录像及另一份可用验证录像。保持原通用模型的整场留出；若某类没有全局验证录像，则从该类的全局训练部分留出时间最晚一场，绝不把全局验证录像移入分类训练。终局训练仍要求训练集包含真实胜负两类，偏好训练仍要求训练和验证都有可区别的比较。分组依据整个录像，双方、相邻局面与假设端点不跨集合。这个最低数量只允许实验训练，不表示已经满足实战强度门槛。

当前 15 份录像中，蕾米视角识别出 7 类：幽幽子、蕾米、觉恋、魔理沙、灵梦、堇子与二重身组合、诹访子。灵梦有 7 场，按 6 场训练、1 场局部验证生成终局和偏好分类模型；其余类暂用通用方法。诹访子的 3 场全部属于原全局留出，保持留出身份，因此本轮不生成诹访子专用参数。全部视角共 13 类，详见 `work/ai-training/strategic-2026-09-27/matchups/classification-report.json`。灵梦的偏好模型在留出中为 5/5，终局局面命中 17/19；这些数据量小，且包含弱教师比较，不等于实战胜率。

Python 信息集搜索与 Godot 实验代理都支持模型包，决策结果写入 `model_routing`，说明识别出的自机及实际使用分类／通用参数。模型在决策入口选择，候选端点沿用这次选择的参数；默认人机仍维持现有已验证策略。

```powershell
$taskPython = 'C:/Users/Lenovo/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$taskGodot = '.godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe'
$taskCorpus = 'work/ai-training/strategic-2026-09-27'
# 完整训练会自动分类；已有通用模型也可单独重训分类。
& $taskPython tools/ai/train_matchups.py $taskCorpus
& $taskGodot --headless --path . --script res://tests/test_ai_matchups.gd
& $taskPython tools/ai/test_matchup_models.py
& $taskPython tools/ai/algorithm_demo.py --weights "$taskCorpus/matchups/preference-models.json" --simulations 8 --depth 3 --output "$taskCorpus/matchups/algorithm-demo.json"
# 离线对局同样接受模型包，--opponent 指定所打卡组。
& $taskGodot --headless --path . --script res://tools/ai/self_play.gd -- --weights=res://work/ai-training/strategic-2026-09-27/matchups/preference-models.json --opponent=res://deck/预设卡组/预组-灵梦_ffc1d4d760ac.mdeck --seeds=2001 --max-actions=1200 --output=res://work/ai-training/matchup-arena.json
```

## 算法环境

`scripts/ai/game_environment.gd` 提供 `reset`、`current_player`、`observation`、`features`、`information_state_string`、`legal_actions`、`apply_action`、`clone`、`resample_from_infostate`、`is_terminal`、`returns`。

这是**主阶段决策模型**：每个动作之后由冻结的原有 AI 处理响应、触发选择、战斗与阶段推进，直到下一个完整主阶段决策。它支持真实规则下的多步出牌和跨回合模拟，尚未把每个高速响应、阻挡、调度与触发选择交给学习策略。当前 RNG 是种子控制的采样转移，没有对每个随机事件提供显式 chance 节点，因此不适用于要求完整随机节点枚举的 CFR 求解器。

动作菜单独立于蕾米的牌序优先级，枚举目标、模式、动态选择及不同支付方案，并交由规则引擎执行。每个菜单默认最多 256 个动作、每组最多 128 个目标、每个费用最多 8 个支付变体；预算耗尽返回 `truncated`，不能宣称穷举所有动作。牌库中的施放权限尚不属于此主阶段动作空间。

动作 ID 是稳定的 48 位动作哈希，合法动作 mask 对每个状态单独提供。神经网络应对候选动作描述打分，不能把这个稀疏 ID 空间直接当成固定 DQN/PPO 输出层。`policy_actions` 另给出用户指定的条件留费筛选，不篡改物理合法动作菜单；它允许保留神枪费用的展开、处理当前高风险威胁及已经验证的立即获胜。

隐藏世界必须从显式提供的卡组先验采样，扣除己方已知牌和双方公开牌后无放回重采样。重采样保持观察者的公开信息和信息历史；未来 RNG 使用独立种子。没有先验、观察牌与先验冲突，或生成/变形后的隐藏牌无法满足数量约束时，返回明确错误。离线 `reset` 使用指定的实验卡组作为先验，不能由此推断实战中总能知道对方完整卡组。

## Python 与开源算法

`tools/ai/environment_server.gd` 在本机回环地址提供带会话令牌的 JSON-lines 服务，状态副本留在 Godot。`tools/ai/godot_env.py` 提供持久 Python 连接、可复制状态与 RLCard 风格的 reset/step/step_back/get_state/get_payoffs 接口。

`tools/ai/information_set_uct.py` 是本项目编写的有界信息集 UCT 基线，真实调用上述接口：每轮重采样隐藏世界，按玩家和可见信息历史共享树节点，选择、执行、评估和回传收益；优先探索红魔馆/蝙蝠与直接压血路线，条件留费由公开风险筛选。它不是复制的第三方算法，也不是精确均衡求解器。

Godot 内的扩展实验决策代理也使用相同条件留费筛选。`tools/ai/self_play.gd` 加载新模型后记录完整 36 特征并标明对应 schema，可继续积累自对战数据；达到动作上限的对局保留未完成状态，不算作和局。

接口对应 [OpenSpiel 的状态 API](https://github.com/google-deepmind/open_spiel/blob/master/docs/api_reference.md) 和 [RLCard 的环境 API](https://github.com/datamllab/rlcard/blob/master/rlcard/envs/env.py)。演示另提供直接调用上游 [OpenSpiel ISMCTSBot](https://github.com/google-deepmind/open_spiel/blob/master/open_spiel/python/algorithms/ismcts.py) 的可选入口，运行时需实际安装上游依赖；本机没有 `pyspiel`，该入口本轮未验证，也没有注册完整的 `pyspiel.Game` 或 RLCard 游戏。

## 复现

```powershell
$taskGodot = '.godot-toolchain/editor/Godot_v4.7.2-stable_win64_console.exe'
$taskPython = 'C:/Users/Lenovo/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$taskCorpus = 'work/ai-training/strategic-2026-09-27'
& $taskGodot --headless --path . --script res://tools/ai/replay_dataset.gd
& $taskPython tools/ai/train_replay_corpus.py $taskCorpus
& $taskGodot --headless --path . --script res://tools/ai/verify_strategic_corpus.gd
& $taskPython tools/ai/algorithm_demo.py --simulations 24 --depth 4 --weights "$taskCorpus/strategic-preference-value.json" --output "$taskCorpus/algorithm-demo.json"
& $taskGodot --headless --path . --script res://tests/test_ai_environment.gd
& $taskPython tools/ai/test_algorithm_bridge.py
& $taskPython tools/ai/test_strategic_training.py
```

新模型保持实验状态。正式切换默认 AI 仍需要独立对战池中的胜率、未完成率和交互设备上的决策延时验证；功能检查与偏好排序不能代替这些证据。
