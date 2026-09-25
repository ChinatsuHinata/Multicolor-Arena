#ifndef FromVersion
  #error FromVersion must be passed by build-patch.ps1
#endif
#ifndef ToVersion
  #error ToVersion must be passed by build-patch.ps1
#endif
#ifndef PatchDir
  #error PatchDir must be passed by build-patch.ps1
#endif
#ifndef InstallerOutputDir
  #error InstallerOutputDir must be passed by build-patch.ps1
#endif

[Setup]
AppId=MulticolorArena.Game
AppName=multicolor:arena
AppVersion={#ToVersion}
AppVerName=multicolor:arena {#ToVersion} 修复补丁
DefaultDirName={localappdata}\Programs\MulticolorArena
DefaultGroupName=Multicolor Arena
UsePreviousAppDir=yes
DisableDirPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no
UninstallDisplayIcon={app}\MulticolorArena.exe
OutputDir={#InstallerOutputDir}
OutputBaseFilename=MulticolorArena-{#FromVersion}-to-{#ToVersion}-win64-patch
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "chinesesimp"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Files]
; Only patch data and its applier are embedded. No full EXE/PCK or player data.
Source: "{#PatchDir}\PatchBundle.bin"; Flags: dontcopy
Source: "{#PatchDir}\patch-engine.cs"; Flags: dontcopy
Source: "{#PatchDir}\apply-patch.ps1"; Flags: dontcopy

[Code]
const
  UninstallKey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\MulticolorArena.Game_is1';

function CheckVersion(const Root: HKEY; var Found: Boolean): Boolean;
var
  InstalledVersion: String;
begin
  Result := True;
  if not RegKeyExists(Root, UninstallKey) then
    Exit;
  Found := True;
  if not RegQueryStringValue(Root, UninstallKey, 'DisplayVersion', InstalledVersion) then
  begin
    Result := False;
    Exit;
  end;
  Result := InstalledVersion = '{#FromVersion}';
end;

function InitializeSetup: Boolean;
var
  Found: Boolean;
begin
  Found := False;
  Result := CheckVersion(HKEY_CURRENT_USER_64, Found) and
    CheckVersion(HKEY_CURRENT_USER_32, Found) and Found;
  if not Result and not WizardSilent then
    MsgBox('此修复补丁仅适用于已安装的 multicolor:arena {#FromVersion}。请先安装对应的完整版本。', mbError, MB_OK);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
  PowerShell, Parameters: String;
begin
  Result := '';
  if not DirExists(WizardDirValue) then
  begin
    Result := '找不到原有游戏安装目录。';
    Exit;
  end;
  ExtractTemporaryFile('PatchBundle.bin');
  ExtractTemporaryFile('patch-engine.cs');
  ExtractTemporaryFile('apply-patch.ps1');
  PowerShell := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
  Parameters := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{tmp}\apply-patch.ps1') +
    '" -InstallDir "' + WizardDirValue + '" -PatchPath "' + ExpandConstant('{tmp}\PatchBundle.bin') +
    '" -FromVersion "{#FromVersion}" -ToVersion "{#ToVersion}"';
  if not Exec(PowerShell, Parameters, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) or (ResultCode <> 0) then
    Result := '修复补丁应用失败。请关闭游戏，并确认安装目录中的文件来自 {#FromVersion} 完整版。';
end;
