#!/bin/bash
# ==============================
# Domain setup without provider API/token
# ==============================
set -euo pipefail

red='\e[1;31m'
green='\e[1;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

for cmd in dig curl wget; do
    command -v "$cmd" >/dev/null 2>&1 || { apt update -y >/dev/null 2>&1; apt install -y "$cmd" >/dev/null 2>&1; }
done

IP=$(wget -qO- ipv4.icanhazip.com || curl -4fsS ifconfig.me)
mkdir -p /usr/local/etc/xray /var/lib/vps

read -rp "Enter your domain (A record must point to this VPS): " DOMAIN
DOMAIN="${DOMAIN%.}"
[[ -z "$DOMAIN" ]] && { echo -e "${red}Domain cannot be empty.${nc}"; exit 1; }

echo "$DOMAIN" | tee /usr/local/etc/xray/domain /root/domain >/dev/null
DNS_IP=$(dig +short A "$DOMAIN" @1.1.1.1 | head -n1 || true)

echo -e "${blue}VPS IPv4 : ${green}$IP${nc}"
echo -e "${blue}DNS IPv4 : ${green}${DNS_IP:-not found}${nc}"
if [[ "$DNS_IP" != "$IP" ]]; then
    echo -e "${yellow}DNS is not pointing to this VPS yet.${nc}"
    echo -e "Create/update this record manually: A  $DOMAIN  ->  $IP"
    echo -e "No provider API, API key, or token is used by this script."
    exit 2
fi

echo -e "${green}Domain is correctly pointed to this VPS.${nc}"

cat > /var/lib/vps/domain-info <<EOF
DOMAIN=$DOMAIN
PUBLIC_IP=$IP
DNS_IP=$DNS_IP
UPDATED_AT=$(date -Is)
EOF
