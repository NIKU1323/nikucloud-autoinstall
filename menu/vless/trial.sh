#!/bin/bash
# TRIAL VLESS ACCOUNT - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
CYAN='\e[36m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│              TRIAL VLESS ACCOUNT            │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"

# Generate random user
username="trialvless$(tr -dc a-z0-9 </dev/urandom | head -c4)"
uuid=$(cat /proc/sys/kernel/random/uuid)
exp_date=$(date -d "1 days" +%Y-%m-%d)
domain=$(cat /etc/xray/domain)
tls_port="443"
none_port="80"

# Tambahkan ke config
cat >> /etc/xray/config.json <<EOF
### $username $exp_date
{
  "id": "$uuid",
  "email": "$username"
}
EOF

# Simpan limit
mkdir -p /etc/limit/ip /etc/limit/vless
echo "1" > /etc/limit/ip/$username
echo "$((1 * 1024 * 1024 * 1024))" > /etc/limit/vless/$username

# Restart Xray
systemctl restart xray

# Buat VLESS Link
vless_tls="vless://$uuid@$domain:$tls_port?encryption=none&security=tls&type=ws&host=$domain&path=/vless#$username"
vless_none="vless://$uuid@$domain:$none_port?encryption=none&security=none&type=ws&host=$domain&path=/vless#$username"

# OUTPUT
clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "     ${GREEN}NIKU TUNNEL / MERCURYVPN - TRIAL VLESS${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Username     : ${YELLOW}$username${NC}"
echo -e "${GREEN}Expired      : ${YELLOW}1 Hari ($exp_date)${NC}"
echo -e "${GREEN}Domain       : ${YELLOW}$domain${NC}"
echo -e "${GREEN}UUID         : ${YELLOW}$uuid${NC}"
echo -e "${GREEN}Limit IP     : ${YELLOW}1${NC}"
echo -e "${GREEN}Limit Kuota  : ${YELLOW}1 GB${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}VLESS TLS    : ${NC}$vless_tls"
echo -e "${GREEN}VLESS NON-TLS: ${NC}$vless_none"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
