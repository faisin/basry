#!/bin/bash
set -euo pipefail
# =========================================
# setup
# =========================================

# color
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
white='\e[1;37m'
nc='\e[0m'

# Canonical project repository (use main, never master).
REPO_OWNER="faisin/basry"
REPO_BRANCH="main"
REPO_RAW="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_BRANCH}"

# delete old
rm -f cf.sh >/dev/null 2>&1
rm -f ssh-vpn.sh >/dev/null 2>&1
rm -f ins-xray.sh >/dev/null 2>&1
rm -f udp-custom.sh >/dev/null 2>&1
rm -f slowdns.sh >/dev/null 2>&1

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${red}ERROR: Script must be run as root.${nc}"
    exit 1
fi

# Detect and validate supported OS versions.
if [ ! -r /etc/os-release ]; then
    echo -e "${red}ERROR: /etc/os-release not found; unsupported OS.${nc}"
    exit 1
fi
. /etc/os-release
OS="${ID:-unknown}"
OS_VERSION="${VERSION_ID:-unknown}"

case "${OS}:${OS_VERSION}" in
    debian:11|debian:12|debian:13|ubuntu:22.04|ubuntu:24.04|ubuntu:26.04)
        ;;
    *)
        echo -e "${red}ERROR: Unsupported OS: ${PRETTY_NAME:-$OS $OS_VERSION}.${nc}"
        echo -e "Supported: Debian 11/12/13 and Ubuntu 22.04/24.04/26.04."
        exit 1
        ;;
esac

ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
echo -e "${green}Detected: ${PRETTY_NAME:-$OS $OS_VERSION} / ${ARCH}${nc}"

# -------------------------------
# 1) Set timezone (configurable; UTC by default)
# -------------------------------
INSTALL_TZ="${INSTALL_TZ:-UTC}"
if command -v timedatectl >/dev/null 2>&1; then
    echo "Setting timezone to ${INSTALL_TZ}..."
    timedatectl set-timezone "${INSTALL_TZ}"
    timedatectl | grep "Time zone" || true
else
    echo -e "${yellow}timedatectl unavailable; keeping existing timezone.${nc}"
fi

# -------------------------------
# 2️⃣ Enable NTP (auto-sync waktu)
# -------------------------------
if command -v timedatectl >/dev/null 2>&1; then
    echo "Enabling NTP..."
    timedatectl set-ntp true || true
    timedatectl status | grep -E "NTP enabled|NTP synchronized" || true
else
    echo -e "${yellow}timedatectl unavailable; skipping NTP configuration.${nc}"
fi

# -------------------------------
# 3) Install required base dependencies
# -------------------------------
export DEBIAN_FRONTEND=noninteractive
echo "Installing base dependencies..."
apt-get update
apt-get install -y ca-certificates curl wget dnsutils jq cron

echo "Enabling and starting cron service..."
systemctl enable cron
systemctl restart cron

echo ""
echo "✅ VPS timezone, NTP, and cron setup complete!"

# create folder
mkdir -p /usr/local/etc/xray
mkdir -p /etc/log

MYIP=$(curl -4fsS --max-time 10 https://ipv4.icanhazip.com 2>/dev/null || curl -4fsS --max-time 10 https://ifconfig.me 2>/dev/null || true)
clear
echo -e "${red}=========================================${nc}"
echo -e "${green}     CUSTOM SETUP DOMAIN VPS     ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "${white}1${nc} Use Domain From Script"
echo -e "${white}2${nc} Choose Your Own Domain"
echo -e "${red}=========================================${nc}"
read -rp "Choose Your Domain Installation 1/2 : " dom 

if [[ $dom -eq 1 ]]; then
    clear
    rm -f /root/cf.sh
    wget -q -O /root/cf.sh "${REPO_RAW}/ssh/cf.sh"
    chmod +x /root/cf.sh && bash /root/cf.sh

elif [[ $dom -eq 2 ]]; then
    read -rp "Enter Your Domain : " domen
    rm -f /usr/local/etc/xray/domain /root/domain
    echo "$domen" | tee /usr/local/etc/xray/domain /root/domain >/dev/null

    echo -e "\n${yellow}Checking DNS record for ${domen}...${nc}"
    DNS_IP=$(dig +short A "$domen" @1.1.1.1 | head -n1)

    if [[ -z "$DNS_IP" ]]; then
        echo -e "${red}No DNS record found for ${domen}.${nc}"
    elif [[ "$DNS_IP" != "$MYIP" ]]; then
        echo -e "${yellow}⚠ Domain does not point to this VPS.${nc}"
        echo -e "Your VPS IP: ${green}$MYIP${nc}"
        echo -e "Current DNS IP: ${red}$DNS_IP${nc}"
    else
        echo -e "${green}✅ Domain already points to this VPS.${nc}"
    fi

    # DNS changes are intentionally manual: no Cloudflare API/token is used.
    if [[ "$DNS_IP" != "$MYIP" ]]; then
        echo -e "\n${yellow}Set an A record manually for ${domen} -> ${MYIP}.${nc}"
        echo -e "${yellow}After updating DNS, run this check again before requesting SSL.${nc}"
    fi
else 
    echo -e "${red}Wrong Argument${nc}"
    exit 1
fi
echo -e "${green}Done${nc}"

echo -e "${red}=========================================${nc}"
echo -e "${blue}       Install SSH VPN           ${nc}"
echo -e "${red}=========================================${nc}"
#install ssh vpn
wget -q -O ssh-vpn.sh "${REPO_RAW}/ssh/ssh-vpn.sh" && chmod +x ssh-vpn.sh && ./ssh-vpn.sh

echo -e "${red}=========================================${nc}"
echo -e "${blue}          Install XRAY              ${nc}"
echo -e "${red}=========================================${nc}"
#Instal Xray
wget -q -O ins-xray.sh "${REPO_RAW}/xray/ins-xray.sh" && chmod +x ins-xray.sh && ./ins-xray.sh

echo -e "${red}=========================================${nc}"
echo -e "${blue}      Install SSH Websocket           ${nc}"
echo -e "${red}=========================================${nc}"
# install sshws
# wget ${REPO_RAW}/ws/install-ws.sh && chmod +x install-ws.sh && ./install-ws.sh

# ==========================================
# INSTALL WEBSOCKET PROXY.JS
# ==========================================
LOG_FILE="/var/log/ws-proxy-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "========================================="
echo "Starting WebSocket Proxy.js installation..."
echo "========================================="

# -------------------------------
# Set non-interactive mode
# -------------------------------
export DEBIAN_FRONTEND=noninteractive

# -------------------------------
# Update & Install dependencies
# -------------------------------
echo "[STEP 1] Updating system and installing packages..."
apt-get update
apt-get install -y ca-certificates wget curl lsof dnsutils jq build-essential
# -------------------------------
# Install Node.js
# -------------------------------
echo "[STEP 2] Checking Node.js version..."
NODE_VERSION=$(node -v 2>/dev/null || echo "v0")
NODE_MAJOR=${NODE_VERSION#v}
NODE_MAJOR=${NODE_MAJOR%%.*}

if [[ $NODE_MAJOR -lt 24 ]]; then
    echo "Node.js version too old ($NODE_VERSION). Installing Node.js 24 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
    apt-get install -y nodejs
else
    echo "Node.js version is sufficient ($NODE_VERSION)"
fi

# -------------------------------
# Download proxy.js
# -------------------------------
echo "[STEP 3] Downloading proxy.js..."
rm -f /usr/local/bin/proxy.js
wget -q --timeout=20 --tries=3 -O /usr/local/bin/proxy.js "${REPO_RAW}/ws/proxy.js"
chmod +x /usr/local/bin/proxy.js
echo "[STEP 3] proxy.js installed at /usr/local/bin/proxy.js"

# -------------------------------
# Download systemd service
# -------------------------------
echo "[STEP 4] Setting up ws-proxy systemd service..."
rm -f /etc/systemd/system/ws-proxy.service
wget -q --timeout=20 --tries=3 -O /etc/systemd/system/ws-proxy.service "${REPO_RAW}/ws/ws-proxy.service"
chmod 644 /etc/systemd/system/ws-proxy.service

cd /usr/local/bin
npm install ws
npm init -y

# Reload systemd to recognize new service
systemctl daemon-reload || true

# Enable and start ws-proxy service
systemctl enable ws-proxy || true
systemctl restart ws-proxy || true

# -------------------------------
# Verify service
# -------------------------------
if systemctl is-active --quiet ws-proxy; then
    echo "[STEP 5] ws-proxy service is active and running."
else
    echo "[WARNING] ws-proxy service failed to start. Check logs with: journalctl -u ws-proxy -f"
fi

# -------------------------------
# Final message
# -------------------------------
echo "========================================="
echo "WebSocket Proxy.js installation complete!"
echo "You can check the service status: systemctl status ws-proxy"
echo "========================================="

#echo -e "${red}=========================================${nc}"
#echo -e "${blue}             Install SlowDNS            ${nc}"
#echo -e "${red}=========================================${nc}"
# install slowdns
# wget ${REPO_RAW}/slowdns/slowdns.sh && chmod +x slowdns.sh && ./slowdns.sh

#echo -e "${red}=========================================${nc}"
#echo -e "${blue}               Install Tor              ${nc}"
#echo -e "${red}=========================================${nc}"
# install tor
#wget ${REPO_RAW}/ssh/tor.sh && chmod +x tor.sh && ./tor.sh

#echo -e "${red}=========================================${nc}"
#echo -e "${blue}           Install UDP CUSTOM           ${nc}"
#echo -e "${red}=========================================${nc}"
# install udp-custom
# wget ${REPO_RAW}/udp-custom/udp-custom.sh && chmod +x udp-custom.sh && ./udp-custom.sh

echo -e "${red}=========================================${nc}"
echo -e "${blue}           Install OpenVPN              ${nc}"
echo -e "${red}=========================================${nc}"
# install tor openvpn
wget -q --timeout=20 --tries=3 -O openvpn.sh "${REPO_RAW}/openvpn/openvpn.sh" && chmod +x openvpn.sh && ./openvpn.sh

cat > /root/.profile <<'EOF'
# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n || true
clear
command -v menu >/dev/null 2>&1 && menu
EOF

apt install -y netfilter-persistent iptables-persistent
# Flush
iptables -L INPUT -n --line-numbers
# Allow loopback
iptables -C INPUT -i lo -j ACCEPT 2>/dev/null || \
iptables -I INPUT -i lo -j ACCEPT
# Allow established connections
iptables -C INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
iptables -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# Allow SSH & Dropbear
iptables -C INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 22 -j ACCEPT
iptables -C INPUT -p tcp --dport 2222 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 2222 -j ACCEPT
iptables -C INPUT -p tcp --dport 109 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 109 -j ACCEPT
iptables -C INPUT -p tcp --dport 110 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 110 -j ACCEPT
iptables -C INPUT -p tcp --dport 222 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 222 -j ACCEPT
iptables -C INPUT -p tcp --dport 333 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 333 -j ACCEPT
iptables -C INPUT -p tcp --dport 444 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 444 -j ACCEPT
iptables -C INPUT -p tcp --dport 777 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 777 -j ACCEPT
iptables -C INPUT -p tcp --dport 8443 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 8443 -j ACCEPT
# Allow HTTP/HTTPS
iptables -C INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 80 -j ACCEPT
iptables -C INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 443 -j ACCEPT
# Allow HTTP/HTTPS nginx
iptables -C INPUT -p tcp --dport 8080 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 8080 -j ACCEPT
iptables -C INPUT -p tcp --dport 4433 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 4433 -j ACCEPT
# Allow WebSocket ports
iptables -C INPUT -p tcp --dport 1444 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 1444 -j ACCEPT
iptables -C INPUT -p tcp --dport 1445 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p tcp --dport 1445 -j ACCEPT
# Save
netfilter-persistent save
# chattr +i /etc/iptables/rules.v4
netfilter-persistent reload

systemctl enable netfilter-persistent
systemctl start netfilter-persistent

echo ""
echo -e "========================================="  | tee -a ~/log-install.txt
echo -e "          Service Information            "  | tee -a ~/log-install.txt
echo -e "========================================="  | tee -a ~/log-install.txt
echo ""
echo "   >>> Service & Port"  | tee -a ~/log-install.txt
echo "   - OpenSSH                  : 22, 2222"  | tee -a ~/log-install.txt
echo "   - Dropbear                 : 109, 110" | tee -a ~/log-install.txt
echo "   - SSH Websocket            : 80, 1445" | tee -a ~/log-install.txt
echo "   - SSH SSL Websocket        : 444, 1444" | tee -a ~/log-install.txt
echo "   - Stunnel4                 : 222, 333, 777" | tee -a ~/log-install.txt
echo "   - Badvpn                   : 7100-7900" | tee -a ~/log-install.txt
echo "   - OpenVPN                  : 443, 1195, 51825" | tee -a ~/log-install.txt
echo "   - Nginx                    : 80" | tee -a ~/log-install.txt
echo "   - Vmess WS TLS             : 443" | tee -a ~/log-install.txt
echo "   - Vless WS TLS             : 443" | tee -a ~/log-install.txt
echo "   - Trojan WS TLS            : 443" | tee -a ~/log-install.txt
echo "   - Shadowsocks WS TLS       : 443" | tee -a ~/log-install.txt
echo "   - Vmess WS none TLS        : 80" | tee -a ~/log-install.txt
echo "   - Vless WS none TLS        : 80" | tee -a ~/log-install.txt
echo "   - Trojan WS none TLS       : 80" | tee -a ~/log-install.txt
echo "   - Shadowsocks WS none TLS  : 80" | tee -a ~/log-install.txt
echo "   - Vmess gRPC               : 443" | tee -a ~/log-install.txt
echo "   - Vless gRPC               : 443" | tee -a ~/log-install.txt
echo "   - Trojan gRPC              : 443" | tee -a ~/log-install.txt
echo "   - Shadowsocks gRPC         : 443" | tee -a ~/log-install.txt
echo ""
echo -e "=========================================" | tee -a ~/log-install.txt
echo -e "               t.me/givps_com            "  | tee -a ~/log-install.txt
echo -e "=========================================" | tee -a ~/log-install.txt
echo ""
echo -e "Auto reboot in 10 seconds..."
sleep 10
clear
reboot
