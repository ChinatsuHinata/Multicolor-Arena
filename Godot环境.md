# Godot 开发环境

本项目使用 **Godot 4.7.2 stable 标准版（Windows x86_64）** 和 GDScript。项目内已放置对应编辑器、Windows 调试模板及正式导出模板；Godot 的便携模式会将编辑器设置保存在 `.godot-toolchain/editor/editor_data`，不影响已安装的其他版本。

## 打开和编译

- 双击项目根目录的 `启动Godot.cmd` 打开编辑器。
- 双击 `编译Windows.cmd` 执行资源导入并正式导出。生成 `builds/Windows-1.2/MulticolorArena.exe` 和同名 `.pck`；分享时两者必须放在一起。
- 命令行也可运行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/build-windows.ps1`。

## 在 VS Code 启动和运行测试

在 VS Code 中打开**项目根目录**，按 `Ctrl+Shift+B` 即可启动 Godot 游戏窗口，直接进行手动测试。游戏进程在 VS Code 终端中运行；关闭游戏窗口即可结束任务。此快捷键调用当前工作区的 `.godot-toolchain/editor/Godot_v4.7.2-stable_win64.exe`，无需另装 Godot 或输入命令。任务定义保存在本机 `.vscode/tasks.json`；该目录已被 Git 忽略，重新克隆项目时需复制这份配置。

其他任务可从 `Ctrl+Shift+P` 打开命令面板，运行 **Tasks: Run Task（任务: 运行任务）** 后选择：

- **Godot: 打开编辑器**：打开本项目的 Godot 编辑器。进入编辑器后按 Godot 的 `F6` 可运行当前场景，按 `F5` 可运行整个项目。
- **Godot: 运行当前测试脚本**：先在 VS Code 打开 `tests/` 下要运行的 `.gd` 测试文件，再执行该任务。它以无界面模式运行，测试结果和退出码显示在终端中。
- **Windows: 创建安装包**：重新导入、导出并创建安装程序。安装任务现在从任务列表选择，不再占用 `Ctrl+Shift+B`。
- **Windows: 创建差分补丁**：输入要升级的旧版本号，导出当前版本并制作、验证差分安装器。
- **Windows: 仅重新打包差分补丁**：输入旧版本号，复用 `builds/installer-staging/<当前版本>/` 中已有的 EXE/PCK。

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

先安装 [Inno Setup 6 或 7](https://jrsoftware.org/isdl.php)。在 VS Code 打开本项目后，运行“终端 → 运行任务”，选择 **Windows: 创建安装包**。任务会重新导入、导出 Windows 游戏，然后生成 `builds/installers/MulticolorArena-<版本>-win64-setup.exe`，并输出 SHA-256。命令行等价于：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/build-installer.ps1
```

仅调整安装脚本且已有同版本导出文件时，可以运行 **Windows: 仅重新打包安装包**。如果 Inno Setup 装在其他目录，可传 `-IsccPath 'C:\完整路径\ISCC.exe'`。

安装程序按固定 AppId 检测此前由本安装包安装的版本，自动选用原安装目录并覆盖更新 EXE/PCK。默认安装在当前用户的 `%LOCALAPPDATA%\Programs\MulticolorArena`，无需管理员权限。更新不打包也不删除安装目录中的 `deck`、`replay`，用户目录中的设置与联机身份也不受影响。旧版 ZIP 便携包没有安装记录，无法自动定位；若要在原文件夹覆盖，请在首次运行安装程序时手动选中该文件夹，并确保该文件夹可写。

编译脚本会检查 Godot 版本、Git LFS 图片是否仍为指针、导入错误、导出错误以及 EXE/PCK 是否生成。日志位于 `.godot-toolchain/logs/`。

## 在 VS Code 创建差分补丁

运行“终端 → 运行任务”，选择 **Windows: 创建差分补丁**，输入要升级的旧版本号，例如 `1.2.1`。任务从 `project.godot` 读取新版本号，要求旧版 EXE/PCK 位于 `builds/installer-staging/<旧版本>/`，随后导出新版、验证差分并编译安装器。已有当前版本导出文件时，可选 **Windows: 仅重新打包差分补丁**；它跳过 Godot 导出，但仍验证新旧文件和差分结果。产物位于 `builds/installers/MulticolorArena-<旧版本>-to-<新版本>-win64-patch.exe`。详细前提及自定义旧版目录的方法见 `docs/修复补丁安装包.md`。

## 素材说明

直接下载 GitHub 源码 ZIP 时，Git LFS 管理的图片可能只是百余字节的指针，Godot 无法导入。本地已从[项目原仓库](https://github.com/ChinatsuHinata/Multicolor-Arena)恢复本次编译需要的图片，并逐个校验 SHA-256。重新获取源码时建议使用 Git 和 Git LFS：

```powershell
git lfs install
git clone https://github.com/ChinatsuHinata/Multicolor-Arena.git
```

Godot 安装来源：[官方 4.7.2 下载页](https://godotengine.org/download/archive/4.7.2-stable/)。当前构建脚本针对 Windows Desktop 预设；项目中的 Android 预设仍需单独配置 Android SDK、JDK 和签名。
