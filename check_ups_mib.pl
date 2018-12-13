#!/usr/bin/perl -w
#
# check_ups_mib.pl - Check UPS based on UPS-MIB.
# Copyright (C) 2018 Ramon Roman Castro <ramonromancastro@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# @package    nagios-plugins
# @author     Ramon Roman Castro <ramonromancastro@gmail.com>
# @link       http://www.rrc2software.com
# @link       https://github.com/ramonromancastro/nagios-plugins
#
# CHANGES
#
# 0.1	First version
# 0.2	Add BYPASS test
# 0.3	Add INPUT and OUTPUT test
# 0.4	Add ALARM test
# 0.5	Add GPL license
# 0.6	Fix check_alarm problem when upsAlarmPresent = 0
# 0.7	Fix invalid .0 index
# 0.8	Fix mib_upsBatteryTemperature NOT FOUND
# 0.9	Now return OK when upsInputLineBads > 0 (this is a counter, not a flag)
# 0.10	Fix set_exit_val()
# 0.11	Change battery check states. Now, test returns WARNING when upsSecondsOnBattery > 0.

use strict;
use Net::SNMP;
use Getopt::Long;
use Switch;

# ----------------------------------
# VARIABLES
# ----------------------------------

# Plugin internal

my $VERSION="0.11";
my $SCRIPTNAME="check_ups_mib.pl";

# Nagios specific

my $NAGIOS_OK = 0;
my $NAGIOS_WARNING = 1;
my $NAGIOS_CRITICAL = 2;
my $NAGIOS_UNKNOWN = 3;
my $NAGIOS_DEPENDENT = 4;

my %ERRORS=('OK'=>$NAGIOS_OK,'WARNING'=>$NAGIOS_WARNING,'CRITICAL'=>$NAGIOS_CRITICAL,'UNKNOWN'=>$NAGIOS_UNKNOWN,'DEPENDENT'=>$NAGIOS_DEPENDENT);
my %ERRORS_TEXT=($NAGIOS_OK=>'OK',$NAGIOS_WARNING=>'WARNING',$NAGIOS_CRITICAL=>'CRITICAL',$NAGIOS_UNKNOWN=>'UNKNOWN',$NAGIOS_DEPENDENT=>'DEPENDENT');

# Arrays

my %mib_upsOutputSource_DESC=(1=>'other(1)',2=>'none(2)',3=>'normal(3)',4=>'bypass(4)',5=>'battery(5)',6=>'booster(6)',7=>'reducer(7)');
my %mib_upsOutputSource_CODE=(1=>'CRITICAL',2=>'CRITICAL',3=>'OK',4=>'CRITICAL',5=>'CRITICAL',6=>'WARNING',7=>'WARNING');
my %mib_upsBatteryStatus_DESC=(1=>'unknown(1)',2=>'batteryNormal(2)',3=>'batteryLow(3)',4=>'batteryDepleted(4)');
my %mib_upsBatteryStatus_CODE=(1=>'WARNING',2=>'OK',3=>'WARNING',4=>'CRITICAL');
my @mib_upsWellKnownAlarms_DESC=("upsAlarmBatteryBad","upsAlarmOnBattery","upsAlarmLowBattery","upsAlarmDepletedBattery","upsAlarmTempBad","upsAlarmInputBad","upsAlarmOutputBad","upsAlarmOutputOverload","upsAlarmOnBypass","upsAlarmBypassBad","upsAlarmOutputOffAsRequested","upsAlarmUpsOffAsRequested","upsAlarmChargerFailed","upsAlarmUpsOutputOff","upsAlarmUpsSystemOff","upsAlarmFanFailure","upsAlarmFuseFailure","upsAlarmGeneralFault","upsAlarmDiagnosticTestFailed","upsAlarmCommunicationsLost","upsAlarmAwaitingPower","upsAlarmShutdownPending","upsAlarmShutdownImminent","upsAlarmTestInProgress");
my @mib_upsWellKnownAlarms_OID=("1.3.6.1.2.1.33.1.6.3.1","1.3.6.1.2.1.33.1.6.3.2","1.3.6.1.2.1.33.1.6.3.3","1.3.6.1.2.1.33.1.6.3.4","1.3.6.1.2.1.33.1.6.3.5","1.3.6.1.2.1.33.1.6.3.6","1.3.6.1.2.1.33.1.6.3.7","1.3.6.1.2.1.33.1.6.3.8","1.3.6.1.2.1.33.1.6.3.9","1.3.6.1.2.1.33.1.6.3.10","1.3.6.1.2.1.33.1.6.3.11","1.3.6.1.2.1.33.1.6.3.12","1.3.6.1.2.1.33.1.6.3.13","1.3.6.1.2.1.33.1.6.3.14","1.3.6.1.2.1.33.1.6.3.15","1.3.6.1.2.1.33.1.6.3.16","1.3.6.1.2.1.33.1.6.3.17","1.3.6.1.2.1.33.1.6.3.18","1.3.6.1.2.1.33.1.6.3.19","1.3.6.1.2.1.33.1.6.3.20","1.3.6.1.2.1.33.1.6.3.21","1.3.6.1.2.1.33.1.6.3.22","1.3.6.1.2.1.33.1.6.3.23","1.3.6.1.2.1.33.1.6.3.24","1.3.6.1.2.1.33.1.6.3.1","1.3.6.1.2.1.33.1.6.3.2","1.3.6.1.2.1.33.1.6.3.3","1.3.6.1.2.1.33.1.6.3.4","1.3.6.1.2.1.33.1.6.3.5","1.3.6.1.2.1.33.1.6.3.6","1.3.6.1.2.1.33.1.6.3.7","1.3.6.1.2.1.33.1.6.3.8","1.3.6.1.2.1.33.1.6.3.9","1.3.6.1.2.1.33.1.6.3.10","1.3.6.1.2.1.33.1.6.3.11","1.3.6.1.2.1.33.1.6.3.12","1.3.6.1.2.1.33.1.6.3.13","1.3.6.1.2.1.33.1.6.3.14","1.3.6.1.2.1.33.1.6.3.15","1.3.6.1.2.1.33.1.6.3.16","1.3.6.1.2.1.33.1.6.3.17","1.3.6.1.2.1.33.1.6.3.18","1.3.6.1.2.1.33.1.6.3.19","1.3.6.1.2.1.33.1.6.3.20","1.3.6.1.2.1.33.1.6.3.21","1.3.6.1.2.1.33.1.6.3.22","1.3.6.1.2.1.33.1.6.3.23","1.3.6.1.2.1.33.1.6.3.24");
my @mib_upsWellKnownAlarms_CODE=("CRITICAL","WARNING","WARNING","CRITICAL","CRITICAL","CRITICAL","CRITICAL","CRITICAL","CRITICAL","CRITICAL","OK","OK","CRITICAL","CRITICAL","CRITICAL","CRITICAL","CRITICAL","CRITICAL","WARNING","WARNING","WARNING","WARNING","CRITICAL","OK");


# SNMP Datas

my $mib_upsBattery                   = "1.3.6.1.2.1.33.1.2";
my $mib_upsBatteryStatus             = $mib_upsBattery.".1.0";
my $mib_upsSecondsOnBattery          = $mib_upsBattery.".2.0";
my $mib_upsEstimatedMinutesRemaining = $mib_upsBattery.".3.0";
my $mib_upsEstimatedChargeRemaining  = $mib_upsBattery.".4.0";
my $mib_upsBatteryVoltage            = $mib_upsBattery.".5.0";
my $mib_upsBatteryCurrent            = $mib_upsBattery.".6.0";
my $mib_upsBatteryTemperature        = $mib_upsBattery.".7.0";

my $mib_upsOutput            = "1.3.6.1.2.1.33.1.4";
my $mib_upsOutputSource      = $mib_upsOutput.".1.0";
my $mib_upsOutputFrequency   = $mib_upsOutput.".2.0";
my $mib_upsOutputNumLines    = $mib_upsOutput.".3.0";
my $mib_upsOutputTable 	     = $mib_upsOutput.".4";
my $mib_upsOutputEntry       = $mib_upsOutputTable.".1";
my $mib_upsOutputLineIndex   = $mib_upsOutputEntry.".1";
my $mib_upsOutputVoltage     = $mib_upsOutputEntry.".2";
my $mib_upsOutputCurrent     = $mib_upsOutputEntry.".3";
my $mib_upsOutputPower       = $mib_upsOutputEntry.".4";
my $mib_upsOutputPercentLoad = $mib_upsOutputEntry.".5";

my $mib_upsInput          = "1.3.6.1.2.1.33.1.3";
my $mib_upsInputLineBads  = $mib_upsInput.".1.0";
my $mib_upsInputNumLines  = $mib_upsInput.".2.0";
my $mib_upsInputTable     = $mib_upsInput.".3";
my $mib_upsInputEntry     = $mib_upsInputTable.".1";
my $mib_upsInputLineIndex = $mib_upsInputEntry.".1";
my $mib_upsInputFrequency = $mib_upsInputEntry.".2";
my $mib_upsInputVoltage   = $mib_upsInputEntry.".3";
my $mib_upsInputCurrent   = $mib_upsInputEntry.".4";
my $mib_upsInputTruePower = $mib_upsInputEntry.".5";

my $mib_upsBypass          = "1.3.6.1.2.1.33.1.5";
my $mib_upsBypassFrequency = $mib_upsBypass.".1.0";
my $mib_upsBypassNumLines  = $mib_upsBypass.".2.0";
my $mib_upsBypassTable     = $mib_upsBypass.".3";
my $mib_upsBypassEntry     = $mib_upsBypassTable.".1";
my $mib_upsBypassLineIndex = $mib_upsBypassEntry.".1";
my $mib_upsBypassVoltage   = $mib_upsBypassEntry.".2";
my $mib_upsBypassCurrent   = $mib_upsBypassEntry.".3";
my $mib_upsBypassPower     = $mib_upsBypassEntry.".4";

my $mib_upsAlarm         = "1.3.6.1.2.1.33.1.6";
my $mib_upsAlarmsPresent = $mib_upsAlarm.".1.0";
my $mib_upsAlarmTable    = $mib_upsAlarm.".2";
my $mib_upsAlarmEntry    = $mib_upsAlarmTable.".1";
my $mib_upsAlarmId       = $mib_upsAlarmEntry.".1";
my $mib_upsAlarmDescr    = $mib_upsAlarmEntry.".2";
my $mib_upsAlarmTime     = $mib_upsAlarmEntry.".3";

# Globals

my $TIMEOUT = 10;
my $o_host = undef;
my $o_community = undef;
my $o_port = 161;
my $o_test = 'IDENT';
my $o_help = undef;
my $o_verb = undef;
my $o_version = undef;
my $o_timeout = undef;
my $o_perf = undef;
my $o_version2 = undef;

my $messages = "";
my $perfomance = "";

my $exit_val=undef;

# functions

sub set_exit_val{
	my ($value) = @_;
	
	switch($value){
		case "OK"{
			if (($exit_val ne 'CRITICAL') && ($exit_val ne 'WARNING')) { $exit_val = $ERRORS{$value}; }
		}
		case "WARNING"{
			if ($exit_val ne 'CRITICAL') { $exit_val = $ERRORS{$value}; }
		}
		case "CRITICAL"{
			$exit_val = $ERRORS{$value};
		}
		case "UNKNOWN"{
			if (($exit_val ne 'CRITICAL') && ($exit_val ne 'WARNING')) { $exit_val = $ERRORS{$value}; }
		}
		case "DEPENDENT"{
			if (($exit_val ne 'CRITICAL') && ($exit_val ne 'WARNING')) { $exit_val = $ERRORS{$value}; }
		}
	}
}

sub array_search{
	my ($element, @array) = @_;
	foreach (0..$#array){
		if ($array[$_] eq $element){
			return $_;
		}
	}
	return -1;
}

sub trim{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub isint{
	my $val = shift;
	return ($val =~ m/^\d+$/);
}

sub p_version {
	print "$SCRIPTNAME - version $VERSION\n";
}

sub print_usage {
	print "Usage: $0 -H <hostname> -C <community> [-2] [-p <port>] -T <test> [-f] [-t <timeout>] [-V] [-v] [-h]\n";
}

sub isnnum { # Return true if arg is not a number
	my $num = shift;
	if ( $num =~ /^(\d+\.?\d*)|(^\.\d+)$/ ) { return 0 ;}
	return 1;
}

sub help {
	print "Check UPS based on UPS-MIB\n\n";
	print "This plugin is not developped by the Nagios Plugin group.\n";
	print "Please do not e-mail them for support on this plugin.\n\n";
	print "For contact info, please read the plugin script file.\n\n";
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
-T, --test=(ALARM|BATTERY|BYPASS|INPUT|OUTPUT)
   test to probe on device
-2, --v2c
   Use snmp v2c
-p, --port=PORT
   SNMP port (Default 161)
-f, --perfparse
   Perfparse compatible output
-t, --timeout=INTEGER
   timeout for SNMP in seconds (Default: $TIMEOUT)
-V, --version
   prints version number
EOT
}

# For verbose output
sub verbose {
	my $t=shift;
	print $t,"\n" if defined($o_verb) ;
}

sub check_options {
	Getopt::Long::Configure ("bundling");
	GetOptions(
		'v'   => \$o_verb,		'verbose'     => \$o_verb,
		'h'   => \$o_help,    	'help'        => \$o_help,
		'H:s' => \$o_host,		'hostname:s'  => \$o_host,
		'p:i' => \$o_port,	   	'port:i'      => \$o_port,
		'T:s' => \$o_test,	   	'test:s'      => \$o_test,
		'C:s' => \$o_community,	'community:s' => \$o_community,
		't:i' => \$o_timeout,	'timeout:i'   => \$o_timeout,
		'V'   => \$o_version,	'version'     => \$o_version,
		'2'   => \$o_version2,	'v2c'         => \$o_version2,
		'f'   => \$o_perf,		'perfparse'   => \$o_perf );

	if (defined($o_timeout) && (isnnum($o_timeout) || ($o_timeout < 2) || ($o_timeout > 60))) 
		{ print "Timeout must be >1 and <60 !\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
	if (!defined($o_timeout)) {$o_timeout=5;}
    	if (defined ($o_help)) { help(); exit $ERRORS{"UNKNOWN"}};
	if (defined($o_version)) { p_version(); exit $ERRORS{"UNKNOWN"}};
	if (!defined($o_host)) { print_usage(); exit $ERRORS{"UNKNOWN"}};
	if (!defined($o_test)) { print "Put test info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
	if (!defined($o_community)) { print "Put snmp login info!\n"; print_usage(); exit $ERRORS{"UNKNOWN"}}
}

# ----------------------------------
# MAIN CODE
# ----------------------------------

check_options();

if (defined($TIMEOUT)) {
	verbose("Alarm at $TIMEOUT + 5");
	alarm($TIMEOUT+5);
}
else {
	verbose("no global timeout defined : $o_timeout + 10");
	alarm ($o_timeout+10);
}

$SIG{'ALRM'} = sub { print "No answer from host\n"; exit $ERRORS{"UNKNOWN"}; };

my ($session,$error);
if (defined ($o_version2)) {
	verbose("SNMP v2c login");
	($session, $error) = Net::SNMP->session(-hostname => $o_host, -version => 2, -community => $o_community, -port => $o_port, -timeout => $o_timeout);
} else {
	verbose("SNMP v1 login");
	($session, $error) = Net::SNMP->session(-hostname => $o_host, -community => $o_community, -port => $o_port, -timeout => $o_timeout );
}

if (!defined($session)) {
	printf("ERROR opening session: %s.\n", $error);
	exit $ERRORS{"UNKNOWN"};
}

sub check_battery(){
	##my @oidlist = ($mib_upsBatteryStatus,$mib_upsSecondsOnBattery,$mib_upsEstimatedMinutesRemaining,$mib_upsEstimatedChargeRemaining,$mib_upsBatteryVoltage,$mib_upsBatteryCurrent,$mib_upsBatteryTemperature);
	#my @oidlist = ($mib_upsBatteryStatus,$mib_upsSecondsOnBattery,$mib_upsEstimatedMinutesRemaining,$mib_upsEstimatedChargeRemaining,$mib_upsBatteryVoltage,$mib_upsBatteryTemperature);	
	my @oidlist = ($mib_upsBatteryStatus,$mib_upsSecondsOnBattery,$mib_upsEstimatedMinutesRemaining,$mib_upsEstimatedChargeRemaining,$mib_upsBatteryVoltage);	
	verbose("Checking OID : @oidlist");
	my $resultat = (version->parse(Net::SNMP->VERSION) < 4) ? $session->get_request(@oidlist) : $session->get_request(-varbindlist => \@oidlist);
	if (!defined($resultat)) {
		printf("ERROR: Description table : %s.\n", $session->error);
		$session->close;
		exit $ERRORS{"UNKNOWN"};
	}
	foreach (keys(%{$resultat})) { verbose("$_ => $resultat->{$_}"); }
	
	@oidlist = ($mib_upsBatteryTemperature);	
	my $upsBatteryTemperature = 0;
	verbose("Checking OID : @oidlist");
	my $resultatTemp = (version->parse(Net::SNMP->VERSION) < 4) ? $session->get_request(@oidlist) : $session->get_request(-varbindlist => \@oidlist);
	if (defined($resultatTemp)) {
		$upsBatteryTemperature = $$resultat{$mib_upsBatteryTemperature};
	}
	foreach (keys(%{$resultatTemp})) { verbose("$_ => $resultatTemp->{$_}"); }

	$exit_val=$ERRORS{$mib_upsBatteryStatus_CODE{$$resultat{$mib_upsBatteryStatus}}};
	if ($$resultat{$mib_upsSecondsOnBattery} > 0) { set_exit_val("WARNING"); }

	$messages.=sprintf("BATTERY STATUS: %s\n", $mib_upsBatteryStatus_CODE{$$resultat{$mib_upsBatteryStatus}});
	$messages.=sprintf("upsBatteryStatus: %s\n", $mib_upsBatteryStatus_DESC{$$resultat{$mib_upsBatteryStatus}});
	$messages.=sprintf("upsSecondsOnBattery: %d seconds\n",$$resultat{$mib_upsSecondsOnBattery});
	$messages.=sprintf("upsEstimatedMinutesRemaining: %d minutes\n", $$resultat{$mib_upsEstimatedMinutesRemaining});
	$messages.=sprintf("upsEstimatedChargeRemaining: %s%%\n", $$resultat{$mib_upsEstimatedChargeRemaining});
	$messages.=sprintf("upsBatteryVoltage: %.1fV\n", $$resultat{$mib_upsBatteryVoltage}*0.1);
	#$messages.=sprintf("upsBatteryCurrent: %.1fA\n", $$resultat{$mib_upsBatteryCurrent}*0.1);
	$messages.=sprintf("upsBatteryTemperature: %dC\n", $upsBatteryTemperature);

	if (defined($o_perf)){
		$perfomance.=sprintf("'upsBatteryStatus'=%d;;;; ", $$resultat{$mib_upsBatteryStatus});
		$perfomance.=sprintf("'upsSecondsOnBattery'=%ds;;;; ",$$resultat{$mib_upsSecondsOnBattery});
		$perfomance.=sprintf("'upsEstimatedMinutesRemaining'=%d;;;; ", $$resultat{$mib_upsEstimatedMinutesRemaining});
		$perfomance.=sprintf("'upsEstimatedChargeRemaining'=%d%%;;;; ", $$resultat{$mib_upsEstimatedChargeRemaining});
		$perfomance.=sprintf("'upsBatteryVoltage'=%.1f;;;; ", $$resultat{$mib_upsBatteryVoltage}*0.1);
		#$perfomance.=sprintf("'upsBatteryCurrent'=%.1f;;;; ", $$resultat{$mib_upsBatteryCurrent}*0.1);
		$perfomance.=sprintf("'upsBatteryTemperature'=%d;;;; ", $upsBatteryTemperature);
	}
}

sub check_alarm(){
	my @oidlist = ();
	my $oidtable = undef;
	my $i = undef;
	my $snmpkey = undef;
	my $alarmIdx = undef;
	my $alarmCode = undef;
	
	@oidlist = ($mib_upsAlarmsPresent);
	verbose("Checking OID : @oidlist");
	my $resultatAlarm = (version->parse(Net::SNMP->VERSION) < 4) ? $session->get_request(@oidlist) : $session->get_request(-varbindlist => \@oidlist);
	if (!defined($resultatAlarm)) {
		printf("ERROR: Description table : %s.\n", $session->error);
		$session->close;
		exit $ERRORS{"UNKNOWN"};
	}
	foreach $snmpkey ( keys %{$resultatAlarm} ) { verbose("$snmpkey => $$resultatAlarm{$snmpkey}"); }

	if (defined($o_perf)){
		$perfomance.=sprintf("'upsAlarmsPresent'=%d;;;; ", $$resultatAlarm{$mib_upsAlarmsPresent});
	}

	if ($$resultatAlarm{$mib_upsAlarmsPresent} == 0){ $exit_val = $NAGIOS_OK }
	else { 
		$exit_val = $NAGIOS_WARNING;
	

		$oidtable = $mib_upsAlarmTable;
		verbose("Checking OID : $oidtable");
		my $resultat = (version->parse(Net::SNMP->VERSION) < 4) ? $session->get_table($oidtable) : $session->get_table(-baseoid => $oidtable);
		if (!defined($resultat)) {
			printf("ERROR: Description table : %s.\n", $session->error);
			$session->close;
			exit $ERRORS{"UNKNOWN"};
		}
	
		foreach $snmpkey ( keys %{$resultat} ) { verbose("$snmpkey => $$resultat{$snmpkey}"); }
	
		for ($i = 1; $i <= $$resultatAlarm{$mib_upsAlarmsPresent}; $i++) {
			$alarmIdx = array_search($$resultat{$mib_upsAlarmDescr.".".$i}, @mib_upsWellKnownAlarms_OID);
			if ($alarmIdx != -1){ $alarmCode = $mib_upsWellKnownAlarms_CODE[$alarmIdx]; $alarmIdx = $mib_upsWellKnownAlarms_DESC[$alarmIdx]; }
			else { $alarmIdx = $$resultat{$mib_upsAlarmDescr.".".$i}; $alarmCode = "WARNING"; }
			set_exit_val($alarmCode);
			$messages.=sprintf(
						"upsAlarmId(%d): %s (%s)\n",
						$$resultat{$mib_upsAlarmId.".".$i},
						$alarmIdx,
						$alarmCode);
		}
	}
	$messages = sprintf("ALARM STATUS: %s\nupsAlarmsPresent: %d\n", $ERRORS_TEXT{$exit_val}, $$resultatAlarm{$mib_upsAlarmsPresent}) . $messages;
}

sub check_bypass(){
	my @oidlist = ();
	my $oidtable = undef;
	my $i = undef;
	my $snmpkey = undef;
	
	#@oidlist = ($mib_upsBypassFrequency,$mib_upsBypassNumLines);
	@oidlist = ($mib_upsBypassNumLines);
	verbose("Checking OID : @oidlist");
	my $resultatBypass = (version->parse(Net::SNMP->VERSION) < 4) ? $session->get_request(@oidlist) : $session->get_request(-varbindlist => \@oidlist);
	if (!defined($resultatBypass)) {
		printf("ERROR: Description table : %s.\n", $session->error);
		$session->close;
		exit $ERRORS{"UNKNOWN"};
	}
	foreach $snmpkey ( keys %{$resultatBypass} ) { verbose("$snmpkey => $$resultatBypass{$snmpkey}"); }
	
	$exit_val = $NAGIOS_OK;
	
	$messages.=sprintf("BYPASS STATUS: %s\n", $ERRORS_TEXT{$exit_val});
	#$messages.=sprintf("upsBypassFrequency: %.1fHz\n", $$resultatBypass{$mib_upsBypassFrequency}*0.1);
	$messages.=sprintf("upsBypassNumLines: %d\n", $$resultatBypass{$mib_upsBypassNumLines});
	if (defined($o_perf)){
		#$perfomance.=sprintf("'upsBypassFrequency'=%.1f;;;; ", $$resultatBypass{$mib_upsBypassFrequency}*0.1);
		$perfomance.=sprintf("'upsBypassNumLines'=%d;;;; ", $$resultatBypass{$mib_upsBypassNumLines});
	}

	$oidtable = $mib_upsBypassTable;
	verbose("Checking OID : $oidtable");
	my $resultat = (version->parse(Net::SNMP->VERSION) < 4) ? $session->get_table($oidtable) : $session->get_table(-baseoid => $oidtable);
	if (defined($resultat)) {
		foreach $snmpkey ( keys %{$resultat} ) { verbose("$snmpkey => $$resultat{$snmpkey}"); }
	
		for ($i = 1; $i <= $$resultatBypass{$mib_upsBypassNumLines}; $i++) {
			$messages.=sprintf(
								"BypassLine(%d): Voltage (%dV) Current (%.1fA) Power (%dW)\n",
								$i,
								$$resultat{$mib_upsBypassVoltage.".".$i},
								$$resultat{$mib_upsBypassCurrent.".".$i}*0.1,
								$$resultat{$mib_upsBypassPower.".".$i});
			if (defined($o_perf)){
				$perfomance.=sprintf("'upsBypassLineIndex%d_Voltage'=%d;;;; ",$i,$$resultat{$mib_upsBypassVoltage.".".$i});
				$perfomance.=sprintf("'upsBypassLineIndex%d_Current'=%.1f;;;; ", $i,$$resultat{$mib_upsBypassCurrent.".".$i}*0.1);
				$perfomance.=sprintf("'upsBypassLineIndex%d_Power'=%d;;;; ", $i,$$resultat{$mib_upsBypassPower.".".$i});
			}
		}
	}
}

sub check_output(){
	my @oidlist = ();
	my $oidtable = undef;
	my $i = undef;
	my $snmpkey = undef;
	my $upsOutputVoltage = 0;
	my $upsOutputCurrent = 0;
	my $upsOutputPower = 0;
	my $upsOutputPercentLoad = 0;
	
	#@oidlist = ($mib_upsOutputSource,$mib_upsOutputFrequency,$mib_upsOutputNumLines);
	@oidlist = ($mib_upsOutputSource,$mib_upsOutputNumLines);
	verbose("Checking OID : @oidlist");
	my $resultatOutput = (version->parse(Net::SNMP->VERSION) < 4) ? $session->get_request(@oidlist) : $session->get_request(-varbindlist => \@oidlist);
	if (!defined($resultatOutput)) {
		printf("ERROR: Description table : %s.\n", $session->error);
		$session->close;
		exit $ERRORS{"UNKNOWN"};
	}
	foreach $snmpkey ( keys %{$resultatOutput} ) { verbose("$snmpkey => $$resultatOutput{$snmpkey}"); }
	
	$exit_val=$ERRORS{$mib_upsOutputSource_CODE{$$resultatOutput{$mib_upsOutputSource}}};
	$messages.=sprintf("OUTPUT STATUS: %s\n", $mib_upsOutputSource_CODE{$$resultatOutput{$mib_upsOutputSource}});
	$messages.=sprintf("upsOutputSource: %s\n", $mib_upsOutputSource_DESC{$$resultatOutput{$mib_upsOutputSource}});
	#$messages.=sprintf("upsOutputFrequency: %.1fHz\n", $$resultatOutput{$mib_upsOutputFrequency}*0.1);
	$messages.=sprintf("upsOutputNumLines: %d\n", $$resultatOutput{$mib_upsOutputNumLines});
	if (defined($o_perf)){
		$perfomance.=sprintf("'upsOutputSource'=%d;;;; ", $$resultatOutput{$mib_upsOutputSource});
		#$perfomance.=sprintf("'upsOutputFrequency'=%.1f;;;; ", $$resultatOutput{$mib_upsOutputFrequency}*0.1);
		$perfomance.=sprintf("'upsOutputNumLines'=%d;;;; ", $$resultatOutput{$mib_upsOutputNumLines});
	}

	$oidtable = $mib_upsOutputTable;
	verbose("Checking OID : $oidtable");
	my $resultat = (version->parse(Net::SNMP->VERSION) < 4) ? $session->get_table($oidtable) : $session->get_table(-baseoid => $oidtable);
	if (!defined($resultat)) {
		printf("ERROR: Description table : %s.\n", $session->error);
		$session->close;
		exit $ERRORS{"UNKNOWN"};
	}
	foreach $snmpkey ( keys %{$resultat} ) { verbose("$snmpkey => $$resultat{$snmpkey}"); }
	
	for ($i = 1; $i <= $$resultatOutput{$mib_upsOutputNumLines}; $i++) {
		$upsOutputVoltage = $upsOutputCurrent = $upsOutputPower = $upsOutputPercentLoad = 0;
		if (not defined $$resultat{$mib_upsOutputVoltage.".".$i}){
			$upsOutputVoltage = (defined $$resultat{$mib_upsOutputVoltage.".".$i.".0"})?$$resultat{$mib_upsOutputVoltage.".".$i.".0"}:0;
			$upsOutputCurrent = (defined $$resultat{$mib_upsOutputCurrent.".".$i.".0"})?$$resultat{$mib_upsOutputCurrent.".".$i.".0"}*0.1:0;
			$upsOutputPower = (defined $$resultat{$mib_upsOutputPower.".".$i.".0"})?$$resultat{$mib_upsOutputPower.".".$i.".0"}:0;
			$upsOutputPercentLoad = (defined $$resultat{$mib_upsOutputPercentLoad.".".$i.".0"})?$$resultat{$mib_upsOutputPercentLoad.".".$i.".0"}:0;
		}
		else{
			$upsOutputVoltage = (defined $$resultat{$mib_upsOutputVoltage.".".$i})?$$resultat{$mib_upsOutputVoltage.".".$i}:0;
			$upsOutputCurrent = (defined $$resultat{$mib_upsOutputCurrent.".".$i})?$$resultat{$mib_upsOutputCurrent.".".$i}*0.1:0;
			$upsOutputPower = (defined $$resultat{$mib_upsOutputPower.".".$i})?$$resultat{$mib_upsOutputPower.".".$i}:0;
			$upsOutputPercentLoad = (defined $$resultat{$mib_upsOutputPercentLoad.".".$i})?$$resultat{$mib_upsOutputPercentLoad.".".$i}:0;
		}
		
		$messages.=sprintf(
							"OutputLine(%d): Voltage (%dV) Current (%.1fA) Power (%dW) Load (%d%%)\n",
							$i,
							$upsOutputVoltage,
							$upsOutputCurrent,
							$upsOutputPower,
							$upsOutputPercentLoad);
		if (defined($o_perf)){
			$perfomance.=sprintf("'upsOutputLineIndex%d_Voltage'=%d;;;; ",$i,$upsOutputVoltage);
			$perfomance.=sprintf("'upsOutputLineIndex%d_Current'=%.1f;;;; ", $i,$upsOutputCurrent);
			$perfomance.=sprintf("'upsOutputLineIndex%d_Power'=%d;;;; ", $i,$upsOutputPower);
			$perfomance.=sprintf("'upsOutputLineIndex%d_PercentLoad'=%d%%;;;; ", $i,$upsOutputPercentLoad);
		}
	}
}

sub check_input(){
	my @oidlist = ();
	my $oidtable = undef;
	my $i = undef;
	my $snmpkey = undef;
	my $upsInputFrequency = 0;
	my $upsInputVoltage = 0;
	my $upsInputCurrent = 0;
	my $upsInputTruePower = 0;
	
	@oidlist = ($mib_upsInputLineBads,$mib_upsInputNumLines);
	verbose("Checking OID : @oidlist");
	my $resultatInput = (version->parse(Net::SNMP->VERSION) < 4) ? $session->get_request(@oidlist) : $session->get_request(-varbindlist => \@oidlist);
	if (!defined($resultatInput)) {
		printf("ERROR: Description table : %s.\n", $session->error);
		$session->close;
		exit $ERRORS{"UNKNOWN"};
	}
	foreach $snmpkey ( keys %{$resultatInput} ) { verbose("$snmpkey => $$resultatInput{$snmpkey}"); }
	
	# 0.9
	# if ($$resultatInput{$mib_upsInputLineBads} >= $$resultatInput{$mib_upsInputNumLines}){ $exit_val = $NAGIOS_CRITICAL }
	# elsif ($$resultatInput{$mib_upsInputLineBads} > 0){ $exit_val = $NAGIOS_WARNING; }
	# else { $exit_val = $NAGIOS_OK; }
	#
	$exit_val = $NAGIOS_OK;
	#
	
	$messages.=sprintf("INPUT STATUS: %s\n", $ERRORS_TEXT{$exit_val});
	$messages.=sprintf("upsInputLineBads: %d\n", $$resultatInput{$mib_upsInputLineBads});
	$messages.=sprintf("upsInputNumLines: %d\n", $$resultatInput{$mib_upsInputNumLines});

	$oidtable = $mib_upsInputTable;
	verbose("Checking OID : $oidtable");
	my $resultat = (version->parse(Net::SNMP->VERSION) < 4) ? $session->get_table($oidtable) : $session->get_table(-baseoid => $oidtable);
	if (!defined($resultat)) {
		printf("ERROR: Description table : %s.\n", $session->error);
		$session->close;
		exit $ERRORS{"UNKNOWN"};
	}
	
	foreach $snmpkey ( keys %{$resultat} ) { verbose("$snmpkey => $$resultat{$snmpkey}"); }
	
	for ($i = 1; $i <= $$resultatInput{$mib_upsInputNumLines}; $i++) {
		$upsInputFrequency = $upsInputVoltage = $upsInputCurrent = $upsInputTruePower = 0;
		if (not defined $$resultat{$mib_upsInputFrequency.".".$i}){
			$upsInputFrequency = (defined $$resultat{$mib_upsInputFrequency.".".$i.".0"})?$$resultat{$mib_upsInputFrequency.".".$i.".0"}*0.1:0;
			$upsInputVoltage = (defined $$resultat{$mib_upsInputVoltage.".".$i.".0"})?$$resultat{$mib_upsInputVoltage.".".$i.".0"}:0;
			$upsInputCurrent = (defined $$resultat{$mib_upsInputCurrent.".".$i.".0"})?$$resultat{$mib_upsInputCurrent.".".$i.".0"}*0.1:0;
			$upsInputTruePower = (defined $$resultat{$mib_upsInputTruePower.".".$i.".0"})?$$resultat{$mib_upsInputTruePower.".".$i.".0"}:0;
		}
		else{
			$upsInputFrequency = (defined $$resultat{$mib_upsInputFrequency.".".$i})?$$resultat{$mib_upsInputFrequency.".".$i}*0.1:0;
			$upsInputVoltage = (defined $$resultat{$mib_upsInputVoltage.".".$i})?$$resultat{$mib_upsInputVoltage.".".$i}:0;
			$upsInputCurrent = (defined $$resultat{$mib_upsInputCurrent.".".$i})?$$resultat{$mib_upsInputCurrent.".".$i}*0.1:0;
			$upsInputTruePower = (defined $$resultat{$mib_upsInputTruePower.".".$i})?$$resultat{$mib_upsInputTruePower.".".$i}:0;
		}
		$messages.=sprintf(
							"InputLine(%d): Frequency (%.1fHz) Voltage (%dV) Current (%.1fA) TruePower (%dW)\n",
							$i,
							$upsInputFrequency,
							$upsInputVoltage,
							$upsInputCurrent,
							$upsInputTruePower);
		if (defined($o_perf)){
			$perfomance.=sprintf("'upsInputLineIndex%d_Frequency'=%.1f;;;; ",$i,$upsInputFrequency);
			$perfomance.=sprintf("'upsInputLineIndex%d_Voltage'=%d;;;; ", $i,$upsInputVoltage);
			$perfomance.=sprintf("'upsInputLineIndex%d_Current'=%.1f;;;; ", $i,$upsInputCurrent);
			$perfomance.=sprintf("'upsInputLineIndex%d_TruePower'=%d;;;; ", $i,$upsInputTruePower);
		}
	}
	

}

switch($o_test){
	case "ALARM"{
		check_alarm();
	}
	case "BATTERY"{
		check_battery();
	}
	case "BYPASS"{
		check_bypass();
	}
	case "INPUT"{
		check_input();
	}
	case "OUTPUT"{
		check_output();
	}
	else{
		help();
		exit $ERRORS{"UNKNOWN"}
	}
}

print $messages;
if (defined($o_perf)){ print "|".$perfomance };
exit $exit_val;