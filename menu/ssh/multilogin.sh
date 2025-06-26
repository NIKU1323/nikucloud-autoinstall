#!/bin/bash
# CEK USER MULTILOGIN SSH - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│         CEK USER MULTILOGIN SSH ACTIVE      │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"

pids=$(pgrep -a sshd | grep -v pts | awk '{print $1}')
> /tmp/log-ssh-multi.txt

for pid in $pids; do
  user=$(ps -o user= -p $pid)
  [[ -z "$user" ]] && continue
  ip=$(netstat -tunp 2>/dev/null | grep $pid | awk '{print $5}' | cut -d: -f1 | head -n 1)
  echo "$user $ip" >> /tmp/log-ssh-multi.txt
done

echo -e "${YELLOW}User Login Aktif (Multi-IP):${NC}"
sort /tmp/log-ssh-multi.txt | uniq -c | sort -nr | while read count user ip; do
  [[ "$user" == "root" ]] && continue
  [[ "$count" -gt 1 ]] && echo -e "➤ ${CYAN}$user${NC} login dari ${YELLOW}$count IP${NC}"
done

rm -f /tmp/log-ssh-multi.txt
