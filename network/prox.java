import java.io.*;
import java.util.Properties;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import javax.swing.*;
import java.awt.*;

/**
 * SQL Workbench/J Automatic Proxy Configuration
 * This class automatically configures proxy settings when loaded
 * 
 * @author SQL Workbench Proxy Configurator
 * @version 2.0
 */
public class ProxyAutoConfig {
    
    // קבועים לקובץ הגדרות ולוג
    private static final String PROPERTIES_FILE = "proxy.properties";
    private static final String LOG_FILE = "proxy-loader.log";
    private static final String VERSION = "2.0";
    private static final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    
    // משתנה לשמירת סטטוס הטעינה
    private static boolean loadedSuccessfully = false;
    private static String errorMessage = null;
    
    /**
     * Static block - רץ אוטומטית כשה-JAR נטען
     */
    static {
        System.out.println("================================================");
        System.out.println(" SQL Workbench/J Proxy Configurator v" + VERSION);
        System.out.println("================================================");
        
        writeLog("=== Proxy JAR loaded at: " + LocalDateTime.now().format(DATE_FORMAT) + " ===");
        
        try {
            // נסה לטעון את ההגדרות
            boolean configured = configureProxy();
            
            if (configured) {
                loadedSuccessfully = true;
                System.out.println("✓ Proxy configuration loaded successfully!");
                writeLog("SUCCESS: Proxy configuration completed");
                
                // הצג סיכום ההגדרות
                printCurrentSettings();
                
                // אופציונלי: הצג חלון אישור (הסר את ההערה להפעלה)
                // showStatusWindow();
                
            } else {
                System.err.println("✗ No proxy.properties file found");
                writeLog("WARNING: No proxy.properties file found");
            }
            
        } catch (Exception e) {
            loadedSuccessfully = false;
            errorMessage = e.getMessage();
            System.err.println("✗ Failed to configure proxy: " + e.getMessage());
            writeLog("ERROR: " + e.getMessage());
            e.printStackTrace();
        }
        
        System.out.println("================================================\n");
    }
    
    /**
     * מגדיר את ה-Proxy מקובץ ההגדרות
     * @return true אם ההגדרות נטענו בהצלחה
     */
    private static boolean configureProxy() throws IOException {
        File configFile = findConfigFile();
        
        if (configFile == null || !configFile.exists()) {
            // נסה ליצור קובץ דוגמה
            createSamplePropertiesFile();
            return false;
        }
        
        System.out.println("Loading configuration from: " + configFile.getAbsolutePath());
        writeLog("Loading configuration from: " + configFile.getAbsolutePath());
        
        Properties props = new Properties();
        try (FileInputStream fis = new FileInputStream(configFile)) {
            props.load(fis);
            
            if (props.isEmpty()) {
                System.out.println("Warning: Properties file is empty!");
                return false;
            }
            
            // טען את כל ההגדרות
            int configCount = 0;
            for (String key : props.stringPropertyNames()) {
                String value = props.getProperty(key);
                
                // דלג על שורות ריקות או הערות
                if (value != null && !value.trim().isEmpty()) {
                    System.setProperty(key, value);
                    System.out.println("  ✓ Set: " + key + " = " + maskPassword(key, value));
                    writeLog("Property set: " + key + " = " + maskPassword(key, value));
                    configCount++;
                }
            }
            
            if (configCount == 0) {
                System.out.println("Warning: No valid properties found in file!");
                return false;
            }
            
            System.out.println("Total properties configured: " + configCount);
            return true;
        }
    }
    
    /**
     * מחפש את קובץ ההגדרות במיקומים שונים
     */
    private static File findConfigFile() {
        // רשימת מיקומים אפשריים
        String[] possibleLocations = {
            PROPERTIES_FILE,                                    // תיקייה נוכחית
            "ext/" + PROPERTIES_FILE,                          // תיקיית ext
            "../" + PROPERTIES_FILE,                           // תיקייה אחת למעלה
            System.getProperty("user.dir") + "/" + PROPERTIES_FILE,  // תיקיית עבודה
            System.getProperty("user.home") + "/.sqlworkbench/" + PROPERTIES_FILE  // תיקיית משתמש
        };
        
        for (String location : possibleLocations) {
            File file = new File(location);
            if (file.exists() && file.canRead()) {
                return file;
            }
        }
        
        return null;
    }
    
    /**
     * יוצר קובץ הגדרות לדוגמה
     */
    private static void createSamplePropertiesFile() {
        try {
            File sampleFile = new File("proxy.properties.sample");
            if (!sampleFile.exists()) {
                try (PrintWriter writer = new PrintWriter(sampleFile)) {
                    writer.println("# SQL Workbench/J Proxy Configuration Sample");
                    writer.println("# Rename this file to 'proxy.properties' and edit the values");
                    writer.println("# Generated: " + LocalDateTime.now().format(DATE_FORMAT));
                    writer.println();
                    writer.println("# SOCKS Proxy (recommended for JDBC connections)");
                    writer.println("socksProxyHost=your.proxy.server.com");
                    writer.println("socksProxyPort=1080");
                    writer.println();
                    writer.println("# HTTP/HTTPS Proxy");
                    writer.println("#http.proxyHost=your.proxy.server.com");
                    writer.println("#http.proxyPort=8080");
                    writer.println("#https.proxyHost=your.proxy.server.com");
                    writer.println("#https.proxyPort=8080");
                    writer.println();
                    writer.println("# Authentication (if required)");
                    writer.println("#http.proxyUser=username");
                    writer.println("#http.proxyPassword=password");
                    writer.println();
                    writer.println("# Non-proxy hosts");
                    writer.println("#http.nonProxyHosts=localhost|127.0.0.1|*.local");
                }
                System.out.println("Created sample configuration file: proxy.properties.sample");
                writeLog("Sample configuration file created");
            }
        } catch (Exception e) {
            System.err.println("Could not create sample file: " + e.getMessage());
        }
    }
    
    /**
     * מסתיר סיסמאות בלוג
     */
    private static String maskPassword(String key, String value) {
        if (key.toLowerCase().contains("password")) {
            return "****";
        }
        return value;
    }
    
    /**
     * מדפיס את ההגדרות הנוכחיות
     */
    private static void printCurrentSettings() {
        System.out.println("\nCurrent Proxy Settings:");
        System.out.println("------------------------");
        
        String[][] proxyProperties = {
            {"SOCKS Host", "socksProxyHost"},
            {"SOCKS Port", "socksProxyPort"},
            {"HTTP Host", "http.proxyHost"},
            {"HTTP Port", "http.proxyPort"},
            {"HTTPS Host", "https.proxyHost"},
            {"HTTPS Port", "https.proxyPort"},
            {"Non-Proxy Hosts", "http.nonProxyHosts"},
            {"HTTP User", "http.proxyUser"}
        };
        
        for (String[] prop : proxyProperties) {
            String value = System.getProperty(prop[1]);
            if (value != null && !value.isEmpty()) {
                System.out.println("  " + prop[0] + ": " + maskPassword(prop[1], value));
            }
        }
        System.out.println("------------------------");
    }
    
    /**
     * כותב הודעה לקובץ לוג
     */
    private static void writeLog(String message) {
        try {
            File logFile = new File(LOG_FILE);
            try (FileWriter fw = new FileWriter(logFile, true);
                 BufferedWriter bw = new BufferedWriter(fw);
                 PrintWriter out = new PrintWriter(bw)) {
                
                out.println(LocalDateTime.now().format(DATE_FORMAT) + " - " + message);
            }
        } catch (IOException e) {
            // אם לא ניתן לכתוב ללוג, פשוט המשך
            System.err.println("Could not write to log file: " + e.getMessage());
        }
    }
    
    /**
     * מציג חלון סטטוס (אופציונלי)
     */
    private static void showStatusWindow() {
        SwingUtilities.invokeLater(() -> {
            JFrame frame = new JFrame("SQL Workbench Proxy Status");
            frame.setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE);
            
            JTextArea textArea = new JTextArea(15, 50);
            textArea.setEditable(false);
            textArea.setFont(new Font("Consolas", Font.PLAIN, 12));
            
            StringBuilder sb = new StringBuilder();
            sb.append("=== SQL WORKBENCH PROXY CONFIGURATION STATUS ===\n\n");
            sb.append("Version: ").append(VERSION).append("\n");
            sb.append("Load Time: ").append(LocalDateTime.now().format(DATE_FORMAT)).append("\n");
            sb.append("Status: ").append(loadedSuccessfully ? "✓ ACTIVE" : "✗ FAILED").append("\n\n");
            
            if (errorMessage != null) {
                sb.append("Error: ").append(errorMessage).append("\n\n");
            }
            
            sb.append("CONFIGURED PROXIES:\n");
            sb.append("------------------\n");
            
            String socksHost = System.getProperty("socksProxyHost");
            String socksPort = System.getProperty("socksProxyPort");
            if (socksHost != null) {
                sb.append("SOCKS: ").append(socksHost).append(":").append(socksPort).append("\n");
            }
            
            String httpHost = System.getProperty("http.proxyHost");
            String httpPort = System.getProperty("http.proxyPort");
            if (httpHost != null) {
                sb.append("HTTP:  ").append(httpHost).append(":").append(httpPort).append("\n");
            }
            
            String httpsHost = System.getProperty("https.proxyHost");
            String httpsPort = System.getProperty("https.proxyPort");
            if (httpsHost != null) {
                sb.append("HTTPS: ").append(httpsHost).append(":").append(httpsPort).append("\n");
            }
            
            String nonProxyHosts = System.getProperty("http.nonProxyHosts");
            if (nonProxyHosts != null) {
                sb.append("\nNon-Proxy Hosts:\n").append(nonProxyHosts.replace("|", "\n  - ")).append("\n");
            }
            
            sb.append("\n[This window will close automatically in 10 seconds]");
            
            textArea.setText(sb.toString());
            
            // צבעים בהתאם לסטטוס
            if (loadedSuccessfully) {
                textArea.setBackground(new Color(240, 255, 240));
            } else {
                textArea.setBackground(new Color(255, 240, 240));
            }
            
            JScrollPane scrollPane = new JScrollPane(textArea);
            frame.add(scrollPane);
            
            // הוסף כפתור סגירה
            JButton closeButton = new JButton("Close");
            closeButton.addActionListener(e -> frame.dispose());
            JPanel buttonPanel = new JPanel();
            buttonPanel.add(closeButton);
            frame.add(buttonPanel, BorderLayout.SOUTH);
            
            frame.pack();
            frame.setLocationRelativeTo(null);
            frame.setVisible(true);
            
            // סגור אוטומטית אחרי 10 שניות
            Timer timer = new Timer(10000, e -> frame.dispose());
            timer.setRepeats(false);
            timer.start();
        });
    }
    
    /**
     * מתודה ציבורית לבדיקת סטטוס
     */
    public static boolean isConfigured() {
        return loadedSuccessfully;
    }
    
    /**
     * מתודה ציבורית לקבלת הודעת שגיאה
     */
    public static String getErrorMessage() {
        return errorMessage;
    }
    
    /**
     * מתודה לבדיקה ידנית (אפשר לקרוא לה מ-SQL Workbench)
     */
    public static void testConnection() {
        System.out.println("\n=== PROXY CONNECTION TEST ===");
        System.out.println("Timestamp: " + LocalDateTime.now().format(DATE_FORMAT));
        System.out.println("Configuration loaded: " + (loadedSuccessfully ? "YES" : "NO"));
        
        if (loadedSuccessfully) {
            printCurrentSettings();
        } else if (errorMessage != null) {
            System.out.println("Error: " + errorMessage);
        }
        
        System.out.println("=== END OF TEST ===\n");
    }
    
    /**
     * Main method לבדיקה ישירה של הקובץ
     */
    public static void main(String[] args) {
        System.out.println("\n*** Running ProxyAutoConfig in test mode ***\n");
        testConnection();
        
        // בדיקה נוספת - הצג את כל system properties שקשורות ל-proxy
        System.out.println("\nAll proxy-related system properties:");
        System.getProperties().forEach((key, value) -> {
            String keyStr = key.toString().toLowerCase();
            if (keyStr.contains("proxy") || keyStr.contains("socks")) {
                System.out.println("  " + key + " = " + value);
            }
        });
    }
}
