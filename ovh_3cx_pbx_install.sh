#!/bin/bash
logfile="/tmp/ovh_3cx_pbx_install.sh.$(date +%Y-%m-%d_%H:%M).log"
function ask_yes_or_no() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}
tred=$(tput setaf 1)
tgreen=$(tput setaf 2)
tyellow=$(tput setaf 3)
tdef=$(tput sgr0)
MAC=$(cat /sys/class/net/e*/address)
RELEASE=$(lsb_release -d |cut -d "(" -f2 |cut -d")" -f1)
REL=$(lsb_release -d)
PASS=$(tr -dc 'A-Za-z0-9!?%=' < /dev/urandom | head -c 10)
echo "#####IBT OVH 3CX PBX install script#####"
echo "Please, enter hostname to use for device monitoring - e.g davroc3cx01.ibt.uk.com"
read NAME
if [[ "no" == $(ask_yes_or_no "Install will continue using $NAME as the hostname for monitoring. Are you sure?") || \
      "no" == $(ask_yes_or_no "Are you *really* sure?") ]]
then
    echo "Please re-enter hostname."
    read NAME
    if [[ "no" == $(ask_yes_or_no "Install will continue using $NAME as the hostname for monitoring. Are you sure?") || \
      "no" == $(ask_yes_or_no "Are you *really* sure?") ]]
      then
        echo "Skipped - please re-run script to begin again"
      exit 0
    fi
fi
echo "${tyellow}BY DEFAULT A RANDOM PASSWORD WILL BE CREATED FOR USER $USER, select no to create your own!!${tdef}"
if [ "no" == $(ask_yes_or_no "Generate random password for $USER? - ${tred}ensure to check final output for password used and record!${tdef}") ]
    then
        echo "Please enter password."
        read PASS
        if [[ "no" == $(ask_yes_or_no "Password will be set to $PASS, is that correct?") || \
          "no" == $(ask_yes_or_no "Are you *really* sure?") ]]
          then
            echo "Please re-run install script with correct details"
          exit 0
        fi
fi
echo "Set apt to use IPv4 only..."
echo "Acquire::ForceIPv4 \"true\";" | sudo tee /etc/apt/apt.conf.d/99force-ipv4
echo "Great, continuing to update packages and install monitoring..."
echo "Installing required tools..."
/usr/bin/sudo /usr/bin/apt -y update 2>&1
/usr/bin/sudo /usr/bin/apt -y upgrade 2>&1
/usr/bin/sudo /usr/bin/apt -y install net-tools dphys-swapfile gnupg2 sipgrep
#Debian 10 and v18
if [ $RELEASE == "buster" ]
then
# Download 3cx key
wget -O- http://downloads-global.3cx.com/downloads/3cxpbx/public.key | sudo apt-key add -
# update sources to include 3cx repos
echo "deb [trusted=yes] http://downloads-global.3cx.com/downloads/debian $RELEASE main" | sudo tee /etc/apt/sources.list.d/3cxpbx.list
echo "deb [trusted=yes] http://downloads-global.3cx.com/downloads/debian $RELEASE-testing main" | sudo tee /etc/apt/sources.list.d/3cxpbx-testing.list
fi
# Debian 12 and v20
if [ $RELEASE == "bookworm" ]
then
wget -O- https://repo.3cx.com/key.pub | gpg --dearmor | sudo tee /usr/share/keyrings/3cx-archive-keyring.gpg > /dev/null
echo "deb [arch=amd64 by-hash=yes signed-by=/usr/share/keyrings/3cx-archive-keyring.gpg] http://repo.3cx.com/3cx bookworm main" | tee /etc/apt/sources.list.d/3cxpbx.list
echo "deb [arch=amd64 by-hash=yes signed-by=/usr/share/keyrings/3cx-archive-keyring.gpg] http://repo.3cx.com/3cx bookworm-testing main" | tee /etc/apt/sources.list.d/3cxpbx-testing.list
fi
echo "Checking for updates..."
if ! /usr/bin/sudo /usr/bin/apt update 2>&1 | grep -q '^[WE]:'; then
    echo "${tgreen}Update check completed.${tdef}" 
else
    echo "${tred}Unable to check for updates - please verify internet connectivity.${tdef}"
    exit 1
fi
echo "setting user debian password..."
echo "debian:$PASS" | /usr/bin/sudo chpasswd
echo "Upgrading as needed..."
/usr/bin/sudo /usr/bin/apt -y upgrade
echo "Installing monitoring agent..."
/usr/bin/sudo /usr/bin/apt -y install zabbix-agent
echo "system updated and zabbix monitoring agent installed."
echo "Configuring monitoring agent..."
# edit zabbix_agentd.conf set zabbix server IP to 213.218.197.155 set hostname to $NAME
sed -i s/^Server=127.0.0.1/Server=213.218.197.155/ /etc/zabbix/zabbix_agentd.conf
sed -i s/^ServerActive=127.0.0.1/ServerActive=213.218.197.155/ /etc/zabbix/zabbix_agentd.conf
sed -i s/^\#.Hostname=/Hostname=$NAME/ /etc/zabbix/zabbix_agentd.conf
# specific zabbix agent monitoring options
#/usr/bin/curl -o /etc/zabbix/zabbix_agentd.conf.d/userparameter_rpi.conf https://raw.githubusercontent.com/danjeman/rpi-zabbix/main/userparameter_rpi.conf
#add iptables rule to permit passive monitoring
iptables -A INPUT -m state --state NEW -p tcp --dport 10050 -j ACCEPT
service iptables-save
/usr/bin/sudo /usr/sbin/service zabbix-agent restart
echo "${tgreen}Monitoring agent configured.${tdef}"
echo "Installing 3cx PBX..."
/usr/bin/sudo /usr/bin/apt -y install 3cxpbx
echo "Upgrading as needed..."
/usr/bin/sudo /usr/bin/apt clean all 2>&1
/usr/bin/sudo /usr/bin/apt -y update 2>&1
# Fix missing debendency libmediainfo
/usr/bin/wget http://security.debian.org/debian-security/pool/updates/main/libz/libzen/libzen0v5_0.4.37-1+deb10u1_amd64.deb
/usr/bin/wget http://ftp.de.debian.org/debian/pool/main/t/tinyxml2/libtinyxml2-6a_7.0.0+dfsg-1_amd64.deb
/usr/bin/wget http://ftp.de.debian.org/debian/pool/main/libm/libmms/libmms0_0.6.4-3_amd64.deb
/usr/bin/wget http://ftp.de.debian.org/debian/pool/main/libm/libmediainfo/libmediainfo0v5_18.12-2_amd64.deb
/usr/bin/dpkg -i libmms0_0.6.4-3_amd64.deb libtinyxml2-6a_7.0.0+dfsg-1_amd64.deb libzen0v5_0.4.37-1+deb10u1_amd64.deb libmediainfo0v5_18.12-2_amd64.deb
/usr/bin/sudo /usr/bin/apt clean all 2>&1
/usr/bin/sudo /usr/bin/apt -y update 2>&1
/usr/bin/sudo /usr/bin/apt -y upgrade 3cxpbx
/usr/bin/sudo 3CXLaunchWebConfigTool
echo "Below is a list of the info used for this setup - ${tred}take note for job sheet/asset info.${tdef}"
echo "${tyellow}Monitoring hostname =${tdef} $NAME"
echo "${tyellow}Password for debian =${tdef} $PASS"
echo "${tyellow}Debian version is =${tdef} $REL"
echo "${tyellow}MAC address =${tdef} $MAC."
echo "${tgreen}Please update helpdesk asset and ticket/job progress sheet.${tdef}"
echo "Goodbye"
