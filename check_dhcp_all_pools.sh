#!/bin/bash
#
# check_dhcp_all_pools.sh is a bash function to check Microsoft DHCP Pools usage 
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
# 1.0	First revision
# 2.0	Control snmpwalk and snmpget error codes
#		Improve internal calculations
#		Add named parameters


# ----------------------------------
# VARIABLES
# ----------------------------------

VERSION="2.0"
DEPENDENCIES=("snmpwalk" "snmpget")
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

OID_DHCP_POOL=.1.3.6.1.4.1.311.1.3.2.1.1.1
OID_DHCP_POOL_FREE=.1.3.6.1.4.1.311.1.3.2.1.1.3
OID_DHCP_POOL_USED=.1.3.6.1.4.1.311.1.3.2.1.1.2

HOSTNAME="localhost"
COMMUNITY="public"
WARNING=80
CRITICAL=90

SNMP_VALUE=
EXIT_VAL=0

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
		echo "[utils.sh] is required but it's not installed in directory where [$0] is located."
		exit $STATE_UNKNOWN;
	fi
}

function print_version(){
	echo "$0 - version $VERSION"
	exit $STATE_UNKNOWN
}

function print_usage(){
	echo "Usage: $0 -H <hostname> -C <SNMP-community> (-w <warning_threshold>) (-c <warning_threshold>) (-h) (-V)"
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
while getopts "H:C:w:c:hV" OPTION;
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
			print_usage
		;;
		"V")
			print_version
		;;
		*)
			print_usage
		;;
	esac
done

snmp_snmpwalk $OID_DHCP_POOL
TEMP=(${SNMP_VALUE[*]})

for i in ${!TEMP[*]};do
	snmp_snmpget $OID_DHCP_POOL_FREE.${TEMP[$i]}
	FREE=`echo $SNMP_VALUE|cut -d " " -f4`
	
	snmp_snmpget $OID_DHCP_POOL_USED.${TEMP[$i]}
	USED=`echo $SNMP_VALUE|cut -d " " -f4`

	MAX=`echo "$FREE+$USED" |bc`

	if [ "$MAX" -ne 0 ]; then
		PERCFREE=$((FREE*100/MAX))
		PERCUSED=$((USED*100/MAX))

		check_range $PERCUSED $CRITICAL
		RESULT=$?
		if [ "$RESULT" -eq 2 ] ; then echo "UNKNOWN: Invalid Critical threshold format"; exit $STATE_UNKNOWN; fi
		if [ "$RESULT" -eq 0 ] ; then EXIT_VAL=$((EXIT_VAL|2))
		else
			check_range $PERCUSED $WARNING
			RESULT=$?
			if [ "$RESULT" -eq 2 ] ; then  echo "UNKNOWN: Invalid Warning threshold format"; exit $STATE_UNKNOWN; fi
			if [ "$RESULT" -eq 0 ] ; then EXIT_VAL=$((EXIT_VAL|1)); fi
		fi
	else
		PERCUSED=0
	fi

	MESSAGE=( "${MESSAGE[@]}" "${TEMP[$i]} - $PERCUSED% used ($USED/$MAX)" )
	PERFOMANCE=( "${PERFOMANCE[@]}" "'Pool_${TEMP[$i]}'=$PERCUSED%;$WARNING;$CRITICAL;0;100" )
done

if [ "$EXIT_VAL" -ge 2 ]; then
	EXIT_VAL=$STATE_CRITICAL
	echo -e "CRITICAL: One or more scopes is nearing capacity"
elif [ "$EXIT_VAL" -ge 1 ]; then
	EXIT_VAL=$STATE_WARNING
	echo -e "WARNING: One or more scopes is nearing capacity"
else
	EXIT_VAL=$STATE_OK
	echo -e "OK: All scopes fine"
fi

for I in ${!MESSAGE[*]};do
	echo -e ${MESSAGE[$I]}
done
echo -n "|"
for I in ${!PERFOMANCE[*]};do
	echo -n "${PERFOMANCE[$I]} "
done

exit $EXIT_VAL