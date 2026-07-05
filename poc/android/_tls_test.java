import java.net.URL;

public class _tls_test {
    public static void main(String[] args) throws Exception {
        String url = args.length > 0 ? args[0]
            : "https://mirrors.cloud.tencent.com/nexus/repository/maven-public/org/jetbrains/kotlin/kotlin-stdlib-jdk7/1.8.0/kotlin-stdlib-jdk7-1.8.0.jar";
        try (var in = new URL(url).openStream()) {
            System.out.println("OK " + url);
        } catch (Exception e) {
            System.out.println("FAIL " + e.getClass().getSimpleName() + ": " + e.getMessage());
            e.printStackTrace();
        }
    }
}
