using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;

// Shared by build-patch.ps1 and apply-patch.ps1. Uses only the .NET Framework
// shipped with Windows PowerShell; no third-party patch tool is needed.
public static class ArenaPatch
{
    private const int Window = 64;
    private const int Stride = 4096;
    private const ulong Multiplier = 257;
    private static readonly byte[] Magic = Encoding.ASCII.GetBytes("MAPATCH1");
    private static readonly string[] Names = { "MulticolorArena.exe", "MulticolorArena.pck" };

    private sealed class Entry
    {
        public string Name;
        public byte[] OldHash;
        public byte[] NewHash;
        public long NewLength;
        public long OperationsStart;
        public long OperationsEnd;
        public string Temporary;
        public string Backup;
    }

    private static byte[] Hash(byte[] data)
    {
        using (var sha = SHA256.Create()) return sha.ComputeHash(data);
    }

    private static byte[] HashFile(string path)
    {
        using (var sha = SHA256.Create())
        using (var stream = File.OpenRead(path)) return sha.ComputeHash(stream);
    }

    private static bool Equal(byte[] a, byte[] b)
    {
        if (a.Length != b.Length) return false;
        for (int i = 0; i < a.Length; i++) if (a[i] != b[i]) return false;
        return true;
    }

    private static ulong Power()
    {
        ulong result = 1;
        unchecked { for (int i = 1; i < Window; i++) result *= Multiplier; }
        return result;
    }

    private static ulong WindowHash(byte[] data, int start)
    {
        ulong result = 0;
        unchecked { for (int i = 0; i < Window; i++) result = result * Multiplier + data[start + i]; }
        return result;
    }

    private static void WriteLiteral(BinaryWriter writer, byte[] target, int start, int end)
    {
        if (end == start) return;
        writer.Write((byte)1);
        writer.Write(end - start);
        writer.Write(target, start, end - start);
    }

    private static void WriteOperations(BinaryWriter writer, byte[] source, byte[] target)
    {
        var anchors = new Dictionary<ulong, List<int>>();
        for (int i = 0; i + Window <= source.Length; i += Stride)
        {
            ulong hash = WindowHash(source, i);
            List<int> positions;
            if (!anchors.TryGetValue(hash, out positions))
            {
                positions = new List<int>();
                anchors.Add(hash, positions);
            }
            positions.Add(i);
        }

        ulong power = Power();
        int cursor = 0, literalStart = 0;
        ulong rolling = target.Length >= Window ? WindowHash(target, 0) : 0;
        while (cursor + Window <= target.Length)
        {
            List<int> positions;
            int bestStart = -1, bestLength = 0;
            if (anchors.TryGetValue(rolling, out positions))
            {
                foreach (int start in positions)
                {
                    int length = 0;
                    while (start + length < source.Length && cursor + length < target.Length &&
                           source[start + length] == target[cursor + length]) length++;
                    if (length > bestLength) { bestStart = start; bestLength = length; }
                }
            }
            if (bestLength >= Window)
            {
                WriteLiteral(writer, target, literalStart, cursor);
                writer.Write((byte)0);
                writer.Write((long)bestStart);
                writer.Write((long)bestLength);
                cursor += bestLength;
                literalStart = cursor;
                if (cursor + Window <= target.Length) rolling = WindowHash(target, cursor);
            }
            else
            {
                if (cursor + Window == target.Length) break;
                unchecked { rolling = (rolling - (ulong)target[cursor] * power) * Multiplier + target[cursor + Window]; }
                cursor++;
            }
        }
        WriteLiteral(writer, target, literalStart, target.Length);
        writer.Write((byte)255);
    }

    public static void Create(string sourceDir, string targetDir, string output, string fromVersion, string toVersion)
    {
        if (String.IsNullOrWhiteSpace(fromVersion) || String.IsNullOrWhiteSpace(toVersion) || fromVersion == toVersion)
            throw new InvalidOperationException("Source and target versions must be different.");
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(output)));
        using (var stream = new FileStream(output, FileMode.Create, FileAccess.Write, FileShare.None))
        using (var writer = new BinaryWriter(stream, Encoding.UTF8))
        {
            writer.Write(Magic);
            writer.Write(fromVersion);
            writer.Write(toVersion);
            writer.Write(Names.Length);
            foreach (string name in Names)
            {
                string oldPath = Path.Combine(sourceDir, name), newPath = Path.Combine(targetDir, name);
                byte[] oldBytes = File.ReadAllBytes(oldPath), newBytes = File.ReadAllBytes(newPath);
                writer.Write(name);
                writer.Write(Hash(oldBytes));
                writer.Write(Hash(newBytes));
                writer.Write((long)newBytes.Length);
                WriteOperations(writer, oldBytes, newBytes);
                Console.WriteLine(name + ": " + oldBytes.Length + " -> " + newBytes.Length + " bytes");
            }
        }
    }

    private static List<Entry> ReadEntries(BinaryReader reader)
    {
        if (!Equal(reader.ReadBytes(Magic.Length), Magic)) throw new InvalidDataException("Invalid patch header.");
        reader.ReadString(); // Version gating is also done by the installer.
        reader.ReadString();
        if (reader.ReadInt32() != Names.Length) throw new InvalidDataException("Unexpected file count.");
        var entries = new List<Entry>();
        foreach (string expectedName in Names)
        {
            var entry = new Entry();
            entry.Name = reader.ReadString();
            if (entry.Name != expectedName) throw new InvalidDataException("Unexpected patch file name.");
            entry.OldHash = reader.ReadBytes(32);
            entry.NewHash = reader.ReadBytes(32);
            entry.NewLength = reader.ReadInt64();
            if (entry.OldHash.Length != 32 || entry.NewHash.Length != 32 || entry.NewLength < 0)
                throw new InvalidDataException("Invalid patch metadata.");
            entry.OperationsStart = reader.BaseStream.Position;
            long written = 0;
            while (true)
            {
                byte op = reader.ReadByte();
                if (op == 255) break;
                long count;
                if (op == 0)
                {
                    long offset = reader.ReadInt64();
                    count = reader.ReadInt64();
                    if (offset < 0) throw new InvalidDataException("Invalid source offset.");
                }
                else if (op == 1)
                {
                    count = reader.ReadInt32();
                    if (count < 0 || count > reader.BaseStream.Length - reader.BaseStream.Position)
                        throw new InvalidDataException("Invalid literal length.");
                    reader.BaseStream.Seek(count, SeekOrigin.Current);
                }
                else throw new InvalidDataException("Invalid patch operation.");
                if (count <= 0 || count > entry.NewLength - written) throw new InvalidDataException("Invalid output length.");
                written += count;
            }
            if (written != entry.NewLength) throw new InvalidDataException("Incomplete patch output.");
            entry.OperationsEnd = reader.BaseStream.Position;
            entries.Add(entry);
        }
        if (reader.BaseStream.Position != reader.BaseStream.Length) throw new InvalidDataException("Trailing patch data.");
        return entries;
    }

    private static void CopyExactly(Stream input, Stream output, long count)
    {
        byte[] buffer = new byte[131072];
        while (count > 0)
        {
            int take = (int)Math.Min(count, buffer.Length);
            int read = input.Read(buffer, 0, take);
            if (read == 0) throw new EndOfStreamException("Incomplete patch input.");
            output.Write(buffer, 0, read);
            count -= read;
        }
    }

    private static void Materialize(BinaryReader reader, Entry entry, string oldPath)
    {
        reader.BaseStream.Position = entry.OperationsStart;
        using (var oldFile = File.OpenRead(oldPath))
        using (var output = new FileStream(entry.Temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None))
        {
            while (reader.BaseStream.Position < entry.OperationsEnd)
            {
                byte op = reader.ReadByte();
                if (op == 255) break;
                if (op == 0)
                {
                    long offset = reader.ReadInt64(), count = reader.ReadInt64();
                    if (offset < 0 || count < 0 || offset > oldFile.Length - count)
                        throw new InvalidDataException("Copy exceeds source file.");
                    oldFile.Position = offset;
                    CopyExactly(oldFile, output, count);
                }
                else
                {
                    int count = reader.ReadInt32();
                    CopyExactly(reader.BaseStream, output, count);
                }
            }
        }
        if (!Equal(HashFile(entry.Temporary), entry.NewHash)) throw new InvalidDataException("Patched file hash mismatch: " + entry.Name);
    }

    public static void Apply(string installDir, string patchPath, string expectedFrom, string expectedTo)
    {
        using (var stream = File.OpenRead(patchPath))
        using (var reader = new BinaryReader(stream, Encoding.UTF8))
        {
            if (!Equal(reader.ReadBytes(Magic.Length), Magic) || reader.ReadString() != expectedFrom ||
                reader.ReadString() != expectedTo) throw new InvalidDataException("Patch version mismatch.");
            stream.Position = 0;
            List<Entry> entries = ReadEntries(reader);
            var changed = new List<Entry>();
            foreach (Entry entry in entries)
            {
                string installed = Path.Combine(installDir, entry.Name);
                if (!File.Exists(installed)) throw new FileNotFoundException("Installed game file missing.", installed);
                byte[] actual = HashFile(installed);
                if (Equal(actual, entry.NewHash)) continue; // Retry after interrupted installer.
                if (!Equal(actual, entry.OldHash)) throw new InvalidDataException("Installed file differs from base version: " + entry.Name);
                changed.Add(entry);
            }
            // Build and verify every new file before replacing any installed file.
            try
            {
                foreach (Entry entry in changed)
                {
                    string installed = Path.Combine(installDir, entry.Name);
                    entry.Temporary = installed + ".patch-" + Guid.NewGuid().ToString("N") + ".tmp";
                    Materialize(reader, entry, installed);
                }
                var replaced = new List<Entry>();
                try
                {
                    foreach (Entry entry in changed)
                    {
                        string installed = Path.Combine(installDir, entry.Name);
                        entry.Backup = installed + ".patch-backup-" + Guid.NewGuid().ToString("N") + ".bak";
                        File.Replace(entry.Temporary, installed, entry.Backup);
                        replaced.Add(entry);
                    }
                }
                catch
                {
                    for (int i = replaced.Count - 1; i >= 0; i--)
                    {
                        Entry entry = replaced[i];
                        File.Replace(entry.Backup, Path.Combine(installDir, entry.Name), null);
                        entry.Backup = null;
                    }
                    throw;
                }
                foreach (Entry entry in changed) if (entry.Backup != null) File.Delete(entry.Backup);
            }
            finally
            {
                foreach (Entry entry in changed)
                    if (entry.Temporary != null && File.Exists(entry.Temporary)) File.Delete(entry.Temporary);
            }
        }
    }
}
