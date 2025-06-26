#!/bin/bash
# AUTO KILL SSH MULTILOGIN - NIKU TUNNEL / MERCURYVPN

NC='\e[0m'
RED='\e[31m'
GREEN='\e[32m'
CYAN='\e[36m'
YELLOW='\e[33m'

clear
echo -e "${CYAN}┌──────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│       AUTO KILL SSH MULTI-LOGIN USER        │${NC}"
echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"

pids=$(pgrep -a sshd | grep -v pts | awk '{print $1}')
> /tmp/log-ssh.txt

for pid in $pids; do
  user=$(ps -o user= -p $pid)
  [[ -z "$user" ]] && continue
  ip=$(netstat -tunp 2>/dev/null | grep $pid | awk '{print $5}' | cut -d: -f1 | head -n 1)
  echo "$user $ip" >> /tmp/log-ssh.txt
done

sort /tmp/log-ssh.txt | uniq -c | while read count user ip; do
  limit_file="/etc/limit/ip/${user}"
  [[ -f $limit_file ]] && limit=$(cat $limit_file) || limit=1
  if [[ $count -gt $limit ]]; then
    pkill -u $user
    echo -e "${YELLOW}➤ User $user KILLED (multi-login $count > limit $limit)${NC}"
  fi
done

rm -f /tmp/log-ssh.txt
