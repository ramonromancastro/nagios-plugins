#!/bin/bash
#
# check_3com_28xx.sh is a bash function to check 3Com Baseline Switch 28xx-SFP Plus 
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

# Changes
# 0.1	First version
# 0.2	Minor changes
# 0.3	Perfomamce value port_usage renamed to port_enabled
# 0.4	Perfomamce fan_error now includes ranges for warning and critical
# 0.5	Add [i] flag to sed
# 0.6	Add license

# ----------------------------------
# VARIABLES
# ----------------------------------
VERSION="0.6"
PROGNAME=`basename $0`
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`

DEPENDENCIES=("wget")

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4
STATE_DESCRIPTION=( "OK" "WARNING" "CRITICAL" "UNKNOWN" "DEPENDENT" )

WARNING=70
CRITICAL=80
HOSTNAME=127.0.0.1
TEST=
VERBOSE=
MESSAGE=( )
PERFOMANCE=
EXIT_VAL=$STATE_UNKNOWN

# REGULAR EXPRESSIONS

# ----------------------------------
# FUNCTIONS
# ----------------------------------
function abandon(){
	rm -f $PLUGIN_HTML_RESPONSE
	exit $1
}

function verb(){
	if [ -n "$VERBOSE" ]; then echo "[ ] $1"; fi
}

function parseValues(){
	PLUGIN_REGEX_PORT_TOTAL=`cat $PLUGIN_HTML_RESPONSE | grep -Eo "^var portNo = [0-9]+;" | sed "s/[^0-9a-z]/ /ig" | awk '{ print $3}'`
	verb "Parse portNo: $PLUGIN_REGEX_PORT_TOTAL"
	if [[ ! $PLUGIN_REGEX_PORT_TOTAL =~ [0-9]+ ]]; then
		echo "UNKNOWN: Error parsing portNo!"
		abandon $STATE_UNKNOWN
	fi
	
	#PLUGIN_REGEX_PORT_USED=`cat $PLUGIN_HTML_RESPONSE | grep -Eo "portState\[[0-9]+\]\[1] = \"Up\";" | wc -l`
	PLUGIN_REGEX_PORT_USED=`cat $PLUGIN_HTML_RESPONSE | grep -Eo "portState\[[0-9]+\]\[0] = 1;" | wc -l`
	verb "Parse portEnabled: $PLUGIN_REGEX_PORT_USED"
	if [[ ! $PLUGIN_REGEX_PORT_USED =~ [0-9]+ ]]; then
		echo "UNKNOWN: Error parsing portEnabled!"
		abandon $STATE_UNKNOWN
	fi

	PLUGIN_REGEX_FAN_TOTAL=`cat $PLUGIN_HTML_RESPONSE | grep -Eo "^var fanNo = [0-9]+;" | sed "s/[^0-9a-z]/ /ig" | awk '{ print $3}'`
	verb "Parse fanNo: $PLUGIN_REGEX_FAN_TOTAL"
	if [[ ! $PLUGIN_REGEX_FAN_TOTAL =~ [0-9]+ ]]; then
		echo "UNKNOWN: Error parsing fanNo!"
		abandon $STATE_UNKNOWN
	fi

	PLUGIN_REGEX_FAN_ERROR=`cat $PLUGIN_HTML_RESPONSE | grep -Eo "^[ ]{4}2;" | wc -l`
	verb "Parse fanError: $PLUGIN_REGEX_FAN_ERROR"
	if [[ ! $PLUGIN_REGEX_FAN_ERROR =~ [0-9]+ ]]; then
		echo "UNKNOWN: Error parsing fanError!"
		abandon $STATE_UNKNOWN
	fi
}

function getHTML(){
	verb "Download [http://$HOSTNAME/polling.htm] to [$PLUGIN_HTML_RESPONSE]"
	wget -q --no-check-certificate -O $PLUGIN_HTML_RESPONSE http://$HOSTNAME/polling.htm
	PLUGIN_HTML_RESPONSE_ERROR=$?

	if [ $PLUGIN_HTML_RESPONSE_ERROR != 0 ]; then
		abandon $STATE_WARNING
	fi
}

function check_dependencies(){
	for i in ${!DEPENDENCIES[*]}; do
		command -v ${DEPENDENCIES[$i]} >/dev/null 2>&1 || { echo "[${DEPENDENCIES[$i]}] is required but it's not installed." >&2; abandon $STATE_UNKNOWN; }
	done
	
	if [ -f $PROGPATH/utils.sh ]; then
		. $PROGPATH/utils.sh
	else
		echo "UNKNOWN: [utils.sh] is required but it's not installed in directory where [$0] is located."
		abandon $STATE_UNKNOWN;
	fi
}

function print_version(){
	echo "$0 - version $VERSION"
	abandon $STATE_OK
}

function print_help(){
	echo "3Com Baseline Switch 28xx-SFP Plus Plugin"
	echo ""
	echo "This plugin is not developped by the Nagios Plugin group."
	echo "Please do not e-mail them for support on this plugin."
	echo ""
	echo "For contact info, please read the plugin script file."
	echo ""
	echo "Usage: $0 -H <hostname> -T <test> -w <warn> -c <crit> [-x <arg>] [-h] [-V] [-v]"
	echo "------------------------------------------------------------------------------------"
	echo "Usable Options:"
	echo ""
	echo "   -H <hostname>   ... name or IP address of host to check"
	echo "   -T <test>       ... test to probe on device"
	echo "      PORT         ... Number of ports enabled"
	echo "      FAN          ... Fan status"
	echo "   -w <warn>       ... warning threshold"
	echo "   -c <crit>       ... critical threshold"
	echo "   -h              ... show this help screen"
	echo "   -V              ... show the current version of the plugin"
	echo "   -v              ... print extra debugging information"
	echo ''
	echo 'Examples:'
	echo "    $0 -h 127.0.0.1 -T PORT -w 80 -c 90"
	echo "    $0 -V"
	echo ""
	echo "------------------------------------------------------------------------------------"
	abandon $STATE_UNKNOWN
}

function port_usage(){

	getHTML
	parseValues
	
	MESSAGE=( "PORT OK: $PLUGIN_REGEX_PORT_USED/$PLUGIN_REGEX_PORT_TOTAL in use" )
	PERFOMANCE=( "${PERFOMANCE[@]}" "'port_enabled'=$PLUGIN_REGEX_PORT_USED;;;0;$PLUGIN_REGEX_PORT_TOTAL" )	
	EXIT_VAL=$STATE_OK
	
	#WARNING_PORT=$((($PLUGIN_REGEX_PORT_TOTAL*$WARNING)/100))
	#CRITICAL_PORT=$((($PLUGIN_REGEX_PORT_TOTAL*$CRITICAL)/100))
	
	#check_range $PLUGIN_REGEX_PORT_USED $CRITICAL_PORT
	#RESULT=$?
	#if [ "$RESULT" -eq 2 ] ; then
	#	abandon $STATE_UNKNOWN
	#fi
	
	#if [ "$RESULT" -eq 0 ] ; then
	#	MESSAGE=( "PORT CRITICAL: $PLUGIN_REGEX_PORT_USED/$PLUGIN_REGEX_PORT_TOTAL" )
	#	EXIT_VAL=$STATE_CRITICAL
	#else
	#	check_range $PLUGIN_REGEX_PORT_USED $WARNING_PORT
	#	RESULT=$?
	#	if [ "$RESULT" -eq 2 ] ; then
	#		abandon $STATE_UNKNOWN
	#	fi
	#	
	#	if [ "$RESULT" -eq 0 ] ; then
	#		MESSAGE=( "PORT WARNING: $PLUGIN_REGEX_PORT_USED/$PLUGIN_REGEX_PORT_TOTAL" )
	#		EXIT_VAL=$STATE_WARNING
	#	else
	#		MESSAGE=( "PORT OK: $PLUGIN_REGEX_PORT_USED/$PLUGIN_REGEX_PORT_TOTAL" )
	#		EXIT_VAL=$STATE_OK
	#	fi
	#fi
	
	#PERFOMANCE=( "${PERFOMANCE[@]}" "'port_usage'=$PLUGIN_REGEX_PORT_USED;$WARNING_PORT;$CRITICAL_PORT;0;$PLUGIN_REGEX_PORT_TOTAL" )
}

function fan_status(){
	getHTML
	parseValues

	if [ "$PLUGIN_REGEX_FAN_ERROR" -ge "$PLUGIN_REGEX_FAN_TOTAL" ]; then
		MESSAGE=( "FAN CRITICAL: All fans are in critical state" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_CRITICAL
	elif [ "$PLUGIN_REGEX_FAN_ERROR" -gt 0 ]; then
		MESSAGE=( "FAN WARNING: One or more fans are in warning state" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_WARNING
	else
		MESSAGE=( "FAN OK: All fans are ok" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_OK
	fi

	PERFOMANCE=( "'fan_error'=$PLUGIN_REGEX_FAN_ERROR;1;$PLUGIN_REGEX_FAN_TOTAL;0;$PLUGIN_REGEX_FAN_TOTAL" )
}


# ----------------------------------
# MAIN CODE
# ----------------------------------

# Check dependencies
check_dependencies

# Show help if no parameters
if [ $# -eq 0 ]; then
	print_help
fi

# Read command line options
while getopts "H:T:w:c:hVv" OPTION;
do
	case $OPTION in
		"H")
			HOSTNAME=$OPTARG
		;;
		"T")
			TEST=$OPTARG
		;;
		"w")
			WARNING=$OPTARG
		;;
		"c")
			CRITICAL=$OPTARG
		;;
		"h")
			print_help
		;;
		"V")
			print_version
		;;
		"v")
			VERBOSE=1
		;;
		*)
			print_help
		;;
	esac
done

# Check parameters
if [ "$WARNING" -ge "$CRITICAL" ]; then
        echo "UNKNOWN: Warning value must be less than the critical value!"
        abandon $STATE_UNKNOWN
fi

PLUGIN_HTML_RESPONSE=/tmp/$PROGNAME.$HOSTNAME.tmp

# Do test
case "$TEST" in
	"PORT") port_usage
		;;
	"FAN") fan_status
		;;
	*) print_help
	   ;;
esac

# Show result
for i in ${!MESSAGE[*]};do
	echo ${MESSAGE[$i]}
done
echo -n "|"
for i in ${!PERFOMANCE[*]};do
	echo -n "${PERFOMANCE[$i]}"
done

abandon $EXIT_VAL
