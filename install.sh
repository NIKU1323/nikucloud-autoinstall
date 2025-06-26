#!/bin/bash

# AUTO INSTALL VPN FULL PACKAGE (Xray, SSH, SSL, gRPC, Websocket)
# Brand: NIKU TUNNEL / MERCURYVPN
# Modified by: Your Name

# Warna log
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'
CYAN='\e[36m'
NC='\e[0m'

log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_debug() { echo -e "${BLUE}[DEBUG]${NC} $1"; }

# Header
clear
echo -e "${CYAN}==================================================${NC}"
echo -e "${CYAN}    NIKU TUNNEL AUTO INSTALLER - FULL PACKAGE     ${NC}"
echo -e "${CYAN}==================================================${NC}"
echo -e ""

# Cek root
if [[ $EUID -ne 0 ]]; then
   log_error "Script ini harus dijalankan sebagai root"
   exit 1
fi

# Variables
DOMAIN=""
IPVPS=$(curl -s ipv4.icanhazip.com)
ALLOWED_URL="http://172.236.138.192/data/allowed.json"
INSTALL_DIR="/etc/multi-services"
LOG_DIR="/var/log/multi-services"
TIMEZONE="Asia/Kuala_Lumpur"
UUID=$(cat /proc/sys/kernel/random/uuid)
EMAIL="admin@$DOMAIN"
PATH_VLESS="/vless"
PATH_VMESS="/vmess"
PATH_TROJAN="/trojan"
PATH_GRPC="/grpc"
PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)

# Fungsi validasi IP
validate_ip() {
    log_info "Memvalidasi IP VPS ($IPVPS)..."
    EXPIRED=$(curl -s --max-time 10 "$ALLOWED_URL" | jq -r '.[] | select(.ip=="'$IPVPS'") | .exp')
    if [[ -n "$EXPIRED" ]]; then
        log_success "IP VPS terdaftar. Lanjutkan instalasi..."
    else
        log_error "IP VPS ($IPVPS) belum terdaftar. Hubungi admin Telegram."
        exit 1
    fi
}

# Fungsi install dependencies
install_dependencies() {
    log_info "Menginstall dependencies..."
    apt update -y
    apt install -y jq curl wget unzip socat openssl git python3 python3-pip lsb-release cron \
                   bash-completion screen netfilter-persistent nginx dropbear squid haproxy \
                   iptables-persistent fail2ban dnsutils stunnel4 build-essential libssl-dev \
                   zlib1g-dev libpcre3-dev libgd-dev cmake make
}

# Fungsi setup domain dan SSL
setup_domain_ssl() {
    while [ -z "$DOMAIN" ]; do
        read -p "$(echo -e "${YELLOW}[?] Masukkan domain pointing ke VPS ini: ${NC}")" DOMAIN
    done
    
    mkdir -p /etc/xray
    echo "$DOMAIN" > /etc/xray/domain
    
    log_info "Menghentikan nginx sementara..."
    systemctl stop nginx

    curl https://get.acme.sh | sh
    source ~/.bashrc

    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    /root/.acme.sh/acme.sh --register-account -m "$EMAIL"
    /root/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone -k ec-256
    /root/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
        --fullchain-file /etc/xray/cert.pem \
        --key-file /etc/xray/key.pem \
        --ecc

    if [[ -f /etc/xray/cert.pem && -f /etc/xray/key.pem ]]; then
        log_success "Sertifikat SSL berhasil dibuat!"
    else
        log_error "Gagal membuat SSL. Pastikan domain mengarah ke IP VPS!"
        exit 1
    fi

    cat /etc/xray/cert.pem /etc/xray/key.pem > /etc/xray/haproxy.pem
    chmod 600 /etc/xray/haproxy.pem
    systemctl start nginx
}

# Fungsi install Xray Core
install_xray() {
    log_info "Menginstall Xray Core..."
    mkdir -p /var/log/xray /tmp/xray
    cd /tmp/xray
    LATEST=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep browser_download_url | grep linux-64.zip | cut -d '"' -f 4)
    wget -q "$LATEST" -O xray.zip
    unzip -o xray.zip
    install -m 755 xray /usr/bin/xray
    install -m 755 geo* /usr/share/xray/
    echo "$UUID" > /etc/xray/uuid
}

# Fungsi config Xray
configure_xray() {
    log_info "Membuat konfigurasi Xray..."
    mkdir -p $INSTALL_DIR $LOG_DIR
    
    cat > /etc/xray/config.json <<EOF
{
  "log": {
    "access": "$LOG_DIR/xray-access.log",
    "error": "$LOG_DIR/xray-error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-direct"
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "dest": 80
          },
          {
            "path": "$PATH_VLESS",
            "dest": 1001,
            "xver": 1
          },
          {
            "path": "$PATH_VMESS",
            "dest": 1002,
            "xver": 1
          },
          {
            "path": "$PATH_TROJAN",
            "dest": 1003,
            "xver": 1
          },
          {
            "path": "$PATH_GRPC",
            "dest": 1004,
            "xver": 1
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "xtls",
        "xtlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/xray/cert.pem",
              "keyFile": "/etc/xray/key.pem"
            }
          ]
        }
      }
    },
    {
      "port": 1001,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "$PATH_VLESS"
        }
      }
    },
    {
      "port": 1002,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$UUID"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "$PATH_VMESS"
        }
      }
    },
    {
      "port": 1003,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "$UUID"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "$PATH_TROJAN"
        }
      }
    },
    {
      "port": 1004,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "grpc",
        "security": "none",
        "grpcSettings": {
          "serviceName": "$PATH_GRPC"
        }
      }
    },
    {
      "port": 1005,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$UUID"
          }
        ]
      },
      "streamSettings": {
        "network": "grpc",
        "security": "none",
        "grpcSettings": {
          "serviceName": "$PATH_GRPC"
        }
      }
    },
    {
      "port": 1006,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "$UUID"
          }
        ]
      },
      "streamSettings": {
        "network": "grpc",
        "security": "none",
        "grpcSettings": {
          "serviceName": "$PATH_GRPC"
        }
      }
    },
    {
      "port": 80,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$UUID"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "$PATH_VMESS"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

    cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target nss-lookup.target
[Service]
ExecStart=/usr/bin/xray run -c /etc/xray/config.json
Restart=on-failure
User=root
[Install]
WantedBy=multi-user.target
EOF
}

# Fungsi config HAProxy
configure_haproxy() {
    log_info "Mengkonfigurasi HAProxy..."
    cat > /etc/haproxy/haproxy.cfg <<EOF
global
    daemon
    maxconn 256
defaults
    mode tcp
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
frontend ssl_ssh
    bind *:443 ssl crt /etc/xray/haproxy.pem
    mode tcp
    default_backend ssh_backend
backend ssh_backend
    mode tcp
    server ssh 127.0.0.1:22
EOF
}

# Fungsi config Nginx
configure_nginx() {
    log_info "Mengkonfigurasi Nginx..."
    rm -f /etc/nginx/sites-enabled/default
    cat > /etc/nginx/conf.d/vpn.conf <<EOF
server {
    listen 80;
    server_name _;
    location $PATH_VMESS { 
        proxy_pass http://127.0.0.1:1002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    location $PATH_VLESS { 
        proxy_pass http://127.0.0.1:1001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    location $PATH_TROJAN { 
        proxy_pass http://127.0.0.1:1003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
}

# Fungsi config SSH Websocket
configure_ssh_websocket() {
    log_info "Mengkonfigurasi SSH Websocket..."
    wget -O /usr/local/bin/ws-stunnel https://raw.githubusercontent.com/myridwan/sc/ipuk/ws-stunnel
    chmod +x /usr/local/bin/ws-stunnel

    cat > /etc/systemd/system/ws-stunnel.service <<EOF
[Unit]
Description=WebSocket SSH Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/ws-stunnel
Restart=always

[Install]
WantedBy=multi-user.target
EOF
}

# Fungsi config Stunnel
configure_stunnel() {
    log_info "Mengkonfigurasi Stunnel..."
    cat > /etc/stunnel/stunnel.conf <<EOF
cert = /etc/xray/cert.pem
key = /etc/xray/key.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[dropbear]
accept = 447
connect = 127.0.0.1:109

[openssh]
accept = 777
connect = 127.0.0.1:22

[ws-stunnel]
accept = 443
connect = 127.0.0.1:80
EOF
}

# Fungsi config Dropbear
configure_dropbear() {
    log_info "Mengkonfigurasi Dropbear..."
    cat > /etc/default/dropbear <<EOF
NO_START=0
DROPBEAR_PORT=109
DROPBEAR_EXTRA_ARGS="-p 143"
DROPBEAR_BANNER="/etc/dropbear/banner"
DROPBEAR_RECEIVE_WINDOW=65536
EOF
}

# Fungsi install BadVPN
install_badvpn() {
    log_info "Menginstall BadVPN..."
    wget -O /usr/bin/badvpn-udpgw "https://raw.githubusercontent.com/myridwan/sc/ipuk/badvpn-udpgw64"
    chmod +x /usr/bin/badvpn-udpgw

    cat > /etc/systemd/system/badvpn.service <<EOF
[Unit]
Description=BadVPN UDP Gateway
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7100 --max-clients 1000 --max-connections-for-client 10
Restart=always

[Install]
WantedBy=multi-user.target
EOF
}

# Fungsi config Fail2Ban
configure_fail2ban() {
    log_info "Mengkonfigurasi Fail2Ban..."
    cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
maxretry = 3
bantime = 3600
findtime = 600

[dropbear]
enabled = true
maxretry = 3
bantime = 3600
findtime = 600

[nginx-http-auth]
enabled = true
maxretry = 3
bantime = 3600
findtime = 600
EOF
}

# Fungsi setup menu CLI
setup_menu() {
    log_info "Menginstall menu CLI..."
    mkdir -p /root/menu && cd /root/menu
    wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu.sh
    wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-ssh.sh
    wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-vmess.sh
    wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-vless.sh
    wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-trojan.sh
    wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-tools.sh
    chmod +x *.sh

    # Download submenu
    mkdir -p /root/menu/{ssh,vmess,vless,trojan}
    for menu in ssh vmess vless trojan; do
        wget -q -O /root/menu/$menu/create.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/$menu/create.sh
        wget -q -O /root/menu/$menu/renew.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/$menu/renew.sh
        wget -q -O /root/menu/$menu/cek.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/$menu/cek.sh
        wget -q -O /root/menu/$menu/trial.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/$menu/trial.sh
        wget -q -O /root/menu/$menu/list.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/$menu/list.sh
        wget -q -O /root/menu/$menu/delete-exp.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/$menu/delete-exp.sh
        wget -q -O /root/menu/$menu/delete.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/$menu/delete.sh
        chmod +x /root/menu/$menu/*.sh
    done

    # Tambahkan menu ke .bashrc
    [[ $(grep -c menu.sh /root/.bashrc) == 0 ]] && echo "clear && bash /root/menu/menu.sh" >> /root/.bashrc

    # Buat symlink untuk akses mudah
    ln -sf /root/menu/menu.sh /usr/local/bin/menu
    chmod +x /usr/local/bin/menu
}

# Fungsi enable services
enable_services() {
    log_info "Mengaktifkan dan memulai semua services..."
    systemctl daemon-reload
    systemctl enable xray ws-stunnel stunnel4 dropbear badvpn fail2ban nginx haproxy squid
    systemctl restart xray ws-stunnel stunnel4 dropbear badvpn fail2ban nginx haproxy squid
}

# Fungsi buat client config
create_client_configs() {
    log_info "Membuat konfigurasi client..."
    mkdir -p $INSTALL_DIR/client-config

    # VLESS Configs
    cat > $INSTALL_DIR/client-config/vless-ws-tls.json <<EOF
{
  "v": "2",
  "ps": "VLESS+WS+TLS ($DOMAIN)",
  "add": "$DOMAIN",
  "port": "443",
  "id": "$UUID",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "$DOMAIN",
  "path": "$PATH_VLESS",
  "tls": "tls"
}
EOF

    cat > $INSTALL_DIR/client-config/vless-ws-nontls.json <<EOF
{
  "v": "2",
  "ps": "VLESS+WS ($DOMAIN)",
  "add": "$DOMAIN",
  "port": "80",
  "id": "$UUID",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "$DOMAIN",
  "path": "$PATH_VLESS",
  "tls": "none"
}
EOF

    cat > $INSTALL_DIR/client-config/vless-grpc-tls.json <<EOF
{
  "v": "2",
  "ps": "VLESS+gRPC+TLS ($DOMAIN)",
  "add": "$DOMAIN",
  "port": "443",
  "id": "$UUID",
  "aid": "0",
  "net": "grpc",
  "type": "none",
  "host": "$DOMAIN",
  "path": "$PATH_GRPC",
  "tls": "tls"
}
EOF

    # VMESS Configs
    cat > $INSTALL_DIR/client-config/vmess-ws-tls.json <<EOF
{
  "v": "2",
  "ps": "VMESS+WS+TLS ($DOMAIN)",
  "add": "$DOMAIN",
  "port": "443",
  "id": "$UUID",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "$DOMAIN",
  "path": "$PATH_VMESS",
  "tls": "tls"
}
EOF

    cat > $INSTALL_DIR/client-config/vmess-ws-nontls.json <<EOF
{
  "v": "2",
  "ps": "VMESS+WS ($DOMAIN)",
  "add": "$DOMAIN",
  "port": "80",
  "id": "$UUID",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "$DOMAIN",
  "path": "$PATH_VMESS",
  "tls": "none"
}
EOF

    cat > $INSTALL_DIR/client-config/vmess-grpc-tls.json <<EOF
{
  "v": "2",
  "ps": "VMESS+gRPC+TLS ($DOMAIN)",
  "add": "$DOMAIN",
  "port": "443",
  "id": "$UUID",
  "aid": "0",
  "net": "grpc",
  "type": "none",
  "host": "$DOMAIN",
  "path": "$PATH_GRPC",
  "tls": "tls"
}
EOF

    # Trojan Configs
    cat > $INSTALL_DIR/client-config/trojan-ws-tls.json <<EOF
{
  "v": "2",
  "ps": "TROJAN+WS+TLS ($DOMAIN)",
  "add": "$DOMAIN",
  "port": "443",
  "id": "$UUID",
  "net": "ws",
  "type": "none",
  "host": "$DOMAIN",
  "path": "$PATH_TROJAN",
  "tls": "tls",
  "sni": "$DOMAIN"
}
EOF

    cat > $INSTALL_DIR/client-config/trojan-grpc-tls.json <<EOF
{
  "v": "2",
  "ps": "TROJAN+gRPC+TLS ($DOMAIN)",
  "add": "$DOMAIN",
  "port": "443",
  "id": "$UUID",
  "net": "grpc",
  "type": "none",
  "host": "$DOMAIN",
  "path": "$PATH_GRPC",
  "tls": "tls",
  "sni": "$DOMAIN"
}
EOF
}

# Fungsi buat admin control
create_admin_control() {
    log_info "Membuat admin control script..."
    cat > $INSTALL_DIR/admin-control.sh <<EOF
#!/bin/bash
# Admin Control Panel

case \$1 in
    "restart-services")
        systemctl restart xray ws-stunnel stunnel4 dropbear badvpn nginx haproxy squid
        echo "All services restarted"
        ;;
    "reboot-server")
        reboot
        ;;
    "check-status")
        echo -e "\n=== Service Status ==="
        systemctl status xray | grep -E "Active:"
        systemctl status ws-stunnel | grep -E "Active:"
        systemctl status stunnel4 | grep -E "Active:"
        systemctl status dropbear | grep -E "Active:"
        systemctl status badvpn | grep -E "Active:"
        systemctl status nginx | grep -E "Active:"
        systemctl status haproxy | grep -E "Active:"
        systemctl status squid | grep -E "Active:"
        ;;
    "list-configs")
        echo -e "\n=== Client Configurations ==="
        ls -la $INSTALL_DIR/client-config
        ;;
    *)
        echo "Usage: \$0 {restart-services|reboot-server|check-status|list-configs}"
        exit 1
        ;;
esac
EOF
    chmod +x $INSTALL_DIR/admin-control.sh
}

# Fungsi setup auto-reboot
setup_auto_reboot() {
    log_info "Mengatur auto-reboot setiap jam 5 pagi..."
    cat > /etc/cron.d/auto_reboot <<EOF
0 5 * * * root /sbin/reboot
EOF
}

# Fungsi setup autokill multi login
setup_autokill() {
    log_info "Mengatur autokill multi login..."
    cat > /usr/bin/autokill <<EOF
#!/bin/bash
# AutoKill Multi Login
for user in \$(cat /etc/passwd | grep -v "nologin" | grep -v "false" | cut -d: -f1); do
    count=\$(ps aux | grep -i sshd | grep \$user | grep -v grep | wc -l)
    if [ \$count -gt 1 ]; then
        pkill -u \$user
    fi
done
EOF
    chmod +x /usr/bin/autokill
}

# Fungsi setup auto delete expired account
setup_autodelete() {
    log_info "Mengatur auto delete expired account..."
    cat > /usr/bin/autodelete <<EOF
#!/bin/bash
# Auto Delete Expired Account
today=\$(date +%s)
while read -r line; do
    user=\$(echo \$line | cut -d: -f1)
    exp=\$(echo \$line | cut -d: -f2)
    if [ \$exp -lt \$today ]; then
        userdel -r \$user
    fi
done < /etc/expired_users
EOF
    chmod +x /usr/bin/autodelete
}

# Fungsi tampilkan info instalasi
show_installation_info() {
    clear
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${CYAN}          INSTALLASI BERHASIL DILAKUKAN           ${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e ""
    echo -e "${GREEN}=== Informasi Server ==="
    echo -e "Hostname       : $(hostname)"
    echo -e "Domain         : $DOMAIN"
    echo -e "IP VPS         : $IPVPS"
    echo -e "Timezone       : $TIMEZONE"
    echo -e "Auto-Reboot    : 5:00 AM"
    echo -e "Fail2Ban       : [ON]"
    echo -e "IPv6           : [OFF]"
    echo -e "AutoKill       : [ON]"
    echo -e "Auto Delete    : [ON]${NC}"

    echo -e "${BLUE}\n=== Service & Port ==="
    echo -e "OpenSSH                 : 22"
    echo -e "SSH Websocket           : 80"
    echo -e "SSH SSL Websocket       : 443"
    echo -e "Stunnel5                : 447, 777"
    echo -e "Dropbear                : 109, 143"
    echo -e "Badvpn                  : 7100-7300"
    echo -e "Nginx                   : 81"
    echo -e "Squid Proxy             : 3128, 8080"
    echo -e "XRAY Vmess WS TLS       : 443"
    echo -e "XRAY Vmess WS None TLS  : 80"
    echo -e "XRAY Vless WS TLS       : 443"
    echo -e "XRAY Vless WS None TLS  : 80"
    echo -e "XRAY Trojan WS          : 443"
    echo -e "XRAY Vmess gRPC         : 443"
    echo -e "XRAY Vless gRPC         : 443"
    echo -e "XRAY Trojan gRPC        : 443${NC}"

    echo -e "${YELLOW}\n=== Informasi Akun ==="
    echo -e "UUID          : $UUID"
    echo -e "Password      : $PASSWORD"
    echo -e "Path WS       :"
    echo -e "  - Vless     : $PATH_VLESS"
    echo -e "  - Vmess     : $PATH_VMESS"
    echo -e "  - Trojan    : $PATH_TROJAN"
    echo -e "Path gRPC     : $PATH_GRPC"
    echo -e "Konfigurasi client disimpan di: $INSTALL_DIR/client-config${NC}"

    echo -e "${GREEN}\nMenu kontrol:"
    echo -e "  - Ketik 'menu' untuk mengakses menu utama"
    echo -e "  - Admin control: $INSTALL_DIR/admin-control.sh${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${CYAN} Script by NIKU TUNNEL - Modified by Your Name ${NC}"
    echo -e "${CYAN}==================================================${NC}"
}

# Main installation
validate_ip
install_dependencies
setup_domain_ssl
install_xray
configure_xray
configure_haproxy
configure_nginx
configure_ssh_websocket
configure_stunnel
configure_dropbear
install_badvpn
configure_fail2ban
setup_menu
enable_services
create_client_configs
create_admin_control
setup_auto_reboot
setup_autokill
setup_autodelete
show_installation_info

# Reboot prompt
read -p "$(echo -e "${YELLOW}Reboot sekarang? (y/n): ${NC}")" answer
if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
    reboot
else
    log_info "Anda bisa reboot manual nanti dengan perintah: reboot"
fi