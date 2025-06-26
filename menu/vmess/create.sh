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
created_at=$(date +%Y-%m-%d)
domain=$(cat /etc/xray/domain)
tls_port="443"
none_port="80"
duration="$days"

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

# Buat VMESS GRPC Link
vmess_json_grpc=$(cat <<EOF
{
  "v": "2",
  "ps": "$username-grpc",
  "add": "$domain",
  "port": "$tls_port",
  "id": "$uuid",
  "aid": "0",
  "net": "grpc",
  "type": "none",
  "host": "$domain",
  "path": "vmess-grpc",
  "tls": "tls"
}
EOF
)
link_grpc="vmess://$(echo $vmess_json_grpc | base64 -w0)"

# Buat OpenClash Format
link_clash=$(echo $vmess_json | base64 -w0)

# OUTPUT
clear
echo -e "━━━━━━━━━━━━━━━━━◇"
echo -e " Xray/Vmess Account"
echo -e "◇━━━━━━━━━━━━━━━━━◇"
echo -e "Remarks          : ${YELLOW}$username${NC}"
echo -e "Domain           : ${YELLOW}$domain${NC}"
echo -e "User Quota       : ${YELLOW}$quota_limit GB${NC}"
echo -e "User Ip          : ${YELLOW}$ip_limit${NC}"
echo -e "Port TLS         : ${YELLOW}$tls_port${NC}"
echo -e "Port none TLS    : ${YELLOW}$none_port${NC}"
echo -e "id               : ${YELLOW}$uuid${NC}"
echo -e "alterId          : ${YELLOW}0${NC}"
echo -e "Security         : ${YELLOW}auto${NC}"
echo -e "Network          : ${YELLOW}ws${NC}"
echo -e "Path             : ${YELLOW}/vmess${NC}"
echo -e "Dynamic          : ${YELLOW}false${NC}"
echo -e "ServiceName      : ${YELLOW}-${NC}"
echo -e "◇━━━━━━━━━━━━━━━━━◇"
echo -e "Link TLS         : ${NC}$link_tls"
echo -e "◇━━━━━━━━━━━━━━━━━◇"
echo -e "Link none TLS    : ${NC}$link_nontls"
echo -e "◇━━━━━━━━━━━━━━━━━◇"
echo -e "Link GRPC        : ${NC}$link_grpc"
echo -e "◇━━━━━━━━━━━━━━━━━◇"
echo -e "Format OpenClash : ${NC}$link_clash"
echo -e "◇━━━━━━━━━━━━━━━━━◇"
echo -e "Aktif Selama     : ${YELLOW}$duration days${NC}"
echo -e "Dibuat Pada      : ${YELLOW}$created_at${NC}"
echo -e "Berakhir Pada    : ${YELLOW}$exp_date${NC}"
echo -e "◇━━━━━━━━━━━━━━━━━◇"
