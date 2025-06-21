#!/bin/bash
# =============================================
# NIKU TUNNEL INSTALLER - VERSI WGET
# Semua file langsung diunduh dari GitHub
# =============================================

REPO="https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu"

echo "🔧 Memulai instalasi dependensi..."
apt update -y && apt upgrade -y
apt install curl socat xz-utils wget unzip iptables iptables-persistent cron netcat -y

echo "📥 Mengunduh file menu..."
wget -q -O /usr/bin/menussh.sh $REPO/menussh.sh
wget -q -O /usr/bin/menuvmess.sh $REPO/menuvmess.sh
wget -q -O /usr/bin/menuvless.sh $REPO/menuvless.sh
wget -q -O /usr/bin/menutrojan.sh $REPO/menutrojan.sh
wget -q -O /usr/bin/add-domain.sh $REPO/add-domain.sh
wget -q -O /usr/bin/menu $REPO/menu.sh

echo "🔐 Memberikan izin eksekusi..."
chmod +x /usr/bin/menussh.sh
chmod +x /usr/bin/menuvmess.sh
chmod +x /usr/bin/menuvless.sh
chmod +x /usr/bin/menutrojan.sh
chmod +x /usr/bin/add-domain.sh
chmod +x /usr/bin/menu

# Symlink
ln -sf /usr/bin/menu /bin/menu

# Input domain
echo -e "\n🌐 Masukkan domain yang sudah dipointing ke VPS:"
read -p "Domain: " domain
if [[ -z $domain ]]; then
  echo "❌ Domain tidak boleh kosong."
  exit 1
fi
echo "$domain" > /etc/xray/domain

# Cek pointing
MYIP=$(curl -s ipv4.icanhazip.com)
LOOKUP=$(ping -c1 $domain | head -1 | grep -oP '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

if [[ "$MYIP" != "$LOOKUP" ]]; then
  echo "❌ Domain belum mengarah ke VPS ini."
  echo "🔁 IP domain: $LOOKUP, VPS IP: $MYIP"
  exit 1
fi

# Stop port 80 services
echo "⛔ Menghentikan service pada port 80..."
systemctl stop nginx >/dev/null 2>&1
systemctl stop xray >/dev/null 2>&1
systemctl stop apache2 >/dev/null 2>&1

# Hapus cert lama
rm -rf ~/.acme.sh/${domain}_ecc

# Install acme.sh
echo "⚙️  Install acme.sh..."
curl https://acme-install.netlify.app/acme.sh -o acme.sh
bash acme.sh --install
rm -f acme.sh

# Generate SSL
echo "🚀 Issuing SSL untuk $domain..."
~/.acme.sh/acme.sh --register-account -m admin@$domain
~/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256 --force

# Validasi
if [[ ! -f ~/.acme.sh/${domain}_ecc/fullchain.cer ]]; then
  echo "❌ Gagal generate SSL cert."
  exit 1
fi

# Pasang cert
~/.acme.sh/acme.sh --install-cert -d $domain --ec \
--fullchain-file /etc/xray/xray.crt \
--key-file /etc/xray/xray.key

# Restart xray
systemctl restart xray

# Info
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
