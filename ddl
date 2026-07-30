-- =====================================================================
--  בדיקת מוכנות: MySQL 8.0.32 Commercial  ->  8.0.46 Community
-- =====================================================================
--  שאילתה אחת (statement יחיד, CTE) שמחזירה דוח מוכנות עם פסק דין.
--  קריאה בלבד - אינה משנה דבר, אינה יוצרת אובייקטים, בטוחה בפרודקשן.
--
--  הרצה (פלט אנכי, קריא הרבה יותר לשדות ארוכים):
--      mysql -u root -p -E < mysql_readiness_check.sql | tee readiness_report.txt
--
--  או בטבלה:
--      mysql -u root -p --table < mysql_readiness_check.sql
--
--  הרשאות נדרשות: SELECT על mysql.* ועל information_schema,
--                  גישה ל-performance_schema, ורצוי PROCESS.
--
--  דירוג: BLOCKER = יישבר אחרי המעבר, חייב טיפול לפני
--         WARNING = ידרוש תשומת לב או ישנה התנהגות
--         INFO    = נתוני תכנון
--
--  !! חשוב: השאילתה לא יכולה לראות את my.cnf עצמו. האופציות
--     early-plugin-load ו-plugin-load-add אינן system variables.
--     חובה להריץ גם את בדיקות מערכת ההפעלה בסוף הקובץ (נספח א).
--
--  קריאת השדה source בממצאי הקונפיגורציה:
--     GLOBAL / SERVER / EXPLICIT / EXTRA -> הגיע מקובץ קונפיגורציה,
--                                           והנתיב מוצג ב-path (שם לתקן)
--     COMMAND_LINE                       -> systemd unit או mysqld_safe
--     PERSISTED                          -> mysqld-auto.cnf (RESET PERSIST)
--     DYNAMIC                            -> הוגדר בזמן ריצה ב-SET, לא בקובץ
--
--  אומת בהרצה מלאה מול MySQL 8.0.46 - כל 17 הבדיקות עוברות ללא שגיאות.
-- =====================================================================

WITH findings AS (

-- ── 1. סביבה נוכחית ─────────────────────────────────────────────────
SELECT 'INFO' AS sev, '00-Environment' AS area,
       'גרסה ומהדורה מותקנות' AS chk,
       CONCAT(VERSION(), '  |  ', @@version_comment, '  |  ',
              @@version_compile_os, ' ', @@version_compile_machine) AS detail,
       'יעד מתוכנן: 8.0.46 MySQL Community Server - GPL' AS action
FROM (SELECT 1) d

UNION ALL
SELECT IF(VERSION() LIKE '8.0.32%', 'INFO', 'WARNING'), '00-Environment',
       'התאמה לתכנית המעבר',
       CONCAT('הגרסה בפועל: ', VERSION()),
       'אם אינה 8.0.32 - עדכן את תכנית השדרוג ואת בדיקת התאימות בהתאם'
FROM (SELECT 1) d

-- ── 2. פלאגינים בלעדיים ל-Enterprise ────────────────────────────────
UNION ALL
SELECT 'BLOCKER', '01-Plugins',
       'פלאגין Enterprise-only טעון',
       CONCAT(plugin_name, '   [', IFNULL(plugin_library, 'built-in'),
              ' | ', plugin_status, ' | ', load_option, ']'),
       'UNINSTALL PLUGIN בזמן שאתה עוד על Enterprise, והסר plugin-load-add מ-my.cnf'
FROM information_schema.plugins
WHERE UPPER(plugin_name) IN (
        'AUDIT_LOG','THREAD_POOL',
        'TP_THREAD_STATE','TP_THREAD_GROUP_STATE','TP_THREAD_GROUP_STATS',
        'MYSQL_FIREWALL','MYSQL_FIREWALL_USERS','MYSQL_FIREWALL_WHITELIST',
        'DATA_MASKING',
        'AUTHENTICATION_LDAP_SASL','AUTHENTICATION_LDAP_SIMPLE',
        'AUTHENTICATION_KERBEROS','AUTHENTICATION_OCI',
        'AUTHENTICATION_PAM','AUTHENTICATION_WINDOWS','AUTHENTICATION_FIDO',
        'KEYRING_OKV','KEYRING_AWS','KEYRING_HASHICORP',
        'KEYRING_ENCRYPTED_FILE','KEYRING_OCI')

-- ── 3. קומפוננטות בלעדיות ל-Enterprise ──────────────────────────────
UNION ALL
SELECT 'BLOCKER', '01-Plugins',
       'קומפוננטה Enterprise-only רשומה',
       component_urn,
       'UNINSTALL COMPONENT לפני ההחלפה - אחרת השרת יתלונן בעלייה'
FROM mysql.component
WHERE component_urn REGEXP 'masking|keyring_oci|keyring_encrypted|keyring_aws|keyring_hashicorp|keyring_okv|audit'

-- ── 4. פונקציות UDF של Enterprise Encryption / Masking ──────────────
UNION ALL
SELECT 'BLOCKER', '01-Plugins',
       'UDF של Enterprise רשומה ב-mysql.func',
       CONCAT(name, '  (library: ', dl, ')'),
       'DROP FUNCTION לפני ההחלפה. חלופה: AES_ENCRYPT או הצפנה בשכבת האפליקציה'
FROM mysql.func
WHERE dl IN ('openssl_udf.so','data_masking.so','component_masking.so')
   OR name REGEXP '^(asymmetric_|create_asymmetric_|create_dh_parameters|mask_|gen_rnd_|gen_range|gen_blocklist|gen_dictionary)'

-- ── 5. TDE: tablespaces מוצפנים ─────────────────────────────────────
UNION ALL
SELECT 'BLOCKER', '02-TDE',
       'קיימים tablespaces מוצפנים',
       CONCAT(COUNT(*), ' tablespaces עם ENCRYPTION=Y'),
       'אם ה-keyring אינו component_keyring_file - Community לא יוכל לפתוח אותם. הגר keyring או בטל הצפנה לפני המעבר'
FROM information_schema.innodb_tablespaces
WHERE ENCRYPTION = 'Y'
HAVING COUNT(*) > 0

UNION ALL
SELECT 'BLOCKER', '02-TDE',
       'טבלאות עם ENCRYPTION בהגדרות',
       CONCAT(table_schema, '.', table_name, '  [', create_options, ']'),
       'ALTER TABLE ... ENCRYPTION=N או הגר את ה-keyring ל-component_keyring_file'
FROM information_schema.tables
WHERE create_options LIKE '%ENCRYPTION%'
  AND table_schema NOT IN ('mysql','information_schema','performance_schema','sys')

UNION ALL
SELECT 'BLOCKER', '02-TDE',
       'סכימות עם הצפנה כברירת מחדל',
       CONCAT(schema_name, '  DEFAULT_ENCRYPTION=YES'),
       'ALTER DATABASE ... DEFAULT ENCRYPTION=N אם מוותרים על TDE'
FROM information_schema.schemata
WHERE default_encryption = 'YES'

-- ── 6. TDE: איזה keyring בשימוש ─────────────────────────────────────
UNION ALL
SELECT 'BLOCKER', '02-TDE',
       'keyring שאינו זמין ב-Community מוגדר',
       CONCAT(vi.variable_name, ' = ', gv.variable_value,
              '   [source=', vi.variable_source,
              IFNULL(CONCAT(' path=', vi.variable_path), ''), ']'),
       'הגר מפתחות עם mysql_migrate_keyring ל-component_keyring_file, ואז ALTER INSTANCE ROTATE INNODB MASTER KEY'
FROM performance_schema.variables_info vi
JOIN performance_schema.global_variables gv
     ON gv.variable_name = vi.variable_name
WHERE vi.variable_source <> 'COMPILED'
  AND (   vi.variable_name LIKE 'keyring_okv%'
       OR vi.variable_name LIKE 'keyring_aws%'
       OR vi.variable_name LIKE 'keyring_hashicorp%'
       OR vi.variable_name LIKE 'keyring_encrypted_file%'
       OR vi.variable_name LIKE 'keyring_oci%')

-- ── 7. חשבונות עם אימות בלעדי ל-Enterprise ──────────────────────────
UNION ALL
SELECT 'BLOCKER', '03-Auth',
       'חשבון עם plugin אימות שאינו ב-Community',
       CONCAT(QUOTE(user), '@', QUOTE(host), '  plugin=', plugin),
       'ALTER USER ... IDENTIFIED WITH caching_sha2_password לפני המעבר, אחרת החשבון ננעל בחוץ'
FROM mysql.user
WHERE plugin IN ('authentication_ldap_sasl','authentication_ldap_simple',
                 'authentication_kerberos','authentication_oci',
                 'authentication_pam','authentication_windows',
                 'authentication_fido')

-- ── 8. משתני קונפיגורציה של Enterprise = כשל עלייה ──────────────────
UNION ALL
SELECT 'BLOCKER', '04-Config',
       'משתנה Enterprise מוגדר בקונפיג - ימנע עלייה של Community',
       CONCAT(vi.variable_name, ' = ', LEFT(gv.variable_value, 120),
              '   [source=', vi.variable_source,
              IFNULL(CONCAT(' path=', vi.variable_path), ''), ']'),
       'משתנה לא מוכר ב-my.cnf הוא שגיאה קטלנית - mysqld יסרב לעלות. הסר את השורה'
FROM performance_schema.variables_info vi
JOIN performance_schema.global_variables gv
     ON gv.variable_name = vi.variable_name
WHERE vi.variable_source <> 'COMPILED'
  AND (   vi.variable_name LIKE 'audit_log%'
       OR vi.variable_name LIKE 'thread_pool%'
       OR vi.variable_name LIKE 'firewall%'
       OR vi.variable_name LIKE 'authentication_ldap%'
       OR vi.variable_name LIKE 'authentication_kerberos%'
       OR vi.variable_name LIKE 'authentication_oci%'
       OR vi.variable_name LIKE 'authentication_fido%'
       OR vi.variable_name LIKE 'authentication_pam%'
       OR vi.variable_name LIKE 'masking%')

-- ── 9. טבלאות מערכת של רכיבי Enterprise ─────────────────────────────
UNION ALL
SELECT 'WARNING', '05-EnterpriseData',
       'טבלת מערכת של רכיב Enterprise קיימת',
       CONCAT(table_schema, '.', table_name, '  (~', IFNULL(table_rows, 0), ' רשומות)'),
       'בדוק תוכן ידנית. אם יש כאן הגדרות בשימוש - תכנן חלופה לפני שמוותרים על הרכיב'
FROM information_schema.tables
WHERE table_schema = 'mysql'
  AND table_name IN ('audit_log_filter','audit_log_user',
                     'firewall_users','firewall_whitelist',
                     'firewall_groups','firewall_group_allowlist',
                     'firewall_membership','masking_dictionaries')

-- ── 10. שדרוג 8.0.32 -> 8.0.46: mysql_native_password ───────────────
UNION ALL
SELECT 'WARNING', '06-Upgrade',
       'חשבונות עם mysql_native_password',
       CONCAT(COUNT(*), ' חשבונות'),
       'עובד ב-8.0.46 אך deprecated מ-8.0.34 והוסר לחלוטין ב-8.4. אם שוקלים 8.4 - זה החסם. המר ל-caching_sha2_password'
FROM mysql.user
WHERE plugin = 'mysql_native_password'
HAVING COUNT(*) > 0

-- ── 11. משתנים deprecated שמוגדרים במפורש ───────────────────────────
UNION ALL
SELECT 'WARNING', '06-Upgrade',
       'משתנה deprecated מוגדר במפורש',
       CONCAT(vi.variable_name, ' = ', LEFT(gv.variable_value, 60),
              '   [source=', vi.variable_source,
              IFNULL(CONCAT(' path=', vi.variable_path), ''), ']'),
       'יפיק אזהרות ב-8.0.46 ועלול להיעלם ב-8.4. עדכן לחלופה המודרנית'
FROM performance_schema.variables_info vi
JOIN performance_schema.global_variables gv
     ON gv.variable_name = vi.variable_name
WHERE vi.variable_source <> 'COMPILED'
  AND vi.variable_name IN (
        'innodb_log_file_size','innodb_log_files_in_group',
        'binlog_transaction_dependency_tracking','expire_logs_days',
        'master_info_repository','relay_log_info_repository',
        'log_bin_use_v1_row_events','default_authentication_plugin',
        'keyring_file_data','avoid_temporal_upgrade','show_old_temporals',
        'transaction_write_set_extraction','group_replication_ip_whitelist')

-- ── 12. מנועים שאינם InnoDB - עקביות ה-dump ─────────────────────────
UNION ALL
SELECT 'WARNING', '07-Dump',
       'טבלאות שאינן InnoDB',
       CONCAT(COUNT(*), ' טבלאות (מנועים: ',
              GROUP_CONCAT(DISTINCT engine ORDER BY engine SEPARATOR ', '), ')'),
       'single-transaction ו-consistent dump אינם נותנים snapshot עקבי ל-MyISAM. נדרשת נעילה או המרה ל-InnoDB'
FROM information_schema.tables
WHERE table_type = 'BASE TABLE'
  AND engine IS NOT NULL
  AND engine <> 'InnoDB'
  AND table_schema NOT IN ('mysql','information_schema','performance_schema','sys')
HAVING COUNT(*) > 0

-- ── 13. DEFINER יתום - נשבר אחרי dump/restore ───────────────────────
UNION ALL
SELECT 'WARNING', '08-Objects',
       'DEFINER שאינו קיים ב-mysql.user',
       CONCAT('VIEW  ', table_schema, '.', table_name, '   definer=', definer),
       'צור מחדש את החשבון ביעד או שנה DEFINER, אחרת האובייקט ייכשל בזמן ריצה'
FROM information_schema.views v
WHERE definer IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM mysql.user u
                  WHERE CONCAT(u.user, '@', u.host) = v.definer)

UNION ALL
SELECT 'WARNING', '08-Objects',
       'DEFINER שאינו קיים ב-mysql.user',
       CONCAT(routine_type, '  ', routine_schema, '.', routine_name, '   definer=', definer),
       'צור מחדש את החשבון ביעד או שנה DEFINER'
FROM information_schema.routines r
WHERE definer IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM mysql.user u
                  WHERE CONCAT(u.user, '@', u.host) = r.definer)

UNION ALL
SELECT 'WARNING', '08-Objects',
       'DEFINER שאינו קיים ב-mysql.user',
       CONCAT('TRIGGER  ', trigger_schema, '.', trigger_name, '   definer=', definer),
       'צור מחדש את החשבון ביעד או שנה DEFINER'
FROM information_schema.triggers t
WHERE definer IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM mysql.user u
                  WHERE CONCAT(u.user, '@', u.host) = t.definer)

-- ── 14. מוכנות לרפליקציה (מסלול A - השבתה של שניות) ─────────────────
UNION ALL
SELECT IF(@@log_bin = 1 AND @@gtid_mode = 'ON' AND @@server_id <> 0,
          'INFO', 'WARNING'),
       '09-Replication',
       'מוכנות למסלול רפליקציה + cutover',
       CONCAT('log_bin=', IF(@@log_bin, 'ON', 'OFF'),
              '  gtid_mode=', @@gtid_mode,
              '  enforce_gtid_consistency=', @@enforce_gtid_consistency,
              '  server_id=', @@server_id,
              '  binlog_format=', @@binlog_format,
              '  binlog_row_image=', @@binlog_row_image),
       'למסלול A נדרשים log_bin=ON, gtid_mode=ON, enforce_gtid_consistency=ON ו-server_id ייחודי'
FROM (SELECT 1) d

-- ── 15. תכנון: גודל נתונים ──────────────────────────────────────────
UNION ALL
SELECT 'INFO', '10-Planning',
       'נפח נתונים להעברה',
       CONCAT(IFNULL(ROUND(SUM(data_length + index_length) / POW(1024,3), 2), 0), ' GB  ב-',
              COUNT(*), ' טבלאות  ב-',
              COUNT(DISTINCT table_schema), ' סכימות'),
       'להערכת זמן dump-instance ו-load-dump במסלול A'
FROM information_schema.tables
WHERE table_type = 'BASE TABLE'
  AND table_schema NOT IN ('mysql','information_schema','performance_schema','sys')

-- ── 16. תכנון: הערכת זמן shutdown ───────────────────────────────────
UNION ALL
SELECT 'INFO', '10-Planning',
       'הערכת זמן shutdown נקי',
       CONCAT('buffer_pool=', ROUND(@@innodb_buffer_pool_size / POW(1024,3), 2), ' GB',
              '  dirty_pages=', (SELECT variable_value FROM performance_schema.global_status
                                 WHERE variable_name = 'Innodb_buffer_pool_pages_dirty'),
              ' / ',            (SELECT variable_value FROM performance_schema.global_status
                                 WHERE variable_name = 'Innodb_buffer_pool_pages_total'),
              '  redo_capacity=', ROUND(@@innodb_redo_log_capacity / POW(1024,2), 0), ' MB'),
       'הרבה dirty pages פירושו shutdown ארוך יותר - זהו עיקר ההשבתה במסלול ההחלפה במקום'
FROM (SELECT 1) d

-- ── 17. הטבלה הגדולה ביותר ──────────────────────────────────────────
UNION ALL
(SELECT 'INFO', '10-Planning',
       'הטבלה הגדולה ביותר',
       CONCAT(table_schema, '.', table_name, '  ',
              ROUND((data_length + index_length) / POW(1024,3), 2), ' GB  (~',
              IFNULL(table_rows, 0), ' שורות, ', engine, ')'),
       'קובעת את זמן ה-load ואת הצורך בהעברה מקבילית'
FROM information_schema.tables
WHERE table_type = 'BASE TABLE'
  AND table_schema NOT IN ('mysql','information_schema','performance_schema','sys')
ORDER BY (data_length + index_length) DESC
LIMIT 1)
)

-- =====================================================================
--  הדוח: שורת פסק דין ואחריה כל הממצאים לפי חומרה
-- =====================================================================
SELECT x.sev AS `חומרה`,
       x.area AS `תחום`,
       x.chk AS `בדיקה`,
       x.detail AS `ממצא`,
       x.action AS `פעולה נדרשת`
FROM (
    SELECT 0 AS ord,
           CASE WHEN SUM(sev = 'BLOCKER') > 0 THEN '*** NOT READY ***'
                WHEN SUM(sev = 'WARNING') > 0 THEN '*** READY WITH CAVEATS ***'
                ELSE '*** READY ***' END AS sev,
           '=== VERDICT ===' AS area,
           CONCAT(SUM(sev = 'BLOCKER'), ' חסמים  |  ',
                  SUM(sev = 'WARNING'), ' אזהרות  |  ',
                  SUM(sev = 'INFO'),    ' מידע') AS chk,
           CASE WHEN SUM(sev = 'BLOCKER') > 0
                THEN 'אל תתחיל את המעבר. טפל בכל החסמים בזמן שאתה עוד על Enterprise'
                ELSE 'אין חסמים מזוהים ברמת בסיס הנתונים' END AS detail,
           'השלם גם: נספח א (בדיקות my.cnf ברמת מערכת ההפעלה) + mysqlsh util check-for-server-upgrade' AS action
    FROM findings
    UNION ALL
    SELECT CASE sev WHEN 'BLOCKER' THEN 1 WHEN 'WARNING' THEN 2 ELSE 3 END,
           sev, area, chk, detail, action
    FROM findings
) x
ORDER BY x.ord, x.area, x.chk;


-- =====================================================================
--  נספח א - בדיקות שחייבות להתבצע מחוץ ל-SQL
-- =====================================================================
--  האופציות early-plugin-load ו-plugin-load-add אינן system variables,
--  ולכן השאילתה למעלה עיוורת אליהן. הן גם הסיבה הנפוצה ביותר לכך
--  שהשרת מסרב לעלות אחרי החלפת המהדורה. הרץ בשל:
--
--    grep -rniE 'plugin.load|early.plugin.load|audit_log|thread_pool|
--                firewall|masking|keyring_okv|keyring_aws|keyring_hashicorp|
--                keyring_encrypted|authentication_ldap|authentication_kerberos|
--                authentication_pam|authentication_oci' \
--         /etc/my.cnf /etc/my.cnf.d/ /etc/mysql/ 2>/dev/null
--
--  אימות חבילות מותקנות (ושמירה כהוכחה לביקורת רישוי):
--    rpm -qa | grep -i mysql | sort | tee /root/pkgs-before.txt
--
--  ספריות Enterprise שקיימות בדיסק ולא יהיו ב-Community:
--    ls -l $(mysql -N -e "SELECT @@plugin_dir") | \
--      grep -iE 'audit|firewall|masking|thread_pool|keyring_(okv|aws|hashicorp|encrypted)|openssl_udf|ldap|kerberos'
--
--  בדיקת תאימות השדרוג הרשמית של Oracle:
--    mysqlsh -- util check-for-server-upgrade root@localhost:3306 \
--            --target-version=8.0.46 --output-format=TEXT
--
--  ואחרי התקנת הבינאריים של Community, לפני systemctl start:
--    mysqld --validate-config --user=mysql
-- =====================================================================
