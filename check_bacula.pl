#!/usr/bin/perl -w
#
# check_bacula.pl is a perl function to Bacula jobs ad media 
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
# 0.10	First release

# Probes:
## MEDIA_USE
# * Ok      : All Media are in use
# * Warning : One or more Media are not used by any job
# * Critical: N/A
## MEDIA_STATUS
# * Ok      : All Media are Ok
# * Warning : One or more Media have 'Error' status;
# * Critical: N/A
## JOB_STATUS
# * Ok      : All Job are Ok
# * Warning : One or more Differential/Incremental Jobs have finished with errors in last xx hours, but one Full Job Ok exists in.
# * Critical: One or more of the latest Full Jobs have finished with errors.
## JOB_RUNNING
# * Ok      : All Job are Ok
# * Warning : One or more Jobs are running more than xx days.
# * Critical: N/A

use strict;
use POSIX;
use File::Basename;
use Switch;
use DBI;
use Getopt::Long;
          
sub print_help();
sub date_now();
sub date_calc();

my $scriptname    = basename($0);
my $version     = "0.10";
my $dbconn      = "";
my $details     = "";
my $perfomance  = "";
my $exitmsg     = "UNKNOWN";
my $opt_host    = "localhost";
my $opt_db      = "bacula";
my $opt_user    = "bacula";
my $opt_pass    = "clave_bacula";
my $opt_help    = "";
my $opt_extra   = "";
my $opt_status  = "";
my $opt_version = "";

my @test_types = ('MEDIA_USE', 'MEDIA_STATUS', 'JOB_STATUS', 'JOB_RUNNING');

my %ERRORS = ('OK'=>'0','WARNING'=>'1','CRITICAL'=>'2','UNKNOWN'=>'3');

Getopt::Long::Configure('bundling');
GetOptions(
	"H=s"        => \$opt_host,
	"host=s"     => \$opt_host,
	
	"d=s"        => \$opt_db,
	"db=s"       => \$opt_db,

	"u=s"        => \$opt_user,
	"username=s" => \$opt_user,
	
	"p=s"        => \$opt_pass,
	"password=s" => \$opt_pass,
	
	"e=s"        => \$opt_extra,
	"extra=s"    => \$opt_extra,
	
	"s=s"        => \$opt_status,
	"status=s"   => \$opt_status,
	
	"h"          => \$opt_help,
	"help"       => \$opt_help,
	
	"V"          => \$opt_version,
	"version"    => \$opt_version
) || die "Try '$scriptname --help' for more information.\n";

#
# FUNCTIONS
#

sub check_version() {
 print "\nCheck bacula status\n";
 print "Version: $version\n\n";
}

sub print_help() {
 check_version();
 print "Usage:\n";
 print "\t$scriptname\n";
 print "\t\t-H <host> -d <database> -u <database user> -p <database password>\n";
 print "\t\t-s <status> [ -e <extra> ]\n";
 print "\t\t[ -h ] [ -V ]\n";
 print "\nOptions:\n";
 print "\t-H | --host\n\t\tBacula SD Host\n";
 print "\t-s | --status\n\t\tBacula status type to check\n";
 print "\t\t* MEDIA_USE    = Check if exists no media used\n";
 print "\t\t* MEDIA_STATUS = Check if exists error media\n";
 print "\t\t* JOB_STATUS   = Check if exists jobs failed in last <extra> days\n";
 print "\t\t* JOB_RUNNING  = Check if exists any jobs running more than <extra> days\n";
 print "\t-e | --extra\n\t\tExtra parameters for status type\n";
 print "\t\t* JOB_STATUS: Last days\n";
 print "\t\t* JOB_RUNNING: Number of days\n";
 print "\t-h | --help\n\t\tPrint this help\n";
 print "\t-V | --version\n\t\tPrint version\n\n";
}

sub date_now() {
 my $ahora = defined $_[0] ? $_[0] : time;
 my $return = strftime("%Y-%m-%d %X", localtime($ahora));
 return($return);
}

sub date_calc() {
 my $day = shift;
 my $ahora = defined $_[0] ? $_[0] : time;
 my $calculado = $ahora - ((24*60*60*1) * $day);
 my $return = strftime("%Y-%m-%d %X", localtime($calculado));
 return ($return);
}

sub check_media_use {
 my $MediaId = "";
 my $VolumeName = "";
 my $VolStatus = "";
 my $dbsql = "SELECT MediaId, VolumeName, VolStatus FROM Media WHERE MediaID NOT IN (SELECT MediaId FROM JobMedia) AND VolStatus NOT IN ('Recycle') AND DATE_ADD(LastWritten, INTERVAL VolRetention SECOND) > CURDATE();";
 my $dbsth = $dbconn->prepare($dbsql) or die "Error preparing statement",$dbconn->errstr;
 $dbsth->execute;
 while (my @row = $dbsth->fetchrow_array()) {
	($MediaId, $VolumeName, $VolStatus) = @row;
	$exitmsg='WARNING';
	$details = "$details\nMediaId ($MediaId) VolumeName ($VolumeName) VolStatus($VolStatus)";
 }
 $perfomance="MediaUnused=".$dbsth->rows().";;;;";
 $dbsth->finish();
 if ($exitmsg eq "UNKNOWN") { $exitmsg = "OK"; };
}

sub check_media_status {
 my $MediaId = "";
 my $VolumeName = "";
 my $VolStatus = "";
 my $dbsql = "SELECT MediaId, VolumeName, VolStatus FROM Media WHERE VolStatus = 'Error';";
 my $dbsth = $dbconn->prepare($dbsql) or die "Error preparing statement",$dbconn->errstr;
 $dbsth->execute;
 while (my @row = $dbsth->fetchrow_array()) {
	($MediaId, $VolumeName, $VolStatus) = @row;
	$exitmsg='WARNING';
	$details = "$details\nMediaId ($MediaId) VolumeName ($VolumeName) VolStatus ($VolStatus)";
 }
 $perfomance="MediaErrors=".$dbsth->rows().";;;;";
 $dbsth->finish();
 if ($exitmsg eq "UNKNOWN") { $exitmsg = "OK"; };
}

sub check_job_running {
 my $begin_date = date_now();
 my $jobname = "";
 my $jobid = "";
 my $jobstarttime = "";
 my $jobsrunning = 0;

 my $dbsql = "SELECT Job.Name, Job.JobId, Job.StartTime FROM Job WHERE (Job.JobStatus = 'R') AND (EndTime = '0000-00-00 00:00:00') AND (DATEDIFF('$begin_date',StartTime) >= $opt_extra) ORDER BY JobId;";
 my $dbsth = $dbconn->prepare($dbsql) or die "Error preparing statement",$dbconn->errstr;
 $dbsth->execute;
 while (my @row_detail = $dbsth->fetchrow_array()) {
	($jobname,$jobid,$jobstarttime) = @row_detail;
		$jobsrunning++;
		$exitmsg = "WARNING";
		$details = "$details\nJobId ($jobid) Name ($jobname) StartTime ($jobstarttime)";
 }
 $dbsth->finish();
 $perfomance="JobsRunning=$jobsrunning;;;;";
 if ($exitmsg eq "UNKNOWN") { $exitmsg = "OK"; };
}

sub check_job_status {
 my $begin_date = date_now();
 my $end_date = "";
 my $dbsth_detail = "";
 my $job_name = "";
 my $jobid = "";
 my $joblevel = "";
 my $jobstatus = "";
 my $jobstatuslong = "";
 my $joberrors = "";
 my $continue = 1;
 my $errorcount=0;

 if ($opt_extra){
	$end_date = date_calc($opt_extra);
	print $end_date;
 }
 else {
	$end_date = '1970-01-01 01:00:00';
 }
 
 my $dbsql = "SELECT DISTINCT Name FROM Job ORDER BY Name;";
 my $dbsth = $dbconn->prepare($dbsql) or die "Error preparing statement",$dbconn->errstr;
 $dbsth->execute;

 while (my @row = $dbsth->fetchrow_array()) {
	($job_name) = @row;
	$dbsql = "SELECT Job.Name, Job.JobId, Job.Level, Job.JobStatus, Status.JobStatusLong, Job.JobErrors FROM Job LEFT JOIN Status ON Status.JobStatus = Job.JobStatus WHERE Job.Name = '$job_name' AND (EndTime <> '') AND ((EndTime <= '$begin_date') and (EndTime >= '$end_date')) ORDER BY EndTime DESC;";
	$dbsth_detail = $dbconn->prepare($dbsql) or die "Error preparing statement",$dbconn->errstr;
	$dbsth_detail->execute;
	$continue = 1;
	while ((my @row_detail = $dbsth_detail->fetchrow_array()) && ($continue)) {
		($job_name,$jobid,$joblevel,$jobstatus,$jobstatuslong,$joberrors) = @row_detail;
		#if ((($joblevel eq "D") || ($joblevel eq "I")) && ($jobstatus eq "f" || ($jobstatus eq  "E"))){
		if ((($joblevel eq "D") || ($joblevel eq "I")) && ($jobstatus eq  "E")){
			$errorcount++;
			$exitmsg = "WARNING";
			$details = "$details\nJobId ($jobid) Name ($job_name) Status($jobstatuslong) Errors($joberrors)";
		}
		if (($jobstatus eq "f") || (($joberrors > 0) && ($jobstatus eq "T"))){
			$errorcount++;
			$exitmsg = "CRITICAL";
			$details = "$details\nJobId ($jobid) Name ($job_name) Status($jobstatuslong) Errors($joberrors)";
			$continue = 0;
		}
		if (($joberrors == 0) && ($jobstatus eq "T")){
			$continue = 0;
		}
	}
	$dbsth_detail->finish();
 }
 $dbsth->finish();
 $perfomance="JobErrors=$errorcount;;;;";
 if ($exitmsg eq "UNKNOWN") { $exitmsg = "OK"; };
}

#
# MAIN CODE
#

if ($opt_help) {
 print_help();
 exit $ERRORS{'UNKNOWN'};
}

if ($opt_version) {
 check_version();
 exit $ERRORS{'UNKNOWN'};
}

if ($opt_status eq "") {
 print_help();
 exit $ERRORS{'UNKNOWN'};
}

my $dbdsn = "DBI:mysql:database=$opt_db;host=$opt_host";
$dbconn    = DBI->connect( $dbdsn,$opt_user,$opt_pass ) or die "Error connecting to: '$dbdsn': $dbconn::errstr\n";
#$exitmsg  = "OK";

switch ($opt_status) {
	case 'MEDIA_USE' { check_media_use; }
	case 'MEDIA_STATUS' { check_media_status; }
	case 'JOB_STATUS' { check_job_status; }
	case 'JOB_RUNNING' { check_job_running; }
	else { print_help(); $exitmsg = 'UNKNOWN'; }
}

$dbconn->disconnect();
print "Bacula status: $exitmsg$details|$perfomance";
exit $ERRORS{$exitmsg};