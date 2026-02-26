#!/bin/bash
#
# querybook-install-fix.patch
# תיקון לסקריפט install-querybook.sh
#
# שימוש:
#   1. העתק קובץ זה לשרת RHEL יחד עם החבילה הראשונה
#   2. חלץ את החבילה: tar -xzf querybook-offline-rhel9-bundle.tar.gz
#   3. הרץ: bash querybook-install-fix.patch
#   4. הרץ התקנה: cd querybook-offline-rhel9 && ./scripts/install-querybook.sh
#

INSTALL_SCRIPT="querybook-offline-rhel9/scripts/install-querybook.sh"

if [ ! -f "$INSTALL_SCRIPT" ]; then
    echo "❌ שגיאה: לא נמצא $INSTALL_SCRIPT"
    echo "ודא שהרצת tar -xzf querybook-offline-rhel9-bundle.tar.gz"
    exit 1
fi

echo "🔧 מתקן את install-querybook.sh..."

# גיבוי
cp "$INSTALL_SCRIPT" "${INSTALL_SCRIPT}.backup"

# תיקון - החלפת שורות 138-152
sed -i '138,152d' "$INSTALL_SCRIPT"

# הוספת הקוד המתוקן
sed -i '137a\
# שלב 6: התקנת Python packages\
log_info "[6/9] מתקין Python packages (זה ייקח כמה דקות)..."\
\
if [ -d "$BUNDLE_DIR/python-packages" ] && [ "$(ls -A $BUNDLE_DIR/python-packages/*.whl 2>/dev/null || ls -A $BUNDLE_DIR/python-packages/*.tar.gz 2>/dev/null)" ]; then\
    # התקנה בסיסית\
    pip install --no-index --find-links="$BUNDLE_DIR/python-packages" \\\
        -r "$INSTALL_DIR/requirements/base.txt" || {\
        log_error "התקנת Python packages נכשלה"\
        exit 1\
    }\
\
    # התקנת prod requirements\
    if [ -f "$INSTALL_DIR/requirements/prod.txt" ]; then\
        pip install --no-index --find-links="$BUNDLE_DIR/python-packages" \\\
            -r "$INSTALL_DIR/requirements/prod.txt" 2>/dev/null || true\
    fi\
\
    # התקנת חבילות נוספות שהורדו\
    pip install --no-index --find-links="$BUNDLE_DIR/python-packages" \\\
        gunicorn celery cryptography 2>/dev/null || true\
\
    log_success "Python packages הותקנו"\
else\
    log_error "לא נמצאו Python packages"\
    exit 1\
fi' "$INSTALL_SCRIPT"

echo "✅ התיקון הושלם!"
echo ""
echo "📋 מה תוקן:"
echo "   - הוסר requirements/bundled.txt (לא קיים)"
echo "   - נוסף requirements/prod.txt (אם קיים)"
echo "   - נוספה התקנה מפורשת: gunicorn, celery, cryptography"
echo ""
echo "💾 גיבוי של הקובץ המקורי: ${INSTALL_SCRIPT}.backup"
echo ""
echo "▶️  להמשך התקנה:"
echo "   cd querybook-offline-rhel9"
echo "   ./scripts/install-querybook.sh"
echo ""
