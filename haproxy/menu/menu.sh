#!/usr/bin/env bash
# ============================================================
# BASRY VPS PANEL — Aurora Edition
# Lightweight terminal dashboard
# ============================================================
set -o pipefail

# ---------- Theme (No Pure White) ----------
RST='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
BLACK='\033[30m'; RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'
BLUE='\033[34m'; MAGENTA='\033[35m'; CYAN='\033[36m'; LIGHT_CYAN='\033[96m'
BRIGHT_GRAY='\033[37m'; LIME='\033[92m'; GOLD='\033[93m'
BG_BLUE='\033[44m'; BG_CYAN='\033[46m'; BG_MAGENTA='\033[45m'

W=72
command_exists(){ command -v "$1" >/dev/null 2>&1; }
line(){ printf '%*s\n' "$W" '' | tr ' ' '─'; }
bar(){ printf "${CYAN}╭%*s╮${RST}\n" "$((W-2))" '' | sed 's/ /─/g'; }
endbar(){ printf "${CYAN}╰%*s╯${RST}\n" "$((W-2))" '' | sed 's/ /─/g'; }

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
    printf "${LIME}●${RST} ${LIGHT_CYAN}%-10s${RST}" "$label"
  elif command_exists systemctl && systemctl is-enabled --quiet "$svc" 2>/dev/null; then
    printf "${GOLD}●${RST} ${DIM}%-10s${RST}" "$label"
  else
    printf "${RED}●${RST} ${DIM}%-10s${RST}" "$label"
  fi
}

header(){
  clear
  printf "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${RST}\n"
  printf "${CYAN}║${RST}  ${BG_CYAN}${BLACK}${BOLD} BASRY VPS PANEL ${RST} ${GOLD}${BOLD}Aurora Edition${RST}                         ${CYAN}║${RST}\n"
  printf "${CYAN}║${RST}  ${DIM}Secure management • VPN • Xray • System                            ${CYAN}║${RST}\n"
  printf "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${RST}\n\n"
}

server_card(){
  local ip domain os up cpu mem disk
  ip=$(get_ip); domain=$(get_domain)
  os=$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || true)
  up=$(get_uptime); cpu=$(get_cpu); mem=$(get_mem); disk=$(get_disk)
  printf "${BLUE}╔══ ${GOLD}${BOLD}SERVER OVERVIEW${RST} ${BLUE}═══════════════════════════════════════════════╗${RST}\n"
  printf "${BLUE}║${RST} ${LIGHT_CYAN}IP${RST}       %-58s${BLUE}║${RST}\n" "$ip"
  printf "${BLUE}║${RST} ${LIGHT_CYAN}DOMAIN${RST}   %-58s${BLUE}║${RST}\n" "$domain"
  printf "${BLUE}║${RST} ${LIGHT_CYAN}OS${RST}       %-58s${BLUE}║${RST}\n" "${os:-Unknown}"
  printf "${BLUE}║${RST} ${LIGHT_CYAN}UPTIME${RST}   %-58s${BLUE}║${RST}\n" "$up"
  printf "${BLUE}║${RST} ${LIGHT_CYAN}CPU${RST}      %-58s${BLUE}║${RST}\n" "$cpu"
  printf "${BLUE}║${RST} ${LIGHT_CYAN}MEMORY${RST}   %-58s${BLUE}║${RST}\n" "${mem:-N/A}"
  printf "${BLUE}║${RST} ${LIGHT_CYAN}DISK${RST}     %-58s${BLUE}║${RST}\n" "${disk:-N/A}"
  printf "${BLUE}╚══════════════════════════════════════════════════════════════════════╝${RST}\n"
}

services(){
  printf "\n${MAGENTA}╔══ ${GOLD}${BOLD}SERVICE MONITOR${RST} ${MAGENTA}═══════════════════════════════════════════════╗${RST}\n"
  printf "${MAGENTA}║${RST}  %b %b %b %b ${MAGENTA}║${RST}\n" "$(state xray Xray)" "$(state nginx Nginx)" "$(state ssh SSH)" "$(state cron Cron)"
  printf "${MAGENTA}║${RST}  %b %b %b %b ${MAGENTA}║${RST}\n" "$(state dropbear Dropbear)" "$(state stunnel4 Stunnel)" "$(state fail2ban Fail2ban)" "$(state ws-proxy WS-Proxy)"
  printf "${MAGENTA}╚══════════════════════════════════════════════════════════════════════╝${RST}\n"
}

item(){ printf " ${GREEN}${BOLD}%2s${RST} ${DIM}│${RST} ${LIGHT_CYAN}%-24s${RST} ${DIM}│ %s${RST}\n" "$1" "$2" "$3"; }

menu(){
  printf "\n${GREEN}╔══ ${GOLD}${BOLD}VPN & ACCESS${RST} ${GREEN}═══════════════════════════════════════════════════╗${RST}\n"
  item 1 'SSH / OpenVPN' 'account • trial • renew • delete'
  item 2 'VMess' 'account management'
  item 3 'VLESS' 'account management'
  item 4 'Trojan' 'account management'
  item 5 'Shadowsocks' 'WS account management'
  printf "${GREEN}╠══ ${GOLD}${BOLD}SYSTEM & TOOLS${RST} ${GREEN}══════════════════════════════════════════════════╣${RST}\n"
  item 6 'System Settings' 'domain • DNS • BBR • bandwidth'
  item 7 'Tor' 'enable • disable • status'
  item 8 'Xray Logs' 'connection / service logs'
  item 9 'Service Status' 'full service overview'
  item 10 'Clear RAM Cache' 'release filesystem cache'
  item 11 'Reboot VPS' 'restart server safely'
  printf "${GREEN}╠══════════════════════════════════════════════════════════════════════╣${RST}\n"
  item 0 'Refresh Dashboard' 'reload status'
  item X 'Exit Panel' 'close dashboard'
  printf "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${RST}\n"
}

pause(){ printf "\n${DIM}Press Enter to return to dashboard...${RST}"; read -r; }

run(){
  local opt confirm
  while :; do
    header; server_card; services; menu
    printf "\n${GOLD}╭─ ACTION ─────────────────────────────────────────────────────────────╮${RST}\n"
    printf "${GOLD}│${RST} ${LIGHT_CYAN}Select${RST} ${CYAN}[0-11, X]${RST}: "
    read -r opt
    printf "${GOLD}╰──────────────────────────────────────────────────────────────────────╯${RST}\n"
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
      [xX]) clear; printf "${CYAN}${BOLD}BASRY VPS PANEL${RST}\n${LIME}Panel ditutup. Jalankan ${LIGHT_CYAN}menu${LIME} untuk membuka kembali.${RST}\n"; exit 0;;
      *) printf "${RED}✕ Pilihan tidak valid.${RST}\n"; sleep 1;;
    esac
  done
}

main(){
  [[ $EUID -eq 0 ]] || { printf "${RED}Run this panel as root.${RST}\n"; exit 1; }
  run
}
main "$@"
