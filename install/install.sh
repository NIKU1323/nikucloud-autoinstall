#!/bin/bash
# =============================================
#         INSTALLER FINAL - NIKU TUNNEL
#     Termasuk menu, domain, SSL otomatis
# =============================================

clear
echo "🔧 Memulai instalasi dependensi..."
apt update -y && apt upgrade -y
apt install curl socat xz-utils wget unzip iptables iptables-persistent cron netcat -y

# Salin semua file menu
mkdir -p /usr/bin
cp menussh.sh /usr/bin/
cp menuvmess.sh /usr/bin/
cp menuvless.sh /usr/bin/
cp menutrojan.sh /usr/bin/
cp add-domain.sh /usr/bin/
cp menu.sh /usr/bin/

chmod +x /usr/bin/menu*
chmod +x /usr/bin/add-domain.sh
ln -sf /usr/bin/menu /bin/menu

# === DOMAIN & SSL ===
echo "🌐 Mengatur domain dan SSL..."
read -p "Masukkan domain yang sudah dipointing ke VPS: " domain
if [[ -z $domain ]]; then
  echo "❌ Domain tidak boleh kosong."
  exit 1
fi

# Simpan domain
echo "$domain" > /etc/xray/domain

# Pastikan port 80 tidak digunakan
if lsof -i:80 | grep LISTEN; then
  echo "❌ Port 80 sedang digunakan. Hentikan service yang memakainya dulu."
  exit 1
fi

# Install acme.sh untuk SSL
curl https://acme-install.netlify.app/acme.sh -o acme.sh
bash acme.sh --install
rm -f acme.sh

~/.acme.sh/acme.sh --register-account -m admin@$domain
~/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256 --force
if [[ ! -f ~/.acme.sh/${domain}_ecc/fullchain.cer ]]; then
    echo "❌ Gagal mendapatkan sertifikat SSL dari Let's Encrypt."
    exit 1
fi

~/.acme.sh/acme.sh --install-cert -d $domain --ec \
--fullchain-file /etc/xray/xray.crt \
--key-file /etc/xray/xray.key

# Restart xray jika ada
systemctl restart xray >/dev/null 2>&1

# Selesai
clear
echo "=========================================="
echo "✅ INSTALASI NIKU TUNNEL SELESAI ✅"
echo "Domain       : $domain"
echo "SSL Cert     : /etc/xray/xray.crt"
echo "SSL Key      : /etc/xray/xray.key"
echo "Jalankan menu: menu"
echo "=========================================="
