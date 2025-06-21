#!/bin/bash
# ======================================
#             MENU UTAMA               
# ======================================
clear
echo "========================================"
echo "         MENU UTAMA - NIKU TUNNEL       "
echo "========================================"
echo "1. Menu SSH"
echo "2. Menu VMESS"
echo "3. Menu VLESS"
echo "4. Menu TROJAN"
echo "5. Tambah Domain + SSL"
echo "6. Reboot VPS"
echo "0. Keluar"
echo "========================================"
read -p "Pilih opsi: " opt

case $opt in
1)
  if [ -f /usr/bin/menussh.sh ]; then
    bash /usr/bin/menussh.sh
  else
    echo "menussh.sh tidak ditemukan!"
  fi
  ;;
2)
  if [ -f /usr/bin/menuvmess.sh ]; then
    bash /usr/bin/menuvmess.sh
  else
    echo "menuvmess.sh tidak ditemukan!"
  fi
  ;;
3)
  if [ -f /usr/bin/menuvless.sh ]; then
    bash /usr/bin/menuvless.sh
  else
    echo "menuvless.sh tidak ditemukan!"
  fi
  ;;
4)
  if [ -f /usr/bin/menutrojan.sh ]; then
    bash /usr/bin/menutrojan.sh
  else
    echo "menutrojan.sh tidak ditemukan!"
  fi
  ;;
5)
  if [ -f /usr/bin/add-domain.sh ]; then
    bash /usr/bin/add-domain.sh
  else
    echo "add-domain.sh tidak ditemukan!"
  fi
  ;;
6)
  reboot
  ;;
0)
  exit 0
  ;;
*)
  echo "Pilihan tidak valid!"
  ;;
esac
