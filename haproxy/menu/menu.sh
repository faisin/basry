#!/usr/bin/env bash
# ============================================================
# BASRY VPS PANEL — # VPN ANAK LOMBOK
# Lightweight terminal dashboard
# ============================================================
set -o pipefail

# ---------- Theme (No Pure White - Hardcoded Overhaul) ----------
RST='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; CYAN='\033[36m'
NEON_CYAN='\033[96m'; NEON_GREEN='\033[92m'; GOLD='\033[93m'; PURPLE='\033[95m'
BG_CYAN='\033[46m'; BLACK='\033[30m'

W=72
command_exists(){ command -v "$1" >/dev/null 2>&1; }

get_ip(){
  local ip=''
  if command_exists curl; then ip=$(curl -4fsS --connect-timeout 3 --max-time 5 https://ipv4.icanhazip.com 2>/dev/null || true); fi
  if [[ -z "$ip" ]] && command_exists wget; then ip=$(wget -qO- --timeout=5 https://ipv4.icanhazip.com 2>/dev/null || true); fi
  printf '%s' "${ip:-Unknown}" | tr -d '[:space:]'
}
get_domain(){
  local d=''
  [[ -r /usr/local/etc/xray/domain ]] && d=$(head -n1 /usr/local/etc/xray/domain 2>/dev/null || true)
  [[ -z "$d" && -r /root/domain ]] && d=$(head -n1 /root/domain 2>/dev/null || true)
  printf '%s' "${d:-Not configured}"
}
get_cpu(){
  if command_exists top; then
    local v; v=$(top -bn1 2>/dev/null | awk -F',' '/Cpu\(s\)/ {gsub(/[^0-9.]/,"",$4); printf "%.0f",100-$4; exit}')
    [[ -n "$v" ]] && printf '%s%%' "$v" && return
  fi
  printf 'N/A'
}
get_mem(){ free -h 2>/dev/null | awk 'NR==2{printf "%s / %s",$3,$2}' || printf 'N/A'; }
get_disk(){ df -h / 2>/dev/null | awk 'NR==2{printf "%s / %s (%s)",$3,$2,$5}' || printf 'N/A'; }
get_uptime(){ uptime -p 2>/dev/null | sed 's/^up //' || printf 'N/A'; }

state(){
  local svc="$1" label="$2"
  if command_exists systemctl && systemctl is-active --quiet "$svc" 2>/dev/null; then
    printf "${NEON_GREEN}●${RST} ${NEON_CYAN}%-10s${RST}" "$label"
  elif command_exists systemctl && systemctl is-enabled --quiet "$svc" 2>/dev/null; then
    printf "${GOLD}●${RST} ${DIM}%-10s${RST}" "$label"
  else
    printf "${RED}●${RST} ${DIM}%-10s${RST}" "$label"
  fi
}

header(){
  clear
  printf "${NEON_CYAN}══════════════════════════════════════════════════════════════════════${RST}\n"
  printf "  ${BG_CYAN}${BLACK}${BOLD} BASRY VPS PANEL ${RST} ${GOLD}${BOLD}Aurora Edition [Pro Style]${RST}\n"
  printf "  ${DIM}Secure Management • VPN Tunneling • Xray Core${RST}\n"
  printf "${NEON_CYAN}══════════════════════════════════════════════════════════════════════${RST}\n\n"
}

server_card(){
  local ip domain os up cpu mem disk
  ip=$(get_ip); domain=$(get_domain)
  os=$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || true)
  up=$(get_uptime); cpu=$(get_cpu); mem=$(get_mem); disk=$(get_disk)
  
  printf "${CYAN}┌─[ ${GOLD}${BOLD}SERVER OVERVIEW${RST} ${CYAN}]─────────────────────────────────────────────┐${RST}\n"
  printf "${CYAN}│${RST} ${NEEN_CYAN:-${NEON_CYAN}}IP Address${RST} : ${NEON_CYAN}%-52s${CYAN}│${RST}\n" "$ip"
  printf "${CYAN}│${RST} ${NEON_CYAN}Domain    ${RST} : ${GOLD}%-52s${CYAN}│${RST}\n" "$domain"
  printf "${CYAN}│${RST} ${NEON_CYAN}OS System ${RST} : ${NEON_CYAN}%-52s${CYAN}│${RST}\n" "${os:-Unknown}"
  printf "${CYAN}│${RST} ${NEON_CYAN}Uptime    ${RST} : ${NEON_CYAN}%-52s${CYAN}│${RST}\n" "$up"
  printf "${CYAN}│${RST} ${NEON_CYAN}CPU Load  ${RST} : ${NEON_CYAN}%-52s${CYAN}│${RST}\n" "$cpu"
  printf "${CYAN}│${RST} ${NEON_CYAN}Memory    ${RST} : ${NEON_CYAN}%-52s${CYAN}│${RST}\n" "${mem:-N/A}"
  printf "${CYAN}│${RST} ${NEON_CYAN}Disk Space${RST} : ${NEON_CYAN}%-52s${CYAN}│${RST}\n" "${disk:-N/A}"
  printf "${CYAN}└─────────────────────────────────────────────────────────────────────┘${RST}\n"
}

services(){
  printf "\n${PURPLE}┌─[ ${GOLD}${BOLD}SERVICE MONITOR${RST} ${PURPLE}]─────────────────────────────────────────────┐${RST}\n"
  printf "${PURPLE}│${RST}  %b  %b  %b  %b ${PURPLE}│${RST}\n" "$(state xray Xray)" "$(state nginx Nginx)" "$(state ssh SSH)" "$(state cron Cron)"
  printf "${PURPLE}│${RST}  %b  %b  %b  %b ${PURPLE}│${RST}\n" "$(state dropbear Dropbear)" "$(state stunnel4 Stunnel)" "$(state fail2ban Fail2ban)" "$(state ws-proxy WS-Proxy)"
  printf "${PURPLE}└─────────────────────────────────────────────────────────────────────┘${RST}\n"
}

item(){ printf " ${NEON_GREEN}%2s${RST} ${DIM}│${RST} ${NEON_CYAN}%-23s${RST} ${DIM}│ %s${RST}\n" "$1" "$2" "$3"; }

menu(){
  printf "\n${GREEN}┌─[ ${GOLD}${BOLD}VPN & ACCESS CONTROL${RST} ${GREEN}]──────────────────────────────────┐${RST}\n"
  item '1' 'SSH / OpenVPN' 'account • trial • renew • delete'
  item '2' 'VMess' 'account management'
  item '3' 'VLESS' 'account management'
  item '4' 'Trojan' 'account management'
  item '5' 'Shadowsocks' 'WS account management'
  printf "${GREEN}├─[ ${GOLD}${BOLD}SYSTEM & TOOLS${RST} ${GREEN}]───────────────────────────────────────┤${RST}\n"
  item '6' 'System Settings' 'domain • DNS • BBR • bandwidth'
  item '7' 'Tor' 'enable • disable • status'
  item '8' 'Xray Logs' 'connection / service logs'
  item '9' 'Service Status' 'full service overview'
  item '10' 'Clear RAM Cache' 'release filesystem cache'
  item '11' 'Reboot VPS' 'restart server safely'
  printf "${GREEN}├─────────────────────────────────────────────────────────────────────┤${RST}\n"
  item '0' 'Refresh Dashboard' 'reload status'
  item 'X' 'Exit Panel' 'close dashboard'
  printf "${GREEN}└─────────────────────────────────────────────────────────────────────┘${RST}\n"
}

pause(){ printf "\n${DIM}Press Enter to return to dashboard...${RST}"; read -r; }

run(){
  local opt confirm
  while :; do
    header; server_card; services; menu
    printf "\n${GOLD}┌─────────────────────────────────────────────────────────────────────┐${RST}\n"
    printf "${GOLD}│${RST} ${NEON_CYAN}Select Action [0-11, X]:${RST} "
    read -r opt
    case "$opt" in
      0|'') ;;
      1) clear; m-sshovpn; pause;;
      2) clear; m-vmess; pause;;
      3) clear; m-vless; pause;;
      4) clear; m-trojan; pause;;
      5) clear; m-ssws; pause;;
      6) clear; m-system; pause;;
      7) clear; m-tor; pause;;
      8) clear; xray-log; pause;;
      9) clear; running; pause;;
      10) clear; clearcache 2>/dev/null || clear_ram_cache 2>/dev/null || true; pause;;
      11) printf "${GOLD}Reboot VPS sekarang? [y/N]: ${RST}"; read -r confirm; if [[ "$confirm" =~ ^[Yy]$ ]]; then printf "${GOLD}Rebooting...${RST}\n"; sleep 2; /sbin/reboot; fi;;
      [xX]) clear; printf "${NEON_CYAN}BASRY VPS PANEL${RST}\n${NEON_GREEN}Panel ditutup dengan aman.${RST}\n"; exit 0;;
      *) printf "${RED}✕ Pilihan tidak valid.${RST}\n"; sleep 1;;
    esac
  done
}

main(){
  [[ $EUID -eq 0 ]] || { printf "${RED}Run this panel as root.${RST}\n"; exit 1; }
  run
}
main "$@"
