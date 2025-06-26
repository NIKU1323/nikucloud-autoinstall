#!/bin/bash
# CREATE VMESS ACCOUNT - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│             CREATE VMESS ACCOUNT            │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"

# INPUT
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

# Buat file JSON VMESS config
cat >> /etc/xray/config.json <<EOF
### $username $exp_date
{
  "id": "$uuid",
  "alterId": 0,
  "email": "$username"
}
EOF

# Simpan limit
mkdir -p /etc/limit/ip /etc/limit/vmess
echo "$ip_limit" > /etc/limit/ip/$username
echo "$((quota_limit * 1024 * 1024 * 1024))" > /etc/limit/vmess/$username

# Restart xray
systemctl restart xray

# Buat VMESS Link
vmess_json=$(cat <<EOF
{
  "v": "2",
  "ps": "$username",
  "add": "$domain",
  "port": "$tls_port",
  "id": "$uuid",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "$domain",
  "path": "/vmess",
  "tls": "tls"
}
EOF
)
link_tls="vmess://$(echo $vmess_json | base64 -w0)"

vmess_json_nontls=$(cat <<EOF
{
  "v": "2",
  "ps": "$username",
  "add": "$domain",
  "port": "$none_port",
  "id": "$uuid",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "$domain",
  "path": "/vmess",
  "tls": "none"
}
EOF
)
link_nontls="vmess://$(echo $vmess_json_nontls | base64 -w0)"

# OUTPUT
clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "      ${GREEN}NIKU TUNNEL / MERCURYVPN - VMESS ACCOUNT${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Username       : ${YELLOW}$username${NC}"
echo -e "${GREEN}Expired        : ${YELLOW}$exp_date${NC}"
echo -e "${GREEN}Domain         : ${YELLOW}$domain${NC}"
echo -e "${GREEN}UUID           : ${YELLOW}$uuid${NC}"
echo -e "${GREEN}Limit IP       : ${YELLOW}$ip_limit${NC}"
echo -e "${GREEN}Limit Kuota    : ${YELLOW}$quota_limit GB${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}VMESS TLS      : ${NC}$link_tls"
echo -e "${GREEN}VMESS None TLS : ${NC}$link_nontls"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
