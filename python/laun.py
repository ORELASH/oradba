#!/usr/bin/env python3
"""
Java Application Launcher - Python/Tkinter Version
Simple GUI launcher for Java applications with proxy authentication
"""

import tkinter as tk
from tkinter import messagebox, ttk, filedialog
import subprocess
import json
import os
import sys
import re
import platform


def find_java_installations():
    """Find all Java installations on the system"""
    java_paths = []
    system = platform.system()
    
    # Check common locations and PATH
    if system == "Windows":
        # Check PATH
        path_java = check_java_in_path()
        if path_java:
            java_paths.append(path_java)
        
        # Check common installation directories
        common_dirs = [
            r"C:\Program Files\Java",
            r"C:\Program Files (x86)\Java",
            r"C:\Program Files\Eclipse Adoptium",
            r"C:\Program Files\AdoptOpenJDK",
            r"C:\Program Files\Zulu",
            os.path.expanduser(r"~\\.jdks")
        ]
        
        for base_dir in common_dirs:
            if os.path.exists(base_dir):
                try:
                    for item in os.listdir(base_dir):
                        java_exe = os.path.join(base_dir, item, "bin", "java.exe")
                        if os.path.isfile(java_exe):
                            version = get_java_version(java_exe)
                            if version:
                                java_paths.append({
                                    'path': java_exe,
                                    'version': version,
                                    'name': item
                                })
                except:
                    pass
        
        # Check registry
        java_from_registry = find_java_in_registry()
        java_paths.extend(java_from_registry)
    
    elif system == "Linux" or system == "Darwin":  # macOS
        # Check PATH
        path_java = check_java_in_path()
        if path_java:
            java_paths.append(path_java)
        
        # Check common locations
        common_dirs = [
            "/usr/lib/jvm",
            "/usr/java",
            "/Library/Java/JavaVirtualMachines",  # macOS
            os.path.expanduser("~/.jdks")
        ]
        
        for base_dir in common_dirs:
            if os.path.exists(base_dir):
                try:
                    for item in os.listdir(base_dir):
                        java_bin = os.path.join(base_dir, item, "bin", "java")
                        if os.path.isfile(java_bin):
                            version = get_java_version(java_bin)
                            if version:
                                java_paths.append({
                                    'path': java_bin,
                                    'version': version,
                                    'name': item
                                })
                except:
                    pass
    
    # Remove duplicates (same path)
    seen_paths = set()
    unique_javas = []
    for java in java_paths:
        if isinstance(java, dict):
            path = java['path']
        else:
            path = java
        
        if path not in seen_paths:
            seen_paths.add(path)
            unique_javas.append(java)
    
    return unique_javas


def check_java_in_path():
    """Check if java is available in PATH"""
    try:
        result = subprocess.run(['java', '-version'], 
                              capture_output=True, 
                              timeout=3)
        if result.returncode == 0:
            version = get_java_version('java')
            if version:
                return {
                    'path': 'java',
                    'version': version,
                    'name': 'java (from PATH)'
                }
    except:
        pass
    return None


def get_java_version(java_path):
    """Get Java version from executable"""
    try:
        result = subprocess.run([java_path, '-version'], 
                              capture_output=True, 
                              timeout=3,
                              text=True)
        
        output = result.stderr + result.stdout
        
        # Parse version from output
        # Examples: "java version "1.8.0_291"" or "openjdk version "11.0.11""
        version_match = re.search(r'version "(.+?)"', output)
        if version_match:
            version_str = version_match.group(1)
            
            # Simplify version (e.g., "1.8.0_291" -> "Java 8", "11.0.11" -> "Java 11")
            if version_str.startswith('1.'):
                # Old versioning (1.8 = Java 8)
                major = version_str.split('.')[1]
                return f"Java {major}"
            else:
                # New versioning (11.x = Java 11)
                major = version_str.split('.')[0]
                return f"Java {major}"
        
        return "Java (unknown version)"
    except:
        return None


def find_java_in_registry():
    """Find Java installations in Windows Registry"""
    java_paths = []
    
    if platform.system() != "Windows":
        return java_paths
    
    try:
        import winreg
        
        # Check both 64-bit and 32-bit registry
        registry_paths = [
            (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\JavaSoft\Java Runtime Environment"),
            (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\JavaSoft\Java Development Kit"),
            (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\JavaSoft\JDK"),
        ]
        
        for hkey, subkey in registry_paths:
            try:
                key = winreg.OpenKey(hkey, subkey)
                
                # Get all versions
                i = 0
                while True:
                    try:
                        version = winreg.EnumKey(key, i)
                        version_key = winreg.OpenKey(key, version)
                        
                        try:
                            java_home = winreg.QueryValueEx(version_key, "JavaHome")[0]
                            java_exe = os.path.join(java_home, "bin", "java.exe")
                            
                            if os.path.isfile(java_exe):
                                java_version = get_java_version(java_exe)
                                if java_version:
                                    java_paths.append({
                                        'path': java_exe,
                                        'version': java_version,
                                        'name': f"Registry: {version}"
                                    })
                        except:
                            pass
                        
                        winreg.CloseKey(version_key)
                        i += 1
                    except OSError:
                        break
                
                winreg.CloseKey(key)
            except:
                pass
    except ImportError:
        pass
    
    return java_paths

class Config:
    """Configuration manager"""
    DEFAULT_CONFIG = {
        'JarPath': 'app.jar',
        'JavaPath': 'java',
        'JvmArgs': '-Xmx512m',
        'AppArgs': '',
        'UsernameProperty': 'http.proxyUser',
        'PasswordProperty': 'http.proxyPassword',
        'LastUsername': ''
    }
    
    def __init__(self, config_file='config.json'):
        self.config_file = config_file
        self.data = self.load()
    
    def load(self):
        """Load configuration from JSON file"""
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            else:
                self.save(self.DEFAULT_CONFIG)
                return self.DEFAULT_CONFIG.copy()
        except Exception as e:
            print(f"Error loading config: {e}")
            return self.DEFAULT_CONFIG.copy()
    
    def save(self, data=None):
        """Save configuration to JSON file"""
        if data is None:
            data = self.data
        try:
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"Error saving config: {e}")
    
    def get(self, key, default=None):
        """Get configuration value"""
        return self.data.get(key, default)
    
    def set(self, key, value):
        """Set configuration value"""
        self.data[key] = value


class SettingsWindow(tk.Toplevel):
    """Settings dialog window"""
    
    def __init__(self, parent, config):
        super().__init__(parent)
        self.config = config
        self.title("Launcher Settings")
        self.geometry("650x400")
        self.resizable(False, False)
        
        # Make modal
        self.transient(parent)
        self.grab_set()
        
        self.create_widgets()
        self.load_settings()
    
    def create_widgets(self):
        """Create settings form widgets"""
        
        # Main frame
        main_frame = ttk.Frame(self, padding="10")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        row = 0
        
        # JAR Path
        ttk.Label(main_frame, text="JAR Path:").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.jar_path = ttk.Entry(main_frame, width=45)
        self.jar_path.grid(row=row, column=1, pady=5, padx=5)
        ttk.Button(main_frame, text="Browse", command=self.browse_jar).grid(row=row, column=2, padx=5)
        row += 1
        
        # Java Path with auto-detection
        ttk.Label(main_frame, text="Java Path:").grid(row=row, column=0, sticky=tk.W, pady=5)
        
        # Frame for combobox and buttons
        java_frame = ttk.Frame(main_frame)
        java_frame.grid(row=row, column=1, columnspan=2, sticky=tk.W, pady=5, padx=5)
        
        self.java_path = ttk.Combobox(java_frame, width=42, state='normal')
        self.java_path.pack(side=tk.LEFT, padx=(0, 5))
        
        ttk.Button(java_frame, text="Browse", command=self.browse_java, width=8).pack(side=tk.LEFT, padx=2)
        ttk.Button(java_frame, text="🔍 Detect", command=self.detect_java, width=8).pack(side=tk.LEFT, padx=2)
        
        row += 1
        
        # JVM Args
        ttk.Label(main_frame, text="JVM Arguments:").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.jvm_args = ttk.Entry(main_frame, width=60)
        self.jvm_args.grid(row=row, column=1, pady=5, padx=5, columnspan=2, sticky=tk.W+tk.E)
        ttk.Label(main_frame, text="Example: -Xmx512m -Dapp.env=prod", 
                 font=('TkDefaultFont', 8), foreground='gray').grid(row=row+1, column=1, columnspan=2, sticky=tk.W, padx=5)
        row += 2
        
        # App Args
        ttk.Label(main_frame, text="App Arguments:").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.app_args = ttk.Entry(main_frame, width=60)
        self.app_args.grid(row=row, column=1, pady=5, padx=5, columnspan=2, sticky=tk.W+tk.E)
        ttk.Label(main_frame, text="Example: --debug --config=prod.xml", 
                 font=('TkDefaultFont', 8), foreground='gray').grid(row=row+1, column=1, columnspan=2, sticky=tk.W, padx=5)
        row += 2
        
        # Separator
        ttk.Separator(main_frame, orient='horizontal').grid(row=row, column=0, columnspan=3, sticky=tk.W+tk.E, pady=10)
        row += 1
        
        # Username Property
        ttk.Label(main_frame, text="Username Property (-D):").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.username_prop = ttk.Entry(main_frame, width=60)
        self.username_prop.grid(row=row, column=1, pady=5, padx=5, columnspan=2, sticky=tk.W+tk.E)
        row += 1
        
        # Password Property
        ttk.Label(main_frame, text="Password Property (-D):").grid(row=row, column=0, sticky=tk.W, pady=5)
        self.password_prop = ttk.Entry(main_frame, width=60)
        self.password_prop.grid(row=row, column=1, pady=5, padx=5, columnspan=2, sticky=tk.W+tk.E)
        row += 1
        
        # Separator
        ttk.Separator(main_frame, orient='horizontal').grid(row=row, column=0, columnspan=3, sticky=tk.W+tk.E, pady=10)
        row += 1
        
        # Save/Cancel buttons
        btn_frame = ttk.Frame(main_frame)
        btn_frame.grid(row=row, column=0, columnspan=3, pady=10)
        
        ttk.Button(btn_frame, text="Save", command=self.save_settings, width=15).pack(side=tk.LEFT, padx=5)
        ttk.Button(btn_frame, text="Cancel", command=self.destroy, width=15).pack(side=tk.LEFT, padx=5)
        
        # Auto-detect Java on startup
        self.after(100, self.detect_java_silent)
    
    def browse_jar(self):
        """Browse for JAR file"""
        filename = filedialog.askopenfilename(
            parent=self,
            title="Select JAR File",
            filetypes=[("JAR Files", "*.jar"), ("All Files", "*.*")]
        )
        if filename:
            self.jar_path.delete(0, tk.END)
            self.jar_path.insert(0, filename)
    
    def browse_java(self):
        """Browse for Java executable"""
        filename = filedialog.askopenfilename(
            parent=self,
            title="Select Java Executable",
            filetypes=[("Executable Files", "*.exe"), ("All Files", "*.*")]
        )
        if filename:
            self.java_path.delete(0, tk.END)
            self.java_path.insert(0, filename)
    
    def detect_java(self):
        """Detect and show Java installations"""
        # Show progress message
        progress = tk.Toplevel(self)
        progress.title("Detecting Java...")
        progress.geometry("300x100")
        progress.transient(self)
        progress.grab_set()
        
        # Center on parent
        x = self.winfo_x() + (self.winfo_width() // 2) - 150
        y = self.winfo_y() + (self.winfo_height() // 2) - 50
        progress.geometry(f"+{x}+{y}")
        
        ttk.Label(progress, text="Searching for Java installations...", 
                 padding=20).pack()
        progress_bar = ttk.Progressbar(progress, mode='indeterminate')
        progress_bar.pack(padx=20, pady=10, fill=tk.X)
        progress_bar.start()
        
        progress.update()
        
        # Find Java installations
        java_installs = find_java_installations()
        
        progress.destroy()
        
        if not java_installs:
            messagebox.showinfo(
                "No Java Found",
                "No Java installations were detected.\n\n"
                "Please install Java or use Browse to select manually.",
                parent=self
            )
            # Set default
            self.java_path.delete(0, tk.END)
            self.java_path.insert(0, "java")
            return
        
        # Populate combobox
        self.java_path['values'] = []
        items = []
        
        for java in java_installs:
            if isinstance(java, dict):
                display = f"{java['version']} - {java['path']}"
                items.append(display)
            else:
                items.append(java)
        
        self.java_path['values'] = items
        
        # Select first one
        if items:
            self.java_path.set(items[0])
        
        messagebox.showinfo(
            "Java Detected",
            f"Found {len(java_installs)} Java installation(s)!\n\n"
            "Select from the dropdown or use Browse.",
            parent=self
        )
    
    def detect_java_silent(self):
        """Detect Java silently on startup (without messages)"""
        java_installs = find_java_installations()
        
        if java_installs:
            items = []
            for java in java_installs:
                if isinstance(java, dict):
                    display = f"{java['version']} - {java['path']}"
                    items.append(display)
                else:
                    items.append(java)
            
            self.java_path['values'] = items
            
            # If current value is empty or "java", set to first detected
            current = self.java_path.get()
            if not current or current == "java":
                if items:
                    self.java_path.set(items[0])
    
    def load_settings(self):
        """Load current settings into form"""
        self.jar_path.insert(0, self.config.get('JarPath', ''))
        self.java_path.insert(0, self.config.get('JavaPath', ''))
        self.jvm_args.insert(0, self.config.get('JvmArgs', ''))
        self.app_args.insert(0, self.config.get('AppArgs', ''))
        self.username_prop.insert(0, self.config.get('UsernameProperty', ''))
        self.password_prop.insert(0, self.config.get('PasswordProperty', ''))
    
    def save_settings(self):
        """Save settings and close"""
        # Extract path from combobox selection
        java_selection = self.java_path.get()
        
        # If format is "Java X - path", extract path
        if " - " in java_selection:
            java_path = java_selection.split(" - ", 1)[1]
        else:
            java_path = java_selection
        
        self.config.set('JarPath', self.jar_path.get())
        self.config.set('JavaPath', java_path)
        self.config.set('JvmArgs', self.jvm_args.get())
        self.config.set('AppArgs', self.app_args.get())
        self.config.set('UsernameProperty', self.username_prop.get())
        self.config.set('PasswordProperty', self.password_prop.get())
        
        self.config.save()
        
        messagebox.showinfo("Success", "Settings saved successfully!", parent=self)
        self.destroy()


class JavaLauncher(tk.Tk):
    """Main launcher window"""
    
    def __init__(self):
        super().__init__()
        
        self.config = Config()
        
        self.title("Java Application Launcher")
        self.geometry("500x320")
        self.resizable(False, False)
        
        # Center window
        self.center_window()
        
        self.create_widgets()
        self.load_last_username()
        
        # Update command preview whenever username/password changes
        self.username_entry.bind('<KeyRelease>', lambda e: self.update_command_preview())
        self.password_entry.bind('<KeyRelease>', lambda e: self.update_command_preview())
    
    def center_window(self):
        """Center window on screen"""
        self.update_idletasks()
        width = self.winfo_width()
        height = self.winfo_height()
        x = (self.winfo_screenwidth() // 2) - (width // 2)
        y = (self.winfo_screenheight() // 2) - (height // 2)
        self.geometry(f'{width}x{height}+{x}+{y}')
    
    def create_widgets(self):
        """Create main window widgets"""
        
        # Top frame for settings button
        top_frame = ttk.Frame(self)
        top_frame.pack(fill=tk.X, padx=10, pady=5)
        
        # Settings button (right side)
        settings_btn = ttk.Button(top_frame, text="⚙ Settings", command=self.open_settings)
        settings_btn.pack(side=tk.RIGHT)
        
        # Main frame
        main_frame = ttk.Frame(self, padding="20")
        main_frame.pack(fill=tk.BOTH, expand=True)
        
        # Username
        ttk.Label(main_frame, text="Username:").grid(row=0, column=0, sticky=tk.W, pady=10)
        self.username_entry = ttk.Entry(main_frame, width=30)
        self.username_entry.grid(row=0, column=1, pady=10, padx=10)
        
        # Password
        ttk.Label(main_frame, text="Password:").grid(row=1, column=0, sticky=tk.W, pady=10)
        
        # Password frame (for entry + show/hide button)
        pwd_frame = ttk.Frame(main_frame)
        pwd_frame.grid(row=1, column=1, pady=10, padx=10, sticky=tk.W)
        
        self.password_entry = ttk.Entry(pwd_frame, width=24, show="•")
        self.password_entry.pack(side=tk.LEFT)
        
        self.show_password_var = tk.BooleanVar(value=False)
        self.show_pwd_btn = ttk.Checkbutton(
            pwd_frame, 
            text="👁", 
            variable=self.show_password_var,
            command=self.toggle_password
        )
        self.show_pwd_btn.pack(side=tk.LEFT, padx=5)
        
        # Launch button
        launch_btn = ttk.Button(main_frame, text="Launch", command=self.launch)
        launch_btn.grid(row=2, column=1, pady=20)
        
        # Separator
        ttk.Separator(self, orient='horizontal').pack(fill=tk.X, padx=10, pady=5)
        
        # Command preview section
        preview_frame = ttk.LabelFrame(self, text="Command Preview", padding="5")
        preview_frame.pack(fill=tk.BOTH, padx=10, pady=5, expand=True)
        
        # Text widget for command preview (read-only)
        self.cmd_preview = tk.Text(preview_frame, height=3, wrap=tk.WORD, 
                                   font=('Courier', 8), state='disabled',
                                   bg='#f0f0f0', relief=tk.SUNKEN)
        self.cmd_preview.pack(fill=tk.BOTH, expand=True)
        
        # Scrollbar for command preview
        scrollbar = ttk.Scrollbar(preview_frame, orient=tk.VERTICAL, command=self.cmd_preview.yview)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        self.cmd_preview.config(yscrollcommand=scrollbar.set)
        
        # Bind Enter key
        self.bind('<Return>', lambda e: self.launch())
        
        # Focus on username
        self.username_entry.focus()
        
        # Initial command preview
        self.update_command_preview()
    
    def load_last_username(self):
        """Load last used username"""
        last_username = self.config.get('LastUsername', '')
        if last_username:
            self.username_entry.insert(0, last_username)
            self.password_entry.focus()
    
    def toggle_password(self):
        """Toggle password visibility"""
        if self.show_password_var.get():
            self.password_entry.config(show="")
        else:
            self.password_entry.config(show="•")
    
    def update_command_preview(self):
        """Update the command preview display"""
        username = self.username_entry.get().strip()
        password = self.password_entry.get()
        
        # Build command for preview
        cmd_parts = []
        
        # Java path
        java_path = self.config.get('JavaPath', 'java')
        cmd_parts.append(java_path)
        
        # JVM args
        jvm_args = self.config.get('JvmArgs', '')
        if jvm_args:
            cmd_parts.extend(jvm_args.split())
        
        # Username property
        username_prop = self.config.get('UsernameProperty', 'http.proxyUser')
        if username:
            cmd_parts.append(f'-D{username_prop}={username}')
        else:
            cmd_parts.append(f'-D{username_prop}=<username>')
        
        # Password property (masked)
        password_prop = self.config.get('PasswordProperty', 'http.proxyPassword')
        if password:
            cmd_parts.append(f'-D{password_prop}={"*" * len(password)}')
        else:
            cmd_parts.append(f'-D{password_prop}=<password>')
        
        # JAR
        jar_path = self.config.get('JarPath', 'app.jar')
        cmd_parts.extend(['-jar', jar_path])
        
        # App args
        app_args = self.config.get('AppArgs', '')
        if app_args:
            cmd_parts.extend(app_args.split())
        
        # Join command
        command = ' '.join(cmd_parts)
        
        # Update text widget
        self.cmd_preview.config(state='normal')
        self.cmd_preview.delete('1.0', tk.END)
        self.cmd_preview.insert('1.0', command)
        self.cmd_preview.config(state='disabled')
    
    def open_settings(self):
        """Open settings dialog"""
        SettingsWindow(self, self.config)
        # Update command preview after settings might have changed
        self.update_command_preview()
    
    def check_java(self):
        """Check if Java is available"""
        try:
            java_path = self.config.get('JavaPath', 'java')
            result = subprocess.run(
                [java_path, '-version'],
                capture_output=True,
                timeout=3
            )
            return result.returncode == 0
        except:
            return False
    
    def check_jar(self):
        """Check if JAR file exists"""
        jar_path = self.config.get('JarPath', '')
        return os.path.isfile(jar_path)
    
    def launch(self):
        """Launch Java application"""
        username = self.username_entry.get().strip()
        password = self.password_entry.get()
        
        if not username or not password:
            messagebox.showerror("Error", "Username and password are required!")
            return
        
        # Check Java
        if not self.check_java():
            response = messagebox.askyesno(
                "Java Not Found",
                "Java is not found!\n\n"
                "Please ensure Java is installed and configured correctly.\n\n"
                "Would you like to open Settings to configure Java path?"
            )
            if response:
                self.open_settings()
            return
        
        # Check JAR
        if not self.check_jar():
            jar_path = self.config.get('JarPath', '')
            response = messagebox.askyesno(
                "JAR Not Found",
                f"JAR file not found:\n{jar_path}\n\n"
                "Would you like to open Settings to configure JAR path?"
            )
            if response:
                self.open_settings()
            return
        
        try:
            # Save username (not password!)
            self.config.set('LastUsername', username)
            self.config.save()
            
            # Build command
            cmd = [self.config.get('JavaPath', 'java')]
            
            # Add JVM args
            jvm_args = self.config.get('JvmArgs', '')
            if jvm_args:
                cmd.extend(jvm_args.split())
            
            # Add username and password properties
            username_prop = self.config.get('UsernameProperty', 'http.proxyUser')
            password_prop = self.config.get('PasswordProperty', 'http.proxyPassword')
            cmd.append(f'-D{username_prop}={username}')
            cmd.append(f'-D{password_prop}={password}')
            
            # Add JAR
            cmd.extend(['-jar', self.config.get('JarPath', '')])
            
            # Add app args
            app_args = self.config.get('AppArgs', '')
            if app_args:
                cmd.extend(app_args.split())
            
            # Launch without console window
            # For Windows: use CREATE_NO_WINDOW flag
            # For other OS: this flag is ignored
            if platform.system() == "Windows":
                # CREATE_NO_WINDOW = 0x08000000
                subprocess.Popen(cmd, creationflags=0x08000000)
            else:
                # For Linux/macOS
                subprocess.Popen(cmd)
            
            # Show success message
            messagebox.showinfo("Success", "Application launched successfully!")
            
            # Close launcher after 2 seconds
            self.after(2000, self.destroy)
            
        except Exception as e:
            messagebox.showerror("Error", f"Failed to launch application:\n{str(e)}")


def main():
    """Main entry point"""
    app = JavaLauncher()
    app.mainloop()


if __name__ == "__main__":
    main()
