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
cp menu.sh /usr/bin/menu  # <- Ganti nama agar bisa dipanggil sebagai 'menu'

# Berikan izin eksekusi
chmod +x /usr/bin/menussh.sh
chmod +x /usr/bin/menuvmess.sh
chmod +x /usr/bin/menuvless.sh
chmod +x /usr/bin/menutrojan.sh
chmod +x /usr/bin/add-domain.sh
chmod +x /usr/bin/menu

# === DOMAIN INPUT ===
echo -e "\n🌐 Masukkan domain yang sudah dipointing ke VPS:"
read -p "Domain: " domain
if [[ -z $domain ]]; then
  echo "❌ Domain tidak boleh kosong."
  exit 1
fi

echo "$domain" > /etc/xray/domain

# === CEK DOMAIN DAN PASANG SSL ===
echo -e "\n🔍 Mengecek pointing domain ke VPS..."
MYIP=$(curl -s ipv4.icanhazip.com)
LOOKUP=$(ping -c1 $domain | head -1 | grep -oP '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

if [[ "$MYIP" != "$LOOKUP" ]]; then
  echo "❌ Domain $domain belum mengarah ke VPS ini."
  echo "🔁 IP domain: $LOOKUP, VPS IP: $MYIP"
  echo "Silakan update DNS domain di Cloudflare ke IP VPS kamu."
  exit 1
fi

# Matikan semua service yang mungkin ganggu port 80
echo "⛔ Menghentikan service pada port 80 (nginx/xray/apache2)..."
systemctl stop nginx >/dev/null 2>&1
systemctl stop xray >/dev/null 2>&1
systemctl stop apache2 >/dev/null 2>&1

# Hapus folder cert lama (kalau ada)
rm -rf ~/.acme.sh/${domain}_ecc

# Install acme.sh
echo "⚙️  Install acme.sh untuk SSL Let's Encrypt..."
curl https://acme-install.netlify.app/acme.sh -o acme.sh
bash acme.sh --install
rm -f acme.sh

# Daftar dan issue cert baru
echo "🚀 Proses issuing SSL untuk $domain (harap tunggu ±20 detik)..."
~/.acme.sh/acme.sh --register-account -m admin@$domain
~/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256 --force

# Verifikasi file berhasil dibuat
if [[ ! -f ~/.acme.sh/${domain}_ecc/fullchain.cer ]]; then
  echo "❌ Gagal generate SSL cert. Mungkin domain belum aktif atau port 80 diblok."
  echo "Silakan cek pointing domain dan pastikan port 80 terbuka."
  exit 1
fi

# Pasang cert ke folder Xray
~/.acme.sh/acme.sh --install-cert -d $domain --ec \
--fullchain-file /etc/xray/xray.crt \
--key-file /etc/xray/xray.key

# Start ulang Xray
echo "🔁 Restart Xray untuk aktifkan SSL..."
systemctl restart xray

# ✅ INSTALASI SELESAI
clear
echo "=========================================="
echo "✅ INSTALASI NIKU TUNNEL SELESAI ✅"
echo "Domain       : $domain"
echo "SSL Cert     : /etc/xray/xray.crt"
echo "SSL Key      : /etc/xray/xray.key"
echo "Menu Utama   : ketik menu"
echo "Branding     : MERCURYVPN / NIKU TUNNEL"
echo "=========================================="

# AUTO MASUK MENU
echo -e "\n🔁 Membuka menu utama..."
sleep 1
menu
