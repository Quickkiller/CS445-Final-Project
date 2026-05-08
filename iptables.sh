#iptables.sh
#honeypot IP
honeypot="192.168.8.100"
limitBurst=10
#Accepts packets from users with an already established connection
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

#accept to port 22, 80, and 443 (Common ports to ACCEPT) (Not sure if these rules are necessary for the purposes of the project)
#iptables -A INPUT -p tcp -m multiport --dports 22,80,443 -j ACCEPT

# Make make default drop
sudo iptables -P INPUT -j DROP