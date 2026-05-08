#iptables.sh
#honeypot IP
honeypot="192.168.8.100"
limitBurst=10
#Accepts packets from users with an already established connection
sudo iptables -N ATTACK
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

#Places nmap scanning packets into honeypot
#Last IP address should be the honeypot IP, currently just a placeholder
sudo iptables -t nat -A PREROUTING -i eth1 -p tcp --tcp-flags ALL FIN -j DNAT --to-destination "$honeypot"
sudo iptables -t nat -A PREROUTING -i eth1 -p tcp --tcp-flags ALL SYN -j DNAT --to-destination "$honeypot"
sudo iptables -t nat -A PREROUTING -i eth1 -p tcp --tcp-flags ALL NONE -j DNAT --to-destination "$honeypot"
sudo iptables -t nat -A PREROUTING -i eth1 -p tcp --tcp-flags ALL FIN,PSH,URG -j DNAT --to-destination "$honeypot"

#allows internal communication with loopback
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A OUTPUT -o lo -j ACCEPT

#Limits ICMP pings
sudo iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 3/min --limit-burst "$limitBurst" -j ACCEPT

#Accepts port 22 with some limitations
sudo iptables -A INPUT -p tcp -dport 22 -m state --state NEW -j ATTACK
sudo iptables -A ATTACK -m recent --set --name ATTACKER
sudo iptables -A ATTACK --update --seconds 60 

# Make make default drop
sudo iptables -A INPUT -j DROP