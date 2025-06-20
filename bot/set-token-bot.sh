#!/bin/bash
read -p "Masukkan Token Bot Telegram: " token
read -p "Masukkan Chat ID Admin Telegram: " admin
mkdir -p /etc/nikucloud
echo "$token" > /etc/nikucloud/bot_token.conf
echo "$admin" > /etc/nikucloud/admin_id.conf
echo "✅ Token dan Admin ID tersimpan!"
