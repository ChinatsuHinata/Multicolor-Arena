# 极彩 TTS 组卡器移植

这里有两个可直接由 Tabletop Simulator 载入的存档：

- `Multicolour_Deck_Builder.json`：以 Workshop `2629086384` 原版极彩 mod 为底本。
- `Multicolour_Deck_Builder_CurrentSave.json`：以本机最后一个手动存档 `TS_Save_90.json` 为底本，保留其中全部 635 个桌面物件。

两者均在原有全局 Lua 上加入组卡器；原 mod 的桌面物件和各物件脚本保持不变。影之诗 mod 的卡库搜索、按卡牌数据生成实体牌与整副卡组的做法用于实现参考，没有复制它的卡牌数据库或外部牌组网站接口。

本机已把后一版本安装为 TTS 的新存档 **91 - 极彩组卡器移植**，并备份原 `SaveFileInfos.json`。原 Workshop 文件、存档 90 均未改动。

## 使用

载入存档后点击左上角“组卡器”。可以搜索牌名、ID 与别名，按类别和颜色组合筛选，按类别、颜色值、名字排序。点击牌名可查看牌文并在鼠标附近生成一张临时预览牌。卡库包含全部已登记卡牌；衍生物及当前规则集禁用牌可以预览，但不能加入卡组。

点击“+主”“+备”加牌；自机牌点击“设自机”。右侧可逐张移除主牌、备牌。提供四套项目规则集；加牌和生成卡组时检查自机、主牌 50 张、备牌至多 10 张、同名上限、官限及禁用牌。测试卡组允许主牌至多 70 张。

卡组可保存、载入、删除；在 TTS 中保存游戏后，这些卡组随存档保留。下方文本框可粘贴项目的 `.mdeck` JSON 导入，也可导出兼容格式。生成时主牌成为一叠牌，自机单独放置，备牌独立放置在鼠标附近。

## 卡图来源与联机限制

513 张已登记牌全部进入组卡器，其中 467 张直接使用原极彩 TTS mod 中的在线卡面图集。另有 46 张在该 mod 中没有可靠的一一对应卡面，使用本机项目的 `recourse/数据库` 图片；清单见 `local_art_manifest.json`。这些本地卡图可供本机游戏使用。其他联机玩家无法看到本地文件；联机前须将这 46 张图片上传至 TTS Cloud 并把存档中的相应 `FaceURL` 换成云端 URL，再重新保存存档。TTS 的[资源导入说明](https://kb.tabletopsimulator.com/custom-content/asset-importing/)与[Cloud Manager 说明](https://kb.tabletopsimulator.com/custom-content/cloud-manager/)列出了本地资源和云端资源的区别。

原版 mod 的在线图集地址照旧保留；如果原地址失效，需要按 TTS 的资源管理流程重新托管。此移植尚未在 TTS 图形客户端内实际载入测试。

## 重新生成与验证

`build_tts_deckbuilder.py` 从项目的 `card_database.gd`、`cards/*.json`、已整理的 TTS 卡牌映射及极彩 mod 存档生成 Lua 目录和两个目标存档。默认输入路径适配本机环境，可用 `--mod`、`--asset-mod`、`--mapping-source` 和 `--output` 指定其他路径。

`verify_build.py` 检查 513 张卡牌、67 套卡图配置、四副预组和底本物件完全保留。使用 TTS 安装目录中的 MoonSharp 解释器检查过 Lua 解析，并在隔离环境执行过界面生成、自机选取、同名四张限制、预组导入和 50 张实体卡组数据生成；生成的界面 XML 可解析。
