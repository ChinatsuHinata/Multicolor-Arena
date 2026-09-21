multicolor:arena 1.1 · Windows 64 位

完整解压到可写入的本地文件夹，再运行 MulticolorArena.exe。
MulticolorArena.exe 和 MulticolorArena.pck 保持同目录，无需安装 Godot。
包含 511 条卡牌记录及全部卡图、四套内置卡组，以及之前的悔棋和新卡更新。

首次运行会在 EXE 旁创建 deck/预设卡组（四个 .mdeck）和 replay 文件夹。
导入旧卡组：将 .mdeck 放入 deck，重新进入卡组编辑器即可看到。
卡组保存后可直接发送 .mdeck 给朋友。不要用别人的 deck 文件夹覆盖自己的卡组。
单局人机/BO1 或整场 BO3 结束后可保存 .mreply；主界面“对局回放”播放。

本次修复详见 Fixes-1.1.md，包括妖精巡礼、百万鬼夜行、禁弹、自机返回和指示物规则。
联机双方及观众必须使用同一版完整发行包。旧版未结束对局及回放受规则版本校验。

房主建房，客机输入地址加入，房主接受加入申请。观众使用“观战”。
掉线锁住推进，30 秒内重连继续；超时掉线方整场判负。
观战、卡组分享、BO3 和虚拟局域网方法见 Portable-Guide.md、LAN-Guide.md、VPN-Guide.md。
本机真实 ENet 回环测试通过；物理双机、异地网络、U 盘介质需实际设备验证。

传输检查：ZIP 旁 CheckTransfer-1.1.cmd 校验压缩包。
解压后 VerifyFiles.cmd 校验 EXE/PCK。两个工具只读取文件。
若本地校验通过而接收电脑校验失败，请重新复制并检查传输与存储设备。
