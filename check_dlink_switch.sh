#!/bin/bash
#
# check_dlink_switch.sh is a bash function to check DLink switches 
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
# 0.2	Add PORT usage test
# 0.2.1	Fix minor perf errors
# 0.3	Ignore internal temperature threshold

# ----------------------------------
# VARIABLES
# ----------------------------------
VERSION="0.3"
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`

DEPENDENCIES=("snmpwalk" "snmpget")

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4
STATE_DESCRIPTION=( "OK" "WARNING" "CRITICAL" "UNKNOWN" "DEPENDENT" )



# OID VALUES
oid_agentCPUutilizationIn1min=.1.3.6.1.4.1.171.12.1.1.6.2.0
oid_swDevInfoNumOfPortInUse=.1.3.6.1.4.1.171.11.117.1.3.2.1.1.2.0
oid_swDevInfoTotalNumOfPort=.1.3.6.1.4.1.171.11.117.1.3.2.1.1.1.0

# OID TABLES
oid_swUnitMgmtModuleName=.1.3.6.1.4.1.171.12.11.1.9.4.1.9
oid_swUnitMgmtFirmwareVersion=.1.3.6.1.4.1.171.12.11.1.9.4.1.11
oid_swUnitMgmtExistState=.1.3.6.1.4.1.171.12.11.1.9.4.1.15
oid_swUnitMgmtSerialNumber=.1.3.6.1.4.1.171.12.11.1.9.4.1.17

oid_agentDRAMUtilization=.1.3.6.1.4.1.171.12.1.1.9.1.4

oid_agentFLASHutilization=1.3.6.1.4.1.171.12.1.1.10.1.4

oid_swTemperatureHighThresh=.1.3.6.1.4.1.171.12.11.1.8.1.3
oid_swTemperatureLowThresh=.1.3.6.1.4.1.171.12.11.1.8.1.4
oid_swTemperatureCurrent=.1.3.6.1.4.1.171.12.11.1.8.1.2

oid_swFanStatus=.1.3.6.1.4.1.171.12.11.1.7.1.3
oid_swPowerStatus=.1.3.6.1.4.1.171.12.11.1.6.1.3

oid_swUnitNumOfUnit=.1.3.6.1.4.1.171.12.11.1.9.3.0
oid_swUnitMgmtStartPos=.1.3.6.1.4.1.171.12.11.1.9.4.1.3
oid_agentPORTutilizationUtil=.1.3.6.1.4.1.171.12.1.1.8.1.4
oid_swEtherCableDiagLinkStatus=.1.3.6.1.4.1.171.12.58.1.1.1.3

codes_swFanStatus=( $STATE_WARNING $STATE_OK $STATE_CRITICAL $STATE_OK $STATE_OK $STATE_OK $STATE_OK )
desc_swFanStatus=( "other(0)" "working(1)" "fail(2)" "speed-0(3)" "speed-low(4)" "speed-middle(5)" "speed-high(6)" )
codes_swPowerStatus=( $STATE_WARNING $STATE_WARNING $STATE_WARNING $STATE_OK $STATE_CRITICAL $STATE_WARNING $STATE_WARNING )
desc_swPowerStatus=( "other(0)" "lowVoltage(1)" "overCurrent(2)" "working(3)" "fail(4)" "connect(5)" "disconnect(6)" )

WARNING=
CRITICAL=
COMMUNITY=127.0.0.1
HOSTNAME=public
TEST=
EXTRA=
VERBOSE=
MESSAGE=( )
PERFOMANCE=
EXIT_VAL=$STATE_UNKNOWN

# ----------------------------------
# FUNCTIONS
# ----------------------------------

function check_dependencies(){
	for i in ${!DEPENDENCIES[*]}; do
		command -v ${DEPENDENCIES[$i]} >/dev/null 2>&1 || { echo "[${DEPENDENCIES[$i]}] is required but it's not installed." >&2; exit 3; }
	done
	
	if [ -f $PROGPATH/utils.sh ]; then
		. $PROGPATH/utils.sh
	else
		echo "[utils.sh] is required but it's not installed in directory where [$0] is located."
		exit 3;
	fi
}

function check_threshold(){
	if [ "$WARNING" == "" ] || [ "$CRITICAL" == "" ]; then
		print_help
	fi
}

function print_version(){
	echo "$0 - version $VERSION"
	exit $STATE_OK
}

function print_help(){
	echo "D-Link Switch Plugin"
	echo ""
	echo "This plugin is not developed by the Nagios Plugin group."
	echo "Please do not e-mail them for support on this plugin."
	echo ""
	echo "For contact info, please read the plugin script file."
	echo ""
	echo "Usage: $0 -H <hostname> -C <community> -T <test> -w <warn> -c <crit> [-x <arg>] [-h] [-V] [-v]"
	echo "------------------------------------------------------------------------------------"
	echo "Usable Options:"
	echo ""
	echo "   -H <hostname>   ... name or IP address of host to check"
	echo "   -C <community>  ... community name for the host's SNMP agent (implies v1 protocol)"
	echo "   -T <test>       ... test to probe on device"
	echo "      FIRMWARE     ... firmware version"
	echo "      LOAD         ... Load% utilization"
	echo "      DRAM         ... DRAM% utilization"
	echo "      PORT         ... Number of ports in use"
	echo "      POWER        ... Power supply status"
	echo "      TEMP         ... Temperature status"
	echo "      FAN          ... Fan status"
	echo "   -w <warn>       ... warning threshold"
	echo "   -c <crit>       ... critical threshold"
	echo "   -x <arg>        ... extra arguments"
	echo "   -h              ... show this help screen"
	echo "   -V              ... show the current version of the plugin"
	echo "   -v              ... print extra debugging information"
	echo ''
	echo 'Examples:'
	echo "    $0 -h 127.0.0.1 -C public -T LOAD -w 80 -c 90"
	echo "    $0 -V"
	echo ""
	echo "------------------------------------------------------------------------------------"
	exit $STATE_UNKNOWN
}

function firmware_test(){
	NUNITS=0
	NWARN=0
	if [ -n "$VERBOSE" ]; then echo "[ ] Reading swUnitMgmtModuleName"; fi
	NAME_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_swUnitMgmtModuleName | cut -d "\"" -f2 ))
	if [ -n "$VERBOSE" ]; then echo "[ ] Reading swUnitMgmtFirmwareVersion"; fi
	FIRMWARE_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_swUnitMgmtFirmwareVersion | cut -d "\"" -f2 ))
	if [ -n "$VERBOSE" ]; then echo "[ ] Reading swUnitMgmtExistState"; fi
	EXIST_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_swUnitMgmtExistState | cut -d " " -f4 ))
	if [ -n "$VERBOSE" ]; then echo "[ ] Reading swUnitMgmtSerialNumber"; fi
	SERIAL_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_swUnitMgmtSerialNumber | cut -d "\"" -f2 ))
	
	for i in ${!EXIST_TABLE[*]}; do
		if [ -n "$VERBOSE" ]; then
			echo "[ ] $oid_swUnitMgmtModuleName = ${NAME_TABLE[$i]}"
			echo "[ ] $oid_swUnitMgmtFirmwareVersion = ${FIRMWARE_TABLE[$i]}"
			echo "[ ] $oid_swUnitMgmtExistState = ${EXIST_TABLE[$i]}"
			echo "[ ] $oid_swUnitMgmtSerialNumber = ${SERIAL_TABLE[$i]}"
		fi
		
		if [ ${EXIST_TABLE[$i]} -eq 1 ]; then
			if [ ! "${FIRMWARE_TABLE[$i]}" == "$EXTRA" ]; then
				MESSAGE=( "${MESSAGE[@]}" "WARNING: Model: ${NAME_TABLE[$i]}, SerialNumber: ${SERIAL_TABLE[$i]}, Firmware: ${FIRMWARE_TABLE[$i]}" )
				NWARN=$((NWARN+1))
			else
				MESSAGE=( "${MESSAGE[@]}" "Model: ${NAME_TABLE[$i]}, SerialNumber: ${SERIAL_TABLE[$i]}, Firmware: ${FIRMWARE_TABLE[$i]}" )
			fi
			NUNITS=$((NUNITS+1))
		fi
	done
	
	if [ "$NWARN" -gt 0 ]; then
		MESSAGE=( "FIRMWARE WARNING: One or more firmwares are in warning state ($EXTRA)" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_CRITICAL
	else
		MESSAGE=( "FIRMWARE OK: All firmwares are ok ($EXTRA)" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_OK
	fi

}

function port_usage(){
	NPORT=0
	UPORT=0
	
	if [ -n "$VERBOSE" ]; then echo "[ ] Reading swEtherCableDiagLinkStatus"; fi
	swEtherCableDiagLinkStatus=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_swEtherCableDiagLinkStatus | cut -d " " -f4 ))
	
	for i in ${!swEtherCableDiagLinkStatus[*]}; do
		NPORT=$[$NPORT+1]
		if [ -n "$VERBOSE" ]; then echo "[ ] $oid_swEtherCableDiagLinkStatus = ${swEtherCableDiagLinkStatus[$i]}"; fi
		if [ ${swEtherCableDiagLinkStatus[$i]} -ne 0 ]; then
			UPORT=$[$UPORT+1]
		fi
	done

	WARNING_PORT=$((($NPORT*$WARNING)/100))
	CRITICAL_PORT=$((($NPORT*$CRITICAL)/100))
	
	check_range $UPORT $CRITICAL_PORT
	RESULT=$?
	if [ "$RESULT" -eq 2 ] ; then
		exit $STATE_UNKNOWN
	fi
	
	if [ "$RESULT" -eq 0 ] ; then
		MESSAGE=( "PORT CRITICAL: $UPORT/$NPORT" )
		EXIT_VAL=$STATE_CRITICAL
	else
		check_range $UPORT $WARNING_PORT
		RESULT=$?
		if [ "$RESULT" -eq 2 ] ; then
			exit $STATE_UNKNOWN
		fi
		
		if [ "$RESULT" -eq 0 ] ; then
			MESSAGE=( "PORT WARNING: $UPORT/$NPORT" )
			EXIT_VAL=$STATE_WARNING
		else
			MESSAGE=( "PORT OK: $UPORT/$NPORT" )
			EXIT_VAL=$STATE_OK
		fi
	fi
	
	PERFOMANCE=( "${PERFOMANCE[@]}" "'port_usage'=$UPORT;$WARNING_PORT;$CRITICAL_PORT;0;$NPORT" )
}

function temperature_status(){
	NCRIT=0
	NWARN=0
	if [ -n "$VERBOSE" ]; then echo "[ ] Reading swTemperatureCurrent"; fi
	TEMP_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_swTemperatureCurrent | cut -d " " -f4 ))
	for i in ${!TEMP_TABLE[*]}; do
		if [ -n "$VERBOSE" ]; then
			echo "[ ] $oid_swTemperatureCurrent = ${TEMP_TABLE[$i]}"
		fi
		VALUE=${TEMP_TABLE[$i]}
		
		MESSAGE=( "${MESSAGE[@]}" "Temperature: $VALUE C" )
		PERFOMANCE=( "${PERFOMANCE[@]}" "'temp_$i'=$VALUE;$WARNING;$CRITICAL;;" )
		
		check_range $VALUE $CRITICAL
		RESULT=$?
		if [ "$RESULT" -eq 2 ] ; then
			exit $STATE_UNKNOWN
		fi
		
		if [ "$RESULT" -eq 0 ] ; then
			NCRIT=$((NCRIT+1))
		else
			check_range $VALUE $WARNING
			RESULT=$?
			if [ "$RESULT" -eq 2 ] ; then
				exit $STATE_UNKNOWN
			fi
			
			if [ "$RESULT" -eq 0 ] ; then
				NWARN=$((NWARN+1))
			fi
		fi

	done
	
	if [ "$NCRIT" -gt 0 ]; then
		MESSAGE=( "TEMPERATURE CRITICAL: One or more temperatures are in critical state" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_CRITICAL
	elif [ "$NWARN" -gt 0 ]; then
		MESSAGE=( "TEMPERATURE WARNING: One or more temperatures are in warning state" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_WARNING
	else
		MESSAGE=( "TEMPERATURE OK: All temperatures are ok" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_OK
	fi
}

function fan_status(){
	NCRIT=0
	NWARN=0
	if [ -n "$VERBOSE" ]; then echo "[ ] Reading swFanStatus"; fi
	FAN_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_swFanStatus | cut -d " " -f4 ))
	for i in ${!FAN_TABLE[*]}; do
		if [ -n "$VERBOSE" ]; then echo "[ ] $oid_swFanStatus = ${FAN_TABLE[$i]}"; fi
		VALUE=${FAN_TABLE[$i]}
		
		MESSAGE=( "${MESSAGE[@]}" "Fan: ${desc_swFanStatus[${FAN_TABLE[$i]}]}" )

		case "${codes_swFanStatus[${FAN_TABLE[$i]}]}" in
			"$STATE_WARNING")
				NWARN=$((NWARN+1))
				;;
			"$STATE_CRITICAL")
				NCRIT=$((NCRIT+1))
				;;
		esac
	done
	
	if [ "$NCRIT" -gt 0 ]; then
		MESSAGE=( "FAN CRITICAL: One or more fans are in critical state" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_CRITICAL
	elif [ "$NWARN" -gt 0 ]; then
		MESSAGE=( "FAN WARNING: One or more fans are in warning state" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_WARNING
	else
		MESSAGE=( "FAN OK: All fans are ok" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_OK
	fi

	PERFOMANCE=( "'fan_error'=$NCRIT;;;;" )
}

function power_status(){
	NCRIT=0
	NWARN=0
	if [ -n "$VERBOSE" ]; then echo "[ ] Reading swPowerStatus"; fi
	POWER_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_swPowerStatus | cut -d " " -f4 ))
	for i in ${!POWER_TABLE[*]}; do
		if [ -n "$VERBOSE" ]; then echo "[ ] $oid_swPowerStatus = ${POWER_TABLE[$i]}"; fi
		VALUE=${POWER_TABLE[$i]}	
		MESSAGE=( "${MESSAGE[@]}" "PowerSupply: ${desc_swPowerStatus[${POWER_TABLE[$i]}]}" )
		case "${codes_swPowerStatus[${POWER_TABLE[$i]}]}" in
			$STATE_WARNING)
				NWARN=$((NWARN+1))
				;;
			$STATE_CRITICAL)
				NCRIT=$((NCRIT+1))
				;;
		esac
	done
	
	if [ "$NCRIT" -gt 0 ]; then
		MESSAGE=( "POWER SUPPLY CRITICAL: One or more power supplies are in critical state" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_CRITICAL
	elif [ "$NWARN" -gt 0 ]; then
		MESSAGE=( "POWER SUPPLY WARNING: One or more power supplies are in warning state" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_WARNING
	else
		MESSAGE=( "POWER SUPPLY OK: All power supplies are ok" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_OK
	fi

	PERFOMANCE=( "'power_supply_error'=$NCRIT;;;;" )
}

function dram_status(){
	NCRIT=0
	NWARN=0
	if [ -n "$VERBOSE" ]; then echo "[ ] Reading agentDRAMUtilization"; fi
	DRAM_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_agentDRAMUtilization | cut -d " " -f4 ))
	for i in ${!DRAM_TABLE[*]}; do
		if [ -n "$VERBOSE" ]; then echo "[ ] $oid_agentDRAMUtilization = ${DRAM_TABLE[$i]}"; fi
		VALUE=${DRAM_TABLE[$i]}	
		
		MESSAGE=( "${MESSAGE[@]}" "DRAM: $VALUE%" )
		PERFOMANCE=( "${PERFOMANCE[@]}" "'dram_$i'=$VALUE%;$WARNING;$CRITICAL;0;100 " )
		
		check_range $VALUE $CRITICAL
		RESULT=$?
		if [ "$RESULT" -eq 2 ] ; then
			exit $STATE_UNKNOWN
		fi
		
		if [ "$RESULT" -eq 0 ] ; then
			NCRIT=$((NCRIT+1))
		else
			check_range $VALUE $WARNING
			RESULT=$?
			if [ "$RESULT" -eq 2 ] ; then
				exit $STATE_UNKNOWN
			fi
			
			if [ "$RESULT" -eq 0 ] ; then
				NWARN=$((NWARN+1))
			fi
		fi
	done
	
	if [ "$NCRIT" -gt 0 ]; then
		MESSAGE=( "DRAM CRITICAL: One or more DRAM are in critical state" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_CRITICAL
	elif [ "$NWARN" -gt 0 ]; then
		MESSAGE=( "DRAM WARNING: One or more DRAM are in warning state" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_WARNING
	else
		MESSAGE=( "DRAM OK: All DRAM are ok" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_OK
	fi
}

function flash_status(){
	NCRIT=0
	NWARN=0
	if [ -n "$VERBOSE" ]; then echo "[ ] Reading agentFLASHutilization"; fi
	FLASH_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_agentFLASHutilization | cut -d " " -f4 ))
	for i in ${!FLASH_TABLE[*]}; do
		if [ -n "$VERBOSE" ]; then echo "[ ] $oid_agentFLASHutilization = ${FLASH_TABLE[$i]}"; fi
		VALUE=${FLASH_TABLE[$i]}	
		
		MESSAGE=( "${MESSAGE[@]}" "FLASH: $VALUE%" )
		PERFOMANCE=( "${PERFOMANCE[@]}" "'flash_$i'=$VALUE%;$WARNING;$CRITICAL;0;100 " )
		
		check_range $VALUE $CRITICAL
		RESULT=$?
		if [ "$RESULT" -eq 2 ] ; then
			exit $STATE_UNKNOWN
		fi
		
		if [ "$RESULT" -eq 0 ] ; then
			NCRIT=$((NCRIT+1))
		else
			check_range $VALUE $WARNING
			RESULT=$?
			if [ "$RESULT" -eq 2 ] ; then
				exit $STATE_UNKNOWN
			fi
			
			if [ "$RESULT" -eq 0 ] ; then
				NWARN=$((NWARN+1))
			fi
		fi
	done
	
	if [ "$NCRIT" -gt 0 ]; then
		MESSAGE=( "FLASH CRITICAL: One or more FLASH are in critical state" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_CRITICAL
	elif [ "$NWARN" -gt 0 ]; then
		MESSAGE=( "FLASH WARNING: One or more FLASH are in warning state" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_WARNING
	else
		MESSAGE=( "FLASH OK: All FLASH are ok" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_OK
	fi
}

function load_usage(){
	if [ -n "$VERBOSE" ]; then echo "[ ] Reading agentCPUutilizationIn1min"; fi
	SNMP_RESULT=`snmpget -v 2c -c $COMMUNITY $HOSTNAME $oid_agentCPUutilizationIn1min`
	if [ -n "$VERBOSE" ]; then echo "[ ] $oid_agentCPUutilizationIn1min = $SNMP_RESULT"; fi
	VALUE=`echo $SNMP_RESULT|cut -d " " -f4`

	check_range $VALUE $CRITICAL
	RESULT=$?
	if [ "$RESULT" -eq 2 ] ; then
		exit $STATE_UNKNOWN
	fi
	
	if [ "$RESULT" -eq 0 ] ; then
		MESSAGE=( "LOAD CRITICAL: $VALUE%" )
		EXIT_VAL=$STATE_CRITICAL
	else
		check_range $VALUE $WARNING
		RESULT=$?
		if [ "$RESULT" -eq 2 ] ; then
			exit $STATE_UNKNOWN
		fi
		
		if [ "$RESULT" -eq 0 ] ; then
			MESSAGE=( "LOAD WARNING: $VALUE%" )
			EXIT_VAL=$STATE_WARNING
		else
			MESSAGE=( "LOAD OK: $VALUE%" )
			EXIT_VAL=$STATE_OK
		fi
	fi

	PERFOMANCE="'load'=$VALUE%;$WARNING;$CRITICAL;0;100"
}

function port_usages(){
	if [ -n "$VERBOSE" ]; then echo "[ ] Reading swDevInfoTotalNumOfPort"; fi
	SNMP_RESULT=`snmpget -v 2c -c $COMMUNITY $HOSTNAME $oid_swDevInfoTotalNumOfPort`
	if [ -n "$VERBOSE" ]; then echo "[ ] $oid_swDevInfoTotalNumOfPort = $SNMP_RESULT"; fi
	TOTAL_PORT=`echo $SNMP_RESULT|cut -d " " -f4`
	
	if [ -n "$VERBOSE" ]; then echo "[ ] Reading swDevInfoNumOfPortInUse"; fi
	SNMP_RESULT=`snmpget -v 2c -c $COMMUNITY $HOSTNAME $oid_swDevInfoNumOfPortInUse`
	if [ -n "$VERBOSE" ]; then echo "[ ] $oid_swDevInfoNumOfPortInUse = $SNMP_RESULT"; fi
	USED_PORT=`echo $SNMP_RESULT|cut -d " " -f4`
	
	VALUE=$((($USED_PORT*100)/$TOTAL_PORT))
	WARNING_PERCENT=$((($TOTAL_PORT*$WARNING)/100))
	CRITICAL_PERCENT=$((($TOTAL_PORT*$CRITICAL)/100))
	
	check_range $VALUE $CRITICAL
	RESULT=$?
	if [ "$RESULT" -eq 2 ] ; then
		exit $STATE_UNKNOWN
	fi
	
	if [ "$RESULT" -eq 0 ] ; then
		MESSAGE=( "PORT CRITICAL: $USED_PORT/$TOTAL_PORT" )
		EXIT_VAL=$STATE_CRITICAL
	else
		check_range $VALUE $WARNING
		RESULT=$?
		if [ "$RESULT" -eq 2 ] ; then
			exit $STATE_UNKNOWN
		fi
		
		if [ "$RESULT" -eq 0 ] ; then
			MESSAGE=( "PORT WARNING: $USED_PORT/$TOTAL_PORT" )
			EXIT_VAL=$STATE_WARNING
		else
			MESSAGE=( "PORT OK: $USED_PORT/$TOTAL_PORT" )
			EXIT_VAL=$STATE_OK
		fi
	fi

	PERFOMANCE=( "'port_usage'=$USED_PORT;$WARNING_PERCENT;$CRITICAL_PERCENT;0;$TOTAL_PORT'" )
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
while getopts "H:C:T:w:c:x:ihVv" OPTION;
do
	case $OPTION in
		"H")
			HOSTNAME=$OPTARG
		;;
		"C")
			COMMUNITY=$OPTARG
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
		"x")
			EXTRA=$OPTARG
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

# Do test
case "$TEST" in
	"FIRMWARE") firmware_test
		;;
	"LOAD")
		check_threshold
		load_usage
		;;
	"PORT")
		check_threshold
		port_usage
		;;
	"POWER") power_status
		;;
	"FAN") fan_status
		;;
	"TEMP")
		check_threshold
		temperature_status
		;;
	"DRAM")
		check_threshold
		dram_status
		;;
	"FLASH")
		check_threshold
		flash_status
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

exit $EXIT_VAL