#!/usr/bin/php
<?php
/*
check_eternus_advcopy.php is a PHP function to check Eternus DX Advanced Copy sessions 
Copyright (C) 2017 Ramon Roman Castro <ramonromancastro@gmail.com>

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option)
any later version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see http://www.gnu.org/licenses/.

@package    nagios-plugins
@author     Ramon Roman Castro <ramonromancastro@gmail.com>
@link       http://www.rrc2software.com
@link       https://github.com/ramonromancastro/nagios-plugins
*/

/*
Devices tested
	- ETERNUS DX 80 S2
	- ETERNUS DX 90 S2

Usage:
	check_eternus_advcopy  -H <hostname> (-p <port>) -U username -P password (-h) (-V)
		-H <hostname>	IP Address/Hostname of FUJITSU ETERNUS device
		-p <port>		SSH port (Default: 22)
		-U <username>	Username (At least [Monitor] User Role)
		-P <password>	Password
		-h				Print usage
		-V				Print plugin version
History:
	0.1		Initial version
	0.2		Improve output messages, disable PHP errors
	0.3		Include plugins details on source code, improve output messages
*/
// Disable all error messages
error_reporting(0);

// CONSTANTS
define("NAGIOS_EXITCODE_OK",0);
define("NAGIOS_EXITCODE_WARNING",1);
define("NAGIOS_EXITCODE_CRITICAL",2);
define("NAGIOS_EXITCODE_UNKNOWN",3);

define("MSG_HEADER","Advanced Copy");
define("PLUGIN_NAME","check_eternus_advcopy");
define("PLUGIN_VERSION","0.3");

// ARRAYS
$nagios_exitCodes_desc = Array("OK","WARNING","CRITICAL","UNKNOWN");

// DEFAULT VALUES
$username="username";
$password="password";
$hostname="127.0.0.1";
$port=22;

// ETERNUS DX CLI COMMANDS
$cli_advancedcopysessions="show advanced-copy-sessions -type all";
$cli_advancedcopysessions_regexp='/(\d+)\s+(\S+)\s+(\S+)\s+(\S[\S ]+?)\s+(\d+)\s+(\S+)\s+(\d+)\s+(\S+)\s+(\S[\S ]+?)\s+(\S[\S ]+?)\s+(\S+)\s+(\S+)/';

// VARIABLES
$exitCode = NAGIOS_EXITCODE_OK;
$exitMsg  = MSG_HEADER.'OK';
$exitExtMsg = '';
$totalSessions = 0;

// FUNCTIONS
function setNagiosExitCode($newExitCode){
	global $exitCode;
	if ($newExitCode == NAGIOS_EXITCODE_CRITICAL)
		$exitCode = NAGIOS_EXITCODE_CRITICAL;
	elseif (($newExitCode == NAGIOS_EXITCODE_WARNING) && ($exitCode != NAGIOS_EXITCODE_CRITICAL))
		$exitCode = NAGIOS_EXITCODE_WARNING;
	elseif (($newExitCode == NAGIOS_EXITCODE_UNKNOWN) && ($exitCode != NAGIOS_EXITCODE_CRITICAL) && ($exitCode != NAGIOS_EXITCODE_WARNING))
		$exitCode = NAGIOS_EXITCODE_UNKNOWN;
}

function setNagiosMsg($msg){
	global $exitMsg;
	$exitMsg = $msg;
}

function setNagiosExtMsg($msg){
	global $exitExtMsg;
	$exitExtMsg .= $msg."\n";
}

function printUsage(){
	echo "Usage: ".PLUGIN_NAME." -H <hostname> (-p <port>) -U username -P password (-h) (-V)\n";
	$exitCode = NAGIOS_EXITCODE_UNKNOWN;
	exit($exitCode);
}

function printVersion(){
	echo "Version: ".PLUGIN_NAME." ".PLUGIN_VERSION."\n";
	$exitCode = NAGIOS_EXITCODE_UNKNOWN;
	exit($exitCode);
}

function printExitMsg(){
	global $exitCode,$exitMsg,$nagios_exitCodes_desc;
	printf("%s %s: %s\n",MSG_HEADER,$nagios_exitCodes_desc[$exitCode],$exitMsg);
}

function parseParameters($noopt = array()) {
	$result = array();
	$params = $GLOBALS['argv'];
	// could use getopt() here (since PHP 5.3.0), but it doesn't work relyingly
	reset($params);
	while (list($tmp, $p) = each($params)) {
		if ($p{0} == '-') {
			$pname = substr($p, 1);
			$value = true;
			if ($pname{0} == '-') {
				// long-opt (--<param>)
				$pname = substr($pname, 1);
				if (strpos($p, '=') !== false) {
					// value specified inline (--<param>=<value>)
					list($pname, $value) = explode('=', substr($p, 2), 2);
				}
			}
			// check if next parameter is a descriptor or a value
			$nextparm = current($params);
			if (!in_array($pname, $noopt) && $value === true && $nextparm !== false && $nextparm{0} != '-') list($tmp, $value) = each($params);
			$result[$pname] = $value;
		} else {
			// param doesn't belong to any option
			$result[] = $p;
		}
	}
	return $result;
}

// Check ssh2 library exists
if (!function_exists("ssh2_connect")){
	die("function ssh2_connect doesn't exist. Please install php");
}

// Read parameters
$options = parseParameters(Array("h","V"));

// Check parameters
if (isset($options["h"])) printUsage();
if (isset($options["V"])) printVersion();
if (!isset($options["H"]) || !isset($options["U"]) || !isset($options["P"])) printUsage();

// Assign parameters
$username=$options["U"];
$password=$options["P"];
$hostname=$options["H"];
if (isset($options["p"])) $port=$options["p"];


if(!($con = ssh2_connect($hostname, $port))){
	setNagiosExitCode(NAGIOS_EXITCODE_WARNING);
	setNagiosMsg("Unable to establish connection");
} else {
	if(!ssh2_auth_password($con, $username, $password)) {
		setNagiosExitCode(NAGIOS_EXITCODE_WARNING);
		setNagiosMsg("Unable to authenticate");
	} else {
		$shell = ssh2_shell($con,"vt102");
		stream_set_blocking($shell, false);
		fwrite($shell, $cli_advancedcopysessions . PHP_EOL);
		sleep(2);
		$advancedcopysessions = stream_get_contents($shell);
		fwrite($shell, "exit" . PHP_EOL);
		fclose($shell);
		$advancedcopysessions = explode(PHP_EOL, $advancedcopysessions);
		for ($i=4;$i<count($advancedcopysessions)-1;$i++){
			$totalSessions++;

			if (preg_match($cli_advancedcopysessions_regexp,$advancedcopysessions[$i],$properties)){
				if (preg_match('/^(EC|OPC|QuickOPC|SnapOPC|SnapOPC\+|Monitor)$/',$properties[3])){		
					switch ($properties[9]) {
						case "Active":
						case "Reserved":
						case "Suspend":
							setNagiosExitCode(NAGIOS_EXITCODE_OK);
							setNagiosExtMsg("$properties[3] ($properties[6] > $properties[8]) is $properties[9]");
							break;
						case "Error Suspend":
							setNagiosExitCode(NAGIOS_EXITCODE_CRITICAL);
							setNagiosExtMsg("CRITICAL - $properties[3] ($properties[6] > $properties[8]) is $properties[9]");
							break;
						case "Unknown":
							setNagiosExitCode(NAGIOS_EXITCODE_WARNING);
							setNagiosExtMsg("WARNING - $properties[3] ($properties[6] > $properties[8]) is $properties[9]");
							break;
						default:
							setNagiosExitCode(NAGIOS_EXITCODE_UNKNOWN);
							setNagiosExtMsg("UNKNOWN - $properties[3] ($properties[6] > $properties[8]) is $properties[9]");
					};
				}
				elseif (preg_match('/^REC$/',$properties[3])){		
					switch ($properties[9]) {
						case "Active":
						case "Reserved":
						case "Suspend":
							setNagiosExitCode(NAGIOS_EXITCODE_OK);
							setNagiosExtMsg("$properties[3] ($properties[6] > $properties[8]) is $properties[9]");
							break;
						case "Halt":
						case "Error Suspend":
							setNagiosExitCode(NAGIOS_EXITCODE_CRITICAL);
							setNagiosExtMsg("CRITICAL - $properties[3] ($properties[6] > $properties[8]) is $properties[9]");
							break;
						case "Unknown":
							setNagiosExitCode(NAGIOS_EXITCODE_WARNING);
							setNagiosExtMsg("WARNING - $properties[3] ($properties[6] > $properties[8]) is $properties[9]");
							break;
						default:
							setNagiosExitCode(NAGIOS_EXITCODE_UNKNOWN);
							setNagiosExtMsg("UNKNOWN - $properties[3] ($properties[6] > $properties[8]) is $properties[9]");
					};
				}
				elseif (preg_match('/^ODX$/',$properties[3])){		
					switch ($properties[9]) {
						case "Active":
						case "Reserved":
							setNagiosExtMsg("$properties[3] ($properties[6] > $properties[8]) is $properties[9]");
							setNagiosExitCode(NAGIOS_EXITCODE_OK);
							break;
						case "Error Suspend":
							setNagiosExitCode(NAGIOS_EXITCODE_CRITICAL);
							setNagiosExtMsg("CRITICAL - $properties[3] ($properties[6] > $properties[8]) is $properties[9]");
							break;
						case "Unknown":
							setNagiosExitCode(NAGIOS_EXITCODE_WARNING);
							setNagiosExtMsg("WARNING - $properties[3] ($properties[6] > $properties[8]) is $properties[9]");
							break;
						default:
							setNagiosExitCode(NAGIOS_EXITCODE_UNKNOWN);
							setNagiosExtMsg("UNKNOWN - $properties[3] ($properties[6] > $properties[8]) is $properties[9]");
					}
				}
				else{
					setNagiosExitCode(NAGIOS_EXITCODE_UNKNOWN);
					setNagiosExtMsg("UNKNOWN TYPE - $properties[3] ($properties[6] > $properties[8]) is $properties[9]");
				}
			}
		}
		setNagiosMsg("$totalSessions session(s)");
	}
}
echo printExitMsg();
echo $exitExtMsg;
exit($exitCode);
?>

