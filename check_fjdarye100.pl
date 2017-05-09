#!/usr/bin/perl -w 
#
# check_fjdarye100.pl is a perl function to check storage systems with FJDARY-E100.MIB support 
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

my $Version='1.0';

use strict;
use Net::SNMP;
use Getopt::Long;
use Switch;

# Nagios specific

my $TIMEOUT = 15;
my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

# SNMP Datas

my $fjdarySspMachineId		= "1.3.6.1.4.1.211.1.21.1.100.1.1.0";
my $fjdaryUnitStatus 		= "1.3.6.1.4.1.211.1.21.1.100.6.0";
my $fjdaryMgtMaintenanceMode	= "1.3.6.1.4.1.211.1.21.1.100.14.1.3.0";

# Globals

my $o_host 		= undef; 	# hostname
my $o_community 	= undef; 	# community
my $o_port 		= 161;		# port
my $o_test 		= 'OVERALL';	# test
my $o_help		= undef; 	# wan't some help ?
my $o_verb		= undef;	# verbose mode
my $o_version		= undef;	# print version
my $o_timeout		= undef;	# Timeout (Default 5)
my $o_perf		= undef;	# Output performance data
my $o_version2	= undef;	# use snmp v2c

# functions

sub fjdaryUnitStatus2Nagios{
	my $num = shift;
	switch ($num){
		case 1 { return "CRITICAL"; }
		case 2 { return "CRITICAL"; }
		case 3 { return "OK"; }
		case 4 { return "WARNING"; }
		case 5 { return "CRITICAL"; }
		else { return "CRITICAL"; }
	}
}

sub fjdaryUnitStatus2String{
	my $num = shift;
	switch ($num){
		case 1 { return "Unknown"; }
		case 2 { return "Unused"; }
		case 3 { return "Ok"; }
		case 4 { return "Warning"; }
		case 5 { return "Failed"; }
		else { return "Unknown [$num]"; }
	}
}

sub isint{
	my $val = shift;
	return ($val =~ m/^\d+$/);
}

sub p_version {
	print "check_fjdarye100.pl version : $Version\n";
}

sub print_usage {
	print "Usage: $0 [-v] -H <host> -C <snmp_community> [-2] [-p <port>] [-f] [-t <timeout>] [-V]\n";
}

sub isnnum { # Return true if arg is not a number
	my $num = shift;
	if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
	return 1;
}

sub help {
	print "\nFujitsu Fjdary-E100 MIB compatible for Nagios version ",$Version,"\n\n";
	print_usage();
   print <<EOT;
-v, --verbose
   print extra debugging information 
-h, --help
   print this help message
-H, --hostname=HOST
   name or IP address of host to check
-C, --community=COMMUNITY NAME
   community name for the host's SNMP agent (implies v1 protocol)
-T, --test=OVERALL|IDENT
   test to probe on device (OVERALL by default)
-2, --v2c
   Use snmp v2c
-P, --port=PORT
   SNMP port (Default 161)
-f, --perfparse
   Perfparse compatible output
-t, --timeout=INTEGER
   timeout for SNMP in seconds (Default: 5)
-V, --version
   prints version number
EOT
}

# For verbose output
sub verb {
	my $t=shift;
	print $t,"\n" if defined($o_verb) ;
}

sub check_options {
	Getopt::Long::Configure ("bundling");
	GetOptions(
		'v'	=> \$o_verb,		'verbose'	=> \$o_verb,
		'h'	=> \$o_help,    	'help'		=> \$o_help,
		'H:s'	=> \$o_host,		'hostname:s'	=> \$o_host,
		'p:i'	=> \$o_port,	   	'port:i'	=> \$o_port,
		'T:s'	=> \$o_test,	   	'test:s'	=> \$o_test,
		'C:s'	=> \$o_community,	'community:s'	=> \$o_community,
		't:i'	=> \$o_timeout,	'timeout:i'	=> \$o_timeout,
		'V'	=> \$o_version,	'version'	=> \$o_version,
		'2'	=> \$o_version2,	'v2c'		=> \$o_version2,
		'f'	=> \$o_perf,		'perfparse'	=> \$o_perf );

	if (defined($o_timeout) && (isnnum($o_timeout) || ($o_timeout < 2) || ($o_timeout > 60))) 
		{ print "Timeout must be >1 and <60 !\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
	if (!defined($o_timeout)) {$o_timeout=5;}
    	if (defined ($o_help)) { help(); exit $ERRORS{"UNKNOWN"}};
	if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"}};
	if (!defined($o_host)) { print_usage(); exit $ERRORS{"UNKNOWN"}}
	if (!defined($o_community)) { print "Put snmp login info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
}

########## MAIN #######

check_options();

# Check gobal timeout if snmp screws up
if (defined($TIMEOUT)) {
	verb("Alarm at $TIMEOUT + 5");
	alarm($TIMEOUT+5);
} else {
	verb("no global timeout defined : $o_timeout + 10");
	alarm ($o_timeout+10);
}

$SIG{'ALRM'} = sub {
	print "No answer from host\n";
	exit $ERRORS{"UNKNOWN"};
};

my ($session,$error);
if (defined ($o_version2)) {
	# SNMPv2
	verb("SNMP v2c login");
	($session, $error) = Net::SNMP->session(
	 -hostname  => $o_host,
	 -version   => 2,
	 -community => $o_community,
	 -port      => $o_port,
	 -timeout   => $o_timeout
	);
} else {
	# SNMPV1
	verb("SNMP v1 login");
	($session, $error) = Net::SNMP->session(
	-hostname  => $o_host,
	-community => $o_community,
	-port      => $o_port,
	-timeout   => $o_timeout
	);
}

if (!defined($session)) {
	printf("ERROR opening session: %s.\n", $error);
	exit $ERRORS{"UNKNOWN"};
}

my $exit_val=undef;

# Get load table
my @oidlist = ($fjdarySspMachineId,$fjdaryUnitStatus,$fjdaryMgtMaintenanceMode);

verb("Checking OID : @oidlist");
my $resultat = (Net::SNMP->VERSION < 4) ? $session->get_request(@oidlist) : $session->get_request(-varbindlist => \@oidlist);
if (!defined($resultat)) {
	printf("ERROR: Description table : %s.\n", $session->error);
	$session->close;
	exit $ERRORS{"UNKNOWN"};
}
$session->close;
if ((!defined($$resultat{$fjdarySspMachineId})) || (!defined($$resultat{$fjdaryUnitStatus})) || (!defined($$resultat{$fjdaryMgtMaintenanceMode}))){
	print "No SNMP information : UNKNOWN\n";
	exit $ERRORS{"UNKNOWN"};
}


my $myfjdarySspMachineId=$$resultat{$fjdarySspMachineId};
verb("OID returned $myfjdarySspMachineId");
my $myfjdaryUnitStatus=$$resultat{$fjdaryUnitStatus};
verb("OID returned $myfjdaryUnitStatus");
my $myfjdaryMgtMaintenanceMode=$$resultat{$fjdaryMgtMaintenanceMode};
verb("OID returned $myfjdaryMgtMaintenanceMode");

switch($o_test){
	case "IDENT"{
		my $myfjdarySspMachineId_model = substr($myfjdarySspMachineId,14,12);
		my $myfjdarySspMachineId_serial = substr($myfjdarySspMachineId,28,12);
		$myfjdarySspMachineId_serial=~ s/#//g;
		$myfjdarySspMachineId_model=~ s/#//g;
		printf("Series: %s, Model Name: %s, Serial No.: %s",substr($myfjdarySspMachineId,2,12),$myfjdarySspMachineId_model,$myfjdarySspMachineId_serial);
		$exit_val=0;
	}
	else{
		if ($myfjdaryMgtMaintenanceMode == 2){
			printf("Overall status: %s (Maintenance mode is On)",fjdaryUnitStatus2String($myfjdaryUnitStatus));
		}
		else{
			printf("Overall status: %s",fjdaryUnitStatus2String($myfjdaryUnitStatus));
		}
		$exit_val=$ERRORS{fjdaryUnitStatus2Nagios($myfjdaryUnitStatus)};
		if (($exit_val != 2) && ($myfjdaryMgtMaintenanceMode == 2)){
			$exit_val=1;
		}
	}
}

exit $exit_val;