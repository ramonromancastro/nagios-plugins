#!/usr/bin/php
<?php
/*
check_mysql.php checks MySQL server status.
Copyright (C) 2017-2022 Ramón Román Castro <ramonromancastro@gmail.com>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

define("NAGIOS_OK",0);
define("NAGIOS_WARNING",1);
define("NAGIOS_CRITICAL",2);
define("NAGIOS_UNKNOWN",3);

define("TEST_UNIT",0);
define("TEST_CHECK_OP",1);
define("TEST_CHECK_VALUE",2);
define("TEST_PERF",3);
define("TEST_VALUE",4);

define("PROGNAME","check_mysql.php");
define("VERSION","0.6");

$mysql_checks = array(
	"pct_slow_queries"          	=> array("%", ">",  5, "5",   'round(100*$mystat{"Slow_queries"} / $mystat{"Questions"},2)'),
	"pct_connections_used"      	=> array("%", ">", 85, "85",  'round(100*$mystat["Threads_connected"] / $mystat["max_connections"],2)'),
	"pct_connections_aborted"   	=> array("%", ">",  3, "3",   'round(100*$mystat{"Aborted_connects"} / $mystat{"Connections"},2)'),
	"query_cache_efficiency"		=> array("%", "<", 20, "20:", 'round(100*$mystat{"Qcache_hits"} / ( $mystat{"Com_select"} + $mystat{"Qcache_hits"} ),2)'),
	"query_cache_prunes_per_day"	=> array("",  ">", 98, "98",  '$mystat{"Qcache_lowmem_prunes"} / ( $mystat{"Uptime"} / 86400 )'),
	"pct_temp_sort_table"			=> array("%", ">", 10, "10",  '($mystat{"Sort_scan"} + $mystat{"Sort_range"} > 0)?round(100*$mystat{"Sort_merge_passes"} / ($mystat{"Sort_scan"} + $mystat{"Sort_range"}),2):0'),
	"pct_temp_disk"					=> array("%", ">", 25, "25",  '($mystat{"Created_tmp_tables"}>0)?round(100*$mystat{"Created_tmp_disk_tables"}/$mystat{"Created_tmp_tables"},2):0'),
	"thread_cache_hit_rate"			=> array("%", "<", 51, "51:", 'round(100 - ( 100 * $mystat{"Threads_created"} / $mystat{"Connections"} ),2)'),
	"table_cache_hit_rate"      	=> array("%", "<", 20, "20:", 'round(100*$mystat["Open_tables"]/$mystat["Opened_tables"],2)'),
	"pct_files_open"				=> array("%", ">", 85, "85",  '($mystat{"open_files_limit"}>0)?round(100 * $mystat{"Open_files"} / $mystat{"open_files_limit"},2):0'),
	"pct_table_locks_immediate" 	=> array("%", "<", 95, "95:", 'round(100*$mystat{"Table_locks_immediate"}/($mystat{"Table_locks_waited"} + $mystat{"Table_locks_immediate"}),2)'),
	"pct_innodb_buffer_used"    	=> array("%", "<", 95, "95:", '(array_key_exists("Innodb_buffer_pool_pages_total",$mystat))?round(100*($mystat["Innodb_buffer_pool_pages_total"]-$mystat["Innodb_buffer_pool_pages_free"])/$mystat["Innodb_buffer_pool_pages_total"],2):100'),
);

function nagios_exitCode2Text($exitCode){
	$text = array(0 => "OK", "WARNING", "CRITICAL", "UNKNOWN");
	return $text[$exitCode];
}

function printVersion(){
	echo PROGNAME . ' v' . VERSION . " (www.rrc2software.com)\n";
}

function printUsage(){
	echo "Usage:\n".
		 " " . PROGNAME . " -H<host> -u<user> -p<password> -s<status> [-V] [-h]\n";
}

function printHelp(){
	global $mysql_checks;
	
	printVersion();
	echo "Copyright (C) 2017-2022 Ramón Román Castro\n".
		 "        <ramonromancastro@gmail.com>\n\n".
		 "This program tests MySQL server status using precalculated queries\n".
		 "over global variables and configurations\n\n\n";
	printUsage();
	echo "\nOptions:\n".
		 " -H<host>\n    MySQL IP address or name\n".
		 " -u<username>\n    MySQL IP address or name\n".
		 " -p<password>\n    MySQL IP address or name\n".
		 " -s<status>\n    MySQL test name\n".
		 " -i\n    Always return exitCode OK and status INFO (for info purpose)\n".
		 " -V\n    Print version information\n".
		 " -h\n    Print detailed help screen\n\n".
		 "Availables MySQL status are:\n";
	$checks = array_keys($mysql_checks);
	sort($checks);
	echo " " . implode("\n ",$checks) . "\n\n";
	echo "Send email to ramonromancastro@gmail.com if you have questions regarding use\n" .
         "of this software. To submit patches or suggest improvements, send email to\n".
         "ramonromancastro@gmail.com\n\n";
}

function makeTest($check,$mystat){
	global $mysql_checks,$options;
	eval('$value='.$mysql_checks[$check][TEST_VALUE].';');
	eval('$result=('.$value.$mysql_checks[$check][TEST_CHECK_OP].$mysql_checks[$check][TEST_CHECK_VALUE].');');
	echo "MYSQL " . ((array_key_exists("i",$options))?"INFO":nagios_exitCode2Text($result)) . " - $check $value" . $mysql_checks[$check][TEST_UNIT] . "\n";
	echo "|\"$check\"=".floor($value) . $mysql_checks[$check][TEST_UNIT] . ";" . $mysql_checks[$check][TEST_PERF] . ";\n";
	return (array_key_exists("i",$options))?NAGIOS_OK:$result;
}

#
# PARSE PARAMETERS
#

$options = getopt("H:u:p:s:iVh");

#
# CHECK PARAMETERS
#

if (!count($options)){
	echo PROGNAME . ": Could not parse arguments\n";
	printUsage();
	exit(NAGIOS_UNKNOWN);
}

if (array_key_exists("h",$options)){
	printHelp();
	exit(NAGIOS_UNKNOWN);
}

if (array_key_exists("V",$options)){
	printVersion();
	exit(NAGIOS_UNKNOWN);
}

if (array_key_exists("s",$options)){
	if (!array_key_exists($options["s"],$mysql_checks)){
		echo "UNKNOWN - Invalid check.\n";
		exit(NAGIOS_UNKNOWN);
	}
}
else{
    echo "UNKNOWN - Unknown check.\n";
    exit(NAGIOS_UNKNOWN);
}

#
# CONNECT TO MYSQL SERVER AND RETRIEVE VALUES
#

$dblink = @new mysqli($options["H"], $options["u"], $options["p"]);

if ($dblink->connect_errno) {
    echo "WARNING - Unable to connect to server.\n";
    exit(NAGIOS_WARNING);
}

if (($result = $dblink->query("SHOW /*!50000 GLOBAL */ VARIABLES")) === FALSE){
    echo "WARNING - Unable to retrieve server information.\n";
    $dblink->close();
    exit(NAGIOS_WARNING);
}

$mystat = array();
while($row = $result->fetch_row()) {
	$mystat[$row[0]] = $row[1];
}

$result->close();

if (($result = $dblink->query("SHOW /*!50000 GLOBAL */ STATUS")) === FALSE){
    echo "WARNING - Unable to retrieve server information.\n";
    $dblink->close();
    exit(NAGIOS_WARNING);
}

while($row = $result->fetch_row()) {
	$mystat[$row[0]] = $row[1];
}

$result->close();

$dblink->close();

#
# TEST VALUES
#

$exitCode=NAGIOS_UNKNOWN;
$exitCode=(int)makeTest($options["s"],$mystat);

exit($exitCode);
?>
