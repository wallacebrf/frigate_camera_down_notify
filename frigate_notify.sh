#!/bin/bash
#version 1.0 dated 8/29/2025
#By Brian Wallace
camera_name=()

#########################################################
#EMAIL SETTINGS USED IF CONFIGURATION FILE IS UNAVAILABLE
#These variables will be overwritten with new corrected data if the configuration file loads properly. 
email_address="email@email.com"
from_email_address="email@email.com"
#########################################################


log_file_location="/mnt/volume1/logging/notifications"
lock_file_location="$log_file_location/frigate_notify.lock"
truenas_multireport_sendemail="/mnt/volume1/logging/multireport_sendemail.py"
email_type=3 	#0=ssmtp, 	#1=Synology Mail PLus server (sendmail), 	#2=msmtp, 	#3=TrueNAS truenas_multireport_sendemail
debug=0
frigate_address="http://192.168.1.101:30059"

nas_name="TrueNAS" #this is only needed if the script cannot access the server name over SNMP, or if the config file is unavailable and will be used in any error messages

camera_name+=("front_left")				#entry 0
camera_name+=("front_right")			#entry 1
camera_name+=("drive")					#entry 2
camera_name+=("patio")					#entry 3
camera_name+=("garage")					#entry 4
camera_name+=("shed")					#entry 5
camera_name+=("north_east")				#entry 6
camera_name+=("north_west")				#entry 7
camera_name+=("backyard")				#entry 8
camera_name+=("frontdoor")				#entry 9
camera_name+=("reardoor")				#entry 10
camera_name+=("apples")					#entry 11

#########################################
#Script Start
#########################################

#check that the required working directory is available, readable, and writable. it should be since we are root, but better check
if [ -d "$log_file_location" ]; then
	if [ -r "$log_file_location" ]; then
		if [ ! -r "$log_file_location" ]; then
			echo -e "ERROR - The script directory \"$log_file_location\" is not writable, exiting script"
			exit 1
		fi
	else
		echo -e "ERROR - The script directory \"$log_file_location\" is not readable, exiting script"
		exit 1
	fi
else
	echo -e "ERROR - The script directory \"$log_file_location\" is not available, exiting script"
	exit 1
fi

#create a lock file in the ramdisk directory to prevent more than one instance of this script from executing at once
if ! mkdir "$lock_file_location"; then
	echo -e "Failed to acquire lock.\n" >&2
	exit 1
fi
trap 'rm -rf $lock_file_location' EXIT #remove the lockdir on exit

##################################################################################################################
#Send Email Notification Function
##################################################################################################################
function send_email(){
#send_email $email_address $from_email_address $log_file_location "frigate_notify_email_contents.txt" "Your_Subject" "Your_Body" 3
#to_email_address=${1}
#from_email_address=${2}
#log_file_location=${3}
#log_file_name=${4}
#subject=${5}
#mail_body=${6}
#email type=${7}  
	#0=ssmtp
	#1=Synology Mail PLus server (sendmail)
	#2=msmtp
	#3=TrueNAS truenas_multireport_sendemail

	if [[ "${3}" == "" || "${4}" == "" || "${7}" == "" ]];then
		echo "Incorrect data was passed to the \"send_email\" function, cannot send email"
	else
		if [ -d "${3}" ]; then #make sure directory exists
			if [ -w "${3}" ]; then #make sure directory is writable 
				if [ -r "${3}" ]; then #make sure directory is readable 
					local now=$(date +"%T")
					echo "To: ${1} " > "${3}/${4}"
					echo "From: ${2} " >> "${3}/${4}"
					echo "Subject: ${5}" >> "${3}/${4}"
					#echo "" >> "${3}/${4}"
					echo -e "\n$now - ${6}\n" >> "${3}/${4}"
													
					if [[ "${1}" == "" || "${2}" == "" || "${5}" == "" || "${6}" == "" ]];then
						echo -e "\n\nOne or more email address parameters [to, from, subject, mail_body] was not supplied, Cannot send an email"
					else
						if [[ ${7} -eq 1 ]]; then #use Synology Mail Plus server "sendmail" command
						
							#verify MailPlus Server package is installed and running as the "sendmail" command is not installed in synology by default. the MailPlus Server package is required
							local install_check=$(/usr/syno/bin/synopkg list | grep MailPlus-Server)

							if [ "$install_check" = "" ];then
								echo "WARNING!  ----   MailPlus Server NOT is installed, cannot send email notifications"
							else
								local status=$(/usr/syno/bin/synopkg is_onoff "MailPlus-Server")
								if [ "$status" = "package MailPlus-Server is turned on" ]; then
									local email_response=$(sendmail -t < "${3}/${4}"  2>&1)
									if [[ "$email_response" == "" ]]; then
										echo -e "\nEmail Sent Successfully" |& tee -a "${3}/${4}"
									else
										echo -e "\n\nWARNING -- An error occurred while sending email. The error was: $email_response\n\n" |& tee "${3}/${4}"
									fi					
								else
									echo "WARNING!  ----   MailPlus Server NOT is running, cannot send email notifications"
								fi
							fi
						elif [[ ${7} -eq 0 ]]; then #use "ssmtp" command
							if ! command -v ssmtp &> /dev/null #verify the ssmtp command is available 
							then
								echo "Cannot Send Email as command \"ssmtp\" was not found"
							else
								local email_response=$(ssmtp "${1}" < "${3}/${4}"  2>&1)
								if [[ "$email_response" == "" ]]; then
									echo -e "\nEmail Sent Successfully" |& tee -a "${3}/${4}"
								else
									echo -e "\n\nWARNING -- An error occurred while sending email. The error was: $email_response\n\n" |& tee "${3}/${4}"
								fi	
							fi
						elif [[ ${7} -eq 2 ]]; then #use "msmtp" command
							if ! command -v msmtp &> /dev/null #verify the msmtp command is available 
							then
								echo "Cannot Send Email as command \"msmtp\" was not found"
							else
								local email_response=$(msmtp "${1}" < "${3}/${4}"  2>&1)
								if [[ "$email_response" == "" ]]; then
									echo -e "\nEmail Sent Successfully" |& tee -a "${3}/${4}"
								else
									echo -e "\n\nWARNING -- An error occurred while sending email. The error was: $email_response\n\n" |& tee "${3}/${4}"
								fi	
							fi
						elif [[ ${7} -eq 3 ]]; then #TrueNAS
							#https://github.com/oxyde1989/standalone-tn-send-email/tree/main
					
							#the command can only take one email address destination at a time. so if there are more than one email addresses in the list, we need to send them one at a time
							address_explode=(`echo "${1}" | sed 's/;/\n/g'`)
							local bb=0
							for bb in "${!address_explode[@]}"; do
								python3 "$truenas_multireport_sendemail" --subject "${5}" --to_address "${address_explode[$bb]}" --mail_body_html "$now - ${6}" --override_fromemail "${2}"
							done
						
						
						else 
							echo "Incorrect parameters supplied, cannot send email" |& tee "${3}/${4}"
						fi
					fi
				else
					echo "cannot send email as directory \"${3}\" does not have READ permissions"
				fi
			else
				echo "cannot send email as directory \"${3}\" does not have WRITE permissions"
			fi
		else
			echo "cannot send email as directory \"${3}\" does not exist"
		fi
	fi
}
							
post_url=$(curl -sS $frigate_address/api/metrics 2>&1)		

if [[ "$(echo -n "$post_url" | grep "Failed")" != "" ]]; then	
	if [ ! -r "$log_file_location/frigate_error.txt" ]; then
		now=$(date)
		echo "$now" > "$log_file_location/frigate_error.txt"
		send_email $email_address $from_email_address $log_file_location "frigate_notify_email_contents.txt" "Frigate OFFLINE" "WARNING - Frigate NVR is not responding." $email_type
	fi 
else
	if [ -r "$log_file_location/frigate_error.txt" ]; then
		send_email $email_address $from_email_address $log_file_location "frigate_notify_email_contents.txt" "Frigate ONLINE" "Frigate NVR has resumed normal operations." $email_type
		rm "$log_file_location/frigate_error.txt"
	fi 
fi

post_url=$(echo "$post_url" | grep "frigate_camera_fps")
		
camera_dead=$(echo "$post_url" | grep "0.0")
		
if [[ $debug -eq 1 ]]; then
	echo -e "Current Camera Frames Per Second:\n_________________________________\n\n"
	echo "$post_url"
	echo -e "\n\n"
fi
		
if [[ "$camera_dead" != "" ]]; then
	if [[ $debug -eq 1 ]]; then
		echo -e "Current Camera(s) Not Responding:\n_________________________________\n\n"
	fi
	counter=0
	for counter in "${!camera_name[@]}"; do
		if [[ "$(echo -n "$camera_dead" | grep "${camera_name[$counter]}")" != "" ]]; then
			#echo "Camera \"${camera_name[$counter]}\" is not responding"
			send_email $email_address $from_email_address $log_file_location "frigate_notify_email_contents.txt" "Frigate Camera \"${camera_name[$counter]}\" Down" "Attention - Camera \"${camera_name[$counter]}\" is not responding and Frigate is not consuming any frames from this camera." $email_type
			if [ ! -r "$log_file_location/${camera_name[$counter]}_error.txt" ]; then
				now=$(date)
				echo "$now" > "$log_file_location/${camera_name[$counter]}_error.txt"
			fi
		else
			if [ -r "$log_file_location/${camera_name[$counter]}_error.txt" ]; then
				send_email $email_address $from_email_address $log_file_location "frigate_notify_email_contents.txt" "Frigate Camera \"${camera_name[$counter]}\" ONLINE" "Camera \"${camera_name[$counter]}\" has resumed normal operation." $email_type
				rm "$log_file_location/${camera_name[$counter]}_error.txt"
			fi
		fi
	done
else
	counter=0
	for counter in "${!camera_name[@]}"; do
		if [ -r "$log_file_location/${camera_name[$counter]}_error.txt" ]; then
			send_email $email_address $from_email_address $log_file_location "frigate_notify_email_contents.txt" "Frigate Camera \"${camera_name[$counter]}\" ONLINE" "Camera \"${camera_name[$counter]}\" has resumed normal operation." $email_type
			rm "$log_file_location/${camera_name[$counter]}_error.txt"
		fi
	done
	#echo "All Cameras Operating"
fi

