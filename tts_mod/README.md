# 极彩 TTS 组卡器移植

这里保留组卡器的 Lua 模板、构建与验证脚本。构建后可生成两个由 Tabletop Simulator 载入的存档；生成的存档、报告和本机卡图清单只保存在本地，不提交到 Git：

- `Multicolour_Deck_Builder.json`：以 Workshop `2629086384` 原版极彩 mod 为底本。
- `Multicolour_Deck_Builder_CurrentSave.json`：以自己选择的本机存档为底本，保留原存档的桌面物件。

两者均在原有全局 Lua 上加入组卡器；原 mod 的桌面物件和各物件脚本保持不变。影之诗 mod 的卡库搜索、按卡牌数据生成实体牌与整副卡组的做法用于实现参考，没有复制它的卡牌数据库或外部牌组网站接口。

请将生成的存档自行导入 TTS；构建脚本不会修改原 Workshop 文件或个人存档。`deck_builder.lua` 是维护源码模板，必须保留，不属于生成产物。

## 使用

载入存档后点击左上角“组卡器”。可以搜索牌名、ID 与别名，按类别和颜色组合筛选，按类别、颜色值、名字排序。点击牌名可查看牌文并在鼠标附近生成一张临时预览牌。卡库包含全部已登记卡牌；衍生物及当前规则集禁用牌可以预览，但不能加入卡组。

点击“+主”“+备”加牌；自机牌点击“设自机”。右侧可逐张移除主牌、备牌。提供四套项目规则集；加牌和生成卡组时检查自机、主牌 50 张、备牌至多 10 张、同名上限、官限及禁用牌。测试卡组允许主牌至多 70 张。

卡组可保存、载入、删除；在 TTS 中保存游戏后，这些卡组随存档保留。下方文本框可粘贴项目的 `.mdeck` JSON 导入，也可导出兼容格式。生成时主牌成为一叠牌，自机单独放置，备牌独立放置在鼠标附近。

## 卡图来源与联机限制

513 张已登记牌全部进入组卡器，其中 467 张直接使用原极彩 TTS mod 中的在线卡面图集。另有 46 张在该 mod 中没有可靠的一一对应卡面，使用本机项目的 `recourse/数据库` 图片；清单见 `local_art_manifest.json`。这些本地卡图可供本机游戏使用。其他联机玩家无法看到本地文件；联机前须将这 46 张图片上传至 TTS Cloud 并把存档中的相应 `FaceURL` 换成云端 URL，再重新保存存档。TTS 的[资源导入说明](https://kb.tabletopsimulator.com/custom-content/asset-importing/)与[Cloud Manager 说明](https://kb.tabletopsimulator.com/custom-content/cloud-manager/)列出了本地资源和云端资源的区别。

原版 mod 的在线图集地址照旧保留；如果原地址失效，需要按 TTS 的资源管理流程重新托管。此移植尚未在 TTS 图形客户端内实际载入测试。

## 重新生成与验证

`build_tts_deckbuilder.py` 从项目的 `card_database.gd`、`cards/*.json`、已整理的 TTS 卡牌映射及极彩 mod 存档生成嵌入 Lua 的目标存档。每次执行生成一个目标存档及报告。

构建前须自行准备本机的原版 Workshop 存档、TTS 卡牌映射 JSON；若要生成个人存档版本，还须提供自己的 TTS 存档。它们不随此仓库提供。默认输入路径仅适配原开发环境，其他电脑应显式传入 `--mod`、`--asset-mod`、`--mapping-source`、`--output` 和 `--report`。例如，在仓库根目录执行（将示例路径替换为自己已有的文件）：

```powershell
python tts_mod/build_tts_deckbuilder.py --mod "C:/TTS-input/2629086384.json" --asset-mod "C:/TTS-input/2629086384.json" --mapping-source "C:/TTS-input/multicolour_cards_database.json" --output tts_mod/Multicolour_Deck_Builder.json --report tts_mod/build_report.json
python tts_mod/build_tts_deckbuilder.py --mod "C:/TTS-input/MySave.json" --asset-mod "C:/TTS-input/2629086384.json" --mapping-source "C:/TTS-input/multicolour_cards_database.json" --output tts_mod/Multicolour_Deck_Builder_CurrentSave.json --report tts_mod/current_save_report.json
python tts_mod/verify_build.py
```

`verify_build.py` 检查已生成的存档、当前已登记卡牌、卡图配置、维护预组和底本物件是否保留。未构建时会提示先生成产物；不要将缺少本机输入误判为游戏运行失败。预组验证和 `make_ui_fixture.py` 的界面夹具均读取 `data/preset_decks.json`，不读取玩家的 `deck/` 目录。`make_ui_fixture.py` 须在生成默认 `Multicolour_Deck_Builder.json` 后运行，输出的 `ui_fixture.lua` 仅供本机 MoonSharp 测试使用。

历史版本曾使用 TTS 安装目录中的 MoonSharp 解释器检查 Lua 解析，并在隔离环境执行界面生成、自机选取、同名四张限制、预组导入和 50 张实体卡组数据生成；这不替代每次修改后的重新构建与验证。
