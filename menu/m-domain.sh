#!/bin/bash
# =========================================
# CHANGE DOMAIN VPS WITH DNS CHECK & AUTO RENEW SSL
# =========================================

# Color
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
white='\e[1;37m'
nc='\e[0m'

MYIP=$(wget -qO- ipv4.icanhazip.com || curl -s ifconfig.me)
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
    wget -q -O /root/cf.sh "https://raw.githubusercontent.com/faisin/basry/main/ssh/cf.sh"
    chmod +x /root/cf.sh && bash /root/cf.sh
    rm -f /root/crt.sh
    wget -q -O /root/crt.sh "https://raw.githubusercontent.com/faisin/basry/main/xray/crt.sh"
    chmod +x /root/crt.sh && bash /root/crt.sh
    #rm -f /root/slowdns.sh
    #wget -q -O /root/slowdns.sh "https://raw.githubusercontent.com/faisin/basry/main/slowdns/slowdns.sh"
    #chmod +x /root/slowdns.sh && bash /root/slowdns.sh

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

    # Continue installation
    rm -f /root/crt.sh
    wget -q -O /root/crt.sh "https://raw.githubusercontent.com/faisin/basry/main/xray/crt.sh"
    chmod +x /root/crt.sh && bash /root/crt.sh

    #rm -f /root/slowdns.sh
    #wget -q -O /root/slowdns.sh "https://raw.githubusercontent.com/faisin/basry/main/slowdns/slowdns.sh"
    #chmod +x /root/slowdns.sh && bash /root/slowdns.sh

else 
    echo -e "${red}Wrong Argument${nc}"
    exit 1
fi

clear
