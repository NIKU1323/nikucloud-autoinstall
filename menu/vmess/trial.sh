#!/bin/bash
# TRIAL VMESS ACCOUNT - NIKU CLOUD

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NC='\e[0m'

clear
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}           TRIAL AKUN VMESS           ${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

user="trialvmess$(tr -dc A-Za-z0-9 </dev/urandom | head -c4)"
uuid=$(cat /proc/sys/kernel/random/uuid)
masaaktif=1
exp=$(date -d "+$masaaktif days" +"%Y-%m-%d")
domain=$(cat /etc/niku/domain)

link_tls="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$domain\",\"port\":\"443\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"$domain\",\"path\":\"/Multi-Path\",\"tls\":\"tls\"}" | base64 -w 0)"
link_nontls="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$domain\",\"port\":\"80\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"$domain\",\"path\":\"/Multi-Path\",\"tls\":\"none\"}" | base64 -w 0)"
link_grpc="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$domain\",\"port\":\"443\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"grpc\",\"type\":\"none\",\"host\":\"$domain\",\"path\":\"gun\",\"tls\":\"tls\"}" | base64 -w 0)"

# Tambahkan ke config.json
sed -i "/#vmess$/,/#clients$/ s/#clients$/          {\n            \"id\": \"$uuid\",\n            \"alterId\": 0,\n            \"email\": \"$user\"\n          },\n          #clients/" /etc/xray/config.json

echo -e "### $user $exp" >> /etc/xray/vmess-clients.txt
systemctl restart xray

clear
echo -e "${GREEN}━━━━━━━━━━━━━━━━━◇${NC}"
echo -e " Trial VMESS Account"
echo -e "${GREEN}◇━━━━━━━━━━━━━━━━━◇${NC}"
echo -e "Remarks          : $user"
echo -e "Domain           : $domain"
echo -e "User Quota       : Unlimited"
echo -e "User Ip          : Unlimited"
echo -e "Port TLS         : 400-900"
echo -e "Port none TLS    : 80, 8080, 8081-9999"
echo -e "id               : $uuid"
echo -e "alterId          : 0"
echo -e "Security         : auto"
echo -e "Network          : ws"
echo -e "Path             : /Multi-Path"
echo -e "Dynamic          : https://bugmu.com/path"
echo -e "ServiceName      : vmess-grpc"
echo -e "${GREEN}◇━━━━━━━━━━━━━━━━━◇${NC}"
echo -e "Link TLS         : ${YELLOW}$link_tls${NC}"
echo -e "${GREEN}◇━━━━━━━━━━━━━━━━━◇${NC}"
echo -e "Link none TLS    : ${YELLOW}$link_nontls${NC}"
echo -e "${GREEN}◇━━━━━━━━━━━━━━━━━◇${NC}"
echo -e "Link GRPC        : ${YELLOW}$link_grpc${NC}"
echo -e "${GREEN}◇━━━━━━━━━━━━━━━━━◇${NC}"
echo -e "Format OpenClash : ${YELLOW}Isi manual sesuai link${NC}"
echo -e "${GREEN}◇━━━━━━━━━━━━━━━━━◇${NC}"
echo -e "Aktif Selama     : $masaaktif Hari"
echo -e "Dibuat Pada      : $(date +%Y-%m-%d)"
echo -e "Berakhir Pada    : $exp"
echo -e "${GREEN}◇━━━━━━━━━━━━━━━━━◇${NC}"
echo -ne "Tekan enter untuk kembali..."
read
bash /root/menu/menu-vmess.sh
