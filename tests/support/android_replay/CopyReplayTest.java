package org.multicolorarena.replay;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

/** JVM regression checks for streaming validation; never instantiates Android UI. */
public final class CopyReplayTest {
    private static int checks;
    private static void check(boolean pass, String message) {
        if (!pass) throw new AssertionError(message);
        checks++;
    }
    private static void invalid(InputStream input, File target, String message) throws Exception {
        boolean rejected = false;
        try (FileOutputStream out = new FileOutputStream(target)) {
            try { ReplayOpenActivity.copyReplay(input, out); }
            catch (Exception expected) { rejected = true; }
        }
        check(rejected, message);
    }
    public static void main(String[] args) throws Exception {
        File target = File.createTempFile("replay-copy-test-", ".bin");
        try {
            byte[] good = "MREPLY1\nexample fixture payload".getBytes(StandardCharsets.UTF_8);
            InputStream split = new ByteArrayInputStream(good) {
                @Override public synchronized int read(byte[] b, int off, int len) { return super.read(b, off, Math.min(len, 3)); }
            };
            try (FileOutputStream out = new FileOutputStream(target)) { ReplayOpenActivity.copyReplay(split, out); }
            check(java.util.Arrays.equals(Files.readAllBytes(target.toPath()), good), "short provider reads preserve complete bytes");
            invalid(new ByteArrayInputStream("MREPLY0\nbad".getBytes(StandardCharsets.UTF_8)), target, "bad magic rejected");
            invalid(new ByteArrayInputStream("MREPL".getBytes(StandardCharsets.UTF_8)), target, "truncated magic rejected");
            invalid(new ByteArrayInputStream(new byte[0]), target, "empty file rejected");
            Thread.currentThread().interrupt();
            invalid(new ByteArrayInputStream(good), target, "cancelled imports stop copying");
            Thread.interrupted();
            InputStream infinite = new InputStream() {
                long position;
                final byte[] magic = "MREPLY1\n".getBytes(StandardCharsets.US_ASCII);
                @Override public int read() { return position < magic.length ? magic[(int) position++] : 0; }
                @Override public int read(byte[] b, int off, int len) {
                    java.util.Arrays.fill(b, off, off + len, (byte) 0);
                    for (int i = 0; i < len && position + i < magic.length; i++) b[off + i] = magic[(int) position + i];
                    position += len; return len;
                }
            };
            invalid(infinite, new File(System.getProperty("os.name").startsWith("Windows") ? "NUL" : "/dev/null"), "unbounded provider stops at 128 MiB");
            System.out.println("Native replay streaming: " + checks + " checks passed");
        } finally { target.delete(); }
    }
}
