import java.io.InputStream;
import java.net.URL;
import javax.net.ssl.HttpsURLConnection;

/** Explicit public GET diagnostic. No app storage, credentials or response text. */
public final class AndroidTransportProbe {
    public static void main(String[] args) throws Exception {
        if (args.length != 1 || !args[0].equals("--live")) {
            throw new IllegalArgumentException("Pass --live for one public GET");
        }
        Thread deadline = new Thread(() -> {
            try { Thread.sleep(30000); } catch (InterruptedException ignored) { return; }
            System.out.println("transport=android-https failure=deadline");
            System.exit(2);
        });
        deadline.setDaemon(true);
        deadline.start();
        long start = System.nanoTime();
        HttpsURLConnection connection = (HttpsURLConnection) new URL(
            "https://www.carousell.ph/search/Ps5%20Slim/"
            + "?addRecent=true&canChangeKeyword=true&includeSuggestions=true"
            + "&searchId=&searchType=all&sort_by=3&query_source=ss_dropdown"
        ).openConnection();
        connection.setConnectTimeout(15000);
        connection.setReadTimeout(15000);
        connection.setInstanceFollowRedirects(false);
        connection.setRequestProperty("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            + "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36");
        connection.setRequestProperty("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,"
            + "image/avif,image/webp,*/*;q=0.8");
        connection.setRequestProperty("Accept-Language", "en-US,en;q=0.9");
        try {
            int status = connection.getResponseCode();
            boolean challenge = "challenge".equals(connection.getHeaderField("cf-mitigated"));
            int bytes = 0;
            try (InputStream body = status >= 400 ? connection.getErrorStream() : connection.getInputStream()) {
                if (body != null) {
                    byte[] buffer = new byte[8192];
                    int read;
                    while ((read = body.read(buffer)) != -1) {
                        bytes += read;
                        if (bytes > 8 * 1024 * 1024) throw new IllegalStateException("Response limit");
                    }
                }
            }
            System.out.println("transport=android-https status=" + status + " bytes=" + bytes
                + " challenge=" + challenge + " durationMs=" + (System.nanoTime() - start) / 1000000);
        } catch (Exception error) {
            System.out.println("transport=android-https failure=" + error.getClass().getSimpleName());
            System.exit(1);
        } finally {
            connection.disconnect();
        }
    }
}
