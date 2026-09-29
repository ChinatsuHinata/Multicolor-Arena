$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$iscc = Join-Path $root '.godot-toolchain/innosetup/ISCC.exe'
$testDir = Join-Path $root ('work/version-repair-installer-tests/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testDir -Force | Out-Null
$source = [IO.File]::ReadAllText((Join-Path $root 'installer/MulticolorArena.iss'))
$code = ($source -split '\[Code\]', 2)[1]
# Exercise the real installer logic with simulated registry calls. The test
# exits in InitializeSetup, before Inno Setup can install or write anything.
$code = $code.Replace('RegKeyExists(', 'FakeKeyExists(').Replace('RegValueExists(', 'FakeValueExists(').Replace('RegQueryStringValue(', 'FakeQuery(').Replace('RegDeleteValue(', 'FakeDelete(').Replace('function InitializeSetup:', 'function OriginalInitializeSetup:')
$globals = @'
  TestExists: array[0..1] of Boolean;
  TestHasVersion: array[0..1] of Boolean;
  TestVersion: array[0..1] of String;
  TestMarker: array[0..1] of String;
  TestCount: Integer;
  TestFailed: Boolean;
'@
$code = $code.Replace('  Updating: Boolean;', "  Updating: Boolean;`r`n$globals")
$fakes = @'
function TestIndex(const Root: HKEY): Integer;
begin
  if Root = HKEY_CURRENT_USER_32 then Result := 1 else Result := 0;
end;

function FakeKeyExists(const Root: HKEY; const Key: String): Boolean;
begin
  Result := TestExists[TestIndex(Root)];
end;

function FakeValueExists(const Root: HKEY; const Key, Name: String): Boolean;
begin
  Result := TestHasVersion[TestIndex(Root)];
end;

function FakeQuery(const Root: HKEY; const Key, Name: String; var Value: String): Boolean;
var I: Integer;
begin
  I := TestIndex(Root);
  if Name = 'DisplayVersion' then
  begin
    Result := TestHasVersion[I];
    Value := TestVersion[I];
  end
  else
  begin
    Result := TestMarker[I] <> '';
    Value := TestMarker[I];
  end;
end;

function FakeDelete(const Root: HKEY; const Key, Name: String): Boolean;
begin
  TestMarker[TestIndex(Root)] := '';
  Result := True;
end;

'@
$code = $code.Replace('function ParseAppVersion(', "$fakes`r`nfunction ParseAppVersion(")
$suite = @'

procedure TestRecord(const Exists, HasVersion: Boolean; const Version, Marker: String);
var I: Integer;
begin
  for I := 0 to 1 do
  begin
    TestExists[I] := Exists;
    TestHasVersion[I] := HasVersion;
    TestVersion[I] := Version;
    TestMarker[I] := Marker;
  end;
end;

procedure TestCheck(const Condition: Boolean; const Name: String);
begin
  TestCount := TestCount + 1;
  if not Condition then
  begin
    TestFailed := True;
    SaveStringToFile('{#TestReport}', 'FAIL: ' + Name + #13#10, True);
  end;
end;

function InitializeSetup: Boolean;
var Allowed: Boolean;
begin
  TestCount := 0;
  TestFailed := False;
  TestRecord(False, False, '', '');
  TestCheck(OriginalInitializeSetup, 'new installation allowed');
  TestRecord(True, True, '2.3.3', '');
  TestCheck(OriginalInitializeSetup and Updating, 'normal upgrade allowed');
  TestRecord(True, True, '2.3.4', '');
  TestCheck(not OriginalInitializeSetup, 'same version remains blocked');
  TestRecord(True, True, '9.0', '');
  TestCheck(not OriginalInitializeSetup, 'downgrade remains blocked');
  TestRecord(True, True, 'invalid', '');
  TestCheck(not OriginalInitializeSetup, 'corrupt unmarked version remains blocked');
  TestRecord(True, False, '', '');
  TestCheck(not OriginalInitializeSetup, 'missing unmarked version remains blocked');
  TestRecord(True, False, '', 'wrong');
  TestCheck(not OriginalInitializeSetup, 'invalid reset marker remains blocked');
  TestRecord(True, False, '', '1');
  Allowed := OriginalInitializeSetup;
  TestCheck(Allowed and not Updating, 'explicit reset allows full reinstall');
  TestRecord(True, True, '9.0', '1');
  TestCheck(not OriginalInitializeSetup, 'marker cannot override an existing version');
  TestRecord(True, True, '', '1');
  TestCheck(not OriginalInitializeSetup, 'empty existing value does not count as removed');
  TestRecord(True, False, '', '1');
  TestHasVersion[1] := True;
  TestVersion[1] := '9.0';
  TestCheck(not OriginalInitializeSetup, 'both registry views must allow installation');
  TestRecord(True, True, '2.3.4', '1');
  CurStepChanged(ssInstall);
  TestCheck((TestMarker[0] = '1') and (TestMarker[1] = '1'), 'marker retained until install succeeds');
  CurStepChanged(ssPostInstall);
  TestCheck((TestMarker[0] = '') and (TestMarker[1] = '') and
    (TestVersion[0] = '2.3.4') and (TestVersion[1] = '2.3.4'), 'successful install clears markers and retains version');
  if not TestFailed then
    SaveStringToFile('{#TestReport}', 'PASS: ' + IntToStr(TestCount) + ' installer checks.', False);
  Result := False;
end;
'@
$header = @"
#define AppVersion "2.3.4"
#define TestReport "$testDir\result.txt"
[Setup]
AppId=MulticolorArena.VersionRepairGateTest
AppName=Version Repair Gate Test
AppVersion={#AppVersion}
DefaultDirName={tmp}\MulticolorArenaVersionRepairGateTest
CreateAppDir=no
Uninstallable=no
PrivilegesRequired=lowest
OutputDir=$testDir
OutputBaseFilename=InstallerGateTests
Compression=none
[Code]
"@
$fixture = Join-Path $testDir 'installer-gates.iss'
[IO.File]::WriteAllText($fixture, "$header`r`n$code`r`n$suite", (New-Object Text.UTF8Encoding($true)))
& $iscc $fixture *> (Join-Path $testDir 'compile.log')
if ($LASTEXITCODE -ne 0) { throw "Gate test compilation failed. See $testDir/compile.log" }
$process = Start-Process -FilePath (Join-Path $testDir 'InstallerGateTests.exe') -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES' -WindowStyle Hidden -PassThru -Wait
$report = Join-Path $testDir 'result.txt'
if (-not (Test-Path -LiteralPath $report)) { throw "Missing test report. Exit code: $($process.ExitCode)" }
$result = Get-Content -LiteralPath $report -Raw
Write-Host $result
if (-not $result.StartsWith('PASS:')) { throw "Installer gate tests failed: $report" }
Write-Host "Artifacts: $testDir"
