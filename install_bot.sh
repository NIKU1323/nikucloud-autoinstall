#!/bin/bash

# Script Instalasi Otomatis IP Management Bot Telegram
# Download bot dari GitHub dan setup otomatis

set -e  # Exit jika ada error

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fungsi untuk menampilkan pesan
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Cek apakah script dijalankan sebagai root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        warning "Script ini tidak direkomendasikan dijalankan sebagai root"
        warning "Lanjutkan? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Update sistem
update_system() {
    log "Updating system packages..."
    sudo apt update
    success "System packages updated"
}

# Install dependencies
install_dependencies() {
    log "Installing required dependencies..."
    
    # Install packages
    sudo apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        screen \
        git \
        curl \
        wget
    
    success "Dependencies installed"
}

# Buat direktori project
setup_project_directory() {
    log "Setting up project directory..."
    
    PROJECT_DIR="$HOME/ip-management-bot"
    
    if [ -d "$PROJECT_DIR" ]; then
        warning "Project directory already exists. Backup first? (y/N): "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            mv "$PROJECT_DIR" "${PROJECT_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
            success "Backup created"
        fi
    fi
    
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    success "Project directory setup completed"
}

# Download bot dari GitHub
download_bot_from_github() {
    log "Downloading bot from GitHub..."
    
    # Download bot.py
    if wget -q https://raw.githubusercontent.com/NIKU1323/nikucloud-autoinstall/main -O telegram_bot.py; then
        success "Bot downloaded successfully"
    else
        error "Failed to download bot from GitHub"
        exit 1
    fi
}

# Buat file-file konfigurasi
create_config_files() {
    log "Creating configuration files..."
    
    # Buat requirements.txt
    cat > requirements.txt << 'EOF'
python-telegram-bot==20.7
aiohttp==3.9.1
python-dotenv==1.0.0
EOF

    # Buat file konfigurasi
    cat > config.env << 'EOF'
# Konfigurasi Telegram Bot
TELEGRAM_BOT_TOKEN=YOUR_TELEGRAM_BOT_TOKEN_HERE

# Konfigurasi API Server
API_BASE_URL=http://47.236.10.221

# Konfigurasi Admin (pisahkan dengan koma jika lebih dari satu)
ADMIN_CHAT_IDS=YOUR_ADMIN_CHAT_ID_HERE

# Konfigurasi Harga
PRICE_PER_DAY=1000

# Konfigurasi Pembayaran
DANA_NUMBER=081234567890
GOPAY_NUMBER=081234567891
OVO_NUMBER=081234567892
EOF

    # Buat file service systemd
    cat > ip-bot.service << 'EOF'
[Unit]
Description=IP Management Telegram Bot
After=network.target

[Service]
Type=simple
User=Puput Jaya
WorkingDirectory={{WORKING_DIR}}
EnvironmentFile={{WORKING_DIR}}/config.env
ExecStart={{PYTHON_PATH}} {{WORKING_DIR}}/telegram_bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Buat script start/stop
    cat > bot_control.sh << 'EOF'
#!/bin/bash

PROJECT_DIR="$HOME/ip-management-bot"
PID_FILE="$PROJECT_DIR/bot.pid"
LOG_FILE="$PROJECT_DIR/bot.log"

start_bot() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null; then
            echo "Bot sudah berjalan (PID: $PID)"
            return 1
        else
            rm "$PID_FILE"
        fi
    fi
    
    echo "Memulai bot..."
    cd "$PROJECT_DIR"
    source venv/bin/activate
    nohup python3 telegram_bot.py > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo "Bot dimulai (PID: $(cat "$PID_FILE"))"
}

stop_bot() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null; then
            echo "Menghentikan bot (PID: $PID)..."
            kill "$PID"
            rm "$PID_FILE"
            echo "Bot dihentikan"
        else
            echo "Bot tidak sedang berjalan"
            rm "$PID_FILE"
        fi
    else
        echo "File PID tidak ditemukan. Bot mungkin tidak berjalan."
    fi
}

status_bot() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null; then
            echo "Bot sedang berjalan (PID: $PID)"
        else
            echo "Bot tidak sedang berjalan (file PID ditemukan: $PID_FILE)"
        fi
    else
        echo "Bot tidak sedang berjalan"
    fi
}

logs_bot() {
    if [ -f "$LOG_FILE" ]; then
        tail -f "$LOG_FILE"
    else
        echo "File log tidak ditemukan: $LOG_FILE"
    fi
}

case "$1" in
    start)
        start_bot
        ;;
    stop)
        stop_bot
        ;;
    restart)
        stop_bot
        sleep 2
        start_bot
        ;;
    status)
        status_bot
        ;;
    logs)
        logs_bot
        ;;
    *)
        echo "Penggunaan: $0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
EOF

    chmod +x bot_control.sh

    success "Configuration files created"
}

# Setup virtual environment
setup_virtualenv() {
    log "Setting up Python virtual environment..."
    
    python3 -m venv venv
    source venv/bin/activate
    
    success "Virtual environment setup completed"
}

# Install Python packages
install_python_packages() {
    log "Installing Python packages..."
    
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    
    success "Python packages installed"
}

# Konfigurasi bot
configure_bot() {
    log "Configuring bot..."
    
    echo
    echo "=== Konfigurasi Bot Telegram ==="
    echo
    
    # Tanya Telegram Bot Token
    while true; do
        read -p "Masukkan Telegram Bot Token: " bot_token
        if [[ ! -z "$bot_token" ]] && [[ "$bot_token" != "YOUR_TELEGRAM_BOT_TOKEN_HERE" ]]; then
            break
        else
            error "Token tidak boleh kosong!"
        fi
    done
    
    # Tanya Admin Chat ID
    while true; do
        read -p "Masukkan Admin Chat ID: " admin_chat_id
        if [[ ! -z "$admin_chat_id" ]] && [[ "$admin_chat_id" != "YOUR_ADMIN_CHAT_ID_HERE" ]]; then
            break
        else
            error "Chat ID tidak boleh kosong!"
        fi
    done
    
    # Update config.env
    sed -i "s/YOUR_TELEGRAM_BOT_TOKEN_HERE/$bot_token/g" config.env
    sed -i "s/YOUR_ADMIN_CHAT_ID_HERE/$admin_chat_id/g" config.env
    
    success "Bot configured"
}

# Setup systemd service
setup_systemd_service() {
    log "Setting up systemd service..."
    
    # Buat service file
    SERVICE_FILE="ip-bot.service"
    WORKING_DIR="$HOME/ip-management-bot"
    PYTHON_PATH="$WORKING_DIR/venv/bin/python3"
    USER=$(whoami)
    
    # Update service file
    sed -i "s|Puput Jaya|$USER|g" "$SERVICE_FILE"
    sed -i "s|{{WORKING_DIR}}|$WORKING_DIR|g" "$SERVICE_FILE"
    sed -i "s|{{PYTHON_PATH}}|$PYTHON_PATH|g" "$SERVICE_FILE"
    
    # Install service
    sudo cp "$SERVICE_FILE" /etc/systemd/system/
    sudo systemctl daemon-reload
    
    success "Systemd service setup completed"
}

# Jalankan bot
start_bot() {
    log "Starting bot..."
    
    # Coba jalankan dengan screen dulu
    if ! command -v screen &> /dev/null; then
        sudo apt install -y screen
    fi
    
    # Jalankan bot di screen
    screen -dmS ip-bot bash -c "cd $HOME/ip-management-bot && source venv/bin/activate && python3 telegram_bot.py"
    
    success "Bot started in screen session 'ip-bot'"
    echo "Gunakan 'screen -r ip-bot' untuk melihat log"
    echo "Gunakan 'screen -d ip-bot' untuk detach"
}

# Tampilkan instruksi penggunaan
show_instructions() {
    echo
    echo "=== Instalasi Selesai! ==="
    echo
    echo "📁 Direktori Project: $HOME/ip-management-bot"
    echo "🔧 File Konfigurasi: config.env"
    echo "📦 Virtual Environment: venv/"
    echo
    echo "=== Perintah yang Tersedia ==="
    echo "./bot_control.sh start    - Mulai bot"
    echo "./bot_control.sh stop     - Hentikan bot"
    echo "./bot_control.sh restart  - Restart bot"
    echo "./bot_control.sh status   - Cek status bot"
    echo "./bot_control.sh logs     - Lihat log bot"
    echo
    echo "=== Perintah Screen ==="
    echo "screen -r ip-bot    - Attach ke bot session"
    echo "screen -d ip-bot    - Detach dari bot session"
    echo "screen -ls          - Lihat semua session"
    echo
    echo "=== Konfigurasi Tambahan ==="
    echo "Edit config.env untuk mengubah konfigurasi"
    echo "Gunakan 'nano config.env' untuk edit"
    echo
}

# Fungsi utama
main() {
    echo "========================================"
    echo "  IP Management Bot Telegram Installer  "
    echo "========================================"
    echo
    
    # Cek root
    check_root
    
    # Update sistem
    update_system
    
    # Install dependencies
    install_dependencies
    
    # Setup project directory
    setup_project_directory
    
    # Download bot dari GitHub
    download_bot_from_github
    
    # Buat file konfigurasi
    create_config_files
    
    # Setup virtual environment
    setup_virtualenv
    
    # Install Python packages
    install_python_packages
    
    # Konfigurasi bot
    configure_bot
    
    # Setup systemd service
    setup_systemd_service
    
    # Jalankan bot
    start_bot
    
    # Tampilkan instruksi
    show_instructions
    
    success "Instalasi selesai! Bot sedang berjalan."
}

# Jalankan script
main "$@"
