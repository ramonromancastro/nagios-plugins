#!/bin/bash

# check_fujitsu_irmc is a bash function to check Fujitsu iRMC Error and CSS status 
# Copyright (C) 2017 Ramon Roman Castro <ramonromancastro@gmail.com>
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see http://www.gnu.org/licenses/.
#
# @package    nagios-plugins
# @author     Ramon Roman Castro <ramonromancastro@gmail.com>
# @link       http://www.rrc2software.com
# @link       https://github.com/ramonromancastro/nagios-plugins

# Changelog:
#
# 0.1    First release
# 0.2    Add parameters by name
# 0.3    Add -v|--verbose parameter
# 0.4    Check LEDs exists
# 0.5    Add -i|--insecure,-vv parameter. Minor bugs fixed. Add System Components output
# 0.6    Fix result code OK when LED Blinking. Minor bugs fixed. Remove System Components output
#

#
# CONSTANTS
#

SCRIPTNAME="${0##*/}"
VERSION="0.6"

NAGIOS_OK=0
NAGIOS_WARNING=1
NAGIOS_CRITICAL=2
NAGIOS_UNKNOWN=3

#
# FUNCTIONS
#

verb() {
	VERB_LEVEL=$1
	VERB_MSG=$2
	COLOR=$((VERB_LEVEL + 34))
	if [ $VERBOSE -ge $VERB_LEVEL ]; then echo -e "\e[97m[ DEBUG$VERB_LEVEL ] $VERB_MSG\e[0m"; fi
}

version() { echo "$SCRIPTNAME v$VERSION"; }

shortusage() {
	cat << EOF
Usage: $SCRIPTNAME [OPTIONS]
$SCRIPTNAME -h for more information.
EOF
}

usage() { 
	cat << EOF

   $SCRIPTNAME [OPTIONS] - Check Fujitsu iRMC status

   This script check Error and CSS LED in Fujitsu iRMC

   OPTIONS:
      -H|--host <HOST>         iRMC hostname/address
      -u|--username <USERNAME> Number of days
      -p|--password <PASSWORD> Path depth report
      -i|--insecure            Use http instead https
      -h|--help                This help text
      -V|--version             Print version number
      -v|--verbose             Display debug info
      -vv                      Display more debug info

   EXAMPLES:
      $SCRIPTNAME --host 192.168.100.99 --username admin -password P@ssw0rd
      $SCRIPTNAME -h
      $SCRIPTNAME -v

EOF
}

#
# VARIABLES
#
HOST="127.0.0.1"
USERNAME="admin"
PASSWORD="P@ssw0rd"
SID=
VERBOSE=0
PROTOCOL=https
HTTP_RESPONSE=
NAGIOS_MESSAGE=
NAGIOS_CODE=
PERF="|'errors'=%s;;1;0;1"

#
# MAIN CODE
#

# Read parameters

if [ $# -eq 0 ]; then
	shortusage
	exit 1
fi

while [[ $# -gt 0 ]]; do
	key="$1"
	case $key in
		-H|--host)
			HOST="$2"
			shift
			;;
		-u|--username)
			USERNAME="$2"
			shift
			;;
		-p|--password)
			PASSWORD="$2"
			shift
			;;
		-h|--help)
			usage
			exit 1
			;;
		-V|--version)
			version
			exit 1
			;;
		-i|--insecure)
			PROTOCOL=http
			;;
		-v|--verbose)
			VERBOSE=1
			;;
		-vv)
			VERBOSE=2
			;;
		*)
			shortusage
			exit 1
			;;
	esac
	shift
done

# Check parameters

if [ -z "$HOST" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
	echo "iRMC UNKNOWN - Missing parameters"
	exit $NAGIOS_UNKNOWN
fi

# Login session

verb 1 "Attempting login into iRMC"
HTTP_RESPONSE=$(curl --silent --insecure --request POST --data "APPLY=99&P99=admin" --anyauth --user $USERNAME:$PASSWORD  "$PROTOCOL://$HOST/login" 2> /dev/null)

if [ $? -ne 0 ]; then
	echo "iRMC UNKNOWN - Cannot connect to iRMC"
	exit $NAGIOS_UNKNOWN
fi

# Base64 encoding
verb 1 "Parsing result"
SID=$(echo $HTTP_RESPONSE | grep -oP "sid=[0-9a-zA-Z\+/]+" | tail -1)
verb 1 "Parsed session identifier (SID): $SID"

if [[ "$SID" =~ sid=.+ ]]; then
	
	# Getting Component Status
	#verb 1 "Getting System Components webpage"
	#HTTP_RESPONSE=$(curl --silent --insecure --request GET "$PROTOCOL://$HOST/8?$SID" 2> /dev/null)
	#verb 2 "$HTTP_RESPONSE"
	
	#verb 1 "Parsing result"
	#CSS_FAIL=$(echo $HTTP_RESPONSE | sed 's/<tr/\n<tag/g; s/<\/tr/\n<tag/g' | grep "<tag" | grep '<img' | sed 's/<[^>]*>/\t/g; s/\t\t\t*/\t/g; s/^\t//g; s/\t$//g' | awk -F '\t' '{ print $5,"-",$2 }')
	#verb 2 "$HTTP_RESPONSE"
	
	verb 1 "Getting System Status webpage"
	HTTP_RESPONSE=$(curl --silent --insecure --request GET "$PROTOCOL://$HOST/7?$SID" 2> /dev/null)
	
	if [ $? -ne 0 ]; then
		NAGIOS_MESSAGE="iRMC UNKNOWN - Error getting System Status"
		NAGIOS_CODE=$NAGIOS_UNKNOWN
	else
		verb 1 "Parsing result"
		verb 2 "$HTTP_RESPONSE"
		ERROR_LED=$(echo $HTTP_RESPONSE | sed 's/<tr/\n<tag/g; s/<\/tr/\n<tag/g; s/<[^>]*>/ /g' | grep "Error LED" | awk '{ print $3 }')
		ERROR_LED=${ERROR_LED:-N/A}
		CSS_LED=$(echo $HTTP_RESPONSE | sed 's/<tr/\n<tag/g; s/<\/tr/\n<tag/g; s/<[^>]*>/ /g' | grep "CSS LED" | awk '{ print $3 }')
		CSS_LED=${CSS_LED:-N/A}
		verb 1 "ERROR LED value = $ERROR_LED"
		verb 1 "CSS LED value = $CSS_LED"
		if [ "$ERROR_LED" == "N/A" ] && [ "$CSS_LED" == "N/A" ]; then
			NAGIOS_MESSAGE="iRMC UNKNOWN - Error getting Error LED and/or CSS LED"
			NAGIOS_CODE=$NAGIOS_UNKNOWN
		else
			NAGIOS_CODE=$NAGIOS_OK
			NAGIOS_MESSAGE="iRMC OK - Error LED: $ERROR_LED, CSS LED: $CSS_LED"
			NAGIOS_PERF=$(printf "$PERF" 0)
			if [[ "$CSS_LED" =~ Blinking ]] || [[ "$ERROR_LED" =~ Blinking ]]; then
				NAGIOS_MESSAGE="iRMC CRITICAL - Error LED: $ERROR_LED, CSS LED: $CSS_LED"
				NAGIOS_CODE=$NAGIOS_CRITICAL
				NAGIOS_PERF=$(printf "$PERF" 1)
			elif [[ "$CSS_LED" =~ On ]] || [[ "$ERROR_LED" =~ On ]]; then
				NAGIOS_MESSAGE="iRMC WARNING - Error LED: $ERROR_LED, CSS LED: $CSS_LED"
				NAGIOS_CODE=$NAGIOS_WARNING
				NAGIOS_PERF=$(printf "$PERF" 1)
			fi
		fi
	fi
	
	# Logout session
	verb 1 "Attempting logout from iRMC"
	HTTP_RESPONSE=$(curl --silent --insecure --request POST --data "APPLY=10&P10=Logout" "$PROTOCOL://$HOST/logout?$SID" 2> /dev/null)

	if [ $? -ne 0 ]; then
		verb 1 "Failed attempting logout from iRMC"
	else
		verb 1 "Logout from iRMC"
	fi
else
	NAGIOS_MESSAGE="iRMC UNKNOWN - Cannot login to iRMC. Invalid username/password?"
	NAGIOS_CODE=$NAGIOS_UNKNOWN
fi

echo "$NAGIOS_MESSAGE$NAGIOS_PERF"
#echo "$CSS_FAIL$NAGIOS_PERF"
exit $NAGIOS_CODE