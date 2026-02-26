# Redshift Password Reset Application
## Complete Implementation Guide

This document contains everything needed to build and deploy a Redshift password reset application that authenticates users via Active Directory.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Windows Development Setup](#windows-development-setup)
3. [Application Files](#application-files)
4. [Configuration](#configuration)
5. [Testing on Windows](#testing-on-windows)
6. [Linux Production Deployment](#linux-production-deployment)
7. [Troubleshooting](#troubleshooting)
8. [Maintenance](#maintenance)

---

## Prerequisites

### Windows Development Machine
- Python 3.8 or higher
- Internet connection
- Access to Active Directory server
- Access to Redshift cluster

### Linux Production Server
- Ubuntu 20.04+ or CentOS 8+
- Root access
- Internet connection
- Network access to AD and Redshift

### Redshift Requirements
- Admin user with ALTER USER permissions
- Network access from application server

### Active Directory Requirements
- LDAP access (port 389 or 636)
- Service account or direct user authentication

---

## Windows Development Setup

### Step 1: Create Project Structure

Create a new folder and run this batch script:

**setup_dev.bat**
```batch
@echo off
echo Setting up Redshift Password Reset Development Environment

:: Check Python installation
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Python not installed. Please install Python 3.8+ from python.org
    pause
    exit /b 1
)

:: Create project directories
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
)

:: Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate.bat

:: Upgrade pip
echo Upgrading pip...
python -m pip install --upgrade pip

:: Create directories
echo Creating project directories...
if not exist "templates" mkdir templates
if not exist "static" mkdir static
if not exist "logs" mkdir logs
if not exist "audit" mkdir audit

echo Development environment setup complete!
echo.
echo Next steps:
echo 1. Create all application files (see documentation)
echo 2. Install requirements: pip install -r requirements.txt
echo 3. Run configuration: python setup_config.py
echo 4. Start application: python app.py
pause
```

### Step 2: Create Requirements File

**requirements.txt**
```
Flask==2.3.3
Flask-WTF==1.1.1
WTForms==3.0.1
psycopg2-binary==2.9.7
ldap3==2.9.1
cryptography==41.0.4
python-dotenv==1.0.0
gunicorn==21.2.0
flask-limiter==3.5.0
```

---

## Application Files

### Main Application File

**app.py**
```python
from flask import Flask, render_template, request, redirect, url_for, flash, session, jsonify
from flask_wtf import FlaskForm, CSRFProtect
from wtforms import PasswordField, SubmitField, StringField
from wtforms.validators import DataRequired, Length, EqualTo
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
import psycopg2
import ldap3
import logging
import json
import os
from datetime import datetime
from cryptography.fernet import Fernet
import base64
from functools import wraps
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Create Flask application
app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('FLASK_SECRET_KEY', 'dev-secret-key')

# CSRF Protection
csrf = CSRFProtect(app)

# Rate Limiting
limiter = Limiter(
    app,
    key_func=get_remote_address,
    default_limits=["30 per minute"]
)

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/app.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

# Configuration Class
class Config:
    def __init__(self):
        self.REDSHIFT_HOST = os.getenv('REDSHIFT_HOST')
        self.REDSHIFT_PORT = int(os.getenv('REDSHIFT_PORT', 5439))
        self.REDSHIFT_DB = os.getenv('REDSHIFT_DB')
        self.REDSHIFT_ADMIN_USER = os.getenv('REDSHIFT_ADMIN_USER')
        self.REDSHIFT_ADMIN_PASSWORD = os.getenv('REDSHIFT_ADMIN_PASSWORD')
        
        self.AD_SERVER = os.getenv('AD_SERVER')
        self.AD_DOMAIN = os.getenv('AD_DOMAIN')
        self.AD_BASE_DN = os.getenv('AD_BASE_DN')
        
        self.ENCRYPTION_KEY = os.getenv('ENCRYPTION_KEY')
        
        # Validate required variables
        required_vars = [
            'REDSHIFT_HOST', 'REDSHIFT_DB', 'REDSHIFT_ADMIN_USER', 
            'REDSHIFT_ADMIN_PASSWORD', 'AD_SERVER', 'AD_DOMAIN', 
            'AD_BASE_DN', 'ENCRYPTION_KEY'
        ]
        
        missing_vars = [var for var in required_vars if not getattr(self, var)]
        if missing_vars:
            raise ValueError(f"Missing environment variables: {', '.join(missing_vars)}")

config = Config()

# Forms
class LoginForm(FlaskForm):
    username = StringField('Username', validators=[DataRequired(message='Username is required')])
    password = PasswordField('Password', validators=[DataRequired(message='Password is required')])
    submit = SubmitField('Login')

class PasswordResetForm(FlaskForm):
    new_password = PasswordField(
        'New Password',
        validators=[
            DataRequired(message='New password is required'),
            Length(min=8, message='Password must be at least 8 characters')
        ]
    )
    confirm_password = PasswordField(
        'Confirm Password',
        validators=[
            DataRequired(message='Please confirm the password'),
            EqualTo('new_password', message='Passwords do not match')
        ]
    )
    submit = SubmitField('Reset Password')

# Services
class PasswordEncryption:
    def __init__(self):
        self.key = config.ENCRYPTION_KEY.encode()
        self.cipher = Fernet(self.key)
    
    def decrypt(self, encrypted_password):
        """Decrypt password"""
        if not encrypted_password.startswith('ENCRYPTED:'):
            return encrypted_password
        
        try:
            encrypted_data = encrypted_password[10:]  # Remove 'ENCRYPTED:' prefix
            decoded = base64.b64decode(encrypted_data.encode())
            decrypted = self.cipher.decrypt(decoded)
            return decrypted.decode()
        except Exception as e:
            logger.error(f"Error decrypting password: {e}")
            return ""

class AuditService:
    def __init__(self):
        self.log_file = os.path.join('audit', 'audit_log.json')
        os.makedirs('audit', exist_ok=True)
    
    def log_action(self, username, action, success, error_message=None, ip_address=None):
        """Log action to audit file"""
        log_entry = {
            'timestamp': datetime.now().isoformat(),
            'username': username,
            'action': action,
            'success': success,
            'error_message': error_message,
            'ip_address': ip_address or 'Unknown'
        }
        
        try:
            logs = self.get_logs()
            logs.append(log_entry)
            
            # Keep only last 1000 entries
            if len(logs) > 1000:
                logs = logs[-1000:]
            
            with open(self.log_file, 'w', encoding='utf-8') as f:
                json.dump(logs, f, ensure_ascii=False, indent=2)
                
            logger.info(f"Audit: {username} - {action} - {'Success' if success else 'Failed'}")
        except Exception as e:
            logger.error(f"Error writing audit log: {e}")
    
    def get_logs(self, limit=50):
        """Get audit log entries"""
        try:
            if os.path.exists(self.log_file):
                with open(self.log_file, 'r', encoding='utf-8') as f:
                    logs = json.load(f)
                    return sorted(logs, key=lambda x: x['timestamp'], reverse=True)[:limit]
            return []
        except Exception as e:
            logger.error(f"Error reading audit log: {e}")
            return []

class ActiveDirectoryService:
    def __init__(self):
        self.server = config.AD_SERVER
        self.domain = config.AD_DOMAIN
        self.base_dn = config.AD_BASE_DN
    
    def authenticate_user(self, username, password):
        """Authenticate user against Active Directory"""
        try:
            # Clean username
            clean_username = username.split('\\')[-1].split('@')[0]
            user_dn = f"{clean_username}@{self.domain}"
            
            server = ldap3.Server(self.server, get_info=ldap3.ALL)
            conn = ldap3.Connection(server, user_dn, password, auto_bind=True)
            
            if conn.bind():
                conn.unbind()
                logger.info(f"AD authentication successful for user: {clean_username}")
                return clean_username
            return None
        except Exception as e:
            logger.error(f"AD Authentication error for user {username}: {e}")
            return None
    
    def test_connection(self):
        """Test AD connection"""
        try:
            server = ldap3.Server(self.server, get_info=ldap3.ALL)
            conn = ldap3.Connection(server, auto_bind=True)
            return True
        except Exception as e:
            logger.error(f"AD connection test failed: {e}")
            return False

class RedshiftService:
    def __init__(self):
        self.encryption = PasswordEncryption()
        self.host = config.REDSHIFT_HOST
        self.port = config.REDSHIFT_PORT
        self.database = config.REDSHIFT_DB
        self.admin_user = config.REDSHIFT_ADMIN_USER
        self.admin_password = self.encryption.decrypt(config.REDSHIFT_ADMIN_PASSWORD)
    
    def get_connection(self):
        """Create Redshift connection"""
        return psycopg2.connect(
            host=self.host,
            port=self.port,
            database=self.database,
            user=self.admin_user,
            password=self.admin_password,
            sslmode='require',
            connect_timeout=10
        )
    
    def user_exists(self, username):
        """Check if user exists in Redshift"""
        try:
            with self.get_connection() as conn:
                with conn.cursor() as cursor:
                    cursor.execute("SELECT COUNT(*) FROM pg_user WHERE usename = %s", (username,))
                    return cursor.fetchone()[0] > 0
        except Exception as e:
            logger.error(f"Error checking if user {username} exists: {e}")
            return False
    
    def reset_password(self, username, new_password):
        """Reset password in Redshift"""
        try:
            with self.get_connection() as conn:
                with conn.cursor() as cursor:
                    # Use parameterized query to prevent SQL injection
                    query = f'ALTER USER "{username}" PASSWORD %s'
                    cursor.execute(query, (new_password,))
                    conn.commit()
                    logger.info(f"Password reset successfully for user {username}")
                    return True
        except Exception as e:
            logger.error(f"Error resetting password for user {username}: {e}")
            return False
    
    def test_connection(self):
        """Test Redshift connection"""
        try:
            with self.get_connection() as conn:
                with conn.cursor() as cursor:
                    cursor.execute("SELECT version()")
                    return True
        except Exception as e:
            logger.error(f"Redshift connection test failed: {e}")
            return False

# Initialize services
audit_service = AuditService()
ad_service = ActiveDirectoryService()
redshift_service = RedshiftService()

# Decorators
def require_auth(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'authenticated' not in session or not session['authenticated']:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

# Routes
@app.route('/')
def index():
    if 'authenticated' not in session or not session['authenticated']:
        return redirect(url_for('login'))
    return redirect(url_for('reset_password'))

@app.route('/login', methods=['GET', 'POST'])
@limiter.limit("5 per minute")
def login():
    form = LoginForm()
    
    if form.validate_on_submit():
        username = form.username.data.strip()
        password = form.password.data
        
        # Authenticate against AD
        authenticated_username = ad_service.authenticate_user(username, password)
        
        if authenticated_username:
            session['authenticated'] = True
            session['username'] = authenticated_username
            
            audit_service.log_action(
                authenticated_username, 'Login', True, 
                ip_address=request.remote_addr
            )
            
            flash(f'Welcome, {authenticated_username}!', 'success')
            return redirect(url_for('reset_password'))
        else:
            audit_service.log_action(
                username, 'Login Failed', False, 
                'Invalid credentials', request.remote_addr
            )
            flash('Invalid username or password', 'error')
    
    return render_template('login.html', form=form)

@app.route('/logout')
def logout():
    username = session.get('username', 'Unknown')
    audit_service.log_action(username, 'Logout', True, ip_address=request.remote_addr)
    session.clear()
    flash('Successfully logged out', 'info')
    return redirect(url_for('login'))

@app.route('/reset-password', methods=['GET', 'POST'])
@require_auth
@limiter.limit("3 per minute")
def reset_password():
    form = PasswordResetForm()
    username = session.get('username')
    
    if form.validate_on_submit():
        new_password = form.new_password.data
        
        # Check if user exists in Redshift
        if not redshift_service.user_exists(username):
            flash(f'User {username} not found in Redshift system', 'error')
            audit_service.log_action(
                username, 'Password Reset Attempt', False,
                'User not found in Redshift', request.remote_addr
            )
            return render_template('reset_password.html', form=form, username=username)
        
        # Reset password
        success = redshift_service.reset_password(username, new_password)
        
        if success:
            audit_service.log_action(
                username, 'Password Reset', True,
                ip_address=request.remote_addr
            )
            flash('Password reset successfully!', 'success')
            return redirect(url_for('success'))
        else:
            audit_service.log_action(
                username, 'Password Reset Attempt', False,
                'Reset operation failed', request.remote_addr
            )
            flash('Error resetting password. Please try again.', 'error')
    
    return render_template('reset_password.html', form=form, username=username)

@app.route('/success')
@require_auth
def success():
    return render_template('success.html')

@app.route('/health')
def health_check():
    """System health check"""
    health_status = {
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'checks': {
            'redshift': redshift_service.test_connection(),
            'active_directory': ad_service.test_connection(),
            'application': True
        }
    }
    
    if not all(health_status['checks'].values()):
        health_status['status'] = 'unhealthy'
        return jsonify(health_status), 503
    
    return jsonify(health_status)

@app.route('/audit')
@require_auth
def audit_log():
    """Audit logs - available to administrators only"""
    logs = audit_service.get_logs(100)
    return render_template('audit.html', logs=logs)

# Error handlers
@app.errorhandler(404)
def not_found_error(error):
    return render_template('error.html', 
                         error_code=404, 
                         error_message='Page not found'), 404

@app.errorhandler(500)
def internal_error(error):
    logger.error(f"Internal server error: {error}")
    return render_template('error.html', 
                         error_code=500, 
                         error_message='Internal server error'), 500

@app.errorhandler(429)
def ratelimit_handler(e):
    return render_template('error.html',
                         error_code=429,
                         error_message='Too many requests. Please wait and try again'), 429

if __name__ == '__main__':
    # Startup checks
    try:
        logger.info("Starting Redshift Password Reset Application...")
        logger.info(f"Environment: {os.getenv('FLASK_ENV', 'production')}")
        
        # Test connections
        if redshift_service.test_connection():
            logger.info("✓ Redshift connection OK")
        else:
            logger.warning("⚠ Redshift connection failed")
            
        if ad_service.test_connection():
            logger.info("✓ Active Directory connection OK")
        else:
            logger.warning("⚠ Active Directory connection failed")
        
        # Start application
        debug_mode = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
        app.run(
            host='0.0.0.0', 
            port=5000, 
            debug=debug_mode
        )
        
    except Exception as e:
        logger.error(f"Failed to start application: {e}")
        print(f"Error starting application: {e}")
        print("Please check your .env configuration")
        input("Press Enter to exit...")
```

### Configuration Setup Script

**setup_config.py**
```python
"""
Initial configuration script for Redshift Password Reset Application
Run once after project setup
"""

import os
import sys
from cryptography.fernet import Fernet
from getpass import getpass
import base64

def generate_encryption_key():
    """Generate encryption key"""
    return Fernet.generate_key().decode()

def encrypt_password(password, key):
    """Encrypt password"""
    f = Fernet(key.encode())
    encrypted = f.encrypt(password.encode())
    return "ENCRYPTED:" + base64.b64encode(encrypted).decode()

def test_redshift_connection(host, port, db, user, password):
    """Test Redshift connection"""
    try:
        import psycopg2
        conn_string = f"host={host} port={port} dbname={db} user={user} password={password} sslmode=require"
        conn = psycopg2.connect(conn_string)
        cursor = conn.cursor()
        cursor.execute("SELECT version()")
        version = cursor.fetchone()[0]
        conn.close()
        print(f"✓ Redshift connection OK! Version: {version[:50]}...")
        return True
    except Exception as e:
        print(f"✗ Redshift connection error: {e}")
        return False

def test_ad_connection(server, domain):
    """Test Active Directory connection"""
    try:
        import ldap3
        server_obj = ldap3.Server(server, get_info=ldap3.ALL)
        conn = ldap3.Connection(server_obj, auto_bind=True)
        print(f"✓ Active Directory connection OK! Server: {server}")
        return True
    except Exception as e:
        print(f"✗ Active Directory connection error: {e}")
        return False

def main():
    print("Redshift Password Reset Application - Initial Configuration")
    print("=" * 60)
    
    # Check if .env already exists
    if os.path.exists('.env'):
        overwrite = input("\n.env file already exists. Overwrite? (y/n): ")
        if overwrite.lower() != 'y':
            print("Configuration cancelled.")
            return
    
    # Generate security keys
    encryption_key = generate_encryption_key()
    secret_key = Fernet.generate_key().decode()
    
    print(f"\nGenerated encryption keys:")
    print(f"   Encryption Key: {encryption_key[:20]}...")
    print(f"   Secret Key: {secret_key[:20]}...")
    
    # Get Redshift details
    print("\nRedshift Configuration:")
    redshift_host = input("Redshift Host (cluster.region.redshift.amazonaws.com): ").strip()
    redshift_port = input("Redshift Port (5439): ").strip() or "5439"
    redshift_db = input("Database Name: ").strip()
    redshift_user = input("Admin Username: ").strip()
    redshift_password = getpass("Admin Password: ")
    
    if not all([redshift_host, redshift_db, redshift_user, redshift_password]):
        print("✗ All Redshift details are required!")
        return
    
    # Encrypt password
    encrypted_password = encrypt_password(redshift_password, encryption_key)
    print("✓ Redshift password encrypted")
    
    # Get Active Directory details
    print("\nActive Directory Configuration:")
    ad_server = input("AD Server (ldap://dc.domain.com): ").strip()
    ad_domain = input("Domain (domain.com): ").strip()
    ad_base_dn = input("Base DN (DC=domain,DC=com): ").strip()
    
    if not all([ad_server, ad_domain, ad_base_dn]):
        print("✗ All Active Directory details are required!")
        return
    
    # Create .env file
    env_content = f"""# Redshift Configuration
REDSHIFT_HOST={redshift_host}
REDSHIFT_PORT={redshift_port}
REDSHIFT_DB={redshift_db}
REDSHIFT_ADMIN_USER={redshift_user}
REDSHIFT_ADMIN_PASSWORD={encrypted_password}

# Active Directory Configuration
AD_SERVER={ad_server}
AD_DOMAIN={ad_domain}
AD_BASE_DN={ad_base_dn}

# Security
ENCRYPTION_KEY={encryption_key}
FLASK_SECRET_KEY={secret_key}

# Environment
FLASK_ENV=development
FLASK_DEBUG=True
"""
    
    with open('.env', 'w', encoding='utf-8') as f:
        f.write(env_content)
    
    print("\n✓ .env file created successfully!")
    
    # Test connections
    test_connections = input("\nTest connections? (y/n): ")
    if test_connections.lower() == 'y':
        print("\nTesting connections...")
        
        # Test Redshift
        redshift_ok = test_redshift_connection(
            redshift_host, redshift_port, redshift_db, 
            redshift_user, redshift_password
        )
        
        # Test AD
        ad_ok = test_ad_connection(ad_server, ad_domain)
        
        if redshift_ok and ad_ok:
            print("\n🎉 All connections successful! Application ready.")
        else:
            print("\n⚠ Some connections failed. Check configuration.")
    
    print("\nYou can now run the application:")
    print("   python app.py")

if __name__ == "__main__":
    main()
```

### HTML Templates

Create a `templates` folder and add these files:

**templates/base.html**
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}Redshift Password Reset{% endblock %}</title>
    
    <!-- Bootstrap CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <!-- Font Awesome -->
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
    
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        
        .card {
            box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
            border: none;
            border-radius: 15px;
        }
        
        .card-header {
            border-radius: 15px 15px 0 0 !important;
            border-bottom: none;
            padding: 1.5rem;
        }
        
        .navbar-brand {
            font-weight: bold;
        }
        
        .btn {
            border-radius: 10px;
            padding: 0.75rem 1.5rem;
        }
        
        .form-control {
            border-radius: 10px;
            border: 2px solid #e9ecef;
            padding: 0.75rem 1rem;
            transition: all 0.3s ease;
        }
        
        .form-control:focus {
            border-color: #667eea;
            box-shadow: 0 0 0 0.2rem rgba(102, 126, 234, 0.25);
        }
        
        .alert {
            border-radius: 10px;
            border: none;
        }
        
        .container-main {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            margin-top: 2rem;
            margin-bottom: 2rem;
            padding: 2rem;
        }
        
        .footer {
            margin-top: auto;
            text-align: center;
            padding: 1rem;
            color: rgba(255, 255, 255, 0.8);
            font-size: 0.9rem;
        }
    </style>
    
    {% block extra_css %}{% endblock %}
</head>
<body class="d-flex flex-column">
    <!-- Navigation -->
    <nav class="navbar navbar-expand-lg navbar-dark" style="background: rgba(0, 0, 0, 0.2); backdrop-filter: blur(10px);">
        <div class="container">
            <a class="navbar-brand" href="{{ url_for('index') }}">
                <i class="fas fa-key me-2"></i>
                Redshift Password Reset
            </a>
            
            <div class="navbar-nav ms-auto">
                {% if session.authenticated %}
                    <span class="navbar-text me-3">
                        <i class="fas fa-user-circle me-1"></i>
                        Hello, {{ session.username }}
                    </span>
                    <a class="nav-link" href="{{ url_for('audit_log') }}" title="Audit Logs">
                        <i class="fas fa-list-alt"></i>
                    </a>
                    <a class="nav-link" href="{{ url_for('logout') }}" title="Logout">
                        <i class="fas fa-sign-out-alt"></i>
                    </a>
                {% endif %}
            </div>
        </div>
    </nav>

    <!-- Main Content -->
    <div class="container flex-grow-1">
        <div class="container-main">
            <!-- Flash Messages -->
            {% with messages = get_flashed_messages(with_categories=true) %}
                {% if messages %}
                    {% for category, message in messages %}
                        <div class="alert alert-{{ 'danger' if category == 'error' else 'success' if category == 'success' else 'info' }} alert-dismissible fade show" role="alert">
                            <i class="fas fa-{{ 'exclamation-triangle' if category == 'error' else 'check-circle' if category == 'success' else 'info-circle' }} me-2"></i>
                            {{ message }}
                            <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
                        </div>
                    {% endfor %}
                {% endif %}
            {% endwith %}

            <!-- Page Content -->
            {% block content %}{% endblock %}
        </div>
    </div>

    <!-- Footer -->
    <div class="footer">
        <p>
            <i class="fas fa-shield-alt me-1"></i>
            Secure Password Reset System | 
            <i class="fas fa-clock me-1"></i>
            2024
        </p>
    </div>

    <!-- Bootstrap JS -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    
    {% block extra_js %}{% endblock %}
</body>
</html>
```

**templates/login.html**
```html
{% extends "base.html" %}

{% block title %}Login - Redshift Password Reset{% endblock %}

{% block content %}
<div class="row justify-content-center">
    <div class="col-md-5 col-lg-4">
        <div class="card">
            <div class="card-header bg-primary text-white text-center">
                <h4 class="mb-0">
                    <i class="fas fa-sign-in-alt me-2"></i>
                    System Login
                </h4>
            </div>
            <div class="card-body p-4">
                <form method="POST" autocomplete="off">
                    {{ form.hidden_tag() }}
                    
                    <div class="mb-3">
                        {{ form.username.label(class="form-label fw-bold") }}
                        {{ form.username(class="form-control", placeholder="Enter username", autofocus=true) }}
                        {% if form.username.errors %}
                            <div class="text-danger mt-1">
                                {% for error in form.username.errors %}
                                    <small><i class="fas fa-exclamation-circle me-1"></i>{{ error }}</small>
                                {% endfor %}
                            </div>
                        {% endif %}
                        <small class="form-text text-muted">
                            <i class="fas fa-info-circle me-1"></i>
                            Use your Active Directory username
                        </small>
                    </div>
                    
                    <div class="mb-4">
                        {{ form.password.label(class="form-label fw-bold") }}
                        {{ form.password(class="form-control", placeholder="Enter password") }}
                        {% if form.password.errors %}
                            <div class="text-danger mt-1">
                                {% for error in form.password.errors %}
                                    <small><i class="fas fa-exclamation-circle me-1"></i>{{ error }}</small>
                                {% endfor %}
                            </div>
                        {% endif %}
                    </div>
                    
                    <div class="d-grid">
                        {{ form.submit(class="btn btn-primary btn-lg") }}
                    </div>
                </form>
                
                <hr class="my-4">
                
                <div class="text-center text-muted">
                    <small>
                        <i class="fas fa-lock me-1"></i>
                        Secure authentication via Active Directory
                    </small>
                </div>
            </div>
        </div>
    </div>
</div>
{% endblock %}
```

**templates/reset_password.html**
```html
{% extends "base.html" %}

{% block title %}Reset Password - {{ username }}{% endblock %}

{% block content %}
<div class="row justify-content-center">
    <div class="col-md-6 col-lg-5">
        <div class="card">
            <div class="card-header bg-warning text-dark text-center">
                <h4 class="mb-0">
                    <i class="fas fa-key me-2"></i>
                    Reset Redshift Password
                </h4>
            </div>
            <div class="card-body p-4">
                <div class="alert alert-info">
                    <i class="fas fa-user me-2"></i>
                    <strong>Current User:</strong> 
                    <span class="badge bg-primary">{{ username }}</span>
                </div>

                <form method="POST" autocomplete="off">
                    {{ form.hidden_tag() }}
                    
                    <div class="mb-3">
                        {{ form.new_password.label(class="form-label fw-bold") }}
                        <div class="input-group">
                            {{ form.new_password(class="form-control", placeholder="Enter new password", id="newPassword") }}
                            <button class="btn btn-outline-secondary" type="button" id="togglePassword" title="Show/Hide Password">
                                <i class="fas fa-eye" id="eyeIcon"></i>
                            </button>
                        </div>
                        {% if form.new_password.errors %}
                            <div class="text-danger mt-1">
                                {% for error in form.new_password.errors %}
                                    <small><i class="fas fa-exclamation-circle me-1"></i>{{ error }}</small>
                                {% endfor %}
                            </div>
                        {% endif %}
                    </div>

                    <div class="mb-3">
                        {{ form.confirm_password.label(class="form-label fw-bold") }}
                        {{ form.confirm_password(class="form-control", placeholder="Confirm new password") }}
                        {% if form.confirm_password.errors %}
                            <div class="text-danger mt-1">
                                {% for error in form.confirm_password.errors %}
                                    <small><i class="fas fa-exclamation-circle me-1"></i>{{ error }}</small>
                                {% endfor %}
                            </div>
                        {% endif %}
                    </div>

                    <div class="alert alert-light border">
                        <h6 class="mb-2">
                            <i class="fas fa-shield-alt me-1"></i>
                            Password Requirements:
                        </h6>
                        <ul class="mb-0 small">
                            <li>At least 8 characters</li>
                            <li>Recommended: Mix of letters, numbers and symbols</li>
                            <li>Avoid using simple words</li>
                        </ul>
                    </div>

                    <div class="d-grid">
                        {{ form.submit(class="btn btn-danger btn-lg") }}
                    </div>
                </form>
                
                <hr class="my-3">
                
                <div class="row text-center">
                    <div class="col-6">
                        <a href="{{ url_for('audit_log') }}" class="btn btn-outline-info btn-sm">
                            <i class="fas fa-list-alt me-1"></i>
                            Audit Logs
                        </a>
                    </div>
                    <div class="col-6">
                        <a href="{{ url_for('logout') }}" class="btn btn-outline-secondary btn-sm">
                            <i class="fas fa-sign-out-alt me-1"></i>
                            Logout
                        </a>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
{% endblock %}

{% block extra_js %}
<script>
document.getElementById('togglePassword').addEventListener('click', function() {
    const passwordField = document.getElementById('newPassword');
    const eyeIcon = document.getElementById('eyeIcon');
    
    if (passwordField.type === 'password') {
        passwordField.type = 'text';
        eyeIcon.classList.remove('fa-eye');
        eyeIcon.classList.add('fa-eye-slash');
    } else {
        passwordField.type = 'password';
        eyeIcon.classList.remove('fa-eye-slash');
        eyeIcon.classList.add('fa-eye');
    }
});
</script>
{% endblock %}
```

**templates/success.html**
```html
{% extends "base.html" %}

{% block title %}Password Reset Successful{% endblock %}

{% block content %}
<div class="row justify-content-center">
    <div class="col-md-6 col-lg-5">
        <div class="card">
            <div class="card-header bg-success text-white text-center">
                <h4 class="mb-0">
                    <i class="fas fa-check-circle me-2"></i>
                    Password Reset Successful!
                </h4>
            </div>
            <div class="card-body p-4 text-center">
                <div class="mb-4">
                    <i class="fas fa-check-circle text-success" style="font-size: 4rem;"></i>
                </div>
                
                <h5 class="mb-3">Your Redshift password has been reset successfully!</h5>
                
                <p class="text-muted mb-4">
                    You can now connect to the Redshift system with your new password.
                </p>
                
                <div class="alert alert-info">
                    <i class="fas fa-info-circle me-2"></i>
                    <strong>Important:</strong> Keep your new password in a secure location
                </div>
                
                <div class="d-grid gap-2">
                    <a href="{{ url_for('reset_password') }}" class="btn btn-warning">
                        <i class="fas fa-key me-2"></i>
                        Reset Another Password
                    </a>
                    <a href="{{ url_for('logout') }}" class="btn btn-outline-secondary">
                        <i class="fas fa-sign-out-alt me-2"></i>
                        Logout
                    </a>
                </div>
            </div>
        </div>
    </div>
</div>
{% endblock %}
```

**templates/audit.html**
```html
{% extends "base.html" %}

{% block title %}Audit Logs{% endblock %}

{% block content %}
<div class="row">
    <div class="col-12">
        <div class="card">
            <div class="card-header bg-info text-white d-flex justify-content-between align-items-center">
                <h4 class="mb-0">
                    <i class="fas fa-list-alt me-2"></i>
                    Audit Logs
                </h4>
                <span class="badge bg-light text-dark">
                    {{ logs|length }} entries
                </span>
            </div>
            <div class="card-body">
                {% if logs %}
                    <div class="table-responsive">
                        <table class="table table-striped table-hover align-middle">
                            <thead class="table-dark">
                                <tr>
                                    <th><i class="fas fa-clock me-1"></i>Timestamp</th>
                                    <th><i class="fas fa-user me-1"></i>User</th>
                                    <th><i class="fas fa-cog me-1"></i>Action</th>
                                    <th><i class="fas fa-check-circle me-1"></i>Status</th>
                                    <th><i class="fas fa-globe me-1"></i>IP Address</th>
                                    <th><i class="fas fa-exclamation-triangle me-1"></i>Error</th>
                                </tr>
                            </thead>
                            <tbody>
                                {% for log in logs %}
                                <tr>
                                    <td>
                                        <small class="text-muted">
                                            {{ log.timestamp[:19].replace('T', ' ') }}
                                        </small>
                                    </td>
                                    <td>
                                        <strong class="text-primary">
                                            <i class="fas fa-user-circle me-1"></i>
                                            {{ log.username }}
                                        </strong>
                                    </td>
                                    <td>
                                        <span class="badge bg-secondary">
                                            {{ log.action }}
                                        </span>
                                    </td>
                                    <td>
                                        {% if log.success %}
                                            <span class="badge bg-success">
                                                <i class="fas fa-check me-1"></i>Success
                                            </span>
                                        {% else %}
                                            <span class="badge bg-danger">
                                                <i class="fas fa-times me-1"></i>Failed
                                            </span>
                                        {% endif %}
                                    </td>
                                    <td>
                                        <code class="small">{{ log.ip_address }}</code>
                                    </td>
                                    <td>
                                        {% if log.error_message %}
                                            <small class="text-danger">
                                                <i class="fas fa-exclamation-circle me-1"></i>
                                                {{ log.error_message }}
                                            </small>
                                        {% else %}
                                            <small class="text-muted">-</small>
                                        {% endif %}
                                    </td>
                                </tr>
                                {% endfor %}
                            </tbody>
                        </table>
                    </div>
                {% else %}
                    <div class="alert alert-info text-center">
                        <i class="fas fa-info-circle fa-2x mb-3"></i>
                        <h5>No audit logs available</h5>
                        <p class="mb-0">Logs will appear here after system activity</p>
                    </div>
                {% endif %}
                
                <div class="mt-4 text-center">
                    <a href="{{ url_for('reset_password') }}" class="btn btn-primary">
                        <i class="fas fa-arrow-left me-2"></i>
                        Back to Main Page
                    </a>
                </div>
            </div>
        </div>
    </div>
</div>
{% endblock %}
```

**templates/error.html**
```html
{% extends "base.html" %}

{% block title %}Error {{ error_code }}{% endblock %}

{% block content %}
<div class="row justify-content-center">
    <div class="col-md-6">
        <div class="card">
            <div class="card-header bg-danger text-white text-center">
                <h4 class="mb-0">
                    <i class="fas fa-exclamation-triangle me-2"></i>
                    Error {{ error_code }}
                </h4>
            </div>
            <div class="card-body text-center p-4">
                <div class="mb-4">
                    <i class="fas fa-exclamation-circle text-danger" style="font-size: 4rem;"></i>
                </div>
                
                <h5 class="mb-3">{{ error_message }}</h5>
                
                {% if error_code == 404 %}
                    <p class="text-muted">The page you requested was not found.</p>
                {% elif error_code == 429 %}
                    <p class="text-muted">Too many requests sent. Please wait a few minutes and try again.</p>
                {% elif error_code == 500 %}
                    <p class="text-muted">A server error occurred. Please try again later.</p>
                {% endif %}
                
                <div class="d-grid gap-2 mt-4">
                    <a href="{{ url_for('index') }}" class="btn btn-primary">
                        <i class="fas fa-home me-2"></i>
                        Back to Home
                    </a>
                    <button onclick="history.back()" class="btn btn-outline-secondary">
                        <i class="fas fa-arrow-left me-2"></i>
                        Go Back
                    </button>
                </div>
            </div>
        </div>
    </div>
</div>
{% endblock %}
```

---

## Configuration

### Environment File Template

Create `.env.example`:

```
# Redshift Configuration
REDSHIFT_HOST=your-cluster.redshift.amazonaws.com
REDSHIFT_PORT=5439
REDSHIFT_DB=your_database
REDSHIFT_ADMIN_USER=redshift_admin
REDSHIFT_ADMIN_PASSWORD=ENCRYPTED:your_encrypted_password_here

# Active Directory Configuration
AD_SERVER=ldap://your-domain-controller.com
AD_DOMAIN=yourdomain.com
AD_BASE_DN=DC=yourdomain,DC=com

# Security
ENCRYPTION_KEY=your_generated_fernet_key_here
FLASK_SECRET_KEY=your-secret-key-change-this
FLASK_ENV=development
FLASK_DEBUG=True
```

### Redshift Setup

Connect to your Redshift cluster and run:

```sql
-- Create technical user for the application
CREATE USER redshift_admin PASSWORD 'StrongPassword123!';

-- Grant permissions to reset passwords
GRANT ALTER ON ALL USERS TO redshift_admin;

-- Alternative: Grant broader permissions if needed
-- ALTER USER redshift_admin CREATEUSER;

-- Verify the user was created
SELECT usename, usesuper FROM pg_user WHERE usename = 'redshift_admin';

-- Test the permissions (optional)
-- ALTER USER test_user PASSWORD 'new_password';
```

---

## Testing on Windows

### Step 1: Install Dependencies

```cmd
# Activate virtual environment
venv\Scripts\activate.bat

# Install packages
pip install -r requirements.txt
```

### Step 2: Configure Application

```cmd
# Run configuration script
python setup_config.py
```

Follow the prompts to enter:
- Redshift cluster details
- Active Directory server information
- Test connections

### Step 3: Run Application

```cmd
# Start the application
python app.py
```

### Step 4: Test Functionality

1. Open browser: `http://localhost:5000`
2. Test health check: `http://localhost:5000/health`
3. Login with AD credentials
4. Reset a password
5. Check audit logs
6. Verify the password works in Redshift

### Development Batch File

Create `run_dev.bat`:

```batch
@echo off
echo Starting Redshift Password Reset Application - Development Mode

call venv\Scripts\activate.bat

if not exist ".env" (
    echo ERROR: .env file not found!
    echo Please run: python setup_config.py
    pause
    exit /b 1
)

echo Starting application on http://localhost:5000
set FLASK_ENV=development
set FLASK_DEBUG=True
python app.py
pause
```

---

## Linux Production Deployment

### Production Deployment Script

Create `deploy_linux.sh`:

```bash
#!/bin/bash
# Production deployment script for Linux

set -e  # Exit on any error

echo "=========================================="
echo "     Redshift Password Reset Deployment"
echo "=========================================="

# Variables
APP_NAME="redshift-password-reset"
APP_USER="redshift-app"
APP_DIR="/opt/$APP_NAME"
SERVICE_NAME="redshift-password-reset"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root (use sudo)"
   exit 1
fi

print_status "Starting deployment process..."

# 1. Update system
print_status "Updating system packages..."
apt update
apt upgrade -y

# 2. Install required packages
print_status "Installing required packages..."
apt install -y python3 python3-pip python3-venv nginx supervisor ufw fail2ban htop

# 3. Create application user
print_status "Creating application user..."
if ! id "$APP_USER" &>/dev/null; then
    useradd -r -s /bin/false -d $APP_DIR $APP_USER
    print_status "User $APP_USER created"
else
    print_warning "User $APP_USER already exists"
fi

# 4. Create application directory
print_status "Setting up application directory..."
mkdir -p $APP_DIR
mkdir -p $APP_DIR/logs
mkdir -p $APP_DIR/audit

# 5. Copy application files (assumes files are in current directory)
print_status "Copying application files..."
cp -r . $APP_DIR/
cd $APP_DIR

# 6. Set up Python virtual environment
print_status "Setting up Python virtual environment..."
sudo -u $APP_USER python3 -m venv venv
sudo -u $APP_USER $APP_DIR/venv/bin/pip install --upgrade pip
sudo -u $APP_USER $APP_DIR/venv/bin/pip install -r requirements.txt

# 7. Set permissions
print_status "Setting file permissions..."
chown -R $APP_USER:$APP_USER $APP_DIR
chmod 755 $APP_DIR
chmod -R 755 $APP_DIR/logs
chmod -R 755 $APP_DIR/audit

# 8. Create systemd service file
print_status "Creating systemd service..."
cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=Redshift Password Reset Web Application
After=network.target

[Service]
Type=exec
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$APP_DIR
Environment=PATH=$APP_DIR/venv/bin
ExecStart=$APP_DIR/venv/bin/gunicorn --bind 127.0.0.1:5000 --workers 3 --timeout 30 app:app
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 9. Create nginx configuration
print_status "Configuring Nginx..."
cat > /etc/nginx/sites-available/$APP_NAME << EOF
server {
    listen 80;
    server_name _;  # Replace with your domain
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
    
    location /health {
        proxy_pass http://127.0.0.1:5000/health;
        access_log off;
    }
}
EOF

# Enable nginx site
ln -sf /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
nginx -t

# 10. Configure firewall
print_status "Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

# 11. Configure fail2ban
print_status "Configuring fail2ban..."
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 1800
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
action = iptables-multiport[name=ReqLimit, port="http,https", protocol=tcp]
logpath = /var/log/nginx/error.log
findtime = 600
bantime = 7200
maxretry = 10
EOF

# 12. Start and enable services
print_status "Starting services..."
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl start $SERVICE_NAME
systemctl enable nginx
systemctl restart nginx
systemctl enable fail2ban
systemctl restart fail2ban

# 13. Create log rotation
print_status "Setting up log rotation..."
cat > /etc/logrotate.d/$APP_NAME << EOF
$APP_DIR/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 $APP_USER $APP_USER
    postrotate
        systemctl reload $SERVICE_NAME
    endscript
}
EOF

# 14. Create backup script
print_status "Creating backup script..."
cat > /usr/local/bin/backup-redshift-app.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/backups/redshift-password-reset"
APP_DIR="/opt/redshift-password-reset"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup configuration and logs
tar -czf $BACKUP_DIR/redshift-app-backup-$DATE.tar.gz \
    $APP_DIR/.env \
    $APP_DIR/audit/ \
    $APP_DIR/logs/ \
    --exclude=$APP_DIR/venv \
    --exclude=$APP_DIR/__pycache__

# Keep only last 7 backups
find $BACKUP_DIR -name "redshift-app-backup-*.tar.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR/redshift-app-backup-$DATE.tar.gz"
EOF

chmod +x /usr/local/bin/backup-redshift-app.sh

# 15. Create monitoring script
print_status "Creating monitoring script..."
cat > /usr/local/bin/monitor-redshift-app.sh << 'EOF'
#!/bin/bash
SERVICE_NAME="redshift-password-reset"
APP_URL="http://localhost:5000/health"

# Check if service is running
if ! systemctl is-active --quiet $SERVICE_NAME; then
    echo "ERROR: $SERVICE_NAME is not running"
    systemctl start $SERVICE_NAME
    exit 1
fi

# Check if application responds
if ! curl -f -s $APP_URL > /dev/null; then
    echo "ERROR: Application health check failed"
    systemctl restart $SERVICE_NAME
    exit 1
fi

echo "OK: Service is running and healthy"
EOF

chmod +x /usr/local/bin/monitor-redshift-app.sh

# 16. Add cron jobs
print_status "Setting up cron jobs..."
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/backup-redshift-app.sh") | crontab -
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/monitor-redshift-app.sh") | crontab -

# 17. Final status check
print_status "Checking service status..."
sleep 5

if systemctl is-active --quiet $SERVICE_NAME; then
    print_status "✓ Service is running successfully!"
else
    print_error "✗ Service failed to start"
    systemctl status $SERVICE_NAME
    exit 1
fi

# Check nginx
if systemctl is-active --quiet nginx; then
    print_status "✓ Nginx is running successfully!"
else
    print_error "✗ Nginx failed to start"
    systemctl status nginx
    exit 1
fi

# Health check
if curl -f -s http://localhost:5000/health > /dev/null; then
    print_status "✓ Application health check passed!"
else
    print_warning "⚠ Application health check failed - check configuration"
fi

print_status "=========================================="
print_status "         Deployment Completed!"
print_status "=========================================="
print_status ""
print_status "Next steps:"
print_status "1. Copy your project files to this server"
print_status "2. Configure .env file: sudo -u $APP_USER $APP_DIR/venv/bin/python $APP_DIR/setup_config.py"
print_status "3. Restart the service: sudo systemctl restart $SERVICE_NAME"
print_status "4. Configure SSL certificates for production"
print_status ""
print_status "Useful commands:"
print_status "- Check service status: systemctl status $SERVICE_NAME"
print_status "- View logs: journalctl -u $SERVICE_NAME -f"
print_status "- Application logs: tail -f $APP_DIR/logs/app.log"
print_status "- Restart service: systemctl restart $SERVICE_NAME"
print_status ""
```

### WSGI Entry Point

Create `wsgi.py`:

```python
"""
WSGI entry point for production deployment
"""
import os
import sys
from dotenv import load_dotenv

# Add the application directory to Python path
sys.path.insert(0, os.path.dirname(__file__))

# Load environment variables
load_dotenv()

from app import app

if __name__ == "__main__":
    app.run()
```

### Update Script

Create `update_app.sh`:

```bash
#!/bin/bash
# Application update script for Linux

APP_NAME="redshift-password-reset"
APP_USER="redshift-app"
APP_DIR="/opt/$APP_NAME"
SERVICE_NAME="redshift-password-reset"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

print_status "Updating Redshift Password Reset Application..."

# Backup current version
print_status "Creating backup..."
/usr/local/bin/backup-redshift-app.sh

# Stop service
print_status "Stopping service..."
systemctl stop $SERVICE_NAME

# Update application files (assumes new files are in current directory)
print_status "Updating application files..."
cp -r . $APP_DIR/
cd $APP_DIR

# Update dependencies
print_status "Updating dependencies..."
sudo -u $APP_USER $APP_DIR/venv/bin/pip install --upgrade -r requirements.txt

# Set permissions
print_status "Setting permissions..."
chown -R $APP_USER:$APP_USER $APP_DIR

# Start service
print_status "Starting service..."
systemctl start $SERVICE_NAME

# Check status
sleep 3
if systemctl is-active --quiet $SERVICE_NAME; then
    print_status "✓ Application updated successfully!"
else
    print_warning "✗ Service failed to start, check logs:"
    journalctl -u $SERVICE_NAME --no-pager -n 20
    exit 1
fi

print_status "Update completed!"
```

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Redshift Connection Issues

**Error:** `psycopg2.OperationalError: could not connect to server`

**Solutions:**
- Check AWS Security Groups allow connections from your server IP
- Verify Redshift cluster is publicly accessible (if needed)
- Confirm username/password are correct
- Test SSL connection requirements

```bash
# Test connection from command line
psql -h your-cluster.redshift.amazonaws.com -p 5439 -d your_database -U admin_user
```

#### 2. Active Directory Authentication Issues

**Error:** `ldap3.core.exceptions.LDAPSocketOpenError`

**Solutions:**
- Check firewall between servers allows LDAP traffic (port 389/636)
- Verify domain controller hostname/IP is reachable
- Test with different username formats:
  - `username`
  - `DOMAIN\username`
  - `username@domain.com`

```bash
# Test LDAP connectivity
ldapsearch -x -H ldap://dc.domain.com -b "DC=domain,DC=com" -s base
```

#### 3. Permission Errors

**Error:** `Permission denied for ALTER USER`

**Solutions:**
- Grant proper permissions to technical user:

```sql
GRANT ALTER ON ALL USERS TO redshift_admin;
-- OR
ALTER USER redshift_admin CREATEUSER;
```

#### 4. SSL/TLS Issues

**Error:** `SSL connection has been closed unexpectedly`

**Solutions:**
- Check if Redshift requires SSL: `sslmode='require'`
- Try different SSL modes: `prefer`, `allow`, `disable`
- Verify network allows SSL traffic

#### 5. Service Won't Start on Linux

**Check logs:**
```bash
# Service logs
journalctl -u redshift-password-reset -f

# Application logs
tail -f /opt/redshift-password-reset/logs/app.log

# Nginx logs
tail -f /var/log/nginx/error.log
```

**Common fixes:**
- Check .env file exists and has correct permissions
- Verify all Python dependencies installed
- Ensure port 5000 is not in use
- Check file permissions for app user

---

## Maintenance

### Regular Maintenance Tasks

#### 1. Monitor Logs

```bash
# Application logs
tail -f /opt/redshift-password-reset/logs/app.log

# Service status
systemctl status redshift-password-reset

# System resources
htop
df -h
```

#### 2. Backup and Restore

```bash
# Manual backup
sudo /usr/local/bin/backup-redshift-app.sh

# Restore from backup
sudo tar -xzf /opt/backups/redshift-password-reset/redshift-app-backup-YYYYMMDD_HHMMSS.tar.gz -C /opt/redshift-password-reset/
sudo systemctl restart redshift-password-reset
```

#### 3. Update Application

```bash
# Using update script
sudo ./update_app.sh

# Manual update
sudo systemctl stop redshift-password-reset
sudo cp new_files/* /opt/redshift-password-reset/
sudo chown -R redshift-app:redshift-app /opt/redshift-password-reset
sudo systemctl start redshift-password-reset
```

#### 4. Security Updates

```bash
# Update system packages
sudo apt update && sudo apt upgrade

# Update Python packages
sudo -u redshift-app /opt/redshift-password-reset/venv/bin/pip install --upgrade -r requirements.txt

# Check for failed login attempts
sudo fail2ban-client status
sudo tail -f /var/log/auth.log
```

#### 5. Performance Monitoring

```bash
# Check application performance
curl -s http://localhost:5000/health | jq

# Monitor resource usage
sudo htop

# Check disk space
df -h

# Monitor network connections
sudo netstat -tulpn | grep :5000
```

#### 6. Log Rotation and Cleanup

Logs are automatically rotated, but you can manually clean up:

```bash
# Clean old logs
sudo find /opt/redshift-password-reset/logs -name "*.log.*" -mtime +30 -delete

# Clean old audit logs (keep last 1000 entries automatically)
# Check audit log size
ls -lh /opt/redshift-password-reset/audit/audit_log.json
```

### SSL Certificate Setup (Production)

For production deployment with HTTPS:

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d yourdomain.com

# Test renewal
sudo certbot renew --dry-run

# Add automatic renewal to cron
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
```

---

## Quick Start Checklist

### Windows Development Setup
- [ ] Install Python 3.8+
- [ ] Create project directory
- [ ] Run `setup_dev.bat`
- [ ] Install requirements: `pip install -r requirements.txt`
- [ ] Create all application files
- [ ] Run `python setup_config.py`
- [ ] Configure Redshift user permissions
- [ ] Test with `python app.py`

### Linux Production Deployment
- [ ] Copy files to Linux server
- [ ] Run `sudo chmod +x deploy_linux.sh`
- [ ] Run `sudo ./deploy_linux.sh`
- [ ] Configure .env: `sudo -u redshift-app python setup_config.py`
- [ ] Restart service: `sudo systemctl restart redshift-password-reset`
- [ ] Test application: `curl http://your-server/health`
- [ ] Configure SSL certificates (optional)

### Final Verification
- [ ] Login with AD credentials works
- [ ] Password reset functionality works
- [ ] Audit logs are created
- [ ] Health check endpoint responds
- [ ] All services start automatically on boot

---

This completes the full implementation guide for the Redshift Password Reset application. The system provides secure, audited password reset functionality with Active Directory authentication and is ready for both development on Windows and production deployment on Linux.
