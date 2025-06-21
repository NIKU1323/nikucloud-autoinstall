#!/bin/bash
clear
echo "========== VMESS MENU =========="
echo "1. Buat Akun VMESS Manual"
echo "0. Kembali"
echo "================================"
read -p "Pilih opsi: " opt
case $opt in
1) bash /etc/xray/add-vmess.sh ;;
0) menu ;;
*) echo "Opsi tidak valid!" && sleep 1 && menuvmess ;;
esac
