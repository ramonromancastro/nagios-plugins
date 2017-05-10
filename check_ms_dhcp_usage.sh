#!/bin/bash
#
# check_ms_dhcp_usage.sh is a bash function to check Microsoft DHCP Pools usage 
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

# CHANGES
#
# 1.0	First revision
# 2.0	Control snmpwalk and snmpget error codes
#		Improve internal calculations
#		Add named parameters
# 2.1	Add utils.sh include
#		Thresholds ranges are now checked by check_range function (included in utils.sh)
# 2.2	Add GPLv3 license
#		Add code comments
#		Add -v verbose option

# ----------------------------------
# CONSTANTS
# ----------------------------------

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

VERSION="2.2"
SCRIPTNAME="check_ms_dhcp_usage.sh"
DEPENDENCIES=("snmpwalk" "snmpget")
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`

OID_DHCP_POOL=.1.3.6.1.4.1.311.1.3.2.1.1.1
OID_DHCP_POOL_FREE=.1.3.6.1.4.1.311.1.3.2.1.1.3
OID_DHCP_POOL_USED=.1.3.6.1.4.1.311.1.3.2.1.1.2

# ----------------------------------
# VARIABLES
# ----------------------------------

HOSTNAME=localhost
COMMUNITY=public
WARNING=80
CRITICAL=90
VERBOSE=

# This variable contains [snmp_snmpxxx] result
SNMP_VALUE=
EXIT_VAL=$STATE_OK

MESSAGE=( )
PERFOMANCE=( )

# ----------------------------------
# FUNCTIONS
# ----------------------------------

function check_dependencies(){
	for i in ${!DEPENDENCIES[*]}; do
		command -v ${DEPENDENCIES[$i]} >/dev/null 2>&1 || { echo "[${DEPENDENCIES[$i]}] is required but it's not installed." >&2; exit $STATE_UNKNOWN; }
	done
	
	if [ -f $PROGPATH/utils.sh ]; then
		. $PROGPATH/utils.sh
	else
		echo "[utils.sh] is required but it's not installed in directory where [$SCRIPTNAME] is located."
		exit $STATE_UNKNOWN;
	fi
}

function print_version(){
	echo "$SCRIPTNAME - version $VERSION"
	exit $STATE_UNKNOWN
}

function print_help(){
	echo "*** $SCRIPTNAME ***"
	echo ""
	echo "This plugin is not developed by the Nagios Plugin group."
	echo "Please do not e-mail them for support on this plugin."
	echo ""
	echo "For contact info, please read the plugin script file."
	echo ""
	echo "Usage: $SCRIPTNAME -H <hostname> -C <community> (-w <warn>) (-c <crit>) (-h) (-v) (-V)"
	echo ""
	echo "   -H <hostname>   ... name or IP address of host to check (default $HOSTNAME)"
	echo "   -C <community>  ... community name for the host's SNMP agent (default $COMMUNITY)"
	echo "   -w <warn>       ... warning threshold percent (default $WARNING)"
	echo "   -c <crit>       ... critical threshold percent (default $CRITICAL)"
	echo "   -h              ... show this help screen"
	echo "   -V              ... show the current version of the plugin"
	echo "   -v              ... print extra debugging information"
	echo ''
	echo 'Examples:'
	echo "    $SCRIPTNAME -H 127.0.0.1 -C public"
	echo "    $SCRIPTNAME -V"
	echo ""
	exit $STATE_UNKNOWN
}

function print_usage(){
	echo "Usage: $SCRIPTNAME -H <hostname> -C <SNMP-community> (-w <warning_threshold>) (-c <warning_threshold>) (-h) (-v) (-V)"
	exit $STATE_UNKNOWN
}

function snmp_snmpget(){
	SNMP_VALUE=`snmpget -v 2c -c $COMMUNITY $HOSTNAME $1 2> /dev/null`
	SNMP_RESULT=$?
	if [ "$SNMP_RESULT" -ne 0 ]; then
		echo "WARNING: SNMP error/timeout"
		exit $STATE_WARNING
	fi
}

function snmp_snmpwalk(){
	SNMP_VALUE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $1 2> /dev/null | cut -d " " -f4))
	if [ "$SNMP_VALUE" == "" ]; then
		echo "WARNING: SNMP error/timeout"
		exit $STATE_WARNING
	fi
}

function verb(){
	if [ -n "$VERBOSE" ]; then echo "[ INFO ] $1"; fi
}

# ----------------------------------
# MAIN CODE
# ----------------------------------

# Check dependencies
check_dependencies

# Show help if no parameters
if [ $# -eq 0 ]; then
	print_usage
fi

# Read command line options
while getopts "H:C:w:c:hVv" OPTION;
do
	case $OPTION in
		"H")
			HOSTNAME=$OPTARG
		;;
		"C")
			COMMUNITY=$OPTARG
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
			print_usage
		;;
	esac
done

# Get DHCP pools
snmp_snmpwalk $OID_DHCP_POOL
TEMP=(${SNMP_VALUE[*]})
verb "oid $OID_DHCP_POOL = ${TEMP[*]}"

for i in ${!TEMP[*]};do
	verb "Retrieving scope ${TEMP[$i]}"
	# Get DHCP pool values
	snmp_snmpget $OID_DHCP_POOL_FREE.${TEMP[$i]}
	verb "oid $OID_DHCP_POOL_FREE.${TEMP[$i]} = $SNMP_VALUE"
	FREE=`echo $SNMP_VALUE|cut -d " " -f4`
	
	snmp_snmpget $OID_DHCP_POOL_USED.${TEMP[$i]}
	verb "oid $OID_DHCP_POOL_USED.${TEMP[$i]} = $SNMP_VALUE"
	USED=`echo $SNMP_VALUE|cut -d " " -f4`

	MAX=`echo "$FREE+$USED" |bc`
	verb "${TEMP[$i]}.MAX = $MAX"

	# Check usage
	if [ "$MAX" -ne 0 ]; then
		USED_PERCENT=$((USED*100/MAX))
		verb "${TEMP[$i]}.USED_PERCENT = $USED_PERCENT%"

		check_range $USED_PERCENT $CRITICAL
		RESULT=$?
		if [ "$RESULT" -eq 2 ] ; then echo "UNKNOWN: Invalid Critical threshold format"; exit $STATE_UNKNOWN; fi
		if [ "$RESULT" -eq 0 ] ; then EXIT_VAL=$((EXIT_VAL|2))
		else
			check_range $USED_PERCENT $WARNING
			RESULT=$?
			if [ "$RESULT" -eq 2 ] ; then  echo "UNKNOWN: Invalid Warning threshold format"; exit $STATE_UNKNOWN; fi
			if [ "$RESULT" -eq 0 ] ; then EXIT_VAL=$((EXIT_VAL|1)); fi
		fi
	else
		USED_PERCENT=0
	fi

	MESSAGE=( "${MESSAGE[@]}" "${TEMP[$i]} - $USED_PERCENT% used ($USED/$MAX)" )
	PERFOMANCE=( "${PERFOMANCE[@]}" "'scope_${TEMP[$i]}'=$USED_PERCENT%;$WARNING;$CRITICAL;0;100" )
done

# Display status
if [ "$EXIT_VAL" -ge 2 ]; then
	EXIT_VAL=$STATE_CRITICAL
	echo -e "CRITICAL: One or more pools are above $CRITICAL% of use"
elif [ "$EXIT_VAL" -ge 1 ]; then
	EXIT_VAL=$STATE_WARNING
	echo -e "WARNING: One or more pools are above $WARNING% of use"
else
	EXIT_VAL=$STATE_OK
	echo -e "OK: All scopes are fine"
fi

# Display messages
for I in ${!MESSAGE[*]};do
	echo -e ${MESSAGE[$I]}
done

# Display perf data
echo -n "|"
for I in ${!PERFOMANCE[*]};do
	echo -n "${PERFOMANCE[$I]} "
done

exit $EXIT_VAL
