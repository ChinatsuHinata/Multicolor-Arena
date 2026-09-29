using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using Microsoft.Win32;

internal sealed class SavedValue
{
    internal bool Exists;
    internal object Data;
    internal RegistryValueKind Kind;
}

internal interface IVersionRecord : IDisposable
{
    string ViewName { get; }
    SavedValue Read(string name);
    void Write(string name, SavedValue value);
}

internal sealed class WindowsVersionRecord : IVersionRecord
{
    private readonly RegistryKey key;
    public string ViewName { get; private set; }

    internal WindowsVersionRecord(RegistryKey key, string viewName)
    {
        this.key = key;
        ViewName = viewName;
    }

    public SavedValue Read(string name)
    {
        if (!key.GetValueNames().Contains(name, StringComparer.OrdinalIgnoreCase))
            return new SavedValue();
        return new SavedValue { Exists = true, Kind = key.GetValueKind(name),
            Data = key.GetValue(name, null, RegistryValueOptions.DoNotExpandEnvironmentNames) };
    }

    public void Write(string name, SavedValue value)
    {
        if (value.Exists) key.SetValue(name, value.Data, value.Kind);
        else key.DeleteValue(name, false);
        key.Flush();
    }

    public void Dispose() { key.Dispose(); }
}

internal static class VersionRepair
{
    internal const string KeyPath = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\MulticolorArena.Game_is1";
    internal const string Marker = "MulticolorArenaVersionReset";

    internal static List<IVersionRecord> OpenRecords(bool writable)
    {
        var records = new List<IVersionRecord>();
        try
        {
            var views = Environment.Is64BitOperatingSystem
                ? new[] { RegistryView.Registry64, RegistryView.Registry32 }
                : new[] { RegistryView.Registry32 };
            foreach (var view in views)
            {
                using (var root = RegistryKey.OpenBaseKey(RegistryHive.CurrentUser, view))
                {
                    var key = root.OpenSubKey(KeyPath, writable);
                    if (key != null) records.Add(new WindowsVersionRecord(key,
                        view == RegistryView.Registry64 ? "64" : "32"));
                }
            }
            return records;
        }
        catch
        {
            foreach (var record in records) record.Dispose();
            throw;
        }
    }

    // Back up both views before touching either. Tests use memory records.
    internal static string Reset(IList<IVersionRecord> records, string backupRoot)
    {
        if (records.Count == 0) return null;
        var versions = records.Select(r => r.Read("DisplayVersion")).ToArray();
        var markers = records.Select(r => r.Read(Marker)).ToArray();
        if (versions.All(v => !v.Exists) && markers.All(IsReset)) return null;

        var folder = Path.Combine(backupRoot, DateTime.Now.ToString("yyyyMMdd-HHmmss") + "-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(folder);
        var restore = new StringBuilder("@echo off\r\nsetlocal\r\n");
        for (int i = 0; i < records.Count; i++)
        {
            var name = "version-" + records[i].ViewName + ".reg";
            var body = "Windows Registry Editor Version 5.00\r\n\r\n[HKEY_CURRENT_USER\\" + KeyPath + "]\r\n"
                + ExportValue("DisplayVersion", versions[i]) + "\r\n" + ExportValue(Marker, markers[i]) + "\r\n";
            File.WriteAllText(Path.Combine(folder, name), body, Encoding.Unicode);
            restore.Append("reg.exe import \"%~dp0" + name + "\" /reg:" + records[i].ViewName + "\r\n");
            restore.Append("if errorlevel 1 goto failed\r\n");
        }
        restore.Append("echo Version record restored.\r\npause\r\nexit /b 0\r\n:failed\r\necho Restore failed.\r\npause\r\nexit /b 1\r\n");
        File.WriteAllText(Path.Combine(folder, "Restore.cmd"), restore.ToString(), Encoding.ASCII);

        // Stop if an installer changed the values while the backups were written.
        for (int i = 0; i < records.Count; i++)
            if (ExportValue("v", records[i].Read("DisplayVersion")) != ExportValue("v", versions[i]) ||
                ExportValue("v", records[i].Read(Marker)) != ExportValue("v", markers[i]))
                throw new IOException("安装记录刚刚发生变化，请关闭安装器后重试。备份：" + folder);

        try
        {
            foreach (var record in records)
            {
                record.Write(Marker, new SavedValue { Exists = true, Data = "1", Kind = RegistryValueKind.String });
                record.Write("DisplayVersion", new SavedValue());
            }
            foreach (var record in records)
                if (record.Read("DisplayVersion").Exists || !IsReset(record.Read(Marker)))
                    throw new IOException("无法确认版本记录已清除。");
        }
        catch (Exception error)
        {
            var rollbackErrors = new List<string>();
            for (int i = 0; i < records.Count; i++)
            {
                try { records[i].Write("DisplayVersion", versions[i]); }
                catch (Exception e) { rollbackErrors.Add(e.Message); }
                try { records[i].Write(Marker, markers[i]); }
                catch (Exception e) { rollbackErrors.Add(e.Message); }
            }
            throw new IOException(error.Message + "\r\n" +
                (rollbackErrors.Count == 0 ? "原版本记录已恢复。" : "自动恢复未完成：" + string.Join("；", rollbackErrors)) +
                "\r\n备份：" + folder, error);
        }
        return folder;
    }

    internal static bool IsReset(SavedValue value)
    {
        return value.Exists && value.Kind == RegistryValueKind.String && (string)value.Data == "1";
    }

    internal static string ExportValue(string name, SavedValue value)
    {
        string prefix = "\"" + name + "\"=";
        if (!value.Exists) return prefix + "-";
        if (value.Kind == RegistryValueKind.DWord)
            return prefix + "dword:" + unchecked((uint)(int)value.Data).ToString("x8");
        byte[] bytes;
        string type;
        switch (value.Kind)
        {
            case RegistryValueKind.String:
                type = "hex(1):";
                bytes = Encoding.Unicode.GetBytes((string)value.Data + "\0");
                break;
            case RegistryValueKind.ExpandString:
                type = "hex(2):";
                bytes = Encoding.Unicode.GetBytes((string)value.Data + "\0");
                break;
            case RegistryValueKind.MultiString:
                type = "hex(7):";
                bytes = Encoding.Unicode.GetBytes(string.Join("\0", (string[])value.Data) + "\0\0");
                break;
            case RegistryValueKind.QWord:
                type = "hex(b):"; bytes = BitConverter.GetBytes((long)value.Data); break;
            case RegistryValueKind.Binary:
                type = "hex:"; bytes = (byte[])value.Data; break;
            case RegistryValueKind.None:
                type = "hex(0):"; bytes = (byte[])value.Data; break;
            default: throw new IOException("无法备份版本记录的数据类型：" + value.Kind);
        }
        return prefix + type + string.Join(",", bytes.Select(b => b.ToString("x2")));
    }
}

internal sealed class RepairWindow : Form
{
    private readonly TextBox status = new TextBox();
    private readonly Button reset = new Button();
    private readonly Button backups = new Button();
    private readonly string backupRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "MulticolorArena", "VersionRepairBackups");

    internal RepairWindow()
    {
        Text = "multicolor:arena · 版本记录修复";
        ClientSize = new Size(570, 365);
        Font = new Font("Microsoft YaHei UI", 10);
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        var intro = new Label { Left = 22, Top = 18, Width = 525, Height = 96,
            Text = "用于误装版本后，因版本号限制无法重新安装的情况。\r\n请先关闭游戏及安装器。工具会备份并清除安装版本记录，\r\n保留游戏文件、卸载信息、安装路径、卡组、回放和设置。\r\n完成后，请使用配套的新版完整安装包重新安装。" };
        status.SetBounds(22, 122, 526, 144);
        status.Multiline = true;
        status.ReadOnly = true;
        status.ScrollBars = ScrollBars.Vertical;
        reset.Text = "清除版本记录";
        reset.SetBounds(22, 286, 158, 40);
        reset.Click += delegate { RunRepair(); };
        backups.Text = "打开备份目录";
        backups.SetBounds(194, 286, 158, 40);
        backups.Click += delegate
        {
            try
            {
                Directory.CreateDirectory(backupRoot);
                System.Diagnostics.Process.Start("explorer.exe", "\"" + backupRoot + "\"");
            }
            catch (Exception e) { ShowError(e); }
        };
        var close = new Button { Text = "关闭", Left = 390, Top = 286, Width = 158, Height = 40 };
        close.Click += delegate { Close(); };
        Controls.AddRange(new Control[] { intro, status, reset, backups, close });
        Shown += delegate { RefreshRecords(); };
    }

    private void RefreshRecords()
    {
        List<IVersionRecord> records = null;
        try
        {
            records = VersionRepair.OpenRecords(false);
            if (records.Count == 0)
            {
                status.Text = "当前 Windows 用户没有本游戏的安装记录。\r\n便携 ZIP 版无需清除版本记录，可直接使用完整安装包。";
                reset.Enabled = false;
                return;
            }
            status.Text = string.Join("\r\n", records.Select(r =>
            {
                var version = r.Read("DisplayVersion");
                return r.ViewName + " 位记录：" + (version.Exists ? Convert.ToString(version.Data) :
                    (VersionRepair.IsReset(r.Read(VersionRepair.Marker)) ? "已清除，可重新安装" : "版本号缺失，可修复"));
            }));
            reset.Enabled = records.Any(r => r.Read("DisplayVersion").Exists || !VersionRepair.IsReset(r.Read(VersionRepair.Marker)));
        }
        catch (Exception e) { reset.Enabled = false; ShowError(e); }
        finally { if (records != null) foreach (var record in records) record.Dispose(); }
    }

    private void RunRepair()
    {
        if (MessageBox.Show(this, "清除后，可用配套的完整安装包重新安装（包括较旧版本）。\r\n差分补丁无法用于重新安装。\r\n\r\n现在备份并清除版本记录？",
            "确认修复", MessageBoxButtons.OKCancel, MessageBoxIcon.Information) != DialogResult.OK) return;
        List<IVersionRecord> records = null;
        reset.Enabled = false;
        try
        {
            records = VersionRepair.OpenRecords(true);
            var folder = VersionRepair.Reset(records, backupRoot);
            foreach (var record in records) record.Dispose();
            records = null;
            RefreshRecords();
            if (folder != null)
                status.AppendText("\r\n\r\n修复完成。请运行配套的完整安装包。\r\n备份：" + folder);
        }
        catch (Exception e) { ShowError(e); RefreshRecords(); }
        finally { if (records != null) foreach (var record in records) record.Dispose(); }
    }

    private void ShowError(Exception error)
    {
        MessageBox.Show(this, error.Message, "修复未完成", MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
}

internal static class VersionRepairProgram
{
    [STAThread]
    private static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new RepairWindow());
    }
}
