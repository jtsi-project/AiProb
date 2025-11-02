#!/bin/bash
# --- AiProb Initiator/Installer (installer.sh) ---
# FUNGSI: Mengunduh skrip instalasi core (init.sh) terbaru dan menjalankan secara otomatis.
# Pengembang: Anjas Amar Pradana / JTSI

set -e

# URL untuk mengunduh init.sh dari Repo Init (CORE LOGIC)
GITHUB_INIT_CORE_RAW_URL="https://raw.githubusercontent.com/jtsi-project/AiProb-Init/main/init.sh"
INIT_CORE_SCRIPT="init.sh"

echo "================================================="
echo "== AiProb v7.2 Initiator (ENTRY POINT) =="
echo "================================================="
echo "Memastikan Anda menjalankan skrip instalasi core terbaru."

if [ -f "$INIT_CORE_SCRIPT" ]; then
    echo "🚨 Peringatan: File '$INIT_CORE_SCRIPT' lama terdeteksi."
    read -p "  -> Hapus yang lama dan unduh core instalasi terbaru? [Y/n] " PERSETUJUAN
    if [ "$PERSETUJUAN" != "y" ] && [ "$PERSETUJUAN" != "Y" ] && [ "$PERSETUJUAN" != "" ]; then
        echo "Initiator dibatalkan. Mohon jalankan ./$INIT_CORE_SCRIPT jika sudah ada."
        exit 0
    fi
    rm -f "$INIT_CORE_SCRIPT"
fi

echo "[1/2] Mengunduh core instalasi terbaru ('$INIT_CORE_SCRIPT') dari GitHub..."
if command -v curl &> /dev/null; then
    curl -sSL -o "$INIT_CORE_SCRIPT" "$GITHUB_INIT_CORE_RAW_URL"
elif command -v wget &> /dev/null; then
    wget -q -O "$INIT_CORE_SCRIPT" "$GITHUB_INIT_CORE_RAW_URL"
else
    echo "ERROR: curl atau wget tidak ditemukan. Tidak dapat mengunduh '$INIT_CORE_SCRIPT'."
    exit 1
fi

if [ ! -f "$INIT_CORE_SCRIPT" ]; then
    echo "ERROR: Pengunduhan gagal. Cek koneksi atau URL GitHub: $GITHUB_INIT_CORE_RAW_URL"
    exit 1
fi

chmod +x "$INIT_CORE_SCRIPT"
echo "✅ Pengunduhan core instalasi berhasil."

echo "[2/2] Mengalihkan ke Core Installer secara Otomatis..."
echo "-------------------------------------------------"

# *** AUTOMATED CHAINING ***
# Menggantikan proses installer.sh dengan init.sh. UX terlihat mulus.
exec "./$INIT_CORE_SCRIPT"

# Jika exec gagal (sangat jarang):
echo "ERROR: Gagal memulai Core Installer. Mohon jalankan secara manual: ./$INIT_CORE_SCRIPT"
echo "-------------------------------------------------"
