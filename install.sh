#!/bin/bash
# COMPLETE VPN INSTALLATION SCRIPT WITH ALL FIXES
# Fixed: Xray download, menu installation, and error handling
# Includes: Xray (VMESS/VLESS/Trojan), SSH, Nginx, HAProxy, and Complete Menu System

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}ERROR: This script must be run as root${NC}"
    exit 1
fi

# Function to handle errors
handle_error() {
    echo -e "${RED}Error occurred on line $1${NC}"
    echo -e "${YELLOW}Checking system status...${NC}"
    systemctl status xray nginx haproxy 2>/dev/null
    exit 1
}

trap 'handle_error $LINENO' ERR

# Cleanup previous installation
cleanup() {
    echo -e "${YELLOW}Cleaning up previous installation...${NC}"
    systemctl stop xray nginx haproxy 2>/dev/null
    rm -rf /tmp/xray /usr/bin/xray /etc/xray /root/menu
}

# Install dependencies
install_deps() {
    echo -e "${YELLOW}[1/9] Installing dependencies...${NC}"
    apt update && apt upgrade -y
    apt install -y jq curl socat openssl wget unzip screen nginx dropbear squid haproxy python3 python3-pip cron
}

# Install Xray (fixed version)
install_xray() {
    echo -e "${YELLOW}[2/9] Installing Xray...${NC}"
    mkdir -p /var/log/xray /tmp/xray
    cd /tmp/xray

    # Direct download URL (no API parsing)
    XRAY_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"

    # Download with retry
    for i in {1..3}; do
        wget --timeout=30 --tries=3 -O xray.zip "$XRAY_URL" && break || {
            echo -e "${YELLOW}Attempt $i failed, retrying...${NC}"
            sleep 3
            [ $i -eq 3 ] && { echo -e "${RED}Failed to download Xray after 3 attempts${NC}"; exit 1; }
        }
    done

    unzip xray.zip || { echo -e "${RED}Failed to extract Xray${NC}"; exit 1; }
    install -m 755 xray /usr/bin/xray || { echo -e "${RED}Failed to install Xray binary${NC}"; exit 1; }
}

# Install geo data
install_geo() {
    echo -e "${YELLOW}[3/9] Installing geo data...${NC}"
    wget --timeout=30 -O /usr/bin/geoip.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
    wget --timeout=30 -O /usr/bin/geosite.dat https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
}

# Configure Xray
configure_xray() {
    echo -e "${YELLOW}[4/9] Configuring Xray...${NC}"
    mkdir -p /etc/xray
    cat > /etc/xray/config.json <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 10085,
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "grpc",
        "security": "tls",
        "grpcSettings": {
          "serviceName": "vmess-grpc"
        }
      }
    },
    {
      "port": 10080,
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/vmess"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
}

# Create Xray service
create_xray_service() {
    echo -e "${YELLOW}[5/9] Creating Xray service...${NC}"
    cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=/usr/bin/xray run -c /etc/xray/config.json
Restart=on-failure
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF
}

# Configure HAProxy
configure_haproxy() {
    echo -e "${YELLOW}[6/9] Configuring HAProxy...${NC}"
    cat > /etc/haproxy/haproxy.cfg <<EOF
global
    daemon
    maxconn 2048

defaults
    mode tcp
    timeout connect 5s
    timeout client 50s
    timeout server 50s

frontend ssl_in
    bind *:443 ssl crt /etc/xray/haproxy.pem alpn h2,http/1.1
    mode tcp
    option tcplog
    tcp-request inspect-delay 5s
    tcp-request content accept if { req.ssl_hello_type 1 }

    acl xray_tls req.ssl_sni -i \$(cat /etc/xray/domain)
    use_backend xray_tls if xray_tls
    default_backend ssh_tls

backend xray_tls
    mode tcp
    server xray 127.0.0.1:10085 check send-proxy

backend ssh_tls
    mode tcp
    server ssh 127.0.0.1:22
EOF
}

# Install complete menu system
install_menu() {
    echo -e "${YELLOW}[7/9] Installing complete menu system...${NC}"
    mkdir -p /root/menu && cd /root/menu

    # Main menu scripts
    wget --timeout=30 -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu.sh
    wget --timeout=30 -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-ssh.sh
    wget --timeout=30 -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-vmess.sh
    wget --timeout=30 -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-vless.sh
    wget --timeout=30 -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-trojan.sh
    wget --timeout=30 -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-tools.sh

    # SSH submenu
    mkdir -p /root/menu/ssh
    wget --timeout=30 -q -O /root/menu/ssh/create.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/create.sh
    wget --timeout=30 -q -O /root/menu/ssh/autokill.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/autokill.sh
    wget --timeout=30 -q -O /root/menu/ssh/cek.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/cek.sh
    wget --timeout=30 -q -O /root/menu/ssh/lock.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/lock.sh
    wget --timeout=30 -q -O /root/menu/ssh/list.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/list.sh
    wget --timeout=30 -q -O /root/menu/ssh/delete-exp.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/delete-exp.sh
    wget --timeout=30 -q -O /root/menu/ssh/delete.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/delete.sh
    wget --timeout=30 -q -O /root/menu/ssh/unlock.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/unlock.sh
    wget --timeout=30 -q -O /root/menu/ssh/trial.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/trial.sh
    wget --timeout=30 -q -O /root/menu/ssh/multilogin.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/multilogin.sh
    wget --timeout=30 -q -O /root/menu/ssh/renew.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/renew.sh

    # VMESS submenu
    mkdir -p /root/menu/vmess
    wget --timeout=30 -q -O /root/menu/vmess/create.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vmess/create.sh
    wget --timeout=30 -q -O /root/menu/vmess/autokill.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vmess/renew.sh
    wget --timeout=30 -q -O /root/menu/vmess/cek.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vmess/cek.sh
    wget --timeout=30 -q -O /root/menu/vmess/lock.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vmess/trial.sh
    wget --timeout=30 -q -O /root/menu/vmess/list.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vmess/list.sh
    wget --timeout=30 -q -O /root/menu/vmess/delete-exp.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vmess/delete-exp.sh
    wget --timeout=30 -q -O /root/menu/vmess/delete.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vmess/delete.sh

    # VLESS submenu
    mkdir -p /root/menu/vless
    wget --timeout=30 -q -O /root/menu/vless/create.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vless/create.sh
    wget --timeout=30 -q -O /root/menu/vless/autokill.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vless/renew.sh
    wget --timeout=30 -q -O /root/menu/vless/cek.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vless/cek.sh
    wget --timeout=30 -q -O /root/menu/vless/lock.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vless/trial.sh
    wget --timeout=30 -q -O /root/menu/vless/list.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vless/list.sh
    wget --timeout=30 -q -O /root/menu/vless/delete-exp.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vless/delete-exp.sh
    wget --timeout=30 -q -O /root/menu/vless/delete.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vless/delete.sh

    # Trojan submenu
    mkdir -p /root/menu/trojan
    wget --timeout=30 -q -O /root/menu/trojan/create.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/trojan/create.sh
    wget --timeout=30 -q -O /root/menu/trojan/autokill.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/trojan/renew.sh
    wget --timeout=30 -q -O /root/menu/trojan/cek.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/trojan/cek.sh
    wget --timeout=30 -q -O /root/menu/trojan/lock.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/trojan/trial.sh
    wget --timeout=30 -q -O /root/menu/trojan/list.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/trojan/list.sh
    wget --timeout=30 -q -O /root/menu/trojan/delete-exp.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/trojan/delete-exp.sh
    wget --timeout=30 -q -O /root/menu/trojan/delete.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/trojan/delete.sh

    # Set permissions
    chmod +x /root/menu/*.sh
    chmod +x /root/menu/menu-tools/*.sh
    chmod +x /root/menu/ssh/*.sh
    chmod +x /root/menu/vless/*.sh
    chmod +x /root/menu/trojan/*.sh
    chmod +x /root/menu/vmess/*.sh
}

# Final configuration
final_setup() {
    echo -e "${YELLOW}[8/9] Finalizing installation...${NC}"
    # Create symlink
    ln -sf /root/menu/menu.sh /usr/local/bin/menu
    chmod +x /usr/local/bin/menu

    # Add to .bashrc
    if ! grep -q "menu.sh" /root/.bashrc; then
        echo "clear && /root/menu/menu.sh" >> /root/.bashrc
    fi

    # Enable services
    systemctl daemon-reload
    systemctl enable xray nginx haproxy
    systemctl restart xray nginx haproxy
}

# Main installation flow
cleanup
install_deps
install_xray
install_geo
configure_xray
create_xray_service
configure_haproxy
install_menu
final_setup

# Completion message
echo -e "${GREEN}Installation completed successfully!${NC}"
echo -e "You can now access the menu by typing: ${YELLOW}menu${NC}"
echo -e "Or by reconnecting to your server"
