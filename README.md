# Frigate Camera Down Notifier

Witht the release of Frigate 0.16 and the addition of the /api/metrics page, this script will allow for email notifications to be sent if:

1.) Frigate itself is not responding, Frigate returns to an online status 

2.) any cameras are offline, cameras return to an online status

The camera emails will be sent per camera. 

# Configuration

Configure the to and from email addresses to send any notiifcations
```
#########################################################
#EMAIL SETTINGS USED IF CONFIGURATION FILE IS UNAVAILABLE
#These variables will be overwritten with new corrected data if the configuration file loads properly. 
email_address="email@email.com"
from_email_address="email@email.com"
#########################################################
```

location on the file system where the script can save the temporary files needed for emails and for camera status tracking
```
log_file_location="/mnt/volume1/logging/notifications"
```

the scrip uses a lock file to ensure only one instance of the script is running at any given time
```
lock_file_location="$log_file_location/frigate_notify.lock"
```

location of the phython file needed to allow the script to send emails if the script is running on TrueNAS
```
truenas_multireport_sendemail="/mnt/volume1/logging/multireport_sendemail.py
```

the type of email client to use on the host system
```
email_type=3 	#0=ssmtp, 	#1=Synology Mail PLus server (sendmail), 	#2=msmtp, 	#3=TrueNAS truenas_multireport_sendemail
```

debug enable or disable to show more details on the terminal. set to a value of "1" to enable debugging mdoe
```
debug=0
```

address of the Frigate system to monitor
```
frigate_address="http://192.168.1.101:30059"
```
