' check_ad_repl.vbs is a VBScript function to check Active Directory replication 
' Copyright (C) 2017 Ramon Roman Castro <ramonromancastro@gmail.com>
'
' This program is free software: you can redistribute it and/or modify it
' under the terms of the GNU General Public License as published by the Free
' Software Foundation, either version 3 of the License, or (at your option)
' any later version.
'
' This program is distributed in the hope that it will be useful, but WITHOUT
' ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
' FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
'
' You should have received a copy of the GNU General Public License along with
' this program. If not, see http://www.gnu.org/licenses/.
'
' @package    nagios-plugins
' @author     Ramon Roman Castro <ramonromancastro@gmail.com>
' @link       http://www.rrc2software.com
' @link       https://github.com/ramonromancastro/nagios-plugins

' Versión: 1.0 (20160721)
' Versión: 1.1 (20160721)
' Versión: 1.2 (20160721)
' Versión: 1.3 (20160726)
' Versión: 1.4 (20161118)
' Versión: 1.5 (20170510)

On Error Resume Next

strComputer = "."
intErrors = 0
intNagiosResult = 0

Set objSWbemLocator = CreateObject("WbemScripting.SWbemLocator")
Set objWMIService = objSWbemLocator.ConnectServer(strComputer, "\root\MicrosoftActiveDirectory")
Set colReplicationOperations = objWMIService.ExecQuery ("Select * from MSAD_ReplNeighbor")
Set objDict = CreateObject("Scripting.Dictionary")

For Each objReplicationJob In colReplicationOperations
	If objReplicationJob.NumConsecutiveSyncFailures > 0 Then
		intNagiosResult = 2
		intErrors = intErrors + 1
		strDetails = strDetails & "[ ERROR ] " & objReplicationJob.NamingContextDN & "." & objReplicationJob.SourceDsaCN & vbNewLine
		If objDict.Exists(objReplicationJob.SourceDsaCN) Then
			objDict.Item(objReplicationJob.SourceDsaCN) = "ERROR"
		Else
			objDict.Add objReplicationJob.SourceDsaCN, "ERROR"
		End If
	Else
		strDetails = strDetails & "[ OK ] " & objReplicationJob.NamingContextDN & "." & objReplicationJob.SourceDsaCN & vbNewLine
		If NOT objDict.Exists(objReplicationJob.SourceDsaCN) Then
			objDict.Add objReplicationJob.SourceDsaCN, "OK"
		End If
	End If
Next

If Err Then
	WScript.Echo "ADREPL UNKNOWN - Internal plugin error."
	WScript.Quit(3)
End If

If intErrors > 0 Then
	WScript.Echo "ADREPL CRITICAL - " & intErrors & " replication error/s found."
Else
	WScript.Echo "ADREPL OK - No replication errors found."
End If

objKeys = objDict.Keys
For intIndex = 0 To objDict.Count - 1
  WScript.Echo "[" & objDict(objKeys(intIndex)) & "] " & objKeys(intIndex) 
Next

WScript.Echo "|errors=" & intErrors

WScript.Quit(intNagiosResult)

On Error GoTo 0