![Release](https://img.shields.io/badge/release-beta-yellow.svg)
![Language](https://img.shields.io/badge/made%20with-bash-brightgreen.svg)
![License](https://img.shields.io/badge/license-GPLv3-blue.svg)
![LastUpdate](https://img.shields.io/badge/last%20update-2020%2F03-orange.svg)
![TestedOn](https://img.shields.io/badge/tested%20on-Kali%20Linux-red.svg)

# Dsturb
Network Traffic Controller

Tested On: Kali Linux, Debian 10, DeepinOS, Mint

### Installation
Clone this repo using git clone
```
git clone https://github.com/avivbintangaringga/dsturb.git
```
Then go to the package directory and install
```
make install
```
### Getting Started
Helper contents
    
	Options:
            -c  --connect                     Enable internet access on target
            -d  --disconnect                  Disable internet access on target
            -r  --randomize                   Randomize interface's MAC Address
            -s  --scan      [scanner]         Host Scanner arp-scan(default),nmap,netdiscover
            -e  --exclude   [IP,IP,IP,...]    Exclude the following IP Addresses
            -L  --limit     [rate-limit]      Limit bandwith for target
            -h  --help                        Display help
    
         Supported rate limit units:
             b   ->  bits per second
             k   ->  kilobits per second
             m   ->  megabits per second
             g   ->  gigabits per second
             t   ->  terabits per second
             B   ->  Bytes per second
             K   ->  Kilobytes per second
             M   ->  Megabytes per second
             G   ->  Gigabytes per second
             T   ->  Terabytes per second
             (default: b)
    
             e.g: 10K, 500K, 1M, 10M
### Examples
You can run to interactive mode with just following comand
```
dsturb
```
Forward target internet access and keep current MAC Address
```
dsturb -c wlp3s0
```
Limit target bandwidth
```
dsturb -cL 50K wlp3s0
```
Limit target bandwidth with one excluded IP Address 
n.b: Your IP Address is always be excluded, so you don't have to exclude it explicitly
```
dsturb -cL 1M -e 192.168.1.20 wlp3s0
```
Limit target bandwidth with many excluded IP Addresses
```
dsturb -cL 50K -e 192.168.1.20,192.168.1.30,192.168.1.40 wlp3s0
```
Drop internet access and randomize interface's MAC Address before starting
```
dsturb -dr wlp3s0
```
Drop and exclude IP Addresses
```
dsturb -dre 192.168.1.20,192.168.1.30 wlp3s0
```
### Authors
[Aviv Bintang Aringga](https://github.com/avivbintangaringga)
[Syahid Nurrohim](https://github.com/syahidnurrohim)

