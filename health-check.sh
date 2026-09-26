#!/bin/bash
LOG=/var/log/basry-health.log
mkdir -p /var/log/basry
exec >>$LOG 2>&1
check(){
 echo "[$(date)] $1: $(systemctl is-active $2 2>/dev/null || echo not-found)"
}
check Xray xray
check Nginx nginx
check OpenSSH ssh
check Dropbear dropbear
check HAProxy haproxy
