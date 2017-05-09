#!/bin/bash
#
# check_disk_all.sh is a bash function to check Linux filesystem 
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
# 1.1	Minor changes
#		Replace [df -k] by [df -kP | tail -n$((\`df -kP | wc -l\`-1))]
#		Add perfomance data
# 1.2	Parameters by identifiers not by position
#		Add [-h] and [-V] options
# 1.2.1	Minor changes
# 1.3	Now checks used% and not free%
# 1.4	Checks free% and not used% again (like check_disk plugin)
#		Add warn and crit values on perfomance data
#		Now, -w and -c are not mandatory arguments
# 1.5	Now checks used% and not free%
# 1.6	Now include exclude/only filesystem type
# 1.7	Perfomance data fixed

# ----------------------------------
# VARIABLES
# ----------------------------------
VERSION="1.7"

WARNING=80
CRITICAL=90
EXCLUDE=
ONLY=

# ----------------------------------
# FUNCTIONS
# ----------------------------------

function print_version(){
	echo "$0 - version $VERSION"
	exit 0
}

function print_usage(){
	echo "Usage: $0 (-w <warn>) (-c <crit>) (-x <fs>) (-h) (-V)"
	exit 3
}

function print_help(){
	echo 'Nagios Filesystem Plugin'
	echo ''
	echo 'This plugin is not developed by the Nagios Plugin group.'
	echo 'Please do not e-mail them for support on this plugin.'
	echo ''
	echo 'For contact info, please read the plugin script file.'
	echo ''
	echo "Usage: $0 (-w <warn>) (-c <crit>) (-x <fs>|-o <fs>) (-h) (-V)"
	echo '---------------------------------------------------------------------'
	echo 'Usable Options:'
	echo '' 
	echo '   -w <warn>'
	echo "       warning threshold (% of consumable used) [default: $WARNING]"
	echo '   -c <crit>'
	echo "       critical threshold (% of consumable used) [default: $CRITICAL]"
	echo '   -x <fs>'
	echo '       excluded file system'
	echo '   -o <fs>'
	echo '       only filesystem type'
	echo '   -h'
	echo '       show this help screen'
	echo '   -V'
	echo '       show the current version of the plugin'
	echo ''
	echo 'Examples:'
	echo "    $0 -w 80 -c 90"
	echo "    $0 -w 80 -c 90 -x nfs"
	echo "    $0 -V"
	echo ''
	echo '---------------------------------------------------------------------'
	exit 3
}

# ----------------------------------
# MAIN CODE
# ----------------------------------

#if [ $# -eq 0 ]; then
#	print_usage
#fi

while getopts "w:c:x:o:hV" OPTION;
do
	case $OPTION in
		"w")
			WARNING=$OPTARG
		;;
		"c")
			CRITICAL=$OPTARG
		;;
		"x")
			EXCLUDE=$OPTARG
		;;
		"o")
			ONLY=$OPTARG
		;;
		"h")
			print_help
		;;
		"V")
			print_version
		;;
		*)
			print_help
		;;
	esac
done

if [ "$WARNING" -ge "$CRITICAL" ]
then
        echo "Warning value must be less than critical value"
        exit 3
fi

# Output for the dashboard
DF_CMD="df -kP"
if [ "$ONLY" != "" ]; then
	DF_CMD="${DF_CMD} -t ${ONLY}";
elif [ "$EXCLUDE" != "" ]; then
	DF_CMD="${DF_CMD} -x ${EXCLUDE}";
fi
`$DF_CMD > /dev/null 2>&1`
if [ $? -ne 0 ]; then
	echo "DISK USAGE UNKNOWN: No file systems processed" ; exit 3
fi
DF=`$DF_CMD | sed 1d`
RESULT=$(${DF_CMD} | sed 1d | grep -v devices|grep -v cdrom|grep -v proc|awk '{ print $6"("$5 ") "}'|sort -nr|tr -d '\n')
PERFOMANCE=$(${DF_CMD} | sed 1d | grep -v devices|grep -v cdrom|grep -v proc|awk  -v WARNING="$WARNING" -v CRITICAL="$CRITICAL" '{ print "'\''" $6 " %" "'\''" "="int($5)"%;"WARNING";"CRITICAL" "}'|tr -d '\n')

i=$(${DF_CMD} | sed 1d | grep -v devices|grep -v cdrom|grep -v proc|awk '{print int($5)}'|sort -nr| head -n1)

if [ "$i" -gt "$CRITICAL" ] ; then
	echo "DISK USAGE CRITICAL: $RESULT\n|$PERFOMANCE" ; exit 2
elif [ "$i" -gt "$WARNING" ] ; then
	echo -e "DISK USAGE WARNING: $RESULT\n|$PERFOMANCE" ; exit 1
else
	echo -e "DISK USAGE OK: $RESULT\n|$PERFOMANCE" ; exit 0
fi