#!/bin/bash
#Ignore INT, TERM, HUP.
#trap '' INT TERM HUP
#Arguments states.
verbose=false
name_state=false
ip_state=false
hostentry_state=false
desired_name=""
desired_ip=""
hostentry_name=""
hostentry_ip=""

lan_interface=""

#Argument activators and assignation.
while [[ $# -gt 0 ]]; do
 #Condition to detect if the user desires -v
 if [[ "$1" == "-v"  || "$1" == "--verbose" ]]; then
  verbose=true
  shift
 #Condition to detect if the user wants to change the name.
 elif [[ "$1" == "-name" ]]; then
  name_state=true
  desired_name="$2"
  shift 2
 #Condition to detect if the user wants to change the ip.
 elif [[ "$1" == "-ip" ]]; then
  ip_state=true
  desired_ip="$2"
  shift 2
 #Condition to detect if the user called hostentry.
 elif [[ "$1" == "-hostentry" ]]; then
  hostentry_state=true
  hostentry_name="$2"
  hostentry_ip="$3"
  shift 3
 #In case does not exist.
 else 
  echo "Argument $1 does not exist." >&2
  exit 1
 fi
done
#Activation of verbose outputs.
log(){
 #If verbose's value us true...
 if $verbose; then
  #The value will be echoed.
  echo "$@"
 fi
}

#Start process of changing hostname will notifying user if necessary.
if $name_state; then
 #Get the current hostname.
 current_name=$(hostnamectl --static 2>/dev/null || hostname)
 #In case the desired and the current hostnames are the same do nothing.
 if [[ "$desired_name" == "$current_name" ]]; then
  log "Hostname is already $desired_name."
 #But if they are different we will change it.
 else
  #Notify user the hostname will be changed.
  log "Changing hostname to $desired_name..."
  #Change the hostname in /etc/hostname and notify any error.
  if ! echo "$desired_name" > /etc/hostname; then
   echo "ERROR in /etc/hostname modification." >&2
   exit 1
  fi
  #Change the hostname in /etc/hosts and notify any error.
  if grep -qE "\b$current_name\b" /etc/hosts; then
   #Replacement everytime the old hostname is used or mentioned with the new one.
   if ! sed -i.bak "s/\b$current_name\b/$desired_name/g" /etc/hosts; then
    echo "ERROR updating /etc/hosts."
    exit 1
   fi
   log "Hostname update was successful."
  else
   #No entry for current hostname, so add it.
   if ! echo "127.0.1.1   $desired_name" >> /etc/hosts; then
    #Notify the user there was an error.
    echo "ERROR: Was not possible to append to /etc/hosts.">&2
    #Finish process.
    exit 1
   fi
   #Notify changes.
   log "Added 127.0.1.1   $desired_name in /etc/hosts."
  fi
  if hostnamectl set-hostname "$desired_name" 2>/dev/null; then
   log "New hostname updated with hostnamectl command."
  elif hostname "$desired_name" 2>/dev/null; then
   log "New hostname updated with hostname command."
  else
   echo "ERROR: Hostname update in the system unsuccesful."
   exit 1
  fi
  log "Hostname changed from $current_name to $desired_name."
 fi
fi

#Assign a valid interface to assign the new IP ADDRES.
if ip_state=true; then
	if ip -4 addr show lan >/dev/null 2>&1; then
		lan_interface="lan"
	elif ip -4 addr show ens33 >/dev/null 2>&1; then
		lan_interface="ens33"
	#In case we are in a server or container.
	elif ip -4 addr show eth0 >/dev/null 2>&1; then
		lan_interface="eth0"
	#In case we have to take the default interface.
	else
		lan_interface=$(ip -4 route | awk '/default/ {print $5; exit}')
	fi
	
	#Get current IP Address and its prefix.
	current_ipAddressComplete=$(ip -4 addr show "$lan_interface" | awk '/inet/ {print $2}' | head -n 1)
	current_ipAddress=${current_ipAddressComplete%/*}
	current_prefix=${current_ipAddressComplete#*/}
	#Notify user if ip address wasn't found.
	if [[ -z "current_ipAddress" ]]; then
	 echo "ERROR: It was not possible to determine the current IP Address."
		exit 1
	fi
	#Verify if a change is necessary.
	if [[ "$current_ipAddress" == "$desired_ip" ]]; then
	 log "IP Address in $lan_interface is already $desired_ip."
	else
		log "Changing IP Address in $lan_interface. From $current_ipAddress to $desired_ip."
		hostname=$(hostnamectl --static 2>/dev/null || hostname)
		#Update /etc/hosts with new IP.
		if grep -qE "^[0-9.]+\s+$hostname(\s|$)" /etc/hosts; then
			#Use existing line to assign it.
			old_ipAddress=$(awk "\$2 == \"$hostname\" {print \$1"} /etc/hosts | head -n 1)
			if [[ "$old_ipAddress" != "$desired_ip" ]]; then
				if ! sed -i.bak "s/^$old_ipAddress[[:space:]]\+$hostname/$desired_ip $hostname/" /etc/hosts; then
					echo "ERROR: It was not possible to update /etc/hosts." >&2
					exit 1
				fi
				log "Changed $hostname IP from $old_ipAddress to $desired_ip in /etc/hosts."
			else
			 log "Is not necessary to change the IP in /etc/hosts."
			fi
		elif grep -q "$current_ipAddress" /etc/hosts; then
			if ! sed -i.bak "s/$current_ipAddress/$desired_ip/g" /etc/hosts; then
				echo "ERROR: It was not possible to update /etc/hosts/ IP" >&2
				exit 1
			fi
			log "$current_ipAddress was replaced with $desired_ip in /etc/hosts."
		#When there is no entry.
		else 
			if ! echo "$desired_ip   $hostname" >> /etc/hosts; then
				echo "ERROR: Was not possible to append the IP in /etc/hosts."
				exit 1
			fi
		fi
		
		#Netplan existance indicator.
		netplan_exists=false
		if [[ -n "$netplan_file" && -f "$netplan_file" ]]; then
		 if grep -q "$current_ipAddress" "$netplan_file"; then
		 	if ! sed -i.bak "s/$current_ipAddress/$desired_ip/g" "$netplan_file"; then
		 		echo "ERROR: It was nos possible to update netplan file."
		 		exit 1
		 	fi
		 	log "Netplan file updated with $desired_ip IP Address."
		 	
		 	if command -v netplan >/dev/null 2>&1; then
		 		if ! netplan apply; then
		 			echo "ERROR: netplan apply command failed."
		 			exit 1
		 		fi
		 		log "netplan apply was successful."
		 		netplan_exists = true
		 	fi
		 else
		 	log "Current IP $current_ipAddress was not found in the netplan file."
		 fi
		else
			log "No netplan file found, so netplan update was not necessary."
		fi
		
		if ! $netplan_exists; then
			if [[ -n "$current_ipAddressComplete" && -n "$current_prefix" ]]; then
			 #Remove old ip address.
			 ip addr del "$current_ipAddressComplete" dev "$lan_interface" 2>/dev/null
			 if ! ip addr add "$desired_ip"/"$current_prefix" dev "$lan_interface"; then
			 	echo "ERROR: Was not possible to apply $desired_ip/$current_prefix on $lan_interface" >&2
			 	exit 1
			 fi
			 ip link set "$lan_interface" up
			 log "The IP $desired_ip/$current_prefix was applied."
			else
				echo "ERROR: Was not possible to apply the new IP." >&2
				exit 1
			fi
		fi
		#Notify in the log system.
		logger -t configure-host.sh "IP changed from $current_ipAddress to $desired_ip on the interface $lan_interface."
		log "IP change completed."
	fi
fi


