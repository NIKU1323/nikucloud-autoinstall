#!/bin/bash
# =============================================
# NIKU TUNNEL INSTALLER FINAL (FIX DOMAIN ERROR)
# By: NIKU TUNNEL / MERCURYVPN
# =============================================

REPO="https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu"

echo "🔧 Memulai instalasi dependensi..."
apt update -y && apt upgrade -y
apt install curl socat xz-utils wget unzip iptables iptables-persistent cron netcat -y

echo "📥 Mengunduh semua file menu..."
mkdir -p /tmp/menu-download
cd /tmp/menu-download

FILES=("menussh.sh" "menuvmess.sh" "menuvless.sh" "menutrojan.sh" "add-domain.sh" "menu.sh")

for file in "${FILES[@]}"; do
  wget -q -O "$file" "$REPO/$file"
  if [[ -f "$file" ]]; then
    cp "$file" "/usr/bin/${file%.sh}"
    chmod +x "/usr/bin/${file%.sh}"
    echo "✅ Menu siap: ${file%.sh}"
  else
    echo "❌ Gagal mengunduh $file"
  fi
done

# Konfigurasi domain
clear
echo "🌐 Masukkan domain yang sudah dipointing ke VPS ini:"
read -p "Domain: " domain

if [[ -z $domain ]]; then
  echo "❌ Domain tidak boleh kosong."
  exit 1
fi

# ✅ FIX: buat folder xray kalau belum ada
mkdir -p /etc/xray
echo "$domain" > /etc/xray/domain

# Validasi pointing
MYIP=$(curl -s ipv4.icanhazip.com)
LOOKUP=$(ping -c1 $domain | head -1 | grep -oP '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

if [[ "$MYIP" != "$LOOKUP" ]]; then
  echo "❌ Domain belum mengarah ke VPS ini."
  echo "🔁 IP domain: $LOOKUP, VPS IP: $MYIP"
  exit 1
fi

# Stop service port 80
echo "⛔ Menghentikan service pada port 80..."
systemctl stop nginx >/dev/null 2>&1
systemctl stop apache2 >/dev/null 2>&1
systemctl stop xray >/dev/null 2>&1

# Install SSL Let's Encrypt (acme.sh)
rm -rf ~/.acme.sh/${domain}_ecc
curl https://acme-install.netlify.app/acme.sh -o acme.sh
bash acme.sh --install
rm -f acme.sh

~/.acme.sh/acme.sh --register-account -m admin@$domain
~/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256 --force

if [[ ! -f ~/.acme.sh/${domain}_ecc/fullchain.cer ]]; then
  echo "❌ Gagal generate SSL certificate."
  exit 1
fi

~/.acme.sh/acme.sh --install-cert -d $domain --ec \
--fullchain-file /etc/xray/xray.crt \
--key-file /etc/xray/xray.key

systemctl restart xray

# Output
clear
echo "=========================================="
echo "✅ INSTALLASI SELESAI"
echo "Domain       : $domain"
echo "SSL Cert     : /etc/xray/xray.crt"
echo "SSL Key      : /etc/xray/xray.key"
echo "Menu         : ketik menu"
echo "Branding     : NIKU TUNNEL / MERCURYVPN"
echo "=========================================="

echo -e "\n🔁 Membuka menu utama..."
sleep 1
menu
