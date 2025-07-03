#!/bin/bash
 
# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root." 
   exit 1
fi
 
# Generate a secure random password (16 characters)
NEW_PASS=$(openssl rand -base64 16)
 
# Change the root password
echo "debian:$NEW_PASS" | chpasswd
 
# Output the new password
echo "The new debian password is: $NEW_PASS"
