#!/bin/bash
clear
echo "🛠️ AUTO INSTALLER NIKUCLOUD VPN PANEL"
echo "===================================="

# 1. Pastikan zip tersedia
if [[ ! -f nikucloud-menu.zip ]]; then
    echo "📥 Downloading nikucloud-menu.zip..."
    wget -q --show-progress https://raw.githubusercontent.com/NIKU1323/nikucloud-menu/main/nikucloud-menu.zip || {
        echo "❌ Gagal download ZIP. Pastikan URL benar."
        exit 1
    }
fi

# 2. Ekstrak ZIP
echo "📂 Menyiapkan folder..."
rm -rf nikucloud-menu
unzip -o nikucloud-menu.zip >/dev/null
cd nikucloud-menu || exit

# 3. Buat semua script executable
echo "🔐 Menyiapkan izin eksekusi..."
chmod +x install/*.sh bot/*.sh tools/*.sh menu/*.sh

# 4. Install dependensi dasar
echo "📦 Menginstall dependensi (screen, python3, pip)..."
apt update -y
apt install screen unzip python3 python3-pip -y
pip3 install telepot psutil

# 5. Jalankan script utama (step by step)
echo "🚀 Menjalankan install SSH VPN..."
bash install/install-sshvpn-full.sh

echo "🔒 Menjalankan install SSL domain..."
bash install/install-ssl.sh

echo "🤖 Menjalankan auto install Bot Panel Telegram..."
bash bot/auto-install-bot-panel.sh

echo ""
echo "✅ SEMUA PROSES INSTALASI SELESAI!"
echo "📌 Menu utama: ketik menu"
echo "📲 Bot telegram sudah aktif via screen: ketik screen -r panel"
