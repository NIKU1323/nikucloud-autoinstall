#!/bin/bash
# CREATE VLESS ACCOUNT - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
CYAN='\e[36m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│             CREATE VLESS ACCOUNT            │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"

read -p "Username           : " username
read -p "Masa aktif (hari)  : " days
read -p "Limit IP           : " ip_limit
read -p "Limit Kuota (GB)   : " quota_limit

[[ -z "$username" || -z "$days" ]] && echo -e "${RED}Input tidak lengkap.${NC}" && exit 1

uuid=$(cat /proc/sys/kernel/random/uuid)
exp_date=$(date -d "$days days" +%Y-%m-%d)
domain=$(cat /etc/xray/domain)
tls_port="443"
none_port="80"

# Tambahkan user ke config
cat >> /etc/xray/config.json <<EOF
### $username $exp_date
{
  "id": "$uuid",
  "email": "$username"
}
EOF

# Simpan limit
mkdir -p /etc/limit/ip /etc/limit/vless
echo "$ip_limit" > /etc/limit/ip/$username
echo "$((quota_limit * 1024 * 1024 * 1024))" > /etc/limit/vless/$username

# Restart Xray
systemctl restart xray

# Buat VLESS Link TLS
vless_tls="vless://$uuid@$domain:$tls_port?encryption=none&security=tls&type=ws&host=$domain&path=/vless#$username"
vless_none="vless://$uuid@$domain:$none_port?encryption=none&security=none&type=ws&host=$domain&path=/vless#$username"

# Output
clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "     ${GREEN}NIKU TUNNEL / MERCURYVPN - VLESS ACCOUNT${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Username     : ${YELLOW}$username${NC}"
echo -e "${GREEN}Expired      : ${YELLOW}$exp_date${NC}"
echo -e "${GREEN}Domain       : ${YELLOW}$domain${NC}"
echo -e "${GREEN}UUID         : ${YELLOW}$uuid${NC}"
echo -e "${GREEN}Limit IP     : ${YELLOW}$ip_limit${NC}"
echo -e "${GREEN}Limit Kuota  : ${YELLOW}$quota_limit GB${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}VLESS TLS    : ${NC}$vless_tls"
echo -e "${GREEN}VLESS NON-TLS: ${NC}$vless_none"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
