#iptables.sh

# Variables
honeypot="192.168.8.100"
limitBurst=5
ext_if="eth0"
lan_if="eth1"
internal_net="192.168.4.0/24"
dmz_net="192.168.8.0/24"

echo "Resetting firewall..."
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -X

# Defaults
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

# Allowing loopback
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT

# Allowing existing connections
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ICMP limits
sudo iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 3/min --limit-burst $limitBurst -j ACCEPT

# UDP floods
sudo iptables -A INPUT -p udp -m limit --limit 10/sec -j ACCEPT
sudo iptables -A INPUT -p udp -j DROP

# SSH brute force
sudo iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set --name SSH
sudo iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 3 --name SSH -j DROP

# DMZ isolation
sudo iptables -A FORWARD -i $ext_if -d $dmz_net -j ACCEPT
sudo iptables -A FORWARD -s $internal_net -d $dmz_net -j ACCEPT
sudo iptables -A FORWARD -s $dmz_net -d $internal_net -j DROP

# Scans
sudo iptables -A INPUT -p tcp --syn -m conntrack --ctstate NEW -m recent --set --name SCAN
sudo iptables -A INPUT -p tcp --syn -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 10 --name SCAN -j DROP
sudo iptables -A INPUT -p tcp --tcp-flags ALL FIN -m recent --set --name SCAN
sudo iptables -A INPUT -p tcp --tcp-flags ALL FIN -m recent --update --seconds 60 --hitcount 5 --name SCAN -j DROP
sudo iptables -A INPUT -p tcp --tcp-flags ALL NONE -m recent --set --name SCAN
sudo iptables -A INPUT -p tcp --tcp-flags ALL NONE -m recent --update --seconds 60 --hitcount 5 --name SCAN -j DROP
sudo iptables -A INPUT -p tcp --tcp-flags ALL FIN,PSH,URG -m recent --set --name SCAN
sudo iptables -A INPUT -p tcp --tcp-flags ALL FIN,PSH,URG -m recent --update --seconds 60 --hitcount 5 --name SCAN -j DROP

# Honeypot routing
sudo iptables -t nat -A PREROUTING -i $ext_if -p tcp --syn -m recent --name SCAN --rcheck -j DNAT --to-destination $honeypot
sudo iptables -t nat -A PREROUTING -i $ext_if -p tcp --tcp-flags ALL FIN -j DNAT --to-destination $honeypot
sudo iptables -t nat -A PREROUTING -i $ext_if -p tcp --tcp-flags ALL NONE -j DNAT --to-destination $honeypot
sudo iptables -t nat -A PREROUTING -i $ext_if -p tcp --tcp-flags ALL FIN,PSH,URG -j DNAT --to-destination $honeypot

echo "Firewall is ready!"

# Note: ARP spoofing is Layer 2 (and not handled by iptables)