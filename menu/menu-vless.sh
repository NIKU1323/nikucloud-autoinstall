#!/bin/bash
# ================================
#      MENU VLESS - NIKU TUNNEL
# ================================
clear
echo "======================================"
echo "        MENU VLESS - MERCURYVPN       "
echo "======================================"
echo "1. Tambah Akun VLESS"
echo "2. Lihat Akun VLESS"
echo "3. Hapus Akun VLESS"
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
    "email": "$user"
  }
EOF

  systemctl restart xray

  vlesslink="vless://${uuid}@${domain}:443?encryption=none&security=tls&type=ws&host=${domain}&path=/vless#${user}"

  echo "Akun VLESS TLS berhasil dibuat!"
  echo "Expired : $exp"
  echo "Link    : $vlesslink"
  ;;
2)
  echo "Daftar akun VLESS:"
  grep email /etc/xray/config.json | grep -oE '[a-zA-Z0-9_.@-]+'
  ;;
3)
  read -p "Username yang akan dihapus: " user
  sed -i "/\"email\": \"$user\"/d" /etc/xray/config.json
  systemctl restart xray
  echo "Akun $user dihapus dari VLESS."
  ;;
4)
  menu
  ;;
*)
  echo "Pilihan tidak valid!"
  ;;
esac
