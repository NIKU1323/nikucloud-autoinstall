#!/bin/bash
# ================================
#       MENU SSH - NIKU TUNNEL
# ================================
clear
echo "======================================"
echo "        MENU SSH - MERCURYVPN         "
echo "======================================"
echo "1. Tambah Akun SSH (Manual)"
echo "2. Lihat Daftar Akun SSH"
echo "3. Hapus Akun SSH"
echo "4. Kembali ke Menu Utama"
echo "======================================"
read -p "Pilih opsi: " opt

case $opt in
1)
  read -p "Username: " user
  read -p "Password: " pass
  read -p "Masa aktif (hari): " masa
  read -p "Limit IP Login (contoh: 2): " limitip
  read -p "Limit Kuota (GB, contoh: 5): " limitgb

  exp=$(date -d "$masa days" +%Y-%m-%d)
  useradd -e $exp -s /bin/false -M $user
  echo "$user:$pass" | chpasswd

  echo "$limitip" > /etc/ssh/limit/ip/$user
  echo "$limitgb" > /etc/ssh/limit/quota/$user

  echo "Akun SSH berhasil dibuat!"
  echo "Username: $user"
  echo "Password: $pass"
  echo "Expired : $exp"
  echo "Limit IP: $limitip"
  echo "Limit GB: $limitgb"
  ;;
2)
  echo "Daftar User SSH Aktif:"
  grep -vE '^#|^$' /etc/passwd | awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}'
  ;;
3)
  read -p "Masukkan username yang akan dihapus: " hapus
  userdel -f $hapus && echo "Akun $hapus berhasil dihapus."
  rm -f /etc/ssh/limit/ip/$hapus
  rm -f /etc/ssh/limit/quota/$hapus
  ;;
4)
  menu
  ;;
*)
  echo "Pilihan tidak valid!"
  ;;
esac
