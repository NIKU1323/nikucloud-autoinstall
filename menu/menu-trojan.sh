#!/bin/bash
# ================================
#     MENU TROJAN - NIKU TUNNEL
# ================================
clear
echo "======================================"
echo "       MENU TROJAN - MERCURYVPN       "
echo "======================================"
echo "1. Tambah Akun TROJAN"
echo "2. Lihat Akun TROJAN"
echo "3. Hapus Akun TROJAN"
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
    "password": "$uuid",
    "email": "$user"
  }
EOF

  systemctl restart xray

  trojanlink="trojan://${uuid}@${domain}:443?type=ws&security=tls&path=/trojan&host=${domain}#${user}"

  echo "Akun TROJAN TLS berhasil dibuat!"
  echo "Expired : $exp"
  echo "Link    : $trojanlink"
  ;;
2)
  echo "Daftar akun TROJAN:"
  grep email /etc/xray/config.json | grep -oE '[a-zA-Z0-9_.@-]+'
  ;;
3)
  read -p "Username yang akan dihapus: " user
  sed -i "/\"email\": \"$user\"/d" /etc/xray/config.json
  systemctl restart xray
  echo "Akun $user dihapus dari TROJAN."
  ;;
4)
  menu
  ;;
*)
  echo "Pilihan tidak valid!"
  ;;
esac
