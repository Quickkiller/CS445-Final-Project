#iptables.sh
#Accepts packets from users with an already established connection
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

#Places nmap scanning packets into honeypot
#Last IP address should be the honeypot IP, currently just a placeholder
iptables -t nat -A PREROUTING -i eth1 -p tcp --tcp-flags ALL FIN -j DNAT --to-destination 192.168.4.0
iptables -t nat -A PREROUTING -i eth1 -p tcp --tcp-flags ALL NONE -j DNAT --to-destination 192.168.4.0
iptables -t nat -A PREROUTING -i eth1 -p tcp --tcp-flags ALL FIN,PSH,URG -j DNAT --to-destination 192.168.4.0

#allows internal communication with loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

#Limits ICMP pings
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 3/min --limit-burst 10 -j ACCEPT

#accept to port 22, 80, and 443 (Common ports to ACCEPT) (Not sure if these rules are necessary for the purposes of the project)
#iptables -A INPUT -p tcp -m multiport --dports 22,80,443 -j ACCEPT

# Make make default drop
iptables -P INPUT -j DROP