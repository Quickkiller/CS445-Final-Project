#snort.sh
#Variable for current IP
myIP="192.168.4.0/24"

#Alerts on the type of TCP scan
alert tcp any any -> "$myIP" any (msg:"TCP FIN SCAN"; sid:1000000; flags:F;)
alert tcp any any -> "$myIP" any (msg:"TCP SYN SCAN"; sid:1000001; flags:S;)
alert tcp any any -> "$myIP" any (msg:"TCP NULL SCAN"; sid:1000002; flags:0;)
alert tcp any any -> "$myIP" any (msg:"TCP XMAS SCAN"; sid:1000003; flags:FPU;)