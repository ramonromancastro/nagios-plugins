@ECHO OFF

REM check_serverviewraid.cmd is a CMD function to check RAID using amCLI.exe 
REM Copyright (C) 2017 Ramon Roman Castro <ramonromancastro@gmail.com>
REM 
REM This program is free software: you can redistribute it and/or modify it
REM under the terms of the GNU General Public License as published by the Free
REM Software Foundation, either version 3 of the License, or (at your option)
REM any later version.
REM 
REM This program is distributed in the hope that it will be useful, but WITHOUT
REM ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
REM FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
REM 
REM You should have received a copy of the GNU General Public License along with
REM this program. If not, see http://www.gnu.org/licenses/.
REM 
REM @package    nagios-plugins
REM @author     Ramon Roman Castro <ramonromancastro@gmail.com>
REM @link       http://www.rrc2software.com
REM @link       https://github.com/ramonromancastro/nagios-plugins

REM ***************************
REM CONSTANTES
REM ***************************

SET AMCLI_VERSION=1.0

REM ***************************
REM VARIABLES CONFIGURABLES
REM ***************************

REM Modificar esta variable para indicar la ruta del ejecutable amCLI.exe
SET AMCLI_PATH=C:\Archivos de programa\Fujitsu\ServerView Suite\RAID Manager\bin\amCLI.exe

REM ***************************
REM CODIGO
REM ***************************

SET /A AMCLI_STATUS_ERROR=0
SET AMCLI_MSG=

FOR /F "delims=:; tokens=1" %%A IN ('"%AMCLI_PATH%" --list') DO (
	CALL:AMCLI_STATUS %%A
)

IF %AMCLI_STATUS_ERROR% EQU 0 (
	ECHO OK: All RAID elements are Ok.
	ECHO ^|errors=%AMCLI_STATUS_ERROR%
	EXIT /B 0
)
IF %AMCLI_STATUS_ERROR% GEQ 1 (
	ECHO WARNING: %AMCLI_STATUS_ERROR% RAID elements are neither Operational or OK
	ECHO ^|errors=%AMCLI_STATUS_ERROR%
	EXIT /B 1
)

ECHO UNKNOWN: Unkinown result
EXIT /B 3

GOTO:EOF

REM ***************************
REM FUNCIONES
REM ***************************

REM AMCLI_STATUS
REM ---------------------------

:AMCLI_STATUS
SET AMCLI_STATUS_AVAILABLE=0
FOR /F "tokens=5" %%A in ('"%AMCLI_PATH%" -? get %1') DO (
	IF "%%A"=="status" SET AMCLI_STATUS_AVAILABLE=1
)
IF %AMCLI_STATUS_AVAILABLE% EQU 1 (
	FOR /F "tokens=1" %%A in ('"%AMCLI_PATH%" -g %1 status') DO (
		IF NOT "%%A"=="Operational" (
			IF NOT "%%A"=="OK" (
				IF NOT "%%A"=="Available" (
					SET /A AMCLI_STATUS_ERROR+=1
				)
			)
		)
		REM SET AMCLI_MSG=%AMCLI_MSG%%1 [%%A] 
	)
)
GOTO:EOF