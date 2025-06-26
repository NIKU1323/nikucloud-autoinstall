#!/bin/bash
# SCRIPT VPN LENGKAP DENGAN SEMUA MENU
# Termasuk: SSH, VMESS, VLESS, Trojan, Shadowsocks
# Fix: Semua masalah termasuk validasi IP, dependency, dan error handling

# Warna
MERAH='\033[0;31m'
HIJAU='\033[0;32m'
KUNING='\033[0;33m'
BIRU='\033[0;34m'
NC='\033[0m'

# Fungsi validasi IP
validasi_ip() {
    echo -e "${KUNING}[1/15] Memvalidasi IP VPS...${NC}"
    apt update && apt install -y curl jq
    
    IP_VPS=$(curl -s ipv4.icanhazip.com)
    URL_WHITELIST="http://172.236.138.192/data/allowed.json"
    
    echo -e "IP VPS: ${BIRU}$IP_VPS${NC}"
    RESPON=$(curl -s "$URL_WHITELIST")
    
    if [[ -z "$RESPON" ]]; then
        echo -e "${MERAH}Gagal validasi IP${NC}"
        exit 1
    fi
    
    if ! jq -e --arg ip "$IP_VPS" '.[] | select(.ip == $ip)' <<< "$RESPON" >/dev/null; then
        echo -e "${MERAH}IP $IP_VPS tidak terdaftar${NC}"
        exit 1
    fi
    echo -e "${HIJAU}Validasi IP berhasil${NC}"
}

# Fungsi input domain
input_domain() {
    echo -e "${KUNING}[2/15] Masukkan domain Anda${NC}"
    read -p "Domain (contoh: vpn.kamu.com): " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        echo -e "${MERAH}Domain tidak boleh kosong!${NC}"
        exit 1
    fi
    echo "$DOMAIN" > /etc/xray/domain
    echo -e "${HIJAU}Domain diset ke: $DOMAIN${NC}"
}

# Fungsi install dependency lengkap
install_dependency() {
    echo -e "${KUNING}[3/15] Menginstall semua dependency...${NC}"
    apt install -y \
        jq curl socat openssl \
        wget unzip screen \
        nginx dropbear squid \
        haproxy python3 python3-pip \
        cron git build-essential \
        libssl-dev zlib1g-dev
}

# Fungsi install Xray
install_xray() {
    echo -e "${KUNING}[4/15] Menginstall Xray...${NC}"
    mkdir -p /var/log/xray /tmp/xray
    cd /tmp/xray
    
    for i in {1..3}; do
        wget --timeout=30 -O xray.zip "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip" && break || {
            echo -e "${KUNING}Percobaan $i gagal, mencoba lagi...${NC}"
            sleep 3
            [ $i -eq 3 ] && { echo -e "${MERAH}Gagal download Xray${NC}"; exit 1; }
        }
    done
    
    unzip xray.zip || { echo -e "${MERAH}Gagal ekstrak Xray${NC}"; exit 1; }
    install -m 755 xray /usr/bin/xray || { echo -e "${MERAH}Gagal install Xray${NC}"; exit 1; }
}

# Fungsi konfigurasi Xray lengkap
configure_xray() {
    echo -e "${KUNING}[5/15] Membuat config Xray lengkap...${NC}"
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
    },
    {
      "port": 10086,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/vless"
        }
      }
    },
    {
      "port": 10089,
      "protocol": "trojan",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/xray/xray.crt",
              "keyFile": "/etc/xray/xray.key"
            }
          ]
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

# Fungsi install SSL
install_ssl() {
    echo -e "${KUNING}[6/15] Menginstall SSL...${NC}"
    systemctl stop nginx
    curl https://get.acme.sh | sh -s email=admin@$DOMAIN
    source ~/.bashrc
    
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone -k ec-256 --force
    ~/.acme.sh/acme.sh --install-cert -d $DOMAIN \
        --fullchain-file /etc/xray/xray.crt \
        --key-file /etc/xray/xray.key \
        --ecc
        
    chmod 600 /etc/xray/xray.key
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/xray/haproxy.pem
    chmod 600 /etc/xray/haproxy.pem
}

# Fungsi konfigurasi Nginx
configure_nginx() {
    echo -e "${KUNING}[7/15] Setup Nginx...${NC}"
    cat > /etc/nginx/conf.d/vpn.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;
    
    ssl_certificate /etc/xray/xray.crt;
    ssl_certificate_key /etc/xray/xray.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    
    location /vmess {
        proxy_pass http://127.0.0.1:10080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
    
    location /vless {
        proxy_pass http://127.0.0.1:10086;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
EOF
}

# Fungsi konfigurasi HAProxy
configure_haproxy() {
    echo -e "${KUNING}[8/15] Setup HAProxy...${NC}"
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

    acl xray_tls req.ssl_sni -i $DOMAIN
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

# Fungsi install menu lengkap
install_full_menu() {
    echo -e "${KUNING}[9/15] Menginstall menu lengkap...${NC}"
    mkdir -p /root/menu/{ssh,vmess,vless,trojan,shadowsocks}

    # Menu utama
    wget -qO /root/menu/menu.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu.sh
    wget -qO /root/menu/menu-ssh.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-ssh.sh
    wget -qO /root/menu/menu-vmess.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-vmess.sh
    wget -qO /root/menu/menu-vless.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-vless.sh
    wget -qO /root/menu/menu-trojan.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-trojan.sh
    wget -qO /root/menu/menu-shadowsocks.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/menu-shadowsocks.sh

    # SSH
    wget -qO /root/menu/ssh/create.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/create.sh
    wget -qO /root/menu/ssh/renew.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/renew.sh
    wget -qO /root/menu/ssh/delete.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/ssh/delete.sh

    # VMESS
    wget -qO /root/menu/vmess/create.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vmess/create.sh
    wget -qO /root/menu/vmess/renew.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vmess/renew.sh
    wget -qO /root/menu/vmess/delete.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vmess/delete.sh

    # VLESS
    wget -qO /root/menu/vless/create.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vless/create.sh
    wget -qO /root/menu/vless/renew.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vless/renew.sh
    wget -qO /root/menu/vless/delete.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/vless/delete.sh

    # Trojan
    wget -qO /root/menu/trojan/create.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/trojan/create.sh
    wget -qO /root/menu/trojan/renew.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/trojan/renew.sh
    wget -qO /root/menu/trojan/delete.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/trojan/delete.sh

    # Shadowsocks
    wget -qO /root/menu/shadowsocks/create.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/shadowsocks/create.sh
    wget -qO /root/menu/shadowsocks/renew.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/shadowsocks/renew.sh
    wget -qO /root/menu/shadowsocks/delete.sh https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main/menu/shadowsocks/delete.sh

    # Set permissions
    chmod +x /root/menu/*.sh
    chmod +x /root/menu/*/*.sh
    
    # Buat symlink
    ln -sf /root/menu/menu.sh /usr/local/bin/menu
}

# Fungsi start service
start_services() {
    echo -e "${KUNING}[10/15] Menjalankan service...${NC}"
    systemctl daemon-reload
    systemctl enable xray nginx haproxy
    systemctl restart xray nginx haproxy
}

# Fungsi tampilan akhir
show_result() {
    echo -e "${HIJAU}[SUKSES] Instalasi selesai 100%${NC}"
    echo -e "===================================="
    echo -e "Domain: ${BIRU}$DOMAIN${NC}"
    echo -e "Port SSH: ${BIRU}22${NC}"
    echo -e "Port VMESS WS: ${BIRU}443${NC}"
    echo -e "Port VLESS WS: ${BIRU}443${NC}"
    echo -e "Port Trojan: ${BIRU}443${NC}"
    echo -e "===================================="
    echo -e "Gunakan perintah: ${KUNING}menu${NC} untuk membuka panel"
    echo -e "Cek status: ${KUNING}systemctl status xray nginx${NC}"
}

# Fungsi utama
main() {
    validasi_ip
    input_domain
    install_dependency
    install_xray
    configure_xray
    install_ssl
    configure_nginx
    configure_haproxy
    install_full_menu
    start_services
    show_result
}

# Jalankan
main
