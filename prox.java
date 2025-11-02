import java.io.*;
import java.util.Properties;
import javax.swing.JOptionPane;

public class ProxyAutoConfig {
    
    static {
        System.out.println("=======================================");
        System.out.println("PROXY JAR LOADED SUCCESSFULLY!");
        System.out.println("=======================================");
        
        // אופציונלי: הצג חלון popup
        // JOptionPane.showMessageDialog(null, "Proxy configuration JAR loaded!");
        
        try {
            configureProxy();
        } catch (Exception e) {
            System.err.println("Failed to configure proxy: " + e.getMessage());
        }
    }
    
    private static void configureProxy() throws IOException {
        System.out.println("Starting proxy configuration...");
        // שאר הקוד...
    }
}
