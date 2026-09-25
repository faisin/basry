#!/bin/bash
# =========================================
# DNS SETUP slowdns - manual DNS, no API token
# =========================================

# Tambah rule INPUT UDP 5300 kalau belum adaiptables -C INPUT -p udp --dport 5300 -j ACCEPT 2>/dev/null || \
iptables -C INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p udp --dport 53 -j ACCEPT
iptables -C INPUT -p udp --dport 5300 -j ACCEPT 2>/dev/null || \
iptables -I INPUT -p udp --dport 5300 -j ACCEPT

# Tambah NAT redirect 53 -> 5300 kalau belum ada
iptables -t nat -C PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 2>/dev/null || \
iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300

# Simpan & reload
netfilter-persistent save
netfilter-persistent reload

# Remove old directory/file
rm -rf /root/nsdomain
rm -f nsdomain

# Get the main domain
domen=$(cat /usr/local/etc/xray/domain 2>/dev/null || cat /root/domain 2>/dev/null)

# Domain and subdomain configuration
subsl=$(</dev/urandom tr -dc 0-9 | head -c5)
DOMAIN="ipgivpn.my.id"
SUB_DOMAIN="${domen}"
NS_DOMAIN="asxns${subsl}.ipgivpn.my.id"
echo "$NS_DOMAIN" > /root/nsdomain

# DNS is intentionally configured manually; this script never accepts, stores, or sends API tokens.
echo ""
echo "Manual DNS setup required (no provider API/token is used)."
echo "Create the required DNS/NS record in your DNS provider before continuing."
echo "Nameserver host: ${NS_DOMAIN}"
echo "Target domain : ${SUB_DOMAIN}"
echo ""
read -rp "Press Enter after the DNS record has been created and propagated..." _

service cron reload
service cron restart

nameserver=$(cat /root/nsdomain)

#tambahan port openssh
grep -qxF "Port 2200" /etc/ssh/sshd_config || echo "Port 2200" >> /etc/ssh/sshd_config
grep -qxF "Port 2299" /etc/ssh/sshd_config || echo "Port 2299" >> /etc/ssh/sshd_config
sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding yes/g' /etc/ssh/sshd_config
service ssh restart
service sshd restart

#konfigurasi slowdns
rm -rf /etc/slowdns
mkdir -m 777 /etc/slowdns
wget -q -O /etc/slowdns/server.key "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/server.key"
wget -q -O /etc/slowdns/server.pub "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/server.pub"
wget -q -O /etc/slowdns/sldns-server "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/sldns-server"
wget -q -O /etc/slowdns/sldns-client "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/sldns-client"

chmod +x /etc/slowdns/server.key
chmod +x /etc/slowdns/server.pub
chmod +x /etc/slowdns/sldns-server
chmod +x /etc/slowdns/sldns-client

#wget -q -O /etc/systemd/system/client-sldns.service "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/client-sldns.service"
#wget -q -O /etc/systemd/system/server-sldns.service "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/server-sldns.service"

#install client-sldns.service
cat > /etc/systemd/system/client-sldns.service << END
[Unit]
Description=Client SlowDNS By SL
Documentation=https://nekopoi.care
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/etc/slowdns/sldns-client -udp 8.8.8.8:53 --pubkey-file /etc/slowdns/server.pub $nameserver 127.0.0.1:2200
Restart=on-failure

[Install]
WantedBy=multi-user.target
END

#install server-sldns.service
cat > /etc/systemd/system/server-sldns.service << END
[Unit]
Description=Server SlowDNS By SL
Documentation=https://nekopoi.care
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/etc/slowdns/sldns-server -udp :5300 -privkey-file /etc/slowdns/server.key $nameserver 127.0.0.1:2299
Restart=on-failure

[Install]
WantedBy=multi-user.target
END

#permission service slowdns
chmod +x /etc/systemd/system/client-sldns.service
chmod +x /etc/systemd/system/server-sldns.service
pkill sldns-server
pkill sldns-client

systemctl daemon-reload
systemctl stop client-sldns
systemctl stop server-sldns

systemctl enable client-sldns
systemctl enable server-sldns

systemctl start client-sldns
systemctl start server-sldns

systemctl restart client-sldns
systemctl restart server-sldns

echo -e "\e[1;32m Success.. \e[0m"
clear
echo "Success Pointing NS $nameserver With Target $domen"

