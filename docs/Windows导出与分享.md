# multicolor:arena 1.0 · Windows 导出与分享

本次增量更新以[卡组分享、观战与回放](卡组分享、观战与回放.md)为准：`.mdeck` 与 `.mreply` 位于 EXE 同目录；观战使用对战端口加1；断线30秒改为整场判掉线方负。

本项目已配置为导出独立 Windows 64 位游戏。朋友不需要安装 Godot，也不需要你的项目或素材目录。

## 本次问题与修复

- 卡图经 Godot 导入后以转换资源保存在 PCK 中，原始 JPG/PNG 路径不一定能被 FileAccess.file_exists 检测到。数据库现在使用 ResourceLoader.exists，继续用 load 加载导入后的纹理。
- 发布版不能写入 res:// 中的卡组。初次从旧集合存档/内置卡组迁移，之后在项目或 EXE 旁的 deck 文件夹读取独立 .mdeck；设置仍用 user://settings.json。
- saves 下的 .gdignore 保留。新增“卡组发行打包”编辑器插件，每次导出读取当时已经保存的全部卡组，写入包内 data/bundled_decks.json。首次运行初始化玩家存档；已有存档（包括删空的卡组列表）不会被覆盖。
- 卡牌定义和预组 JSON 显式包含。work、测试、开发工具、文档、打包输出、旧参考应用、待入库卡片和异画归档排除，已登记的全部 486 种卡牌和对应卡图完整保留。

## 今后直接从 Godot 导出

1. 先在游戏中保存希望分享的卡组，关闭测试运行。未保存的编辑不会进入发行包。
2. 重新打开本项目一次，使新增插件生效。在“项目 → 项目设置 → 插件”中确认“卡组发行打包”已启用。
3. 打开“项目 → 导出”，选择已有的 Windows Desktop 预设。导出模板版本必须与编辑器一致；本次使用 Godot 4.7.2。
4. 资源页保持“导出项目中的所有资源”，包含过滤为 `cards/*.json,data/*.json,net/*.json`，保留已配置的排除过滤。不要只导出 main.tscn 的依赖，因为卡图由 JSON 路径动态加载；联机也需要规则版本清单。
5. 点击“导出项目”，关闭“导出调试”，输出到 `C:/Users/tzx20/Documents/test/builds/Windows-1.0-bugfix0921/MulticolorArena.exe`。不要仅点击“导出 PCK/ZIP”。导出输出中应有 `BUNDLED_DECKS`（当前卡组数）和 `REGISTERED_CARDS: 486`。
6. 将 Windows 文件夹内的 EXE、同名 PCK 以及导出器附带的其他运行文件一起压缩为 ZIP。朋友先完整解压，再双击 MulticolorArena.exe。不要单发 EXE，也不要单独改名或移动 PCK。

当前预设未启用“Embed PCK”，所以 EXE 和 PCK 分开是正常结果。嵌入 PCK 只改变文件组织，不会修复缺资源，也不会减少卡图所需空间。分享时推荐保留分离文件并压成一个 ZIP。

## 当前分享包

`builds/MulticolorArena-1.0-bugfix0921-win64.zip`

2026-09-21 修复包，623628827 字节，SHA-256：`e2b7d53488ff2b9c7fcfa214e14998442d2e566099a685f7d469e56cfdacbb07`。压缩包旁 `CheckTransfer-bugfix0921.cmd` 校验 ZIP，包内 `VerifyFiles.cmd` 校验 EXE/PCK。414 项回归、534 项实际 Release 首启检查通过；重启保存、删空卡组、本地解压启动及逐文件哈希检查通过。真实双机和 USB 传输仍需在用户设备复测。

包含当前保存的 4 副卡组、486 条卡牌定义及对应图像、红金色卡背、垫子3、运行脚本、局域网 BO1/BO3 模块、双机测试及虚拟局域网异地联机说明。保留每局硬币、单局投降和双方延迟显示；v0.18.2修复自机幽幽子死亡返回自机区的触发，以及结晶竖直入盘。两套预组模板仍可通过游戏内“载入测试卡组”使用。未入库图片不自动成为游戏卡牌。开发用联机身份、恢复令牌、测试快照及日志不打包。

## 玩家存档

Windows 默认位置：`%APPDATA%/Godot/app_userdata/极彩 Multicolour/`。

- EXE 旁 `deck`：玩家独立 `.mdeck` 卡组，可复制分享；首次运行生成四个预设。旧用户目录的 decks.json 仅用于迁移。
- EXE 旁 `replay`：`.mreply` 回放文件。
- settings.json：玩家设置。
- logs/godot.log：运行日志。
- lan/identity.bin：本机联机身份和重连信息。
- lan/host.bin：房主最近保存的房间、规则状态和 BO3 状态。保留上一代 .bak，勿用其他玩家的记录覆盖。

升级游戏通常只需替换完整 EXE/PCK 文件组，已有玩家卡组会保留。初始卡组只对首次运行生效；给老玩家补发套牌可使用游戏里的「导出代码」「导入代码」功能。

## 验证范围

使用实际 Windows Release 模板验证全部 486 张纹理、卡牌 JSON、初始卡组、写入、重启保留编辑、空卡组不重置、设置写入和战场加载，并通过发行版 ENet 回环连接、入房、准备、隐藏手牌与胜负同步检查。首启/重启/空存档共1546项发行检查通过。发行验证场景排除于最终分享包，v0.18 记录位于 work/v018/export；最终普通入口另做启动检查。真实双机环境仍待用户验证。

v0.18.1新增80项协议、系列赛及图形界面检查通过；更新发行版首次启动验证518项，包含硬币和双方延迟，普通入口启动与卡组初始化再次通过。ZIP完整性检查通过，汇总work/v0181/validation.json。双方应更新相同版本；旧版本未结束的联机快照不兼容新系列状态，个人卡组不受影响。

## 官方参考

- [导出项目与资源过滤](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html)
- [FileAccess 与导入资源路径](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html#class-fileaccess-method-file-exists)
- [res:// 与 user:// 存档路径](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html)


## v0.18.2：U 盘传输后的完整性检查

本机仍保留的 v0.18.1 EXE/PCK 与原始发布记录的 SHA-256 完全一致。用户反馈问题发生在转入 U 盘之后，压缩包和解压后的文件均有问题；当前未读取 U 盘，不能据此断言硬件损坏，也未进行磁盘修复或格式化。文件系统、存储介质或复制环节都需进一步排查。[Microsoft 存储和文件损坏排查](https://learn.microsoft.com/en-us/troubleshoot/windows-server/backup-and-storage/troubleshoot-data-corruption-and-disk-errors)

新分享包采用英文短文件名，且附两层只读校验。文件名调整方便传输，不代表能修复存储故障。

1. 将 `MulticolorArena-1.0-win64.zip` 与 `CheckTransfer-1.0.cmd` 放在同一文件夹。在源电脑双击校验工具，应显示 PASS。
2. 将二者复制到接收电脑的本地磁盘后再运行该工具。PASS 表示 ZIP 的 SHA-256 与本次源包一致；FAIL 表示文件内容不同；MISSING/UNREADABLE 表示缺失或读取失败。失败时先重复制，可换 USB 接口或另一种传输方式作对照。
3. 完整解压后双击文件夹中的 `VerifyFiles.cmd`。EXE 和 PCK 都应显示 PASS。工具只读文件，检查大小和 SHA-256，不修改磁盘、游戏或存档。
4. 两层都通过但仍不能运行时，保留完整报错和游戏日志继续排查。如果系统仍报目录损坏，应先保全 U 盘中的其他重要资料，再单独检查存储设备。

另附 `MulticolorArena-1.0-win64.zip.sha256.txt`，可人工比较 `Get-FileHash -LiteralPath '压缩包完整路径' -Algorithm SHA256` 输出。检查工具中的预期值仅适用于本次发布的这一份包；自行重新导出的文件需重新生成校验值，不能沿用旧值。

本轮也发现导出预设的 JSON 包含/开发文件排除项被清空，已恢复。今后导出时保留资源过滤，并检查输出目录没有混入旧版本 EXE/PCK。


v0.18.2 验证结果：123项规则/先制/系列赛/延迟回归、518项实际Release首启检查全部通过；最终ZIP完成CRC、解压字节比对和解压后启动验证，4副初始卡组一致。只读校验工具通过正常及人为损坏文件用例。汇总位于work/v0182/validation.json；USB和真实双机仍未检测。


## 1.0 产品信息

正式名称multicolor:arena，版本1.0，Windows文件/产品版本1.0.0.0。发行文件为MulticolorArena.exe和MulticolorArena.pck（文件名不含冒号）。主菜单、窗口标题、关于页和规则握手版本同步更新。

为保证升级兼容，user://固定使用原来的 `%APPDATA%/Godot/app_userdata/极彩 Multicolour/`；个人卡组首次迁移至 EXE 旁的 deck，设置继续保留，旧版未结束的联机快照不兼容。1.0包含图形化BO3换备牌、断线锁定和30秒掉线整场判负、两张符卡费用修订。真实双机仍待用户检验。


1.0验证：194项本机规则/协议/图形回归及522项实际Release检查通过；ZIP完整解压比对和启动检查通过。分享包623581519字节，校验汇总work/v1/validation.json。真实双机尚待用户测试。
