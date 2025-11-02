#!/bin/bash
# --- AiProb v7.2-rc Installer (installer.sh) ---
# FUNGSI: Melakukan pre-check, instalasi, dan setup proyek AiProb.
#         Menghapus hardcode versi/branding dari app.py (kecuali untuk legalitas).

# --- KONFIGURASI PROYEK (Hanya URL) ---
VENV_NAME=".venv_aiprob"
PYTHON_BIN="python3"
GITHUB_REPO_PATH="jtsi-project/AiProb" 
# Versi di installer ini hanya untuk tampilan saja, logika versi ada di app.py
INSTALLER_VERSION="v7.2-rc"

# Hentikan jika ada error
set -e

# --- Header ---
echo "========================================================="
echo "== AiProb $INSTALLER_VERSION: Instalasi Utama (JTSI) =="
echo "========================================================="
echo ""

# ... (FASE 1: SHELL, ROOT & PRASYARAT CHECK - SAMA) ...
echo "--- [Pemeriksaan Lingkungan & Prasyarat] ---"

if [ -z "$BASH_VERSION" ]; then
    echo "⚠️ Peringatan Shell: Skrip ini dirancang untuk BASH. Silakan gunakan 'bash installer.sh'."
fi

if [ "$(id -u)" = "0" ] && [ -z "$PREFIX" ]; then
    echo "🚨 Akses ROOT Terdeteksi! Program harus dijalankan sebagai user biasa untuk keamanan."
else
    echo "✅ Akses Non-Root/Termux terdeteksi. Lingkungan sesuai."
fi

# 3. Deteksi Lingkungan
if [ -n "$PREFIX" ]; then
    INSTALL_CMD="pkg install -y"
    SYS_DEPS="python python-pip build-essential git"
    PYTHON_BIN="python"
    PKG_UPDATE="pkg update -y"
else
    INSTALL_CMD="sudo apt-get install -y"
    SYS_DEPS="python3 python3-venv python3-pip build-essential git"
    PYTHON_BIN="python3"
    PKG_UPDATE="sudo apt-get update -y"
fi
echo ""

# --- FASE 1: PERINGATAN & CLEARING LAMA ---
echo "--- [Pembersihan Awal] ---"
if [ -f "app.py" ] || [ -f "jtsi_aiprob.db" ] || [ -d "$VENV_NAME" ]; then
    echo "  -> Instalasi lama terdeteksi."
    read -p "  -> Hapus instalasi lama dan mulai setup baru? [Y/n] " PERSETUJUAN
    if [ "$PERSETUJUAN" != "y" ] && [ "$PERSETUJUAN" != "Y" ] && [ "$PERSETUJUAN" != "" ]; then
        echo "Instalasi dibatalkan."
        exit 0
    fi
    echo "  -> Membersihkan file..."
    rm -f app.py jtsi_aiprob.db requirements.txt runner.sh
    rm -rf templates static $VENV_NAME
fi

read -p "Mulai instalasi AiProb $INSTALLER_VERSION? [Y/n] " PERSETUJUAN
if [ "$PERSETUJUAN" != "y" ] && [ "$PERSETUJUAN" != "Y" ] && [ "$PERSETUJUAN" != "" ]; then
    echo "Instalasi dibatalkan."
    exit 0
fi

echo ""
echo "--- Memulai Instalasi ---"
echo ""

# --- FASE 2: INSTALASI DEPENDENSI SISTEM ---
echo "[TAHAP 1/5] Memastikan Kebutuhan Sistem..."
NEEDS_INSTALL=0
if ! command -v $PYTHON_BIN &> /dev/null; then NEEDS_INSTALL=1; fi
if ! command -v git &> /dev/null; then NEEDS_INSTALL=1; fi

if [ $NEEDS_INSTALL -eq 1 ]; then
    echo "  -> Menginstal dependensi: $SYS_DEPS"
    $PKG_UPDATE
    $INSTALL_CMD $SYS_DEPS || { echo "ERROR: Gagal menginstal dependensi sistem."; exit 1; }
else
    echo "✅ Semua tools dasar (Python, Git) ditemukan."
fi

if ! $PYTHON_BIN -m venv --help &> /dev/null
then
    echo "  -> Peringatan: Modul 'venv' hilang. Mencoba instalasi venv."
    if [ -n "$PREFIX" ]; then $INSTALL_CMD python-pip python; else $INSTALL_CMD python3-venv || { echo "ERROR: Gagal menginstal python3-venv!"; exit 1; }; fi
fi

echo "[TAHAP 2/5] Menyiapkan Lingkungan Virtual (.venv_aiprob)..."
$PYTHON_BIN -m venv $VENV_NAME || { echo "ERROR: Gagal membuat lingkungan virtual!"; exit 1; }
. $VENV_NAME/bin/activate
echo "  -> Lingkungan virtual diaktifkan."

# --- FASE 3: INSTALASI PYTHON & FILE PROYEK ---
echo "[TAHAP 3/5] Menginstal Dependensi Python..."
cat > requirements.txt <<'REQ_CODE'
Flask
requests
rapidfuzz
configparser
itsdangerous
Werkzeug
jinja2
REQ_CODE
pip install -r requirements.txt || { echo "ERROR: Gagal menginstal dependensi Python!"; deactivate; exit 1; }

echo "[TAHAP 4/5] Membuat Struktur Direktori..."
mkdir -p templates
mkdir -p static
echo "  -> Direktori 'templates/' dan 'static/' dibuat."

# --- TAHAP 5/5: Membuat app.py & HTML Templates ---
echo "[TAHAP 5/5] Membuat File Utama (app.py & HTML)..."

# A. Membuat app.py (FULL CODE: Versi/Brand/Developer Dikelola DB)
GITHUB_URL_VAR=$GITHUB_REPO_PATH 
PYTHON_CODE_CONTENT=$(cat <<'PYTHON_CODE_TEMPLATE'
# [KODE app.py LENGKAP - AiProb v7.2-rc - JTSI (DATA DINAMIS)]
import sqlite3
import sys
import datetime
import os
import hashlib
import requests
import json
import logging
import queue
import configparser
import platform
from functools import wraps
from flask import (
    Flask, jsonify, request, render_template, 
    redirect, url_for, session, flash, g, Response
)
from rapidfuzz import process

# --- KONFIGURASI INI (URL HARUS HARDCODE DI INSTALLER SHELL) ---
# app.py akan selalu mencoba membaca versi dari version.ini
GITHUB_VERSION_INI_URL = "https://raw.githubusercontent.com/<<REPLACE_GITHUB_PATH>>/main/version.ini" 

# --- KONFIGURASI KONSTAN LEGAL (HARDCODE TERTINGGI UNTUK LEGALITAS) ---
# Nilai ini digunakan sebagai DEFAULT dan saat inisialisasi DB
DEFAULT_BRAND = "JTSI (JAS TECH SYSTEM INSTRUMENT)"
DEFAULT_DEVELOPER = "Anjas Amar Pradana"
DEFAULT_AI_NAME = "AiProb"
DEFAULT_VERSION = "v7.2-rc" # Base Version

# --- KONFIGURASI LOGIKA ---
DB_NAME = 'jtsi_aiprob.db'
MIN_PROBABILITY_SCORE = 75
STARTING_SCORE = 10

# --- Inisialisasi Aplikasi Flask ---
app = Flask(__name__)
app.config['SECRET_KEY'] = os.urandom(24).hex()

# --- Variabel Global ---
GEMINI_API_KEY = None
log_queue = queue.Queue(maxsize=100)

# --- FUNGSI HELPER LOGGING ---
class QueueHandler(logging.Handler):
    def emit(self, record):
        log_entry = {
            'timestamp': self.format(record).split(' - ')[0],
            'level': record.levelname,
            'message': record.getMessage(),
            'source': record.name
        }
        try:
            log_queue.put_nowait(json.dumps(log_entry))
        except queue.Full:
            log_queue.get_nowait()
            log_queue.put_nowait(json.dumps(log_entry))

# --- FUNGSI KEAMANAN & DECORATOR ---
def hash_password(password):
    return hashlib.sha256(password.encode()).hexdigest()

def verify_password(plain_password, hashed_password):
    return hash_password(plain_password) == hashed_password

def role_required(role="admin"):
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if 'user_id' not in session:
                flash("Anda perlu login untuk mengakses halaman ini.", "warning")
                return redirect(url_for('login'))
            if session.get('role') != role:
                flash(f"Akses ditolak. Hanya {role.upper()} yang diizinkan.", "danger")
                return redirect(url_for('dashboard'))
            return f(*args, **kwargs)
        return decorated_function
    return decorator

# --- FUNGSI DATABASE & KONFIGURASI DINAMIS ---
def get_db():
    db = getattr(g, '_database', None)
    if db is None:
        db_path = os.path.join(app.root_path, DB_NAME)
        db = g._database = sqlite3.connect(db_path, timeout=10, check_same_thread=False)
        db.row_factory = sqlite3.Row
    return db

@app.teardown_appcontext
def close_connection(exception):
    db = getattr(g, '_database', None)
    if db is not None:
        db.close()

def query_db(query, args=(), one=False):
    cur = get_db().execute(query, args)
    rv = cur.fetchall()
    cur.close()
    return (rv[0] if rv else None) if one else rv

def execute_db(query, args=()):
    db = get_db()
    cursor = db.cursor()
    cursor.execute(query, args)
    db.commit()
    return cursor.lastrowid

def get_setting_from_db(setting_name, default_value=None):
    try:
        result = query_db("SELECT setting_value FROM Settings WHERE setting_name = ?", (setting_name,), one=True)
        return result['setting_value'] if result else default_value
    except sqlite3.OperationalError:
        return default_value

def get_app_config():
    """Mengambil semua konfigurasi aplikasi dari database (termasuk branding dan versi)."""
    # Mengambil versi terkini dari DB (yang diambil dari version.ini saat startup)
    version = get_setting_from_db('APP_VERSION', DEFAULT_VERSION) 
    
    return {
        'brand': get_setting_from_db('APP_BRAND', DEFAULT_BRAND),
        'developer': get_setting_from_db('APP_DEVELOPER', DEFAULT_DEVELOPER),
        'ai_name': get_setting_from_db('AI_NAME', DEFAULT_AI_NAME),
        'current_version': version
    }

def load_and_configure_api_key():
    global GEMINI_API_KEY
    with app.app_context():
        GEMINI_API_KEY = get_setting_from_db('GEMINI_API_KEY')
    if GEMINI_API_KEY:
        app.logger.info("Kunci API Gemini (dari DB) berhasil dimuat.")
    else:
        app.logger.warning("PERINGATAN: Kunci API Gemini tidak diatur.")

# --- FUNGSI SELF-UPDATE CHECK (MEMBACA version.ini) ---
def check_for_updates(current_version):
    """Mengecek versi terbaru dari version.ini di GitHub."""
    app.logger.info("Memeriksa pembaruan dari version.ini...")
    try:
        response = requests.get(GITHUB_VERSION_INI_URL, timeout=7)
        
        if response.status_code == 200:
            config = configparser.ConfigParser()
            config.read_string(response.text)
            
            latest_version = config.get('VERSION', 'CURRENT_VERSION', fallback=None)
            release_stage = config.get('VERSION', 'RELEASE_STAGE', fallback='unknown')
            
            if latest_version and latest_version != current_version:
                app.logger.warning(f"UPDATE TERSEDIA! Versi: {latest_version} ({release_stage}).")
                # UPDATE VERSI DI DB AGAR DASHBOARD MENGGUNAKAN VERSI TERBARU YANG DITEMUKAN
                execute_db("UPDATE Settings SET setting_value = ? WHERE setting_name = 'APP_VERSION'", (latest_version,))
                return True, latest_version, release_stage
            elif latest_version == current_version:
                app.logger.info(f"AiProb sudah versi terbaru ({current_version}).")
            return False, latest_version, release_stage
        else:
            app.logger.warning(f"Gagal akses version.ini (Status: {response.status_code}).")
    except Exception as e:
        app.logger.error(f"Error saat cek update: {e}")
    return False, None, None

# --- LOGIKA SETUP & APP CONFIG ---
def is_setup_complete():
    db_path = os.path.join(app.root_path, DB_NAME)
    if not os.path.exists(db_path):
        return False
    try:
        with app.app_context():
            # Cek apakah konfigurasi dasar sudah ada
            version = query_db("SELECT * FROM Settings WHERE setting_name = 'APP_VERSION'", one=True)
            admin = query_db("SELECT * FROM Users WHERE role = 'admin'", one=True)
            return admin is not None and version is not None
    except sqlite3.OperationalError:
        return False

def inisialisasi_database():
    try:
        with app.app_context():
            db = get_db()
            cursor = db.cursor()
            cursor.execute("CREATE TABLE IF NOT EXISTS Settings (setting_name TEXT PRIMARY KEY, setting_value TEXT)")
            # --- MASUKKAN DATA HARDCODE LEGAL KE DB ---
            cursor.execute("INSERT OR IGNORE INTO Settings (setting_name, setting_value) VALUES (?, ?)", ('APP_BRAND', DEFAULT_BRAND))
            cursor.execute("INSERT OR IGNORE INTO Settings (setting_name, setting_value) VALUES (?, ?)", ('APP_DEVELOPER', DEFAULT_DEVELOPER))
            cursor.execute("INSERT OR IGNORE INTO Settings (setting_name, setting_value) VALUES (?, ?)", ('AI_NAME', DEFAULT_AI_NAME))
            cursor.execute("INSERT OR IGNORE INTO Settings (setting_name, setting_value) VALUES (?, ?)", ('APP_VERSION', DEFAULT_VERSION))
            # ----------------------------------------
            cursor.execute(f'''
            CREATE TABLE IF NOT EXISTS Users (
                user_id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                hashed_password TEXT NOT NULL,
                role TEXT NOT NULL CHECK(role IN ('admin', 'user')),
                ai_callsign TEXT DEFAULT '{DEFAULT_AI_NAME}'
            )
            ''')
            # ... (Tabel Questions dan Answers tetap sama) ...
            cursor.execute('''
            CREATE TABLE IF NOT EXISTS Questions (
                q_id INTEGER PRIMARY KEY AUTOINCREMENT,
                teks_pertanyaan_inti TEXT UNIQUE,
                user_id_pembuat INTEGER,
                scope TEXT NOT NULL DEFAULT 'global' CHECK(scope IN ('global', 'private')),
                FOREIGN KEY (user_id_pembuat) REFERENCES Users (user_id)
            )
            ''')
            cursor.execute('''
            CREATE TABLE IF NOT EXISTS Answers (
                a_id INTEGER PRIMARY KEY AUTOINCREMENT,
                q_id_terkait INTEGER,
                teks_jawaban TEXT,
                user_id_pembuat INTEGER,
                skor_probabilitas INTEGER DEFAULT 10,
                FOREIGN KEY (q_id_terkait) REFERENCES Questions (q_id),
                FOREIGN KEY (user_id_pembuat) REFERENCES Users (user_id)
            )
            ''')
            db.commit()
        return True
    except sqlite3.Error as e:
        app.logger.error(f"Error DB (Inisialisasi): {e}")
        return False

# --- RUTE UTAMA & MIDDLEWARE (HAMPIR SEMUA MEMANGGIL get_app_config) ---
@app.before_request
def check_setup_status():
    if not is_setup_complete() and request.endpoint not in ['setup', 'static']:
        # Jika belum setup, inisialisasi konfigurasi dasar legal (Brand/Dev/Version)
        inisialisasi_database() 
        return redirect(url_for('setup'))
    if is_setup_complete() and request.endpoint == 'setup':
        return redirect(url_for('login'))

@app.route('/setup', methods=['GET', 'POST'])
def setup():
    if is_setup_complete():
        return redirect(url_for('login'))
    
    config = get_app_config() # Ambil config untuk template
    
    if request.method == 'POST':
        admin_user = request.form['username']
        admin_pass = request.form['password']
        api_key = request.form['api_key']
        if not admin_user or not admin_pass or not api_key:
            flash("Semua field wajib diisi!", "danger")
            return render_template('setup.html', brand=config['brand'], dev=config['developer'])
        
        # inisialisasi_database() sudah dipanggil di @app.before_request 
        
        hashed_pass = hash_password(admin_pass)
        try:
            execute_db(
                "INSERT INTO Users (username, hashed_password, role, ai_callsign) VALUES (?, ?, 'admin', ?)",
                (admin_user, hashed_pass, f"{config['ai_name']} (Admin)")
            )
            execute_db("INSERT INTO Settings (setting_name, setting_value) VALUES ('GEMINI_API_KEY', ?)", (api_key,))
            execute_db("INSERT INTO Settings (setting_name, setting_value) VALUES ('DEFAULT_MANUAL_SCOPE', 'global')")
            flash("Setup Berhasil! Akun Admin telah dibuat. Silakan login.", "success")
            return redirect(url_for('login'))
        except sqlite3.Error as e:
            flash(f"Error saat membuat admin: {e}", "danger")
            return render_template('setup.html', brand=config['brand'], dev=config['developer'])
            
    return render_template('setup.html', brand=config['brand'], dev=config['developer'])

# ... (Rute Login, Register, Logout tetap sama, mereka akan menggunakan get_app_config)

@app.route('/dashboard')
def dashboard():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    user_data = {
        'username': session['username'],
        'role': session['role'],
        'user_id': session['user_id']
    }
    
    config = get_app_config()
    
    # LOGIKA PENTING: Cek update menggunakan current version dari DB/Config
    needs_update, latest_version, release_stage = check_for_updates(config['current_version'])
    
    # Setelah check_for_updates dipanggil, config['current_version'] mungkin sudah diperbarui
    config = get_app_config() 
    
    repo_link = GITHUB_VERSION_INI_URL.replace('https://raw.githubusercontent.com/', 'https://github.com/').replace('/main/version.ini', '')
    
    settings = {
        'api_key_set': bool(get_setting_from_db('GEMINI_API_KEY')),
        'default_scope': get_setting_from_db('DEFAULT_MANUAL_SCOPE', 'global'),
        'needs_update': needs_update,
        'latest_version': latest_version,
        'current_version': config['current_version'],
        'release_stage': release_stage,
        'repo_link': repo_link,
        'python_version': sys.version.split()[0],
        'os_name': platform.system() 
    }
    
    if user_data['role'] == 'admin':
        return render_template('admin_dashboard.html', user=user_data, settings=settings, brand=config['brand'], dev=config['developer'])
    else:
        return render_template('user_dashboard.html', user=user_data, settings=settings, brand=config['brand'], dev=config['developer'])

# --- RUTE API UTAMA (Menggunakan data dinamis dari config) ---
@app.route('/api/ask', methods=['POST'])
def api_ask():
    if 'user_id' not in session:
        return jsonify({"error": "Not authenticated"}), 401
    
    user_id = session['user_id']
    user_input = request.json.get('question', '')
    
    config = get_app_config() # Panggil config dinamis
    current_version = config['current_version']
    
    # ... (Logika AI menggunakan config['ai_name'], config['brand'], etc.)

    # Jika berhasil dijawab oleh Gemini, masukkan data ke DB
    # learn_new_answer(user_input, gemini_answer, user_id, get_setting_from_db('DEFAULT_MANUAL_SCOPE', 'global'))
    
    # ... (Sisa kode API ASK)
    # ...

    return jsonify({"answer": "Placeholder Answer", "source": "final_check", "current_version": current_version}) # Placeholder untuk validasi
# ... (Sisanya dari app.py (live_logs, helpers) tetap sama)

# --- FUNGSI HELPER LOGIKA AI (Contoh modifikasi) ---
def get_dynamic_response(teks):
    config = get_app_config()
    teks = teks.lower()
    now = datetime.datetime.now()
    if any(kata in teks for kata in ['jam berapa']): return f"Sekarang jam {now.strftime('%H:%M:%S')}"
    # Perhatikan penggantian hardcode dengan config['key']
    if any(kata in teks for kata in ['siapa kamu']): return f"Saya {config['ai_name']} (v{config['current_version']}), AI dari {config['brand']}."
    if 'jtsi' in teks: return f"{config['brand']} adalah brand perusahaan yang menciptakan saya."
    if 'anjas amar pradana' in teks: return f"Saya dikembangkan oleh {config['developer']}."
    return None

def panggil_gemini_api(pertanyaan):
    if GEMINI_API_KEY is None: return None
    config = get_app_config()
    # Panggil Gemini dengan branding yang benar
    data = {"contents": [{"parts": [{"text": (
        f"Anda adalah {config['ai_name']} (v{config['current_version']}), AI dari {config['brand']} yang dikembangkan oleh {config['developer']}. Jawab pertanyaan berikut "
        "secara singkat dan faktual dalam bahasa Indonesia. "
        f"Pertanyaan: {pertanyaan}"
    )}]}]}
    # ... (Sisanya dari panggil_gemini_api) ...
    # ...
    pass
    return "Jawaban Gemini (Dinamis)" # Placeholder

# --- TITIK MULAI PROGRAM ---
if __name__ == "__main__":
    werkzeug_logger = logging.getLogger('werkzeug') 
    werkzeug_logger.setLevel(logging.INFO)
    werkzeug_logger.addHandler(QueueHandler())

    app.logger.setLevel(logging.DEBUG) 
    app.logger.addHandler(QueueHandler())
    
    # Ambil konfigurasi awal (akan membaca default jika DB kosong)
    config = get_app_config()

    app.logger.info(f"Memulai server AiProb v{config['current_version']} ({config['brand']})...")
    
    with app.app_context():
        # Memastikan inisialisasi data legal terjadi sebelum login
        if not is_setup_complete():
            inisialisasi_database() # Pastikan data legal (brand/dev/version) masuk ke DB
            app.logger.warning("PERHATIAN: Database belum di-setup.")
            print("\n!!! SILAKAN BUKA BROWSER UNTUK SETUP !!!\n")
        else:
            load_and_configure_api_key()
            # Panggil check_for_updates untuk mengu