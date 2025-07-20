using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace KeepAwake
{
    public partial class MainForm : Form
    {
        // Windows API להחזקת המערכת ערה
        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        static extern uint SetThreadExecutionState(uint esFlags);

        const uint ES_CONTINUOUS = 0x80000000;
        const uint ES_SYSTEM_REQUIRED = 0x00000001;
        const uint ES_DISPLAY_REQUIRED = 0x00000002;

        // Windows API להזזת עכבר
        [DllImport("user32.dll")]
        static extern bool SetCursorPos(int x, int y);

        [DllImport("user32.dll")]
        static extern bool GetCursorPos(out Point lpPoint);

        private Timer keepAwakeTimer;
        private bool isKeepAwakeActive = false;
        private NotifyIcon trayIcon;

        public MainForm()
        {
            InitializeComponent();
            SetupTrayIcon();
        }

        private void InitializeComponent()
        {
            this.SuspendLayout();
            
            // הגדרות הטופס הראשי
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(350, 200);
            this.Text = "Keep Awake - מונע שומר מסך";
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.FixedSingle;
            this.MaximizeBox = false;
            this.ShowInTaskbar = false; // הסתרה מסרגל המשימות
            this.WindowState = FormWindowState.Minimized;

            // כפתור הפעלה/כיבוי
            Button toggleButton = new Button();
            toggleButton.Size = new Size(200, 40);
            toggleButton.Location = new Point(75, 50);
            toggleButton.Text = "הפעל מניעת שומר מסך";
            toggleButton.UseVisualStyleBackColor = true;
            toggleButton.Click += ToggleButton_Click;

            // תווית מצב
            Label statusLabel = new Label();
            statusLabel.Size = new Size(300, 20);
            statusLabel.Location = new Point(25, 110);
            statusLabel.Text = "מצב: כבוי";
            statusLabel.Name = "statusLabel";
            statusLabel.TextAlign = ContentAlignment.MiddleCenter;

            // תווית הוראות
            Label instructionsLabel = new Label();
            instructionsLabel.Size = new Size(300, 40);
            instructionsLabel.Location = new Point(25, 140);
            instructionsLabel.Text = "התוכנה תמנע מהמחשב לעבור לשומר מסך\nלסגירה - לחץ ימני על האייקון במגש המערכת";
            instructionsLabel.TextAlign = ContentAlignment.MiddleCenter;
            instructionsLabel.ForeColor = Color.Gray;

            // הוספת הקונטרולים לטופס
            this.Controls.Add(toggleButton);
            this.Controls.Add(statusLabel);
            this.Controls.Add(instructionsLabel);

            this.ResumeLayout(false);

            // הגדרת הטיימר
            keepAwakeTimer = new Timer();
            keepAwakeTimer.Interval = 30000; // 30 שניות
            keepAwakeTimer.Tick += KeepAwakeTimer_Tick;
        }

        private void SetupTrayIcon()
        {
            // יצירת אייקון במגש המערכת
            trayIcon = new NotifyIcon();
            trayIcon.Text = "Keep Awake";
            trayIcon.Visible = true;
            
            // יצירת אייקון פשוט (נקודה ירוקה)
            Bitmap iconBitmap = new Bitmap(16, 16);
            using (Graphics g = Graphics.FromImage(iconBitmap))
            {
                g.Clear(Color.Transparent);
                g.FillEllipse(Brushes.Green, 2, 2, 12, 12);
            }
            trayIcon.Icon = Icon.FromHandle(iconBitmap.GetHicon());

            // תפריט קליק ימני
            ContextMenuStrip contextMenu = new ContextMenuStrip();
            
            ToolStripMenuItem showItem = new ToolStripMenuItem("הצג חלון");
            showItem.Click += (s, e) => {
                this.Show();
                this.WindowState = FormWindowState.Normal;
                this.BringToFront();
            };
            
            ToolStripMenuItem exitItem = new ToolStripMenuItem("יציאה");
            exitItem.Click += (s, e) => {
                StopKeepAwake();
                trayIcon.Dispose();
                Application.Exit();
            };

            contextMenu.Items.Add(showItem);
            contextMenu.Items.Add(new ToolStripSeparator());
            contextMenu.Items.Add(exitItem);
            
            trayIcon.ContextMenuStrip = contextMenu;
            
            // לחיצה כפולה להצגת החלון
            trayIcon.MouseDoubleClick += (s, e) => {
                this.Show();
                this.WindowState = FormWindowState.Normal;
                this.BringToFront();
            };
        }

        private void ToggleButton_Click(object sender, EventArgs e)
        {
            Button button = sender as Button;
            Label statusLabel = this.Controls["statusLabel"] as Label;

            if (!isKeepAwakeActive)
            {
                StartKeepAwake();
                button.Text = "עצור מניעת שומר מסך";
                statusLabel.Text = "מצב: פעיל - המחשב לא יעבור לשומר מסך";
                statusLabel.ForeColor = Color.Green;
                trayIcon.Text = "Keep Awake - פעיל";
            }
            else
            {
                StopKeepAwake();
                button.Text = "הפעל מניעת שומר מסך";
                statusLabel.Text = "מצב: כבוי";
                statusLabel.ForeColor = Color.Black;
                trayIcon.Text = "Keep Awake - כבוי";
            }
        }

        private void StartKeepAwake()
        {
            // הפעלת מצב Keep Awake
            SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED);
            
            // הפעלת הטיימר לסימולציה של פעילות
            keepAwakeTimer.Start();
            isKeepAwakeActive = true;
        }

        private void StopKeepAwake()
        {
            // עצירת מצב Keep Awake
            SetThreadExecutionState(ES_CONTINUOUS);
            
            // עצירת הטיימר
            keepAwakeTimer.Stop();
            isKeepAwakeActive = false;
        }

        private void KeepAwakeTimer_Tick(object sender, EventArgs e)
        {
            // סימולציה קלה של תנועת עכבר
            Point currentPos;
            GetCursorPos(out currentPos);
            
            // הזזה קטנה של העכבר ואז חזרה למקום המקורי
            SetCursorPos(currentPos.X + 1, currentPos.Y + 1);
            Thread.Sleep(50);
            SetCursorPos(currentPos.X, currentPos.Y);
        }

        protected override void SetVisibleCore(bool value)
        {
            // התחלה במצב מוסתר
            base.SetVisibleCore(false);
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            // במקום לסגור, הסתר את החלון
            if (e.CloseReason == CloseReason.UserClosing)
            {
                e.Cancel = true;
                this.Hide();
            }
            else
            {
                StopKeepAwake();
                trayIcon?.Dispose();
                base.OnFormClosing(e);
            }
        }
    }

    static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }
    }
}
