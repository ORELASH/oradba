#!/usr/bin/env python3
"""
RedshiftManager Auto Project Builder
בונה את כל הפרויקט אוטומטיות ממקורות Claude

שמור קובץ זה בשם: build_redshift_manager.py
הרץ: python build_redshift_manager.py
"""

import os
from pathlib import Path
from datetime import datetime

def create_directory_structure():
    """יוצר את מבנה התיקיות"""
    base_dir = Path("RedshiftManager")
    
    directories = [
        base_dir,
        base_dir / "models",
        base_dir / "pages", 
        base_dir / "config",
        base_dir / "logs",
        base_dir / "data",
        base_dir / "backup"
    ]
    
    for directory in directories:
        directory.mkdir(parents=True, exist_ok=True)
        print(f"📁 {directory}")
    
    return base_dir

def create_file(path, content, description=""):
    """יוצר קובץ עם תוכן"""
    try:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✅ {path} {description}")
        return True
    except Exception as e:
        print(f"❌ שגיאה ביצירת {path}: {e}")
        return False

def build_project():
    """בונה את כל הפרויקט"""
    
    print("🚀 RedshiftManager Project Builder")
    print("=" * 50)
    
    # יצירת מבנה תיקיות
    base_dir = create_directory_structure()
    
    # requirements.txt
    requirements_content = """streamlit>=1.28.0
pandas>=2.0.0
numpy>=1.24.0
psycopg2-binary>=2.9.7
sqlalchemy>=2.0.0
cryptography>=41.0.0
keyring>=24.2.0
bcrypt>=4.0.0
plotly>=5.15.0
matplotlib>=3.7.0
seaborn>=0.12.0
requests>=2.31.0
boto3>=1.28.0
botocore>=1.31.0
python-dateutil>=2.8.0
pytz>=2023.3
pathlib2>=2.3.7
python-dotenv>=1.0.0
pywin32>=306
"""
    
    # setup.bat
    setup_bat_content = """@echo off
chcp 65001 > nul
echo =====================================
echo   RedshiftManager - Setup Script
echo =====================================
echo.

python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python לא מותקן
    echo הורד Python מ: https://python.org
    pause
    exit /b 1
)

echo ✓ Python זוהה
echo.

echo יוצר Virtual Environment...
python -m venv venv

echo מפעיל Virtual Environment...
call venv\\Scripts\\activate.bat

echo משדרג pip...
python -m pip install --upgrade pip

echo מתקין תלויות...
pip install -r requirements.txt

echo התקנה הושלמה!
echo להפעלה: run.bat
pause
"""
    
    # run.bat
    run_bat_content = """@echo off
chcp 65001 > nul
title RedshiftManager

echo =====================================
echo      RedshiftManager v1.0
echo =====================================

if not exist "venv\\Scripts\\activate.bat" (
    echo ERROR: הרץ setup.bat תחילה
    pause
    exit /b 1
)

call venv\\Scripts\\activate.bat

echo מפעיל אפליקציה...
echo האפליקציה תיפתח ב: http://localhost:8501
echo.

streamlit run main.py --server.port 8501 --server.headless false

pause
"""
    
    # README.md
    readme_content = f"""# 🗄️ RedshiftManager

מערכת ניהול משתמשים ותפקידים ל-Amazon Redshift

## 🚀 התקנה והפעלה

1. הרץ: `setup.bat`
2. הרץ: `run.bat`
3. פתח דפדפן ב: http://localhost:8501

## ✨ תכונות

- ניהול Clusters מרובים
- ניהול משתמשים ותפקידים
- בונה הרשאות גרפי
- דוחות ומוניטורינג
- אבטחה מתקדמת

---
נוצר: {datetime.now().strftime('%Y-%m-%d')}
"""
    
    # .gitignore
    gitignore_content = """__pycache__/
*.py[cod]
venv/
config/settings.db
*.db
logs/
*.log
backup/
credentials.json
"""
    
    # models/__init__.py
    models_init_content = '''"""RedshiftManager Models Package"""

try:
    from .database_models import DatabaseManager, RedshiftCluster, RedshiftUser, RedshiftRole
    from .encryption_model import EncryptionManager, CredentialManager, AuthenticationManager
    from .redshift_connection_model import RedshiftConnector, RedshiftUserInfo, SchemaInfo, TableInfo
    from .configuration_model import ConfigurationManager, ClusterConfig, AppSettings
except ImportError as e:
    print(f"Warning: Could not import all models: {e}")

__version__ = "1.0.0"
'''
    
    # pages/__init__.py
    pages_init_content = '''"""RedshiftManager Pages Package"""

try:
    from .clusters_management_page import show_clusters_management
    from .users_management_page import show_users_management
    from .roles_management_page import show_roles_management
    from .permissions_management_page import show_permissions_management
    from .reports_monitoring_page import show_reports_monitoring
    from .settings_page import show_settings
except ImportError as e:
    print(f"Warning: Could not import all pages: {e}")

__version__ = "1.0.0"
'''
    
    # main.py placeholder
    main_py_placeholder = '''"""
RedshiftManager Main Application
נא להעתיק את התוכן מ-Claude Artifact: "Complete Main App - אפליקציה ראשית מלאה"
"""

import streamlit as st

st.error("❌ קובץ main.py לא הושלם!")
st.info("📋 העתק את התוכן מ-Claude Artifact")
st.info("🎯 חפש: 'Complete Main App - אפליקציה ראשית מלאה'")
st.code("""
# שלבים:
1. פתח את ה-artifact בצ'אט
2. העתק את כל התוכן
3. החלף את הקובץ הזה
4. הרץ מחדש: run.bat
""")
'''
    
    # יצירת קבצים
    files_to_create = [
        (base_dir / "requirements.txt", requirements_content, "- תלויות Python"),
        (base_dir / "setup.bat", setup_bat_content, "- סקריפט התקנה"),
        (base_dir / "run.bat", run_bat_content, "- סקריפט הפעלה"),
        (base_dir / "README.md", readme_content, "- תיעוד"),
        (base_dir / ".gitignore", gitignore_content, "- Git ignore"),
        (base_dir / "models" / "__init__.py", models_init_content, "- מודלים"),
        (base_dir / "pages" / "__init__.py", pages_init_content, "- דפים"),
        (base_dir / "main.py", main_py_placeholder, "- אפליקציה ראשית (PLACEHOLDER)")
    ]
    
    success_count = 0
    for file_path, content, desc in files_to_create:
        if create_file(file_path, content, desc):
            success_count += 1
    
    # יצירת קבצי placeholder למודלים
    model_placeholders = [
        "database_models.py",
        "encryption_model.py", 
        "redshift_connection_model.py",
        "configuration_model.py"
    ]
    
    for model_file in model_placeholders:
        placeholder_content = f'''"""
{model_file.replace('.py', '').title()} Module
נא להעתיק את התוכן מ-Claude Artifacts
"""

# חפש ב-Claude artifacts:
# "{model_file.replace('_', ' ').title().replace('.py', '')}"

print("⚠️  {model_file} - קובץ placeholder")
print("📋 העתק את התוכן מ-Claude Artifacts")
'''
        create_file(base_dir / "models" / model_file, placeholder_content, f"- {model_file} placeholder")
        success_count += 1
    
    # יצירת קבצי placeholder לדפים
    page_placeholders = [
        "clusters_management_page.py",
        "users_management_page.py",
        "roles_management_page.py", 
        "permissions_management_page.py",
        "reports_monitoring_page.py",
        "settings_page.py"
    ]
    
    for page_file in page_placeholders:
        placeholder_content = f'''"""
{page_file.replace('.py', '').replace('_', ' ').title()} 
נא להעתיק את התוכן מ-Claude Artifacts
"""

import streamlit as st

def show_{page_file.replace('.py', '')}():
    st.error("❌ דף לא הושלם!")
    st.info("📋 העתק את התוכן מ-Claude Artifacts")
    st.info(f"🎯 חפש: '{page_file.replace('_', ' ').title().replace('.py', '')}'")

if __name__ == "__main__":
    show_{page_file.replace('.py', '')}()
'''
        create_file(base_dir / "pages" / page_file, placeholder_content, f"- {page_file} placeholder")
        success_count += 1
    
    # יצירת קובץ הוראות
    instructions_content = f"""
🎯 RedshiftManager - הוראות השלמה

נוצר: {datetime.now().strftime('%Y-%m-%d %H:%M')}
קבצים שנוצרו: {success_count}

📋 שלבים להשלמה:

1. ✅ מבנה הפרויקט נוצר
2. ✅ קבצים בסיסיים נוצרו  
3. ⏳ יש להשלים קבצי קוד ראשיים

🔧 קבצים להשלמה (9 קבצים):

📄 main.py (קריטי!)
   ← העתק מ: "Complete Main App - אפליקציה ראשית מלאה"

📁 models/ (4 קבצים):
   • database_models.py ← "Database Models - מודל בסיס הנתונים"
   • encryption_model.py ← "Encryption Model - מודל הצפנה ואבטחה"  
   • redshift_connection_model.py ← "Redshift Connection Model"
   • configuration_model.py ← "Configuration Model - מודל קונפיגורציה והגדרות"

📁 pages/ (6 קבצים):
   • clusters_management_page.py ← "Clusters Management Page"
   • users_management_page.py ← "Users Management Page"
   • roles_management_page.py ← "Roles Management Page"
   • permissions_management_page.py ← "Permissions Management Page"
   • reports_monitoring_page.py ← "Reports & Monitoring Page"
   • settings_page.py ← "Settings Page"

🚀 אחרי השלמת הקבצים:
   1. setup.bat  (התקנה)
   2. run.bat    (הפעלה)
   3. פתח: http://localhost:8501

💡 טיפ: תתחיל עם main.py - זה הקובץ הכי חשוב!
"""
    
    create_file(base_dir / "INSTRUCTIONS.txt", instructions_content, "- הוראות השלמה")
    
    print("\n" + "=" * 50)
    print(f"✅ הפרויקט נוצר בהצלחה!")
    print(f"📁 תיקייה: {base_dir}")
    print(f"📄 קבצים: {success_count + 1}")
    print("\n📋 שלבים הבאים:")
    print("1. פתח את התיקייה שנוצרה")
    print("2. קרא את INSTRUCTIONS.txt")
    print("3. השלם את 9 קבצי הקוד")
    print("4. הרץ setup.bat")
    print("5. הרץ run.bat")
    print("\n🎉 בהצלחה!")

if __name__ == "__main__":
    build_project()
    input("\nלחץ Enter ליציאה...")
