#!/bin/bash
# ===========================================
#       GANTI DOMAIN + PASANG SSL OTOMATIS
# ===========================================

read -p "Masukkan domain baru: " domain
if [[ -z $domain ]]; then
  echo "❌ Domain tidak boleh kosong."
  exit 1
fi

# Simpan domain
echo "$domain" > /etc/xray/domain

# Install dependensi SSL
apt install socat cron curl netcat -y > /dev/null 2>&1

# Cek port 80
if lsof -i:80 | grep LISTEN; then
  echo "❌ Port 80 sedang digunakan. Hentikan service lain dulu."
  exit 1
fi

# Install acme.sh
curl https://acme-install.netlify.app/acme.sh -o acme.sh
bash acme.sh --install
rm -f acme.sh

# Registrasi akun dan pasang sertifikat
~/.acme.sh/acme.sh --register-account -m admin@$domain > /dev/null 2>&1
~/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256 --force > /dev/null 2>&1

~/.acme.sh/acme.sh --install-cert -d $domain --ec \
--fullchain-file /etc/xray/xray.crt \
--key-file /etc/xray/xray.key > /dev/null 2>&1

# Restart xray
systemctl restart xray

clear
echo "=========================================="
echo "✅ DOMAIN DAN SSL BERHASIL DIPERBARUI"
echo "Domain Baru  : $domain"
echo "SSL Cert     : /etc/xray/xray.crt"
echo "SSL Key      : /etc/xray/xray.key"
echo "Xray Restart: OK"
echo "=========================================="
