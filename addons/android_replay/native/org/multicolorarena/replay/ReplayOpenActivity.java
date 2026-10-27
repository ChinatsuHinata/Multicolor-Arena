package org.multicolorarena.replay;

import android.app.Activity;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.provider.OpenableColumns;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InterruptedIOException;
import java.nio.charset.StandardCharsets;
import java.util.UUID;
import org.json.JSONObject;

/** Receives only replay VIEW intents. The source provider is never modified. */
public final class ReplayOpenActivity extends Activity {
    public static final long MAX_BYTES = 128L * 1024L * 1024L;
    private static final String MIME = "application/x-multicolorarena-replay";
    private static final byte[] MAGIC = "MREPLY1\n".getBytes(StandardCharsets.US_ASCII);
    private Thread worker;
    private final java.util.ArrayDeque<Intent> requests = new java.util.ArrayDeque<>();
    private boolean importing;

    @Override public void onCreate(Bundle savedState) {
        super.onCreate(savedState);
        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        int pad = (int) (24 * getResources().getDisplayMetrics().density);
        content.setPadding(pad, pad, pad, pad);
        content.addView(new ProgressBar(this));
        TextView text = new TextView(this);
        text.setText("正在读取回放…"); text.setTextSize(18);
        content.addView(text); setContentView(content);
        enqueue(getIntent());
    }

    @Override protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent); setIntent(intent);
        enqueue(intent);
    }

    private void enqueue(Intent intent) {
        if (requests.size() >= 8) {
            Toast.makeText(this, "待处理回放较多，请稍后重试。", Toast.LENGTH_LONG).show();
            return;
        }
        requests.add(new Intent(intent));
        if (!importing) receive(requests.remove());
    }

    private void complete() {
        if (isFinishing() || isDestroyed()) return;
        importing = false;
        if (requests.isEmpty()) openGame();
        else receive(requests.remove());
    }

    private void receive(final Intent intent) {
        importing = true;
        worker = new Thread(() -> {
            File inbox = new File(getCacheDir(), "replay-inbox");
            String id = UUID.randomUUID().toString().replace("-", "");
            File partial = new File(inbox, id + ".part");
            File replay = new File(inbox, id + ".mreply");
            try {
                if (!inbox.isDirectory() && !inbox.mkdirs()) throw new ImportFailure("无法创建回放缓存。");
                File[] stale = inbox.listFiles((dir, name) -> name.matches("[0-9a-f]{32}\\.(part|json\\.part)"));
                if (stale != null) for (File file : stale)
                    if (file.lastModified() < System.currentTimeMillis() - 24L * 60 * 60 * 1000) file.delete();
                File[] pending = inbox.listFiles((dir, name) -> name.matches("[0-9a-f]{32}\\.json"));
                if (pending != null && pending.length >= 8) {
                    runOnUiThread(() -> {
                        Toast.makeText(this, "待处理回放较多，请先回到游戏处理已有回放。", Toast.LENGTH_LONG).show();
                        complete();
                    });
                    return;
                }
                if (!Intent.ACTION_VIEW.equals(intent.getAction())) throw new ImportFailure("请从文件管理器打开回放文件。");
                Uri uri = intent.getData();
                if (uri == null || !("content".equals(uri.getScheme()) || "file".equals(uri.getScheme())))
                    throw new ImportFailure("不支持此回放文件位置。");
                String name = displayName(uri);
                String lower = name.toLowerCase(java.util.Locale.ROOT);
                if (!lower.endsWith(".mreply") && !lower.endsWith(".replay")) {
                    if (!MIME.equals(intent.getType())) throw new ImportFailure("请选择 .mreply 回放文件。");
                    name = "回放.mreply";
                }
                try (InputStream source = getContentResolver().openInputStream(uri);
                     FileOutputStream output = new FileOutputStream(partial)) {
                    if (source == null) throw new ImportFailure("无法读取回放，请重新从文件管理器打开。");
                    copyReplay(source, output);
                    output.getFD().sync();
                }
                if (Thread.currentThread().isInterrupted()) throw new InterruptedIOException();
                if (!partial.renameTo(replay)) throw new ImportFailure("无法保存回放缓存。");
                JSONObject request = new JSONObject();
                request.put("file", replay.getName()); request.put("name", name);
                publish(inbox, id, request);
                runOnUiThread(this::complete);
            } catch (InterruptedIOException cancelled) {
                partial.delete(); replay.delete();
            } catch (Exception failure) {
                partial.delete(); replay.delete();
                String message = failure instanceof ImportFailure ? failure.getMessage()
                    : "无法读取此回放，请确认文件仍可访问后重试。";
                try {
                    JSONObject request = new JSONObject(); request.put("error", message);
                    publish(inbox, id, request);
                    runOnUiThread(this::complete);
                } catch (Exception ignored) {
                    runOnUiThread(() -> { Toast.makeText(this, message, Toast.LENGTH_LONG).show(); complete(); });
                }
            }
        }, "ReplayImport");
        worker.start();
    }

    /** Bounded streaming prevents an untrusted provider from exhausting disk space. */
    static void copyReplay(InputStream source, FileOutputStream output) throws Exception {
        byte[] buffer = new byte[64 * 1024];
        long total = 0;
        while (true) {
            if (Thread.currentThread().isInterrupted()) throw new InterruptedIOException();
            int read = source.read(buffer);
            if (read < 0) break;
            if (read == 0) continue;
            if (total + read > MAX_BYTES) throw new ImportFailure("回放文件超过 128 MiB 限制。");
            for (int i = 0; i < read && total + i < MAGIC.length; i++)
                if (buffer[i] != MAGIC[(int) total + i]) throw new ImportFailure("此文件不是有效的极彩回放。");
            output.write(buffer, 0, read); total += read;
        }
        if (total < MAGIC.length) throw new ImportFailure("回放文件不完整。");
    }

    private String displayName(Uri uri) {
        String name = uri.getLastPathSegment();
        if ("content".equals(uri.getScheme())) {
            try (Cursor cursor = getContentResolver().query(uri, new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null)) {
                if (cursor != null && cursor.moveToFirst()) {
                    int column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                    if (column >= 0 && !cursor.isNull(column)) name = cursor.getString(column);
                }
            } catch (Exception ignored) { }
        }
        if (name == null) name = "回放.mreply";
        name = name.replace('\\', '/'); name = name.substring(name.lastIndexOf('/') + 1);
        name = name.replaceAll("[\\p{Cntrl}]", "");
        if (name.length() > 180) name = name.substring(name.length() - 180);
        return name;
    }

    private void publish(File inbox, String id, JSONObject request) throws Exception {
        File temporary = new File(inbox, id + ".json.part");
        File complete = new File(inbox, id + ".json");
        try (FileOutputStream output = new FileOutputStream(temporary)) {
            output.write(request.toString().getBytes(StandardCharsets.UTF_8)); output.getFD().sync();
        }
        if (!temporary.renameTo(complete)) { temporary.delete(); throw new Exception("Cannot publish request"); }
    }

    private void openGame() {
        if (isFinishing() || isDestroyed()) return;
        Intent launch = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (launch != null) {
            launch.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT | Intent.FLAG_ACTIVITY_SINGLE_TOP);
            startActivity(launch);
        } else Toast.makeText(this, "请打开游戏查看导入的回放。", Toast.LENGTH_LONG).show();
        finish();
    }

    @Override protected void onDestroy() {
        if (worker != null && worker.isAlive()) worker.interrupt();
        super.onDestroy();
    }

    private static final class ImportFailure extends Exception {
        ImportFailure(String message) { super(message); }
    }
}
