# Windows 导出与分享（v0.18.1）

本项目已配置为导出独立 Windows 64 位游戏。朋友不需要安装 Godot，也不需要你的项目或素材目录。

## 本次问题与修复

- 卡图经 Godot 导入后以转换资源保存在 PCK 中，原始 JPG/PNG 路径不一定能被 FileAccess.file_exists 检测到。数据库现在使用 ResourceLoader.exists，继续用 load 加载导入后的纹理。
- 发布版不能写入 res:// 中的卡组。开发时仍读取 saves/decks.json；发布版改用 user://decks.json，设置改用 user://settings.json。
- saves 下的 .gdignore 保留。新增“卡组发行打包”编辑器插件，每次导出读取当时已经保存的全部卡组，写入包内 data/bundled_decks.json。首次运行初始化玩家存档；已有存档（包括删空的卡组列表）不会被覆盖。
- 卡牌定义和预组 JSON 显式包含。work、测试、开发工具、文档、打包输出、旧参考应用、待入库卡片和异画归档排除，已登记的全部 486 种卡牌和对应卡图完整保留。

## 今后直接从 Godot 导出

1. 先在游戏中保存希望分享的卡组，关闭测试运行。未保存的编辑不会进入发行包。
2. 重新打开本项目一次，使新增插件生效。在“项目 → 项目设置 → 插件”中确认“卡组发行打包”已启用。
3. 打开“项目 → 导出”，选择已有的 Windows Desktop 预设。导出模板版本必须与编辑器一致；本次使用 Godot 4.7.2。
4. 资源页保持“导出项目中的所有资源”，包含过滤为 `cards/*.json,data/*.json,net/*.json`，保留已配置的排除过滤。不要只导出 main.tscn 的依赖，因为卡图由 JSON 路径动态加载；联机也需要规则版本清单。
5. 点击“导出项目”，关闭“导出调试”，输出到 `C:/Users/tzx20/Documents/test/builds/Windows/Multicolour.exe`。不要仅点击“导出 PCK/ZIP”。导出输出中应有 `BUNDLED_DECKS`（当前卡组数）和 `REGISTERED_CARDS: 486`。
6. 将 Windows 文件夹内的 EXE、同名 PCK 以及导出器附带的其他运行文件一起压缩为 ZIP。朋友先完整解压，再双击 EXE。不要单发 EXE，也不要单独改名或移动 PCK。

当前预设未启用“Embed PCK”，所以 EXE 和 PCK 分开是正常结果。嵌入 PCK 只改变文件组织，不会修复缺资源，也不会减少卡图所需空间。分享时推荐保留分离文件并压成一个 ZIP。

## 当前分享包

`builds/极彩Multicolour-Windows-v0.18.1-LAN.zip`

包含当前保存的 4 副卡组、486 条卡牌定义及对应图像、红金色卡背、垫子3、运行脚本、局域网 BO1/BO3 模块、双机测试及虚拟局域网异地联机说明。v0.18.1增加每局硬币、单局投降和双方延迟显示。两套预组模板仍可通过游戏内“载入测试卡组”使用。未入库图片不自动成为游戏卡牌。开发用联机身份、恢复令牌、测试快照及日志不打包。

## 玩家存档

Windows 默认位置：`%APPDATA%/Godot/app_userdata/极彩 Multicolour/`。

- decks.json：玩家自己的卡组；保存时保留 .bak 备份。
- settings.json：玩家设置。
- logs/godot.log：运行日志。
- lan/identity.bin：本机联机身份和重连信息。
- lan/host.bin：房主最近保存的房间、规则状态和 BO3 状态。保留上一代 .bak，勿用其他玩家的记录覆盖。

升级游戏通常只需替换完整 EXE/PCK 文件组，已有玩家卡组会保留。初始卡组只对首次运行生效；给老玩家补发套牌可使用游戏里的卡组复制／粘贴功能。

## 验证范围

使用实际 Windows Release 模板验证全部 486 张纹理、卡牌 JSON、初始卡组、写入、重启保留编辑、空卡组不重置、设置写入和战场加载，并通过发行版 ENet 回环连接、入房、准备、隐藏手牌与胜负同步检查。首启/重启/空存档共1546项发行检查通过。发行验证场景排除于最终分享包，v0.18 记录位于 work/v018/export；最终普通入口另做启动检查。真实双机环境仍待用户验证。

v0.18.1新增80项协议、系列赛及图形界面检查通过；更新发行版首次启动验证518项，包含硬币和双方延迟，普通入口启动与卡组初始化再次通过。ZIP完整性检查通过，汇总work/v0181/validation.json。双方应更新相同版本；旧版本未结束的联机快照不兼容新系列状态，个人卡组不受影响。

## 官方参考

- [导出项目与资源过滤](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html)
- [FileAccess 与导入资源路径](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html#class-fileaccess-method-file-exists)
- [res:// 与 user:// 存档路径](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html)
