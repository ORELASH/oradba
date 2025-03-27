# מדריך להפקת מטריקות במערכת Cloudera CDP

מסמך זה מפרט כיצד ניתן לאסוף מידע על משתמשים וקבוצות ב-Ranger, כמות ג'ובים יומיים, ושימוש ממוצע ב-CPU בקלאסטר Cloudera CDP.

## 1. איסוף מידע על משתמשים וקבוצות ב-Ranger

### באמצעות Ranger REST API

```bash
# קבלת רשימת כל המשתמשים (וספירתם)
curl -k -u admin:password 'https://ranger-host:6182/service/xusers/users' | jq '. | length'

# קבלת רשימת כל הקבוצות (וספירתן)
curl -k -u admin:password 'https://ranger-host:6182/service/xusers/groups' | jq '. | length'

# גישה מפורטת יותר למידע על משתמשים
curl -k -u admin:password 'https://ranger-host:6182/service/xusers/users' | jq '.vXUsers[] | {name: .name, status: .status}'
```

### באמצעות שאילתות SQL ישירות לבסיס הנתונים של Ranger

```sql
-- התחברות לבסיס הנתונים של Ranger (PostgreSQL בדרך כלל)
psql -U rangeradmin -d ranger

-- ספירת משתמשים פעילים
SELECT COUNT(*) FROM x_user WHERE status = 1;

-- ספירת קבוצות פעילות
SELECT COUNT(*) FROM x_group WHERE status = 1;

-- קבלת מידע מפורט על משתמשים
SELECT user_name, first_name, last_name, status 
FROM x_user 
ORDER BY user_name;

-- קבלת מידע מפורט על קבוצות
SELECT group_name, status 
FROM x_group 
ORDER BY group_name;
```

## 2. איסוף מידע על כמות ג'ובים יומיים

### באמצעות YARN CLI

```bash
# ספירת כל האפליקציות שהסתיימו היום
yarn application -list -appStates FINISHED,KILLED,FAILED \
  -startedTimeBegin $(date +%s -d "today 00:00:00")000 | grep -c "application_"

# ספירת אפליקציות לפי סטטוס
yarn application -list -appStates ALL \
  -startedTimeBegin $(date +%s -d "today 00:00:00")000 | \
  awk '{count[$7]++} END {for (status in count) print status": "count[status]}'
```

### באמצעות Cloudera Manager API

```bash
# קבלת מספר הג'ובים שרצו היום
curl -k -u admin:password \
  'https://cm-host:7183/api/v32/clusters/cluster-name/services/yarn/yarnApplications?from=midnight&to=now&limit=1000' | \
  jq '. | length'

# קבלת פירוט אפליקציות לפי סטטוס
curl -k -u admin:password \
  'https://cm-host:7183/api/v32/clusters/cluster-name/services/yarn/yarnApplications?from=midnight&to=now&limit=1000' | \
  jq 'group_by(.state) | map({state: .[0].state, count: length}) | .[]'
```

## 3. מדידת שימוש ממוצע ב-CPU בקלאסטר

### באמצעות Cloudera Manager API

```bash
# קבלת ממוצע שימוש ב-CPU לאורך כל השרתים בקלאסטר להיום
curl -k -u admin:password \
  'https://cm-host:7183/api/v32/timeseries?query=select+cpu_percent_across_hosts+where+category+%3D+CLUSTER&from=midnight&to=now&contentType=application/json' | \
  jq '.items[0].timeSeries[0].data[] | .value' | \
  awk '{ sum += $1; count++ } END { if (count > 0) print "Average CPU usage: " sum / count "%" }'

# קבלת שימוש CPU ממוצע לפי שעה להיום
curl -k -u admin:password \
  'https://cm-host:7183/api/v32/timeseries?query=select+cpu_percent_across_hosts+where+category+%3D+CLUSTER&from=midnight&to=now&contentType=application/json' | \
  jq '.items[0].timeSeries[0].data[] | {time: .timestamp, cpu: .value}' | \
  grep -v "{}" | jq -s 'group_by(.time | sub("T"; " ") | sub("\\..*"; "") | sub(":..$"; "")) | 
  map({hour: .[0].time | sub("T"; " ") | sub("\\..*"; "") | sub(":..$"; ""), 
       avg_cpu: map(.cpu) | add / length}) | .[]'
```

## 4. סקריפט אוטומטי לאיסוף כל המטריקות

להלן סקריפט Bash שמאחד את כל הפקודות לעיל ומפיק דוח יומי מסודר:

```bash
#!/bin/bash

# הגדרת משתנים
CM_HOST="cloudera-manager-host"
CM_PORT="7183"
RANGER_HOST="ranger-host"
RANGER_PORT="6182"
CLUSTER_NAME="your-cluster-name"
USERNAME="admin"
PASSWORD="password"
OUTPUT_FILE="cloudera_daily_metrics_$(date +%Y-%m-%d).txt"

echo "==== דוח מטריקות יומי לתאריך $(date +%Y-%m-%d) ====" > $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# === איסוף נתוני משתמשים וקבוצות Ranger ===
echo "==== משתמשים וקבוצות Ranger ====" >> $OUTPUT_FILE

echo "מספר משתמשים ב-Ranger:" >> $OUTPUT_FILE
curl -s -k -u $USERNAME:$PASSWORD "https://$RANGER_HOST:$RANGER_PORT/service/xusers/users" | jq '. | length' >> $OUTPUT_FILE

echo "מספר קבוצות ב-Ranger:" >> $OUTPUT_FILE
curl -s -k -u $USERNAME:$PASSWORD "https://$RANGER_HOST:$RANGER_PORT/service/xusers/groups" | jq '. | length' >> $OUTPUT_FILE

echo "" >> $OUTPUT_FILE

# === איסוף נתוני ג'ובים יומיים ===
echo "==== ג'ובים יומיים ====" >> $OUTPUT_FILE

echo "מספר סך הג'ובים שרצו היום:" >> $OUTPUT_FILE
curl -s -k -u $USERNAME:$PASSWORD "https://$CM_HOST:$CM_PORT/api/v32/clusters/$CLUSTER_NAME/services/yarn/yarnApplications?from=midnight&to=now&limit=10000" | jq '. | length' >> $OUTPUT_FILE

echo "פילוח ג'ובים לפי סטטוס:" >> $OUTPUT_FILE
curl -s -k -u $USERNAME:$PASSWORD "https://$CM_HOST:$CM_PORT/api/v32/clusters/$CLUSTER_NAME/services/yarn/yarnApplications?from=midnight&to=now&limit=10000" | \
  jq 'group_by(.state) | map({state: .[0].state, count: length}) | .[]' >> $OUTPUT_FILE

echo "" >> $OUTPUT_FILE

# === איסוף נתוני שימוש CPU ===
echo "==== שימוש CPU ====" >> $OUTPUT_FILE

echo "ממוצע שימוש CPU בקלאסטר להיום:" >> $OUTPUT_FILE
curl -s -k -u $USERNAME:$PASSWORD "https://$CM_HOST:$CM_PORT/api/v32/timeseries?query=select+cpu_percent_across_hosts+where+category+%3D+CLUSTER&from=midnight&to=now&contentType=application/json" | \
  jq '.items[0].timeSeries[0].data[] | .value' | \
  awk '{ sum += $1; count++ } END { if (count > 0) print sum / count "%" }' >> $OUTPUT_FILE

echo "" >> $OUTPUT_FILE
echo "==== סיום דוח ====" >> $OUTPUT_FILE

echo "הדוח נוצר בהצלחה: $OUTPUT_FILE"
```

## 5. הערות חשובות והגדרת דוחות בממשק Cloudera Manager

1. **הרשאות גישה**:
   - וודא שיש לך הרשאות מספקות לגישה ל-Ranger API ו-Cloudera Manager API.
   - במקרים מסוימים ייתכן שתצטרך הרשאות מיוחדות לקריאת נתונים מבסיס הנתונים של Ranger.

2. **יצירת דוחות מותאמים אישית**:
   1. היכנס לממשק Cloudera Manager
   2. לחץ על "Charts" בתפריט העליון
   3. לחץ על "Chart Builder"
   4. בחר את המטריקות הרצויות (כגון CPU Usage Across Hosts)
   5. הגדר את טווח הזמן הרצוי
   6. שמור את הדוח בשם הרצוי
   7. הגדר תזמון להפקת הדוח באופן אוטומטי

3. **אוטומציה**:
   - ניתן להגדיר את הסקריפט המצורף לרוץ כמשימת Cron יומית כדי לאסוף סטטיסטיקות באופן אוטומטי.
   - דוגמה לתזמון משימת Cron יומית שתרוץ ב-23:55 כל יום:
   ```
   55 23 * * * /path/to/your/script.sh
   ```

4. **עומסים**:
   - שים לב שביצוע שאילתות מרובות ל-API עלול להעמיס על המערכת.
   - מומלץ לתזמן איסוף נתונים לשעות שאינן עמוסות.
