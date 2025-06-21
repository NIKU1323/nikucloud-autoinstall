#!/bin/bash
clear
echo "=========== SSH MENU ==========="
echo "1. Buat Akun SSH Manual"
echo "0. Kembali"
echo "================================"
read -p "Pilih opsi: " opt
case $opt in
1) bash /etc/ssh/add-ssh.sh ;;
0) menu ;;
*) echo "Opsi tidak valid!" && sleep 1 && menussh ;;
esac
