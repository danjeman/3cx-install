#!/bin/bash
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
MAC=$(cat /sys/class/net/eth0/address)
RELEASE=$(lsb_release -d |cut -d "(" -f2 |cut -d")" -f1)
REL=$(lsb_release -d)
PASS=e4syTr1d3nt
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
if [ "no" == $(ask_yes_or_no "Set debian user password to IBT default?") ]
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
ehco "Set apt to use IPv4 only..."
echo "Acquire::ForceIPv4 \"true\";" | sudo tee /etc/apt/apt.conf.d/99force-ipv4
echo "Great, continuing to update packages and install monitoring..."
echo "Installing required tools..."
/usr/bin/sudo /usr/bin/apt -y update 2>&1
/usr/bin/sudo /usr/bin/apt -y install net-tools dphys-swapfile gnupg2 sipgrep
# Download 3cx key
wget -O- http://downloads-global.3cx.com/downloads/3cxpbx/public.key | sudo apt-key add -
# update sources to include 3cx repos
echo "deb http://downloads-global.3cx.com/downloads/debian $RELEASE main" | sudo tee /etc/apt/sources.list.d/3cxpbx.list
echo "deb http://downloads-global.3cx.com/downloads/debian $RELEASE-testing main" | sudo tee /etc/apt/sources.list.d/3cxpbx-testing.list
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
/usr/bin/sudo /usr/bin/apt -y upgrade 3cxpbx=18.0.4.965
echo "Below is a list of the info used for this setup - ${tred}take note for job sheet/asset info.${tdef}"
echo "${tyellow}Monitoring hostname =${tdef} $NAME"
echo "${tyellow}Password for debian =${tdef} $PASS"
echo "${tyellow}Debian version is =${tdef} $REL"
echo "${tyellow}MAC address =${tdef} $MAC."
echo "${tgreen}Please update helpdesk asset and ticket/job progress sheet.${tdef}"
echo "Goodbye"
