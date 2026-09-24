#!/bin/bash
# =========================================
# SYSTEM MENU
# =========================================

# ---------- Colors ----------
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
cyan='\e[1;36m'
white='\e[1;37m'
nc='\e[0m'

# ---------- System Info ----------
MYIP=$(wget -qO- ipv4.icanhazip.com || curl -s ifconfig.me)
domain=$(cat /usr/local/etc/xray/domain 2>/dev/null || cat /root/domain 2>/dev/null)

# Function to display system status
show_system_status() {
    echo -e "${cyan}System Status:${nc}"
    
    # Check Xray status
    if systemctl is-active --quiet xray; then
        echo -e "  Xray: ${green}● RUNNING${nc}"
    else
        echo -e "  Xray: ${red}● STOPPED${nc}"
    fi
    
    # Check Nginx status
    if systemctl is-active --quiet nginx; then
        echo -e "  Nginx: ${green}● RUNNING${nc}"
    else
        echo -e "  Nginx: ${red}● STOPPED${nc}"
    fi
    
    # Show domain if exists
    if [[ -n "$domain" ]]; then
        echo -e "  Domain: ${cyan}$domain${nc}"
    fi
    
    echo ""
}

# Function to display menu
show_menu() {
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}             SYSTEM MENU               ${nc}"
    echo -e "${red}=========================================${nc}"
    echo ""
    
    # Show system status
    show_system_status
    
    echo -e " ${white}1${nc} Panel Domain"
    echo -e " ${white}2${nc} Speedtest VPS"
    echo -e " ${white}3${nc} Set Auto Reboot"
    echo -e " ${white}4${nc} Restart All Services"
    echo -e " ${white}5${nc} Bandwidth Monitor"
    echo -e " ${white}6${nc} Install TCP BBR"
    echo -e " ${white}7${nc} DNS Changer"
    echo -e " ${white}8${nc} Clear RAM Cache"
    echo -e " ${white}9${nc} System Information"
    echo ""
    echo -e "${red}=========================================${nc}"
    echo -e " ${white}0${nc} Back To Menu"
    echo -e   "Press ${yellow}x${nc} or Ctrl+C To-Exit"
    echo -e "${red}=========================================${nc}"
    echo ""
}

# Main menu loop
while true; do
    show_menu
    read -p " Select menu [0-9] or x: " opt
    
    case $opt in
        1)
            clear
            echo -e "${green}Opening Domain Panel...${nc}"
            sleep 1
            m-domain
            ;;
        2)
            clear
            echo -e "${green}Running Speedtest...${nc}"
            sleep 1
            speedtest
            ;;
        3)
            clear
            echo -e "${green}Opening Auto-Reboot Settings...${nc}"
            sleep 1
            auto-reboot
            ;;
        4)
            clear
            echo -e "${yellow}Restarting all services...${nc}"
            sleep 1
            restart
            ;;
        5)
            clear
            echo -e "${green}Opening Bandwidth Monitor...${nc}"
            sleep 1
            bw
            ;;
        6)
            clear
            echo -e "${yellow}Opening TCP BBR Installation...${nc}"
            sleep 1
            m-tcp
            ;;
        7)
            clear
            echo -e "${green}Opening DNS Changer...${nc}"
            sleep 1
            m-dns
            ;;
        8)
            clear
            echo -e "${yellow}Clearing RAM Cache...${nc}"
            sleep 1
            clearcache
            ;;
        9)
            clear
            echo -e "${cyan}Showing System Information...${nc}"
            sleep 1
            
            # Basic system info
            echo -e "${blue}=========================================${nc}"
            echo -e "${blue}          SYSTEM INFORMATION            ${nc}"
            echo -e "${blue}=========================================${nc}"
            echo ""
            echo -e "${cyan}Server IP:${nc} $MYIP"
            
            if [[ -n "$domain" ]]; then
                echo -e "${cyan}Domain:${nc} $domain"
            fi
            
            echo -e "${cyan}Uptime:${nc} $(uptime -p | sed 's/up //')"
            echo -e "${cyan}OS:${nc} $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '