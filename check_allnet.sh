#!/bin/bash
#
# check_allnet.sh is a bash function to check ALLNET 6700 
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

#
# PLUGIN INFORMATION
#
plugin_version=0.1

#
# ALLNET 6700 HTML
#
msg_OKFan='OK'
msg_OKPS='Healthy'
allnet_config=check_allnet.cfg

#
# ALLNET6700 REGULAR EXPRESSIONS
#
re_cpuloading='<th>(CPU Loading\(%\))</th>[[:space:]]+<td>[[:space:]]+<div class="number">([^<]+)'
re_cpufan='<th>(CPU Fan Speed)</th>[[:space:]]+<td>[[:space:]]+<div class="number">[[:space:]]*([^<]+)'
re_systemfan='<th>(System Fan Speed)</th>[[:space:]]+<td>[[:space:]]+<div class="number">[[:space:]]*([^<]+)'
re_ps='<th>(Power Supply)<br>\(Redundant Model\)</th>[[:space:]]+<td>[[:space:]]+<div class="number">[[:space:]]*([^<]+)'

#
# CONFIGURATION PARAMETERS
#
allnet_host=localhost
allnet_user=username
allnet_pass=password

sed 's/HOSTNAME/'$allnet_host'/g' $allnet_config > /tmp/check_allnet.$allnet_host.cfg

#wget -i /tmp/check_allnet.$allnet_host.cfg --post-data='username=$allnet_user&pwd=$allnet_pass&site=web_disk'

text=`cat /tmp/getform.html?name=system`

if [[ $text =~ $re_cpuloading ]]; then
	variable=`echo ${BASH_REMATCH[1]}`
	value=`echo ${BASH_REMATCH[2]}` 
	echo "$variable ($value)"
fi

if [[ $text =~ $re_cpufan ]]; then
	variable=`echo ${BASH_REMATCH[1]}`
	value=`echo ${BASH_REMATCH[2]}` 
	echo "$variable ($value)"
fi

if [[ $text =~ $re_systemfan ]]; then
	variable=`echo ${BASH_REMATCH[1]}`
	value=`echo ${BASH_REMATCH[2]}` 
	echo "$variable ($value)"
fi

if [[ $text =~ $re_ps ]]; then
	variable=`echo ${BASH_REMATCH[1]}`
	value=`echo ${BASH_REMATCH[2]}` 
	echo "$variable ($value)"
fi 
