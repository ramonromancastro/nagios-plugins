#!/bin/bash
#
# check_3com_29xx.sh is a bash function to check 3Com Baseline Switch 29xx-SFP Plus 
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
# 0.2	Minor changes. Add CPU checks
# 0.3	Remove port usage check
# 0.4	Add FIRMWARE and LOAD test
# 0.5	Add HEALTH test
# 0.6	Add license

# ----------------------------------
# VARIABLES
# ----------------------------------
VERSION="0.6"
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`

DEPENDENCIES=("snmpwalk" "snmpget")

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

STATE_DESCRIPTION=( "OK" "WARNING" "CRITICAL" "UNKNOWN" "DEPENDENT" )
EntitySensorStatus_Description=( "ok" "unavailable" "nonoperational" )
EntitySensorStatus_ExitCodes=( $STATE_OK $STATE_UNKNOWN $STATE_CRITICAL )
RlEnvMonState_Description=( "normal" "warning" "critical" "shutdown" "notPresent" "notFunctioning" )
RlEnvMonState_ExitCodes=( $STATE_OK $STATE_WARNING $STATE_CRITICAL $STATE_CRITICAL $STATE_OK $STATE_WARNING )

WARNING=80
CRITICAL=90

# OID VALUES
oid_rlCpuUtilEnable=.1.3.6.1.4.1.89.1.6.0 # Value must be 1. If not, CPU values are invalid
oid_rlCpuUtilDuringLastSecond=.1.3.6.1.4.1.89.1.7.0
oid_rlCpuUtilDuringLastMinute=.1.3.6.1.4.1.89.1.8.0
oid_rlCpuUtilDuringLast5Minutes=.1.3.6.1.4.1.89.1.9.0

# OID TABLES
oid_rlPhdUnitGenParamStackUnit=.1.3.6.1.4.1.89.53.14.1.1
oid_rlPhdUnitGenParamSoftwareVersion=.1.3.6.1.4.1.89.53.14.1.2
oid_rlPhdUnitGenParamFirmwareVersion=.1.3.6.1.4.1.89.53.14.1.3
oid_rlPhdUnitGenParamHardwareVersion=.1.3.6.1.4.1.89.53.14.1.4
oid_rlPhdUnitGenParamSerialNum=.1.3.6.1.4.1.89.53.14.1.5

oid_rlPhdUnitEnvParamStackUnit=.1.3.6.1.4.1.89.53.15.1.1
oid_rlPhdUnitEnvParamUpTime=.1.3.6.1.4.1.89.53.15.1.11
oid_rlPhdUnitEnvParamMainPSStatus=.1.3.6.1.4.1.89.53.15.1.2
oid_rlPhdUnitEnvParamRedundantPSStatus=.1.3.6.1.4.1.89.53.15.1.3
oid_rlPhdUnitEnvParamFan1Status=.1.3.6.1.4.1.89.53.15.1.4
oid_rlPhdUnitEnvParamFan2Status=.1.3.6.1.4.1.89.53.15.1.5
oid_rlPhdUnitEnvParamFan3Status=.1.3.6.1.4.1.89.53.15.1.6
oid_rlPhdUnitEnvParamFan4Status=.1.3.6.1.4.1.89.53.15.1.7
oid_rlPhdUnitEnvParamFan5Status=.1.3.6.1.4.1.89.53.15.1.8
oid_rlPhdUnitEnvParamTempSensorValue=.1.3.6.1.4.1.89.53.15.1.9
oid_rlPhdUnitEnvParamTempSensorStatus=.1.3.6.1.4.1.89.53.15.1.10

COMMUNITY=127.0.0.1
HOSTNAME=public
INTERFACE=117
VERBOSE=
TEST=
EXTRA=
MESSAGE=( )
PERFOMANCE=
WARNING=80
CRITICAL=90
EXIT_VAL=$STATE_OK

# ----------------------------------
# FUNCTIONS
# ----------------------------------

function check_EntitySensorStatus(){
	PARAM_VAL=$1
	case ${EntitySensorStatus_ExitCodes[$[PARAM_VAL-1]]} in
		0)
			;;
		1)
			NWARN=$((NWARN+1))
			;;
		2)
			NCRIT=$((NCRIT+1))
			;;
		*)
			NUNKN=$((NUNKN+1))
			;;
	esac
}

function check_RlEnvMonState(){
	PARAM_VAL=$1
	case ${RlEnvMonState_ExitCodes[$[PARAM_VAL-1]]} in
		0)
			;;
		1)
			NWARN=$((NWARN+1))
			;;
		2)
			NCRIT=$((NCRIT+1))
			;;
		*)
			NUNKN=$((NUNKN+1))
			;;
	esac
}

function check_threshold(){
	if [ "$WARNING" == "" ] || [ "$CRITICAL" == "" ]; then
		print_help
	fi
}

function snmp_number(){
	SNMP_VALUE=`snmpget -v 2c -Oe -c $COMMUNITY $HOSTNAME $1 | cut -d " " -f4`
	echo $SNMP_VALUE
}

function snmp_string(){
	SNMP_VALUE=`snmpget -v 2c -Oe -c $COMMUNITY $HOSTNAME $1 | cut -d " " -f4 | cut -d "\"" -f2`
	echo $SNMP_VALUE
}

function verb(){
	if [ -n "$VERBOSE" ]; then echo "[ INFO ] $1"; fi
}

function set_state(){
	PARAM_VAL=$1
	case $EXIT_VAL in
		$STATE_OK)
			EXIT_VAL=$PARAM_VAL
			;;
		$STATE_WARNING)
			if [ $PARAM_VAL -eq $STATE_CRITICAL]; then
				EXIT_VAL=$PARAM_VAL
			fi
			;;
	esac
}

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

function print_version(){
	echo "$0 - version $VERSION"
	exit $STATE_OK
}

function print_help(){
	echo "3Com Baseline Switch 29xx-SFP Plus"
	echo ""
	echo "This plugin is not developped by the Nagios Plugin group."
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
	echo "      HEALTH       ... Health test (FA, PS, Temp)"
	echo "   -w <warn>       ... warning threshold"
	echo "   -c <crit>       ... critical threshold"
	echo "   -x <arg>        ... extra arguments"
	echo "   -h              ... show this help screen"
	echo "   -V              ... show the current version of the plugin"
	echo "   -v              ... print extra debugging information"
	echo ''
	echo 'Examples:'
	echo "    $0 -h 127.0.0.1 -C public"
	echo "    $0 -V"
	echo ""
	echo "------------------------------------------------------------------------------------"
	exit $STATE_UNKNOWN
}

function health_test(){
	NWARN=0
	NCRIT=0
	NUNKN=0
	verb "Reading rlPhdUnitEnvParamStackUnit"
	UNIT_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_rlPhdUnitEnvParamStackUnit | cut -d " " -f4 ))
	verb "Reading rlPhdUnitEnvParamMainPSStatus"
	MAINPS_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_rlPhdUnitEnvParamMainPSStatus | cut -d " " -f4 ))
	verb "Reading rlPhdUnitEnvParamRedundantPSStatus"
	REDUNDANTPS_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_rlPhdUnitEnvParamRedundantPSStatus | cut -d " " -f4 ))
	verb "Reading rlPhdUnitEnvParamFan1Status"
	FAN1_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_rlPhdUnitEnvParamFan1Status | cut -d " " -f4 ))
	verb "Reading rlPhdUnitEnvParamFan2Status"
	FAN2_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_rlPhdUnitEnvParamFan2Status | cut -d " " -f4 ))
	verb "Reading rlPhdUnitEnvParamFan3Status"
	FAN3_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_rlPhdUnitEnvParamFan3Status | cut -d " " -f4 ))
	verb "Reading rlPhdUnitEnvParamFan4Status"
	FAN4_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_rlPhdUnitEnvParamFan4Status | cut -d " " -f4 ))
	verb "Reading rlPhdUnitEnvParamFan5Status"
	FAN5_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_rlPhdUnitEnvParamFan5Status | cut -d " " -f4 ))
	verb "Reading rlPhdUnitEnvParamTempSensorValue"
	TEMPVALUE_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_rlPhdUnitEnvParamTempSensorValue | cut -d " " -f4 ))
	verb "Reading rlPhdUnitEnvParamTempSensorStatus"
	TEMPSTATUS_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_rlPhdUnitEnvParamTempSensorStatus | cut -d " " -f4 ))
	
	for i in ${!UNIT_TABLE[*]}; do
		check_RlEnvMonState "${MAINPS_TABLE[$i]}"
		MESSAGE=( "${MESSAGE[@]}" "Unit${UNIT_TABLE[$i]}.MainPS: ${RlEnvMonState_Description[$[${MAINPS_TABLE[$i]}-1]]}" )
		check_RlEnvMonState "${REDUNDANTPS_TABLE[$i]}"
		MESSAGE=( "${MESSAGE[@]}" "Unit${UNIT_TABLE[$i]}.RedundantPS: ${RlEnvMonState_Description[$[${REDUNDANTPS_TABLE[$i]}-1]]}" )
		check_RlEnvMonState "${FAN1_TABLE[$i]}"
		MESSAGE=( "${MESSAGE[@]}" "Unit${UNIT_TABLE[$i]}.Fan1: ${RlEnvMonState_Description[$[${FAN1_TABLE[$i]}-1]]}" )
		check_RlEnvMonState "${FAN2_TABLE[$i]}"
		MESSAGE=( "${MESSAGE[@]}" "Unit${UNIT_TABLE[$i]}.Fan2: ${RlEnvMonState_Description[$[${FAN2_TABLE[$i]}-1]]}" )
		check_RlEnvMonState "${FAN3_TABLE[$i]}"
		MESSAGE=( "${MESSAGE[@]}" "Unit${UNIT_TABLE[$i]}.Fan3: ${RlEnvMonState_Description[$[${FAN3_TABLE[$i]}-1]]}" )
		check_RlEnvMonState "${FAN4_TABLE[$i]}"
		MESSAGE=( "${MESSAGE[@]}" "Unit${UNIT_TABLE[$i]}.Fan4: ${RlEnvMonState_Description[$[${FAN4_TABLE[$i]}-1]]}" )
		check_RlEnvMonState "${FAN5_TABLE[$i]}"
		MESSAGE=( "${MESSAGE[@]}" "Unit${UNIT_TABLE[$i]}.Fan5: ${RlEnvMonState_Description[$[${FAN5_TABLE[$i]}-1]]}" )
		MESSAGE=( "${MESSAGE[@]}" "Unit${UNIT_TABLE[$i]}.Temp: ${EntitySensorStatus_Description[$[${TEMPSTATUS_TABLE[$i]}-1]]}" )
		if [ "${TEMPVALUE_TABLE[$i]}" -ne 0 ]; then
			check_EntitySensorStatus "${TEMPSTATUS_TABLE[$i]}"
			MESSAGE=( "${MESSAGE[@]}" "Unit${UNIT_TABLE[$i]}.Temp.Celsius ${TEMPVALUE_TABLE[$i]}" )
		fi
		#TEMPVALUE_TABLE
		#TEMPSTATUS_TABLE
	done
	
	if [ "$NCRIT" -gt 0 ]; then
		MESSAGE=( "CRITICAL: $NCRIT sensors are in critical state" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_CRITICAL
	elif [ "$NWARN" -gt 0 ]; then
		MESSAGE=( "WARNING: $NWARN sensors are in warning state" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_WARNING
	elif [ "$NUNKN" -gt 0 ]; then
		MESSAGE=( "UNKNOWN: $NUNKN sensors are in unknown state" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_UNKNOWN
	else
		MESSAGE=( "OK: All sensors are ok" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_OK
	fi
}

function firmware_test(){
	NUNITS=0
	NWARN=0
	if [ -n "$VERBOSE" ]; then echo "[ ] Reading rlPhdUnitGenParamStackUnit"; fi
	NAME_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_rlPhdUnitGenParamStackUnit | cut -d " " -f4 ))
	if [ -n "$VERBOSE" ]; then echo "[ ] Reading rlPhdUnitGenParamFirmwareVersion"; fi
	FIRMWARE_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_rlPhdUnitGenParamFirmwareVersion | cut -d "\"" -f2 ))
	if [ -n "$VERBOSE" ]; then echo "[ ] Reading rlPhdUnitGenParamSerialNum"; fi
	SERIAL_TABLE=($( snmpwalk -v 2c -c $COMMUNITY $HOSTNAME $oid_rlPhdUnitGenParamSerialNum | cut -d "\"" -f2 ))
	
	for i in ${!NAME_TABLE[*]}; do
		if [ -n "$VERBOSE" ]; then
			echo "[ ] $oid_rlPhdUnitGenParamStackUnit = ${NAME_TABLE[$i]}"
			echo "[ ] $oid_rlPhdUnitGenParamFirmwareVersion = ${FIRMWARE_TABLE[$i]}"
			echo "[ ] $oid_rlPhdUnitGenParamSerialNum = ${SERIAL_TABLE[$i]}"
		fi
		
		if [ ! "${FIRMWARE_TABLE[$i]}" == "$EXTRA" ]; then
			MESSAGE=( "${MESSAGE[@]}" "CRITICAL: Unit: ${NAME_TABLE[$i]}, SerialNumber: ${SERIAL_TABLE[$i]}, Firmware: ${FIRMWARE_TABLE[$i]}" )
			NWARN=$((NWARN+1))
		else
			MESSAGE=( "${MESSAGE[@]}" "Unit: ${NAME_TABLE[$i]}, SerialNumber: ${SERIAL_TABLE[$i]}, Firmware: ${FIRMWARE_TABLE[$i]}" )
		fi
		NUNITS=$((NUNITS+1))
	done
	
	if [ "$NWARN" -gt 0 ]; then
		MESSAGE=( "FIRMWARE CRITICAL: One or more firmwares are in warning state" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_CRITICAL
	else
		MESSAGE=( "FIRMWARE OK: All firmwares are ok" "${MESSAGE[@]}")
		EXIT_VAL=$STATE_OK
	fi
}

function load_usage(){
	verb "Read rlCpuUtilEnable"
	rlCpuUtilEnable=$(snmp_number $oid_rlCpuUtilEnable)
	
	verb "Read rlCpuUtilDuringLastSecond"
	rlCpuUtilDuringLastSecond=$(snmp_number $oid_rlCpuUtilDuringLastSecond)
	
	verb "Read rlCpuUtilDuringLastMinute"
	rlCpuUtilDuringLastMinute=$(snmp_number $oid_rlCpuUtilDuringLastMinute)
	
	verb "Read rlCpuUtilDuringLast5Minutes"
	rlCpuUtilDuringLast5Minutes=$(snmp_number $oid_rlCpuUtilDuringLast5Minutes)

	if [ $rlCpuUtilEnable -eq 1 ]; then
		check_range $rlCpuUtilDuringLast5Minutes $CRITICAL
		RESULT=$?
		if [ "$RESULT" -eq 2 ] ; then
			set_state $STATE_UNKNOWN
		fi

		if [ "$RESULT" -eq 0 ] ; then
			MESSAGE=( "LOAD CRITICAL: $rlCpuUtilDuringLast5Minutes%" )
			set_state $STATE_CRITICAL
		else
			check_range $rlCpuUtilDuringLast5Minutes $WARNING
			RESULT=$?
			if [ "$RESULT" -eq 2 ] ; then
				set_state $STATE_UNKNOWN
			fi
			
			if [ "$RESULT" -eq 0 ] ; then
				MESSAGE=( "LOAD WARNING: $rlCpuUtilDuringLast5Minutes%" )
				set_state $STATE_WARNING
			else
				MESSAGE=( "LOAD OK: $rlCpuUtilDuringLast5Minutes%" )
				set_state $STATE_OK
			fi
		fi
		MESSAGE=( "${MESSAGE[@]}" "Load: $rlCpuUtilDuringLast5Minutes%")
	fi
	PERFOMANCE=( "${PERFOMANCE[@]}" "'load_1s'=$rlCpuUtilDuringLastSecond%;$WARNING;$CRITICAL;0;100")
	PERFOMANCE=( "${PERFOMANCE[@]}" "'load_1m'=$rlCpuUtilDuringLastMinute%;$WARNING;$CRITICAL;0;100")
	PERFOMANCE=( "${PERFOMANCE[@]}" "'load_5m'=$rlCpuUtilDuringLast5Minutes%;$WARNING;$CRITICAL;0;100")
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
while getopts "H:C:T:w:c:x:hVv" OPTION;
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
	"FIRMWARE")
		firmware_test
		;;
	"LOAD")
		check_threshold
		load_usage
		;;
	"HEALTH")
		health_test
		;;
	*)
		print_help
		;;
esac

# Show result
for i in ${!MESSAGE[*]};do
	echo ${MESSAGE[$i]}
done
echo -n "|"
for i in ${!PERFOMANCE[*]};do
	echo -n "${PERFOMANCE[$i]} "
done

exit $EXIT_VAL