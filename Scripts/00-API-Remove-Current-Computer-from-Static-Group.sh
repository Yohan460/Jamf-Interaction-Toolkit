#!/bin/bash
# set -x
jssGroupname="$4"
# jssGroupname="User Needs Help Clearing Disk Space"

# HIGHLY RECCOMEDED TO USE Encrypted-Script-Parameters
# Please check out the Encrypted-Script-Parameters Repo from jamfIT on GitHub
# https://github.com/jamfit/Encrypted-Script-Parameters
jss_url="$5"
jss_userEncrptyed="$6"
jss_passEncrptyed="$7"

# for testing
# jss_url="https://cubandave.local:8443"
# jss_userEncrptyed="U2FsdGVkX1/yDQNBhlSHn1I316TBLP9XAoQ5qBbBodE="
# jss_passEncrptyed="U2FsdGVkX1/yDQNBhlSHn65nLo71IAWNgCZ8Eae3DWY="

# DONT FORGET TO UPDATE THE SALT & PASS PHRASE
function DecryptString() {
    # Usage: ~$ DecryptString "Encrypted String"
    local SALT=""
    local K=""

    # for testing
    # local SALT="f20d03418654879f"
    # local K="1761bd1ea2ccce4268c74629"
    echo "${1}" | /usr/bin/openssl enc -aes256 -d -a -A -S "$SALT" -k "$K"
}

computerinGroup() {
	##CURL needs indivudual expansion
	# shellcheck disable=SC2086
	curl ${CURL_OPTIONS} --header "Accept:application/xml" --request "GET" --user "${jss_user}:${jss_pass}" "$jss_url/JSSResource/computergroups/id/$groupNameIDLookup" | grep "<id>$computerIDLookup</id>" 
}

jss_user=$(DecryptString "$jss_userEncrptyed")
jss_pass=$(DecryptString "$jss_passEncrptyed")


computersUDID=$(system_profiler SPHardwareDataType | awk '/UUID/ { print $3; }')
# computersUDID="CA984439-6E47-5D44-B52D-C855768AC39B"
# echo computersUDID is $computersUDID

CURL_OPTIONS="--location --insecure --silent --show-error --connect-timeout 30"

##CURL needs indivudual expansion
# shellcheck disable=SC2086
groupNameIDLookup=$( curl ${CURL_OPTIONS} --header "Accept: application/xml" --request "GET" --user "${jss_user}:${jss_pass}" "$jss_url/JSSResource/computergroups" | xmllint --format - | grep -B 1 ">$jssGroupname<" | /usr/bin/awk -F'<id>|</id>' '{print $2}' | sed '/^\s*$/d' )

##CURL needs indivudual expansion
# shellcheck disable=SC2086
computerIDLookup=$( curl ${CURL_OPTIONS} --header "Accept:application/xml" --request "GET" --user "${jss_user}:${jss_pass}" "$jss_url/JSSResource/computers/udid/$computersUDID" | xpath "/computer[1]/general/id/text()" 2>/dev/null )

GROUPXML="<computer_group><computer_deletions>
<computer>
<id>$computerIDLookup</id>
</computer>
</computer_deletions>
</computer_group>"

# echo $GROUPXML

if [[ -z "$groupNameIDLookup" ]] ; then
	#statements
	echo "groupNameIDLookup came back blank the group '$jssGroupname' may not exist"
	exit 1
fi

if [[ -z "$computerIDLookup" ]] ; then
	#statements
	echo "computerIDLookup came back blank the computer '$computersUDID' may not exist"
	exit 1
fi

# echo groupNameIDLookup is $groupNameIDLookup
# echo computerIDLookup is $computerIDLookup


if [[ "$( computerinGroup )" != "" ]] ; then
	#statements	
	echo "Attempting to upload changes to group '$jssGroupname'"
	curl -s -k -u "${jss_user}:${jss_pass}" "$jss_url/JSSResource/computergroups/id/$groupNameIDLookup" -X PUT -H "Content-type:application/xml" --data "$GROUPXML"


	if [[ "$( computerinGroup )" == "" ]] ; then
		echo comptuer successfully removed to group
		exit 0
		
	else
		echo computer is still in the  group
		exit 1
	fi
else
	echo "Computer '$computerIDLookup' is not in the group '$jssGroupname'"
	exit 0 
fi


