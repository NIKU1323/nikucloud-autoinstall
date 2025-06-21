#!/bin/bash
clear
echo "======================================="
echo "          NIKU TUNNEL MENU"
echo "======================================="
echo "1. SSH Menu"
echo "2. VMESS Menu"
echo "3. VLESS Menu"
echo "4. TROJAN Menu"
echo "5. Add/Change Domain"
echo "0. Keluar"
echo "======================================="
read -p "Pilih opsi: " opt
case $opt in
1) menussh ;;
2) menuvmess ;;
3) menuvless ;;
4) menutrojan ;;
5) add-domain ;;
0) exit ;;
*) echo "Opsi tidak valid!" && sleep 1 && menu ;;
esac
