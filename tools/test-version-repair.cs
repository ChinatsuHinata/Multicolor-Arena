using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Text;
using Microsoft.Win32;

internal sealed class MemoryRecord : IVersionRecord
{
    internal readonly Dictionary<string, SavedValue> Values;
    internal bool FailNextDelete;
    internal int Writes;
    public string ViewName { get; private set; }
    internal MemoryRecord(string view, Dictionary<string, SavedValue> values)
    {
        ViewName = view;
        Values = values;
    }
    public SavedValue Read(string name)
    {
        SavedValue value;
        return Values.TryGetValue(name, out value) ? value : new SavedValue();
    }
    public void Write(string name, SavedValue value)
    {
        Writes++;
        if (FailNextDelete && name == "DisplayVersion" && !value.Exists)
        {
            FailNextDelete = false;
            throw new IOException("Simulated delete failure");
        }
        if (value.Exists) Values[name] = value;
        else Values.Remove(name);
    }
    public void Dispose() { }
}

internal static class VersionRepairTests
{
    private static int checks;
    private static void Check(bool condition, string name)
    {
        if (!condition) throw new Exception("FAIL: " + name);
        checks++;
    }
    private static SavedValue Text(string data)
    {
        return new SavedValue { Exists = true, Data = data, Kind = RegistryValueKind.String };
    }
    private static MemoryRecord Record(string view, string version)
    {
        var values = new Dictionary<string, SavedValue>();
        if (version != null) values["DisplayVersion"] = Text(version);
        values["InstallLocation"] = Text(@"D:\游戏\multicolor");
        values["UninstallString"] = Text("unins000.exe");
        return new MemoryRecord(view, values);
    }

    [STAThread]
    private static int Main(string[] args)
    {
        try
        {
            string root = args[0];
            Directory.CreateDirectory(root);
            Check(VersionRepair.Reset(new IVersionRecord[0], Path.Combine(root, "absent")) == null,
                "missing installation is a no-op");
            Check(!Directory.Exists(Path.Combine(root, "absent")), "no empty backup for missing installation");

            var a = Record("64", "9.9.9");
            var b = Record("32", "bad\"version\\值");
            string backup = VersionRepair.Reset(new IVersionRecord[] { a, b }, root);
            Check(!a.Read("DisplayVersion").Exists && !b.Read("DisplayVersion").Exists, "both views cleared");
            Check(VersionRepair.IsReset(a.Read(VersionRepair.Marker)) && VersionRepair.IsReset(b.Read(VersionRepair.Marker)), "both markers written");
            Check((string)a.Read("InstallLocation").Data == @"D:\游戏\multicolor", "installation location preserved");
            Check((string)b.Read("UninstallString").Data == "unins000.exe", "uninstall information preserved");
            Check(File.ReadAllText(Path.Combine(backup, "version-64.reg"), Encoding.Unicode).Contains(
                VersionRepair.ExportValue("DisplayVersion", Text("9.9.9"))), "original version backed up");
            Check(File.ReadAllText(Path.Combine(backup, "version-32.reg"), Encoding.Unicode).Contains(
                VersionRepair.ExportValue("DisplayVersion", Text("bad\"version\\值"))), "malformed Unicode version backed up");
            Check(File.ReadAllText(Path.Combine(backup, "Restore.cmd")).Contains("/reg:64") &&
                File.ReadAllText(Path.Combine(backup, "Restore.cmd")).Contains("/reg:32"), "restore uses original views");
            int writes = a.Writes + b.Writes;
            Check(VersionRepair.Reset(new IVersionRecord[] { a, b }, root) == null && a.Writes + b.Writes == writes,
                "repeat reset is a no-op");

            var missing = Record("64", null);
            VersionRepair.Reset(new IVersionRecord[] { missing }, root);
            Check(!missing.Read("DisplayVersion").Exists && VersionRepair.IsReset(missing.Read(VersionRepair.Marker)),
                "manually removed version can be repaired");

            var corrupt = Record("64", null);
            corrupt.Values["DisplayVersion"] = new SavedValue { Exists = true, Data = 123, Kind = RegistryValueKind.DWord };
            string corruptBackup = VersionRepair.Reset(new IVersionRecord[] { corrupt }, root);
            Check(File.ReadAllText(Path.Combine(corruptBackup, "version-64.reg"), Encoding.Unicode).Contains("dword:0000007b"),
                "non-string version backed up before removal");

            var shared = Record("64", "2.0");
            var shared32 = new MemoryRecord("32", shared.Values);
            VersionRepair.Reset(new IVersionRecord[] { shared, shared32 }, root);
            Check(!shared.Read("DisplayVersion").Exists && VersionRepair.IsReset(shared.Read(VersionRepair.Marker)),
                "shared registry views are handled idempotently");

            var failA = Record("64", "3.0");
            failA.Values[VersionRepair.Marker] = Text("previous");
            var failB = Record("32", "4.0");
            failB.FailNextDelete = true;
            try
            {
                VersionRepair.Reset(new IVersionRecord[] { failA, failB }, root);
                throw new Exception("Missing expected write failure");
            }
            catch (IOException error)
            {
                Check(error.Message.Contains("原版本记录已恢复"), "failure reports rollback");
            }
            Check((string)failA.Read("DisplayVersion").Data == "3.0" && (string)failB.Read("DisplayVersion").Data == "4.0",
                "partial failure restores both versions");
            Check((string)failA.Read(VersionRepair.Marker).Data == "previous" && !failB.Read(VersionRepair.Marker).Exists,
                "partial failure restores original marker state");

            string blockedPath = Path.Combine(root, "blocked-backup");
            File.WriteAllText(blockedPath, "not a directory");
            var blocked = Record("64", "5.0");
            try
            {
                VersionRepair.Reset(new IVersionRecord[] { blocked }, blockedPath);
                throw new Exception("Missing expected backup failure");
            }
            catch (IOException) { }
            Check(blocked.Writes == 0 && (string)blocked.Read("DisplayVersion").Data == "5.0",
                "backup failure makes no registry changes");

            Check(VersionRepair.ExportValue("v", new SavedValue { Exists = true, Data = -1, Kind = RegistryValueKind.DWord }) ==
                "\"v\"=dword:ffffffff", "unsigned DWORD backup");
            Check(VersionRepair.ExportValue("v", new SavedValue { Exists = true, Data = 1L, Kind = RegistryValueKind.QWord }) ==
                "\"v\"=hex(b):01,00,00,00,00,00,00,00", "QWORD backup");
            Check(VersionRepair.ExportValue("v", new SavedValue { Exists = true, Data = "%USERPROFILE%", Kind = RegistryValueKind.ExpandString }).StartsWith(
                "\"v\"=hex(2):25,00"), "expandable value backed up without expansion");
            Check(VersionRepair.ExportValue("v", new SavedValue { Exists = true, Data = new string[] { "a", "b" }, Kind = RegistryValueKind.MultiString }) ==
                "\"v\"=hex(7):61,00,00,00,62,00,00,00,00,00", "multi-string backup");

            System.Windows.Forms.Application.EnableVisualStyles();
            using (var form = new RepairWindow())
            using (var bitmap = new Bitmap(form.Width, form.Height))
            {
                form.StartPosition = System.Windows.Forms.FormStartPosition.Manual;
                form.Location = new Point(-32000, -32000);
                form.Show();
                System.Windows.Forms.Application.DoEvents();
                form.Controls.OfType<System.Windows.Forms.TextBox>().Single().Text = "64 位记录：9.9.9\r\n32 位记录：9.9.9";
                form.DrawToBitmap(bitmap, new Rectangle(0, 0, bitmap.Width, bitmap.Height));
                bitmap.Save(Path.Combine(root, "repair-window.png"));
                form.Close();
            }
            Console.WriteLine("PASS: " + checks + " checks. No real installation records were modified.");
            Console.WriteLine("Artifacts: " + root);
            return 0;
        }
        catch (Exception error) { Console.Error.WriteLine(error); return 1; }
    }
}
