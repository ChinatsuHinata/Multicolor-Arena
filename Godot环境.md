# Godot 开发环境

本项目使用 **Godot 4.7.2 stable 标准版（Windows x86_64）** 和 GDScript。项目内已放置对应编辑器、Windows 调试模板及正式导出模板；Godot 的便携模式会将编辑器设置保存在 `.godot-toolchain/editor/editor_data`，不影响已安装的其他版本。

## 打开和编译

- 双击项目根目录的 `启动Godot.cmd` 打开编辑器。
- 双击 `编译Windows.cmd` 执行资源导入并正式导出。生成 `builds/Windows-1.2/MulticolorArena.exe` 和同名 `.pck`；分享时两者必须放在一起。
- 命令行也可运行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/build-windows.ps1`。

## 在 VS Code 创建安装包

先安装 [Inno Setup 6 或 7](https://jrsoftware.org/isdl.php)。在 VS Code 打开本项目后，运行“终端 → 运行生成任务”，选择 **Windows: 创建安装包**，或按 `Ctrl+Shift+B`。任务会重新导入、导出 Windows 游戏，然后生成 `builds/installers/MulticolorArena-<版本>-win64-setup.exe`，并输出 SHA-256。命令行等价于：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/build-installer.ps1
```

仅调整安装脚本且已有同版本导出文件时，可以运行 **Windows: 仅重新打包安装包**。如果 Inno Setup 装在其他目录，可传 `-IsccPath 'C:\完整路径\ISCC.exe'`。

安装程序按固定 AppId 检测此前由本安装包安装的版本，自动选用原安装目录并覆盖更新 EXE/PCK。默认安装在当前用户的 `%LOCALAPPDATA%\Programs\MulticolorArena`，无需管理员权限。更新不打包也不删除安装目录中的 `deck`、`replay`，用户目录中的设置与联机身份也不受影响。旧版 ZIP 便携包没有安装记录，无法自动定位；若要在原文件夹覆盖，请在首次运行安装程序时手动选中该文件夹，并确保该文件夹可写。

编译脚本会检查 Godot 版本、Git LFS 图片是否仍为指针、导入错误、导出错误以及 EXE/PCK 是否生成。日志位于 `.godot-toolchain/logs/`。

## 素材说明

直接下载 GitHub 源码 ZIP 时，Git LFS 管理的图片可能只是百余字节的指针，Godot 无法导入。本地已从[项目原仓库](https://github.com/ChinatsuHinata/Multicolor-Arena)恢复本次编译需要的图片，并逐个校验 SHA-256。重新获取源码时建议使用 Git 和 Git LFS：

```powershell
git lfs install
git clone https://github.com/ChinatsuHinata/Multicolor-Arena.git
```

Godot 安装来源：[官方 4.7.2 下载页](https://godotengine.org/download/archive/4.7.2-stable/)。当前构建脚本针对 Windows Desktop 预设；项目中的 Android 预设仍需单独配置 Android SDK、JDK 和签名。
