#!/bin/bash
clear
echo "========= GANTI DOMAIN ========="
read -p "Masukkan domain baru: " domain
if [[ -z $domain ]]; then
    echo "❌ Domain tidak boleh kosong!"
    exit 1
fi

# Simpan domain
echo "$domain" > /etc/xray/domain
echo "✅ Domain disimpan: $domain"

# Hentikan service yang menggunakan port 80
echo "⛔ Menghentikan service pada port 80..."
systemctl stop nginx >/dev/null 2>&1
systemctl stop apache2 >/dev/null 2>&1
systemctl stop xray >/dev/null 2>&1

# Hapus SSL sebelumnya
rm -rf ~/.acme.sh/${domain}_ecc

# Install acme.sh jika belum
if [[ ! -f ~/.acme.sh/acme.sh ]]; then
    echo "⚙️  Menginstal acme.sh..."
    curl https://acme-install.netlify.app/acme.sh -o acme.sh
    bash acme.sh --install
    rm -f acme.sh
fi

# Register dan issue sertifikat
echo "🚀 Mengenerate SSL untuk $domain..."
~/.acme.sh/acme.sh --register-account -m admin@$domain
~/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256 --force

# Validasi
if [[ ! -f ~/.acme.sh/${domain}_ecc/fullchain.cer ]]; then
    echo "❌ Gagal membuat sertifikat SSL!"
    exit 1
fi

# Install sertifikat
~/.acme.sh/acme.sh --install-cert -d $domain --ec \
--fullchain-file /etc/xray/xray.crt \
--key-file /etc/xray/xray.key

# Restart Xray
systemctl restart xray

echo "✅ SSL berhasil dipasang untuk: $domain"
echo "🔁 Xray berhasil direstart."
read -n 1 -s -r -p "Tekan tombol apapun untuk kembali..."
menu
