#!/bin/bash
# TRIAL VMESS ACCOUNT - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│              TRIAL VMESS ACCOUNT            │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"

# Buat username dan UUID
username="trialvmess$(tr -dc a-z0-9 </dev/urandom | head -c4)"
uuid=$(cat /proc/sys/kernel/random/uuid)
exp_date=$(date -d "1 days" +"%Y-%m-%d")
domain=$(cat /etc/xray/domain)
tls_port="443"
none_port="80"

# Buat config user
cat >> /etc/xray/config.json <<EOF
### $username $exp_date
{
  "id": "$uuid",
  "alterId": 0,
  "email": "$username"
}
EOF

# Default limit trial
mkdir -p /etc/limit/ip /etc/limit/vmess
echo "1" > /etc/limit/ip/$username
echo "$((1 * 1024 * 1024 * 1024))" > /etc/limit/vmess/$username

# Restart xray
systemctl restart xray

# Link TLS
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

# Link None TLS
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
echo -e "     ${GREEN}NIKU TUNNEL / MERCURYVPN - TRIAL VMESS${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Username       : ${YELLOW}$username${NC}"
echo -e "${GREEN}Expired        : ${YELLOW}1 Hari ($exp_date)${NC}"
echo -e "${GREEN}Domain         : ${YELLOW}$domain${NC}"
echo -e "${GREEN}UUID           : ${YELLOW}$uuid${NC}"
echo -e "${GREEN}Limit IP       : ${YELLOW}1${NC}"
echo -e "${GREEN}Limit Kuota    : ${YELLOW}1 GB${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}VMESS TLS      : ${NC}$link_tls"
echo -e "${GREEN}VMESS None TLS : ${NC}$link_nontls"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
