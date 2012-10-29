@echo off

set resources_dir=res
set installJkMod=0
set apachePath=null

:init_apache_path
set httpd_path=bin\httpd.exe
set x86_path=C:\Program Files (x86)\Apache Software Foundation\Apache2.2
set x64_path=C:\Program Files\Apache Software Foundation\Apache2.2

if exist "%x86_path%\%httpd_path%" set apachePath=%x86_path%
if exist "%x64_path%\%httpd_path%" set apachePath=%x64_path%

REM ////////////////// MENU /////////////////////

:start
cls
echo ===============================================
echo ==         Apache2.2 mod_jk installer         =
echo == ------------------------------------------ =
echo ==         Released by Nicolas FRADIN         =
echo ==             Date: 2012/10/11               =
echo ===============================================
echo.
if /I %installJkMod%==1 (
	goto start_install
) else (
	goto query
)

:query
set /p userInput=Do you wish to install mod_jk for apache2.2 ? (y/n) :
echo.
if /I "x%userInput%"=="xy" (
	set installJkMod=1
	goto start
) else (
	if /I "x%userInput%"=="xn" (
		goto exit
	) else (
		goto invalid_query
	)
)

:invalid_query
echo Invalid response. Please try again
echo.
goto query


REM ////////////////// INSTALL /////////////////////

:start_install
echo Starting install of mod_jk for Apache2.2 ...
echo --------------------------------------------

:check_apache_path
REM -- If apache path is undefined ask to user
if /I "%apachePath%"=="q" (
	goto exit
) else (
	if exist "%apachePath%\%httpd_path%" (
		goto install_step1
	) else (
		goto apache_path_query
	)
)

:apache_path_query
echo.
echo Apache2.2 installation directory was not found !
set /p apachePath=Please specify a valid Apache2.2 path [q to exit]:
goto check_apache_path


:install_step1
echo Apache installation path :
echo %apachePath%
echo --------------------------------------------
pause
echo.

:copy_files
echo + Copying mod_jk to Apache2.2 modules directory...
xcopy "%resources_dir%\mod_jk.so" "%apachePath%\modules\" /Q /R /Y
echo.

echo + Copying mod_jk config to Apache2.2 config directory...
xcopy "%resources_dir%\httpd-jk.conf" "%apachePath%\conf\extra\" /Q /R /Y
echo.

echo + Copying workers config to Apache2.2 config directory...
xcopy "%resources_dir%\workers.properties" "%apachePath%\conf\" /Q /R /Y
echo.

:modify_httpd_conf
set http_file=%apachePath%\conf\httpd.conf
set load_line=LoadModule jk_module modules/mod_jk.so
set include_line=Include conf/extra/httpd-jk.conf
findstr /m "mod_jk.so" "%http_file%">nul
if %errorlevel%==1 (
	echo + Add LoadModule to Apache2.2 "httpd.conf"...
	echo.
	echo.>>"%http_file%"
	echo #Added by Apache2.2 mod_jk installer>>"%http_file%"
	echo %load_line%>>"%http_file%"
)
findstr /m "httpd-jk.conf" "%http_file%">nul
if %errorlevel%==1 (
	echo + Add Include to Apache2.2 "httpd.conf"...
	echo.
	echo.>>"%http_file%"
	echo #Added by Apache2.2 mod_jk installer>>"%http_file%"
	echo %include_line%>>"%http_file%"
)


:query_configure_mod_jk
echo --------------------------------------------------------
echo.
set /p configureWorkers=Would you like configue mod_jk workers ? (y/n) :
if /I "x%configureWorkers%"=="xy" (
	goto start_configure_mod_jk
) else (
	if /I "x%configureWorkers%"=="xn" (
		goto install_success
	) else (
		echo Invalid response. Please try again.
		goto query_configure_mod_jk
	)
)



REM ////////////////// CONFIG /////////////////////

:start_configure_mod_jk
cls
echo Starting configuration of jk_mod for Apache2.2 ...
echo --------------------------------------------------

:query_how_many_workers
set /p nbWorkers=How many workers would you like to configure ? [1-3] or [0 to exit] :
if /I "x%nbWorkers%"=="x0" goto install_success
if /I "x%nbWorkers%"=="x" (
	echo Invalid response. Please try again.
	echo.
	goto query_how_many_workers
)
if /I %nbWorkers% gtr 0 (
	if /I 4 gtr %nbWorkers% (
		goto configure_workers_loop
	)
	echo Invalid response. Please try again.
	echo.
	goto query_how_many_workers
) else (
	echo Invalid response. Please try again.
	echo.
	goto query_how_many_workers
)

:configure_workers_loop
set /A nbWorkers=%nbWorkers%+1
set counter=1
REM - Initialize arrays containing workers configurations
set workerName[0]=initArray
set workerHost[0]=initArray
set workerPort[0]=initArray
set workerType[0]=initArray

:worker_config_loop
if %nbWorkers% gtr %counter% (
	echo.
	echo Configuring worker number %counter%
	echo --------------------------------------------------
	goto configure_worker
) else (
	goto write_workers_property_file
)

:configure_worker
REM - Set worker name
set /p workerNameVar=Worker name ? [worker%counter%] :
if /I "x%workerNameVar%"=="x" (call res\array.bat add workerName worker%counter%) else (call res\array.bat add workerName %workerNameVar%)

REM - Set worker host
set /p workerHostVar=Host ? [localhost] :
if /I "x%workerHostVar%"=="x" (call res\array.bat add workerHost localhost) else (call res\array.bat add workerHost %workerHostVar%)

REM - Set worker port
set /p workerPortVar=Port ? [8009] :
if /I "x%workerPortVar%"=="x" (call res\array.bat add workerPort 8009) else (call res\array.bat add workerPort %workerPortVar%)

REM - Set worker type
set /p workerTypeVar=Type ? [ajp13] :
if /I "x%workerTypeVar%"=="x" (call res\array.bat add workerType ajp13) else (call res\array.bat add workerType %workerTypeVar%)

REM - Increment counter and return to loop
set /A counter=%counter%+1
goto worker_config_loop


:write_workers_property_file
echo.
echo + Writing workers properties file...

REM - Initialize variables
set file="%apachePath%\conf\workers.properties"
set counter=1

:fill_workersList_loop
REM - Get into %value% variable the workerName at position %counter% in array
call res\array.bat getitem workerName %counter% value
if %nbWorkers% gtr %counter% (
	if /I "%counter%"=="1" (set workersList=%value%) else (set workersList=%workersList%,%value%)
	set /A counter=%counter%+1
	goto fill_workersList_loop
)

REM - Delete old file if exists
if exist %file% del %file%

REM - Write new file
echo #>>%file%
echo # Apache2.2 workers properties file - generated by mod_jk installer >>%file%
echo #>>%file%
echo.>>%file%
echo # Workers list>>%file%
echo workers.list=%workersList%>>%file%
echo.>>%file%

REM - Iterate on workers and write config
set counter=1

:write_worker_config_loop
call res\array.bat getitem workerName %counter% WName
call res\array.bat getitem workerHost %counter% WHost
call res\array.bat getitem workerPort %counter% WPort
call res\array.bat getitem workerType %counter% WType
if %nbWorkers% gtr %counter% (
	echo # %WName% configuration>>%file%
	echo worker.%WName%.host=%WHost%>>%file%
	echo worker.%WName%.port=%WPort%>>%file%
	echo worker.%WName%.type=%WType%>>%file%
	echo.>>%file%
	set /A counter=%counter%+1
	goto write_worker_config_loop
)

goto install_success

REM //////////////////  EXIT /////////////////////

:install_success
echo -------------------------------------------------------
echo.
echo Apache2.2 mod_jk was installed with success !
echo.
echo You just have to configure your tomcat server to enable AJP conector...
echo.
set installJkMod=1
goto exit

:exit
echo.
echo Press any key to exit.
pause>nul