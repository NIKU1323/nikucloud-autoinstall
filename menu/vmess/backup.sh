#!/bin/bash
# BACKUP VMESS ACCOUNTS - NIKU CLOUD

backup_file="/root/vmess-backup.json"

if [[ ! -f /etc/xray/config.json ]]; then
  echo "Xray config tidak ditemukan!"
  exit 1
fi

clients=$(grep -oP '"email": *"\K[^"]+' /etc/xray/config.json)
echo "[" > "$backup_file"
for email in $clients; do
  uuid=$(grep -B3 "\"$email\"" /etc/xray/config.json | grep '"id"' | cut -d'"' -f4)
  exp=$(grep "$email" /etc/xray/vmess-clients.txt | awk '{print $3}')
  echo "  {\"email\": \"$email\", \"uuid\": \"$uuid\", \"exp\": \"$exp\"}," >> "$backup_file"
done
sed -i '$ s/,$//' "$backup_file"  # remove trailing comma
echo "]" >> "$backup_file"

echo -e "\n✅ Backup selesai: $backup_file"
