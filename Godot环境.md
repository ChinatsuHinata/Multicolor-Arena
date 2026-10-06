# Godot 开发环境

本项目使用 **Godot 4.7.2 stable 标准版（Windows x86_64）** 和 GDScript。项目内已放置对应编辑器、Windows 调试模板及正式导出模板；Godot 的便携模式会将编辑器设置保存在 `.godot-toolchain/editor/editor_data`，不影响已安装的其他版本。

## 打开和编译

- 双击项目根目录的 `启动Godot.cmd` 打开编辑器。
- 双击 `编译Windows.cmd` 执行资源导入并正式导出。生成 `builds/Windows-1.2/MulticolorArena.exe` 和同名 `.pck`；分享时两者必须放在一起。
- 命令行也可运行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/build-windows.ps1`。

## Android 调试开发

Android 工具放在以下位置，供本项目的便携 Godot 编辑器使用：

| 组件 | 位置或版本 |
| --- | --- |
| Godot 编辑器 | `.godot-toolchain/editor/Godot_v4.7.2-stable_win64.exe` |
| Android 导出模板 | `.godot-toolchain/editor/editor_data/export_templates/4.7.2.stable/android_debug.apk`、`android_release.apk` |
| Android SDK | `.godot-toolchain/android-sdk/` |
| JDK 17 | `C:\Program Files\Microsoft\jdk-17.0.10.7-hotspot` |
| 调试签名密钥 | `.godot-toolchain/editor/editor_data/keystores/debug.keystore` |

SDK 包含 Android Platform-Tools 35.0.0 或更新版本、Build-Tools 35.0.1、Platform 35、Command-line Tools (latest)、CMake 3.10.2.4988404 和 NDK 28.1.13356709。在便携编辑器的**编辑器设置 → 导出 → Android** 中，`Java SDK Path` 应指向上述 JDK 根目录，`Android SDK Path` 应指向本项目的 `.godot-toolchain/android-sdk`；`Debug Keystore` 应指向实际存在的调试密钥。设置保存在 `.godot-toolchain/editor/editor_data/editor_settings-4.7.tres`。若设置时编辑器已经打开，请重启编辑器以载入新路径。

在项目根目录运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\build-android.ps1
```

脚本先导入资源，再使用现有的 `Android` 预设和 `--export-debug` 生成包含 arm64 与 x86_64 的 `builds/Android-debug/MulticolorArena-debug.apk`，分别支持实体设备和本项目的 x86_64 模拟器。它检查 Godot 及模板版本、SDK 组件、JDK 17、编辑器路径设置、导出日志、APK 内容与签名；日志写入 `.godot-toolchain/logs/android-*.log`。可用 `-OutputPath 'builds/Android-debug/其他名称.apk'` 指定项目内的 APK 路径；其他机器上的 JDK 路径可用 `-JavaSdkPath` 指定，同时应更新便携编辑器设置。

VS Code 的 **Android: 导出 APK** 可单独执行上述命令，不需要启动模拟器。每次 Windows 或 Android 导出前，`tools/sync-export-version.ps1` 都会从 `project.godot` 的 `config/version` 同步 Windows 文件版本及 Android 的 `versionName`、`versionCode`，并检查两平台的资源包含与排除规则相同。修改版本号只需修改 `project.godot`。

发布版本请运行 **发布: 导出 Windows 和 Android APK**。它依次重新导出 `builds/installer-staging/<版本>/MulticolorArena.exe`、同名 PCK，以及 `builds/Android-debug/MulticolorArena-<版本>-debug.apk`；随后对实际 PCK 与 APK 的卡牌、数据及网络 JSON 逐个比较 SHA-256，检查核心规则脚本在两边都存在、版本号一致。校验范围不包含界面脚本和布局，因此已有的 Android/PC 界面与输入差异会保留。任一检查失败，任务会报错，不能把两平台视为一组完成的发布构建。命令行使用 `tools/build-both.ps1`；需要安装包或差分补丁时，使用同脚本的 `-Installer` 或 `-FromVersion <旧版本>`。这些任务生成的 Android 包仍是调试签名 APK。

### AOSP 模拟器

项目使用基于 QEMU 的 [Android Emulator](https://source.android.com/docs/setup/test/avd) 和 **Android 35 default x86_64 系统镜像**。该镜像不含 Google Play，适合在开源 Android 系统环境中测试游戏。模拟器与镜像放在 `.godot-toolchain/android-sdk/`，虚拟设备 `MulticolorArena_API35_AOSP` 的数据放在 `.godot-toolchain/android-home/avd/`；两处都被 Git 忽略。首次配置需从 Android 官方仓库下载约 1 GB 的压缩包，并为虚拟设备留出数 GB 空间。

在 VS Code 中运行 **Android: 配置开源模拟器** 可安装缺失组件并创建 1280×720 横屏虚拟设备；运行 **Android: 启动模拟器** 只启动设备；运行 **Android: 在模拟器运行游戏** 则会构建调试 APK、启动设备、安装并打开游戏。命令行等价于：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\run-android-emulator.ps1
```

已有新编译的 APK 时，可加 `-SkipBuild` 直接安装运行；JDK 位置不同时可加 `-JavaSdkPath 'C:\实际路径\jdk-17'`。为兼容项目路径中的中文字符，脚本会在系统临时目录建立指向本项目的英文路径映射，供 Android SDK 工具使用。脚本会复用已运行的同名模拟器；新启动时采用冷启动，避免载入可能导致启动崩溃的图形快照。已安装的应用和数据仍会保留。复用设备时，`.godot-toolchain/logs/android-emulator.log` 不会更新，其中可能仍保留上次启动失败的记录，应先核对文件修改时间。首次启动前，可用 `.godot-toolchain\android-sdk\emulator\emulator.exe -accel-check` 检查虚拟化。本项目的 x86_64 镜像需要硬件加速；Windows 推荐启用 [Windows Hypervisor Platform](https://developer.android.com/studio/run/emulator-acceleration)，并在 BIOS/UEFI 中开启 CPU 虚拟化，系统功能变更后须重启。模拟器启动和 AVD 命令用法见 [Android 官方文档](https://developer.android.com/studio/run/emulator-commandline)。

调试 APK 使用 Godot 配置的调试密钥签名，适合设备安装和功能测试。连接启用 USB 调试的 Android 设备后，可运行以下命令检查连接并安装：

```powershell
& .\.godot-toolchain\android-sdk\platform-tools\adb.exe devices
& .\.godot-toolchain\android-sdk\platform-tools\adb.exe install -r .\builds\Android-debug\MulticolorArena-debug.apk
```

相同包名如果此前使用另一密钥签名，覆盖安装会失败；需要先在设备上处理旧安装及其数据。

### 同一 Wi-Fi 给手机传 APK

PC 与 Android 手机连接同一 Wi-Fi 后，在 VS Code 运行 **Android: 同 Wi-Fi 分享最新 APK**，或在项目根目录运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\share-apk-lan.ps1
```

脚本默认选 `builds/Android-debug/` 中修改时间最新的 APK，终端会显示实际文件名、大小和手机浏览器下载地址。需要指定文件时传入 `-ApkPath 'builds/Android-debug/MulticolorArena-1.2.7-debug.apk'`。服务只监听 PC 当前的 Wi-Fi IPv4 地址，不监听 VPN 网卡；指定网卡地址可用 `-Address 192.168.1.17`，端口可用 `-Port 8765` 调整。手机打开终端显示的完整地址即可下载；保持终端运行，结束后按 `Ctrl+C`。下载支持 HTTP Range 断点续传，文件通过 1 MiB 缓冲区流式发送，不会整包读入内存。每次启动都会生成新的随机地址，旧地址随服务停止失效。

如果手机无法打开地址，先确认双方连接同一 Wi-Fi、未启用路由器的客户端隔离，且 PC 的防火墙允许该 Wi-Fi 网段访问所选 TCP 端口。浏览器下载后仍需由 Android 系统确认安装；覆盖旧版需保持相同包名和签名。

正式发布前，需要设置自己的唯一包名、版本号、图标和独立的**发布签名密钥**，妥善备份密钥与密码，并检查导出资源与权限。Google Play 上架需要 AAB 和相应的 Gradle 构建设置；调试 APK 不应作为正式发布包。项目目前按 1600×900 桌面界面设计，仍须在真机上检查触控目标、拖放和手势、屏幕比例与安全区域、软键盘、文件访问及性能，再决定 Android 界面的适配范围。Godot 的组件要求和签名说明见[官方 Android 导出文档](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html)。

## 在 VS Code 编辑 GDScript

使用 Godot 官方维护的 [Godot Tools 扩展](https://github.com/godotengine/godot-vscode-plugin)（扩展 ID：`geequlim.godot-tools`）。在 VS Code 打开本项目根目录后，工作区设置会使用项目自带的 Godot 4.7.2；打开 `.gd` 文件时，插件自动启动无窗口的 Godot 语言服务，提供补全、悬停说明、跳转定义与错误提示。无需先手动打开 Godot 编辑器。

- 按 `F5`，选择 **Godot: 调试游戏**，运行主场景并使用断点调试。
- 在“运行和调试”下拉框选择 **Godot: 调试当前场景**，可调试当前 `.tscn`，或与当前 `.gd` 同名的 `.tscn`。
- 按 `Shift+Alt+F`，使用插件的 GDScript 格式化功能。

配置位于 `.vscode/settings.json`、`.vscode/launch.json` 和 `.vscode/extensions.json`。语言服务地址为 `127.0.0.1:6005`；无窗口模式和 VS Code 调试器会自动分配可用端口。便携 Godot 的外部脚本编辑器已设为本机 VS Code，并启用外部脚本修改后的自动重载；其他电脑需在 Godot“编辑器设置 → 文本编辑器 → 外部”更新 VS Code 路径。安装后若已有 VS Code 窗口未识别插件，运行命令 **Developer: Reload Window（开发人员: 重新加载窗口）**。

## 在 VS Code 启动和运行测试

在 VS Code 中打开**项目根目录**，按 `Ctrl+Shift+B` 即可启动 Godot 游戏窗口，直接进行手动测试。游戏进程在 VS Code 终端中运行；关闭游戏窗口即可结束任务。此快捷键调用当前工作区的 `.godot-toolchain/editor/Godot_v4.7.2-stable_win64.exe`，无需另装 Godot 或输入命令。任务定义保存在 `.vscode/tasks.json`，随项目共享。

其他任务可从 `Ctrl+Shift+P` 打开命令面板，运行 **Tasks: Run Task（任务: 运行任务）** 后选择：

- **Godot: 打开编辑器**：打开本项目的 Godot 编辑器。进入编辑器后按 Godot 的 `F6` 可运行当前场景，按 `F5` 可运行整个项目。
- **Godot: 运行当前测试脚本**：先在 VS Code 打开 `tests/` 下要运行的 `.gd` 测试文件，再执行该任务。它以无界面模式运行，测试结果和退出码显示在终端中。
- **Android: 导出 APK**：单独导出调试 APK，无需运行模拟器。
- **Android: 配置开源模拟器 / 启动模拟器 / 在模拟器运行游戏**：分别执行首次配置、仅启动虚拟设备、构建并在虚拟设备运行游戏；细节见上文。
- **发布: 导出 Windows 和 Android APK**：自动同步版本并验证两平台的核心数据。
- **发布: 创建 Windows 安装包和 Android APK**：在双平台验证后创建 Windows 安装程序。
- **发布: 创建 Windows 差分补丁和 Android APK**：输入旧版本号，在双平台验证后创建差分安装器。
- **Windows: 仅重新打包差分补丁**：输入旧版本号，复用 `builds/installer-staging/<当前版本>/` 中已有的 EXE/PCK。
- **发布: 创建并推送双端 PCK 差分更新包到云端**：构建 Windows 和 Android 的 PCK 差分包，签名后上传 ECS，供客户端登录时自动更新。
- **PCK: 推送已构建差分更新包到云端**：跳过构建，复用当前版本的双端 PCK 补丁并推送到云端。
- **PCK: 检查云端推送连接**：仅检查 SSH 连接和认证，不构建或上传补丁；适合推送失败时排查。

如果经常运行当前测试脚本，可在 VS Code 的 **Preferences: Open Keyboard Shortcuts (JSON)（首选项: 打开键盘快捷方式(JSON)）** 中添加以下个人快捷键：

```jsonc
[
  {
    "key": "ctrl+alt+t",
    "command": "workbench.action.tasks.runTask",
    "args": "Godot: 运行当前测试脚本"
  }
]
```

## 在 VS Code 创建安装包

先安装 [Inno Setup 6 或 7](https://jrsoftware.org/isdl.php)。在 VS Code 打开本项目后，运行“终端 → 运行任务”，选择 **发布: 创建 Windows 安装包和 Android APK**。任务会重新导出并验证双平台游戏，然后生成 `builds/installers/MulticolorArena-<版本>-win64-setup.exe`，并输出 SHA-256。命令行等价于：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/build-both.ps1 -Installer
```

仅调整安装脚本且已有同版本导出文件时，可以运行 **Windows: 仅重新打包安装包**。如果 Inno Setup 装在其他目录，可传 `-IsccPath 'C:\完整路径\ISCC.exe'`。

安装程序按固定 AppId 检测此前由本安装包安装的版本，自动选用原安装目录并覆盖更新 EXE/PCK。默认安装在当前用户的 `%LOCALAPPDATA%\Programs\MulticolorArena`，无需管理员权限。更新不打包也不删除安装目录中的 `deck`、`replay`，用户目录中的设置与联机身份也不受影响。旧版 ZIP 便携包没有安装记录，无法自动定位；若要在原文件夹覆盖，请在首次运行安装程序时手动选中该文件夹，并确保该文件夹可写。

编译脚本会检查 Godot 版本、Git LFS 图片是否仍为指针、导入错误、导出错误以及 EXE/PCK 是否生成。日志位于 `.godot-toolchain/logs/`。

## 在 VS Code 创建差分补丁

运行“终端 → 运行任务”，选择 **发布: 创建 Windows 差分补丁和 Android APK**，输入要升级的旧版本号，例如 `1.2.1`。任务从 `project.godot` 读取新版本号，要求旧版 EXE/PCK 位于 `builds/installer-staging/<旧版本>/`，随后导出双平台、验证核心数据与差分并编译安装器。已有当前版本导出文件时，可选 **Windows: 仅重新打包差分补丁**；它跳过 Godot 导出，但仍验证新旧文件和差分结果。产物位于 `builds/installers/MulticolorArena-<旧版本>-to-<新版本>-win64-patch.exe`。详细前提及自定义旧版目录的方法见 `docs/修复补丁安装包.md`。

## 在 VS Code 推送云端差分更新包

运行“终端 → 运行任务”，选择 **发布: 创建并推送双端 PCK 差分更新包到云端**。任务调用 `tools/publish-pck-update.ps1 -UseInstalledWindowsPck -Publish`，从 `project.godot` 读取目标版本，从 `D:\Program Files (x86)\MulticolorArena` 的发行 PCK 和本机已安装签名补丁链识别实际来源版本，合成完整 Windows 基线并使用对应 Android 快照导出差分包。流程同时保留 1.2.7.1 累计兼容包，然后签名、上传 ECS、核对云端 SHA-256 并切换 `pck/chain.json` 和 `pck/latest.json`。客户端登录后检查清单并下载更新。

已经通过 **发布: 创建 Windows 和 Android PCK 补丁** 生成当前版本的补丁时，可选择 **PCK: 推送已构建差分更新包到云端**，等价于 `tools/publish-pck-update.ps1 -UseInstalledWindowsPck -SkipBuild -Publish`。任务复用 `builds/pck-patches/<安装版实际版本>-to-<目标版本>/` 的双端补丁，以及 `1.2.7.1-to-<目标版本>/` 的双端累计包，重新生成签名清单并上传。

验证更新时选择 **PCK: 用虚拟新版本测试安装版自动更新**。任务生成独立测试版本和真实差分，在发行 EXE 副本、隔离用户目录和本机回环服务中验证登录下载、安装、重启资源及避免重复下载，报告保存在 `builds/pck-tests/`；源码版本和正式发布清单保持不变。安装目录完整 PCK 的版本可能早于实际运行版本，任务会合并用户目录已有补丁来识别后者。

目标版本须高于固定基底 **1.2.7.1**，且云端不能已有同名版本目录。运行前须有本地发行签名私钥 `.godot-toolchain/release-signing.key` 和 ECS SSH 私钥 `%USERPROFILE%\.ssh\id_ed25519_multicolor_ecs`；SSH 私钥口令在任务终端中输入。补丁机制及基底准备见 [双端 PCK 补丁](docs/PCK补丁.md)。

推送任务会在构建前检查 SSH 和暂存目录。连接失败时可运行 **PCK: 检查云端推送连接**（`tools/publish-pck-update.ps1 -CheckConnection`），查看保留在异常中的 SSH 原始报错。若出现 `kex_exchange_identification: read: Connection reset`，说明连接在 SSH 握手阶段被重置，目录命令尚未执行；先检查代理/TUN/VPN 是否转发服务器流量，再检查 ECS 的 SSH 日志和来源 IP 限制。使用代理时，可将 `8.137.122.187` 设置为直连后重新检查。

## 素材说明

直接下载 GitHub 源码 ZIP 时，Git LFS 管理的图片可能只是百余字节的指针，Godot 无法导入。本地已从[项目原仓库](https://github.com/ChinatsuHinata/Multicolor-Arena)恢复本次编译需要的图片，并逐个校验 SHA-256。重新获取源码时建议使用 Git 和 Git LFS：

```powershell
git lfs install
git clone https://github.com/ChinatsuHinata/Multicolor-Arena.git
```

Godot 安装来源：[官方 4.7.2 下载页](https://godotengine.org/download/archive/4.7.2-stable/)。
