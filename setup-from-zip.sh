#!/bin/bash
# Auto Download Repo ZIP + Unzip + Jalankan Installer

REPO_URL="https://github.com/NIKU1323/nikucloud-autoinstall"
ZIP_URL="${REPO_URL}/archive/refs/heads/main.zip"
ZIP_NAME="nikucloud-autoinstall.zip"
DIR_NAME="nikucloud-autoinstall-main"

echo "📥 Mendownload repo ZIP dari: $ZIP_URL"
wget -O "$ZIP_NAME" "$ZIP_URL" || { echo "❌ Gagal download ZIP. Cek koneksi atau URL!"; exit 1; }

echo "📂 Mengekstrak ZIP..."
unzip -o "$ZIP_NAME" || { echo "❌ Gagal extract ZIP."; exit 1; }

cd "$DIR_NAME" || { echo "❌ Folder hasil extract tidak ditemukan."; exit 1; }

echo "🚀 Menjalankan auto-install-all.sh..."
chmod +x auto-install-all.sh
./auto-install-all.sh

echo "✅ Proses selesai!"

