#!/bin/bash

NETPLAN="etc/netplan/10-lxc.yaml"

CURRENT_IP_ADDR=$(hostname -I | awk '{print $1}')
NEW_IP_ADDR="192.168.16.21"

echo "Checking current IP Address..."
if ["$CURRENT_IP_ADDR"!="$NEW_IP_ADDR"]; then
 #Notify the user has old IP Address.
 echo "+++ Replacing undesired IP Address ($CURRENT_IP_ADDR) to $NEW_IP_ADDR +++"
 #Create a backup of the old netplan.
 sudo cp "$NETPLAN" "${NETPLAN}.bak"
 #Modify the ip address.
 sudo netplan set ethernets.eth0.addresses=["$NEW_IP_ADDR/24"]
 #Apply changes.
 sudo netplan apply
 #Update the /etc/hosts file. Deleting the line that has the text server1, then adding the new ip address we want at the end of the file.
 sudo sed -i "/server1/d" /etc/hosts && echo "192.168.16.21 server1" | sudo tee -a /etc/hosts
 #Notify user.
 echo "IP address updated to $NEW_IP_ADDR"
#Case where current ip address and the new ip address are equal.
else
 echo "Updating the IP address is not necessary."
fi
echo "IP Address configuration finished."

echo "Checking installed packages..."
#Check if apache is installed, if not do a apt update and install it.
if ! dpkg -s apache2 >/dev/null 2>&1; then
 echo "Installing apache2."
 sudo apt update
 sudo apt install -y apache2
else
 echo "apache2 already installed."
fi
#Check if squid is installed, if not do a apt update and install it.
if ! dpkg -s squid >/dev/null 2>&1; then
 echo "Installing squid." 
 sudo apt update
 sudo apt install -y squid
else 
 echo "squid already installed."
fi
echo "Package configuration finished."

echo "Creating users..."

USERS_LIST=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")
DENNIS_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"

#For loop in the USERS_LIST.
for USER in "${USERS_LIST[@]}"; do
 #Create the users that does not exist.
 if ! id  "$USER" &>/dev/null; then
  if ["$USER"=="dennis"]; then
   sudo useradd -m -s /bin/bash -G sudo "$USER"
  else 
   sudo useradd -m -s /bin/bash "$USER"
  fi
 echo "The user $USER was just created."
 else
  echo "The user $USER already exists."
 fi
 
 #SSH directory generator.
 SSH_TEMP_DIR="/home/$USER/.ssh"
 sudo mkdir -p "$SSH_TEMP_DIR"
 sudo chown "$USER":"$USER" "$SSH_TEMP_DIR"
 sudo chmod 700 "$SSH_TEMP_DIR"

 #Generate the keys.
 if [! -f "$SSH_TEMP_DIR/id_rsa"]; then
  sudo -u "$USER" ssh-keygen -t rsa -b 4096 -f "$SSH_DIR/id_rsa" -N ""
 fi
 if [! -f "$SSH_TEMP_DIR/id_ed25519"]; then
  sudo -u "$USER" ssh-keygen -t rsa -b ed25519 -f "$SSH_DIR/id_ed25519" -N ""
 fi

 #Generated keys are now auth keys.
 AUTH_KEYS="$SSH_TEMP_DIR/authorized_keys"
 sudo touch "$AUTH_KEYS"
 sudo chown "$USER":"$USER" "$AUTH_KEYS"
 sudo chmod 600 "$AUTH_KEYS"

 #In case the current user is dennis.
 if ["$USER"=="dennis"]; then
  grep -qxF "$DENNIS_PUBLICKEY" "AUTH_KEYS" || echo "$DENNIS_PUBLICKEY" | sudo tee -a "$AUTH_KEYS" >/dev/null
 fi
done

echo "All the missing users were created."

