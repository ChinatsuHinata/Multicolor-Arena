using System;

public static class CloudReportAskPass {
    public static void Main() {
        Console.Write(Environment.GetEnvironmentVariable("MULTICOLOR_REPORT_KEY_PASSPHRASE"));
    }
}
