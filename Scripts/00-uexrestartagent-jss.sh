#!/bin/bash

loggedInUser=`/bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }' | grep -v root`

##########################################################################################
##								Paramaters for Branding									##
##########################################################################################

title="Your IT Deparment"

#Jamf Pro 10 icon if you want another custom one then please update it here.
customLogo="/Library/Application Support/JAMF/Jamf.app/Contents/Resources/AppIcon.icns"

#if you you jamf Pro 10 to brand the image for you self sevice icon will be here
SelfServiceIcon="/Users/$loggedInUser/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png"

##########################################################################################
##########################################################################################
##							Do not make any changes below								##
##########################################################################################
##########################################################################################
# 
# Restart notification checks the plists in the ../UEX/logout2.0/ folder to notify & force a
# restart if required.
# 
# Name: restart-notification.sh
# Version Number: 3.7
# 
# Created Jan 18, 2016 by 
# David Ramirez (David.Ramirez@adidas-group.com)
#
# Updates January 23rd, 2017 by
# DR = David Ramirez (David.Ramirez@adidas-group.com) 
# 
# Copyright (c) 2018 the adidas Group
# All rights reserved.
##########################################################################################
########################################################################################## 

##########################################################################################
##						STATIC VARIABLES FOR CocoaDialog DIALOGS						##
##########################################################################################

CocoaDialog="/Library/Application Support/JAMF/UEX/resources/cocoaDialog.app/Contents/MacOS/CocoaDialog"

##########################################################################################


##########################################################################################
##							STATIC VARIABLES FOR JH DIALOGS								##
##########################################################################################

jhPath="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

#if the icon file doesn't exist then set to a standard icon
if [[ -e "$SelfServiceIcon" ]]; then
	icon="$SelfServiceIcon"
elif [ -e "$customLogo" ] ; then
	icon="$customLogo"
else
	icon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertNoteIcon.icns"
fi
##########################################################################################

##########################################################################################
# 										LOGGING PREP									 #
##########################################################################################
# logname=$(echo $packageName | sed 's/.\{4\}$//')
# logfilename="$logname".log
logdir="/Library/Application Support/JAMF/UEX/UEX_Logs/"
# resulttmp="$logname"_result.log
##########################################################################################

##########################################################################################
# 										Functions										 #
##########################################################################################

fn_getPlistValue () {
	/usr/libexec/PlistBuddy -c "print $1" /Library/Application\ Support/JAMF/UEX/$2/"$3"
}

logInUEX () {
	sudo echo $(date)	$compname	:	"$1" >> "$logfilepath"
}

logInUEX4DebugMode () {
	if [ $debug = true ] ; then	
		logMessage="-DEBUG- $1"
		logInUEX $logMessage
	fi
}

log4_JSS () {
	sudo echo $(date)	$compname	:	"$1"  | tee -a "$logfilepath"
}

##########################################################################################
##			CALCULATIONS TO SEE IF A RESTART HAS OCCURRED SINCE BEING REQUIRED			##
##########################################################################################

lastReboot=`date -jf "%s" "$(sysctl kern.boottime | awk -F'[= |,]' '{print $6}')" "+%s"`
lastRebootFriendly=`date -r$lastReboot`

rundate=`date +%s`

plists=`ls /Library/Application\ Support/JAMF/UEX/restart_jss/ | grep ".plist"`

set -- "$plists" 
IFS=$'\n' ; declare -a plists=($*)  
unset IFS

for i in "${plists[@]}" ; do
	# Check all the plist in the folder for any required actions
	# if the user has already had a fresh restart then delete the plist
	# other wise the advise and schedule the logout.
	# name=`/usr/libexec/PlistBuddy -c "print name" "/Library/Application Support/JAMF/UEX/restart_jss/$i"`
	# packageName=`/usr/libexec/PlistBuddy -c "print packageName" "/Library/Application Support/JAMF/UEX/restart_jss/$i"`
	# plistrunDate=`/usr/libexec/PlistBuddy -c "print runDate" "/Library/Application Support/JAMF/UEX/restart_jss/$i"`

	name=$(fn_getPlistValue "name" "restart_jss" "$i")
	packageName=$(fn_getPlistValue "packageName" "restart_jss" "$i")
	plistrunDate=$(fn_getPlistValue "runDate" "restart_jss" "$i")
	runDateFriendly=`date -r $plistrunDate`
	
# 	echo lastReboot is $lastReboot
# 	echo plistRunDate is $plistRunDate
	
	timeSinceReboot=`echo "${lastReboot} - ${plistrunDate}" | bc`
	
	#######################
	# Logging files setup #
	#######################
	logname=$(echo $packageName | sed 's/.\{4\}$//')
	logfilename="$logname".log
	resulttmp="$logname"_result.log
	logfilepath="$logdir""$logfilename"
	resultlogfilepath="$logdir""$resulttmp"
	
# 	echo timeSinceReboot is $timeSinceReboot
	if [[ $timeSinceReboot -gt 0 ]] || [ -z "$plistrunDate" ]  ; then
		# the computer has rebooted since $runDateFriendly
		#delete the plist
		logInUEX "Deleting the restart plsit $i because the computer has rebooted since $runDateFriendly"
		sudo rm "/Library/Application Support/JAMF/UEX/restart_jss/$i"
	else 
		# the computer has NOT rebooted since $runDateFriendly
		lastline=`awk 'END{print}' "$logfilepath"`
		if [[ "$lastline" != *"Prompting the user"* ]] ; then 
			logInUEX "The computer has NOT rebooted since $runDateFriendly"
			logInUEX "Prompting the user that a restart is required"
		fi
		restart="true"
	fi
done

##########################################################################################

##########################################################################################
## 							Login Check Run if no on is logged in						##
##########################################################################################
# no login  RUN NOW
# (skip to install stage)
loggedInUser=`/bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }' | grep -v root`

##########################################################################################
##					Notification if there are scheduled restarts						##
##########################################################################################

sleep 15
otherJamfprocess=`ps aux | grep jamf | grep -v grep | grep -v launchDaemon | grep -v jamfAgent | grep -v uexrestartagent`
otherJamfprocess+=`ps aux | grep [Ss]plashBuddy`
if [[ "$restart" == "true" ]] ; then
	while [[ $otherJamfprocess != "" ]] ; do 
		sleep 15
		otherJamfprocess=`ps aux | grep jamf | grep -v grep | grep -v launchDaemon | grep -v jamfAgent | grep -v uexrestartagent`
		otherJamfprocess+=`ps aux | grep [Ss]plashBuddy`
	done
fi

# only run the restart command once all other jamf policies have completed
if [[ $otherJamfprocess == "" ]] ; then 
	if [[ "$restart" == "true" ]] ; then
		
		if [ $loggedInUser ] ; then
		# message
		notice='In order for the changes to complete you must restart your computer. Please save your work and click "Restart Now" within the allotted time. 
	
Your computer will be automatically restarted at the end of the countdown.'
	
		#notice
		restartclickbutton=`"$jhPath" -windowType hud -lockHUD -windowPostion lr -title "$title" -description "$notice" -icon "$icon" -timeout 3600 -countdown -alignCountdown center -button1 "Restart Now"`
	
			# force restart
# 			sudo shutdown -r now
			
			# Nicer restart (http://apple.stackexchange.com/questions/103571/using-the-terminal-command-to-shutdown-restart-and-sleep-my-mac)
			osascript -e 'tell app "System Events" to restart'
		else
			# force restart
			# while no on eis logged in you can do a force shutdown

			logInUEX "no one is logged in forcing a restart."
			sudo shutdown -r now
			# Nicer restart (http://apple.stackexchange.com/questions/103571/using-the-terminal-command-to-shutdown-restart-and-sleep-my-mac)
# 			osascript -e 'tell app "System Events" to restart'
		fi
	fi
fi

##########################################################################################

exit 0

##########################################################################################
##									Version History										##
##########################################################################################
# 
# 
# Jan 18, 2016 	v1.0	--DR--	Stage 1 Delivered
# Sep 5, 2016 	v2.0	--DR--	Logging added
# Apr 24, 2018 	v3.7	--DR--	Funtctions added
# 
# 