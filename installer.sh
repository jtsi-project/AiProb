#!/bin/bash
# --- AiProb Initiator/Installer (installer.sh) ---
# FUNGSI: Mengunduh skrip instalasi core (init.sh) terbaru dan menjalankan secara otomatis.
# Repositori Core: jtsi-project/AiProb-Core

set -e

# URL untuk mengunduh init.sh dari Repo CORE LOGIC
GITHUB_CORE_LOGIC_RAW_URL="https://raw.githubusercontent.com/jtsi-project/AiProb-Core/main/init.sh"
CORE_SCRIPT_NAME="init.sh"

echo "================================================="
echo "== AiProb v7.2 Initiator (ENTRY POINT) =="
echo "================================================="
echo "Memastikan Anda menjalankan skrip instalasi core terbaru."

if [ -f "$CORE_SCRIPT_NAME" ]; then
    echo "🚨 Peringatan: File '$CORE_SCRIPT_NAME' lama terdeteksi."
    read -p "  -> Hapus yang lama dan unduh core instalasi terbaru? [Y/n] " PERSETUJUAN
    if [ "$PERSETUJUAN" != "y" ] && [ "$PERSETUJUAN" != "Y" ] && [ "$PERSETUJUAN" != "" ]; then
        echo "Initiator dibatalkan. Mohon jalankan ./$CORE_SCRIPT_NAME jika sudah ada."
        exit 0
    fi
    rm -f "$CORE_SCRIPT_NAME"
fi

echo "[1/2] Mengunduh core instalasi terbaru ('$CORE_SCRIPT_NAME') dari GitHub (AiProb-Core)..."
if command -v curl &> /dev/null; then
    curl -sSL -o "$CORE_SCRIPT_NAME" "$GITHUB_CORE_LOGIC_RAW_URL"
elif command -v wget &> /dev/null; then
    wget -q -O "$CORE_SCRIPT_NAME" "$GITHUB_CORE_LOGIC_RAW_URL"
else
    echo "ERROR: curl atau wget tidak ditemukan. Tidak dapat mengunduh '$CORE_SCRIPT_NAME'."
    exit 1
fi

if [ ! -f "$CORE_SCRIPT_NAME" ]; then
    echo "ERROR: Pengunduhan gagal. Cek koneksi atau URL GitHub: $GITHUB_CORE_LOGIC_RAW_URL"
    exit 1
fi

chmod +x "$CORE_SCRIPT_NAME"
echo "✅ Pengunduhan core instalasi berhasil."

echo "[2/2] Mengalihkan ke Core Installer secara Otomatis..."
echo "-------------------------------------------------"

# *** AUTOMATED CHAINING ***
exec "./$CORE_SCRIPT_NAME"

echo "ERROR: Gagal memulai Core Installer. Mohon jalankan secara manual: ./$CORE_SCRIPT_NAME"
echo "-------------------------------------------------"
