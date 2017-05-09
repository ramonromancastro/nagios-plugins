#!/bin/bash
#
# check_apc_agent.sh is a bash function to check APC PowerChute agent 
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

# NAGIOS CONSTANTS

PLUGIN_NAGIOS_RETURN_OK=0
PLUGIN_NAGIOS_RETURN_WARNING=1
PLUGIN_NAGIOS_RETURN_CRITICAL=2
PLUGIN_NAGIOS_RETURN_UNKNOWN=3

# LOCAL CONSTANTS

PLUGIN_STATUS_NORMAL='On line.*'

# LOCAL VARIABLES

PLUGIN_SERVER=localhost
PLUGIN_WARNING=20
PLUGIN_CRITICAL=10

# REGULAR EXPRESSIONS

PLUGIN_REGEX_STATUS="\|Device Status\|([^\|]+)\|"
PLUGIN_REGEX_RUNTIME="\|Runtime Remaining\|([0-9]+)\|"
PLUGIN_REGEX_LOAD="\|UPS Load\|([0-9]+(,[0-9]+)?)\|"

# READ PARAMETERS

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 SERVER WARNING-LEVEL CRITICAL-LEVEL"
    exit 1
fi

PLUGIN_SERVER=$1
PLUGIN_WARNING=$2
PLUGIN_CRITICAL=$3

PLUGIN_HTML_RESPONSE=`wget -q --no-check-certificate -O - https://$PLUGIN_SERVER:6547/quickstatus | tr  "\r\n" "|" | sed 's/<[^>]*>//g;s/ \{2,\}//g;s/|\{2,\}/|/g'`
PLUGIN_REGEX_STATUS_VALUE="Unknown"
PLUGIN_REGEX_RUNTIME_VALUE=0
PLUGIN_RESULT=$PLUGIN_NAGIOS_RETURN_OK

if [[ $PLUGIN_HTML_RESPONSE =~ $PLUGIN_REGEX_STATUS ]]; then
	PLUGIN_REGEX_STATUS_VALUE=${BASH_REMATCH[1]}
	if [[ ! $PLUGIN_REGEX_STATUS_VALUE =~ $PLUGIN_STATUS_NORMAL ]]; then
		PLUGIN_RESULT=$PLUGIN_NAGIOS_RETURN_WARNING
	fi
else
	PLUGIN_RESULT=$PLUGIN_NAGIOS_RETURN_UNKNOWN
fi

if [[ $PLUGIN_HTML_RESPONSE =~ $PLUGIN_REGEX_LOAD ]]; then
	PLUGIN_REGEX_LOAD_VALUE=${BASH_REMATCH[1]}
fi

if [[ $PLUGIN_HTML_RESPONSE =~ $PLUGIN_REGEX_RUNTIME ]]; then
	PLUGIN_REGEX_RUNTIME_VALUE=${BASH_REMATCH[1]}
	if [[ $PLUGIN_REGEX_RUNTIME_VALUE -le $PLUGIN_CRITICAL ]]; then
		PLUGIN_RESULT=$PLUGIN_NAGIOS_RETURN_CRITICAL
	elif [[ $PLUGIN_REGEX_RUNTIME_VALUE -le $PLUGIN_WARNING ]]; then
			PLUGIN_RESULT=$PLUGIN_NAGIOS_RETURN_WARNING
	fi
else
	PLUGIN_RESULT=$PLUGIN_NAGIOS_RETURN_UNKNOWN
fi

echo "Device Status: $PLUGIN_REGEX_STATUS_VALUE"
echo "UPS Load: $PLUGIN_REGEX_LOAD_VALUE %"
echo "Runtime Remaining: $PLUGIN_REGEX_RUNTIME_VALUE Minutes"
echo "|'avail_time'=$PLUGIN_REGEX_RUNTIME_VALUE 'ups_load'=$PLUGIN_REGEX_LOAD_VALUE%"
exit $PLUGIN_RESULT
