#!/bin/bash
# ================================
#       MENU VMESS - NIKU TUNNEL
# ================================
clear
echo "======================================"
echo "       MENU VMESS - MERCURYVPN        "
echo "======================================"
echo "1. Tambah Akun VMESS"
echo "2. Lihat Akun VMESS"
echo "3. Hapus Akun VMESS"
echo "4. Kembali ke Menu Utama"
echo "======================================"
read -p "Pilih opsi: " opt

domain=$(cat /etc/xray/domain)

case $opt in
1)
  read -p "Username: " user
  read -p "Masa aktif (hari): " masa
  uuid=$(cat /proc/sys/kernel/random/uuid)
  exp=$(date -d "$masa days" +"%Y-%m-%d")

  cat >> /etc/xray/config.json <<EOF
  ,
  {
    "id": "$uuid",
    "alterId": 0,
    "email": "$user"
  }
EOF

  systemctl restart xray

  vmesslink=$(cat <<EOF
{
  "v": "2",
  "ps": "$user",
  "add": "$domain",
  "port": "443",
  "id": "$uuid",
  "aid": "0",
  "net": "ws",
  "path": "/vmess",
  "type": "none",
  "host": "$domain",
  "tls": "tls"
}
EOF
  )

  link="vmess://$(echo "$vmesslink" | base64 -w0)"
  echo "Akun VMESS TLS berhasil dibuat!"
  echo "Expired : $exp"
  echo "Link    : $link"
  ;;
2)
  echo "Daftar akun VMESS:"
  grep email /etc/xray/config.json | cut -d '"' -f4
  ;;
3)
  read -p "Username yang akan dihapus: " user
  sed -i "/\"email\": \"$user\"/d" /etc/xray/config.json
  systemctl restart xray
  echo "Akun $user dihapus dari VMESS."
  ;;
4)
  menu
  ;;
*)
  echo "Pilihan tidak valid!"
  ;;
esac
