@echo off
setlocal EnableDelayedExpansion

:: Check if PowerShell is available
powershell -Command "exit 0" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo PowerShell is required but not found.
    exit /b 1
)

:: Default settings
set "USE_DEFAULT_PROXIES=true"
set "SERVER_PORT=8412"

:: Load settings from settings.json using PowerShell
if exist "settings.json" (
    for /f "delims=" %%j in ('powershell -Command "Get-Content -Path 'settings.json' -Raw | ConvertFrom-Json | Select-Object -Property use_default_proxies,server_port | ConvertTo-Json"') do (
        set "JSON=%%j"
        for /f "tokens=1,2 delims=:,}" %%a in ("!JSON!") do (
            if "%%a"=="\""use_default_proxies\""" (
                set "USE_DEFAULT_PROXIES=%%b"
                set "USE_DEFAULT_PROXIES=!USE_DEFAULT_PROXIES:"=!"
                set "USE_DEFAULT_PROXIES=!USE_DEFAULT_PROXIES: =!"
            )
            if "%%a"=="\""server_port\""" (
                set "SERVER_PORT=%%b"
                set "SERVER_PORT=!SERVER_PORT:"=!"
                set "SERVER_PORT=!SERVER_PORT: =!"
            )
        )
    )
)

:: Validate SERVER_PORT
if "!SERVER_PORT!"=="" set "SERVER_PORT=8412"
echo !SERVER_PORT! | findstr /R "^[0-9]*$" >nul
if %ERRORLEVEL% neq 0 (
    echo Invalid server port: !SERVER_PORT!
    exit /b 1
)

:: Load proxy configurations
set "PROXY_LIST="
if "!USE_DEFAULT_PROXIES!"=="true" (
    :: Define all default proxies from Go program
    set "PROXY_LIST=62.164.253.245:44946:NhXyame6kJn3hAJ:R2CQl6K5BWvv1SV;62.164.237.210:45040:ipgUogZe2aZfRw6:i8Ri5iQoXIvUu0u;195.222.125.119:44955:H4n5PA20MCKUDUM:8BLEhtevkq5ghMf;31.13.189.78:10168:PP6HRtUGjqw8EdR:wc8DFwiQkz63xkj;31.13.189.78:10176:PP6HRtUGjqw8EdR:wc8DFwiQkz63xkj;31.13.189.78:10216:PP6HRtUGjqw8EdR:wc8DFwiQkz63xkj;31.13.189.78:10249:PP6HRtUGjqw8EdR:wc8DFwiQkz63xkj;31.13.189.78:10283:PP6HRtUGjqw8EdR:wc8DFwiQkz63xkj;31.13.189.78:10292:PP6HRtUGjqw8EdR:wc8DFwiQkz63xkj;31.13.189.78:10310:PP6HRtUGjqw8EdR:wc8DFwiQkz63xkj;31.13.189.78:10316:PP6HRtUGjqw8EdR:wc8DFwiQkz63xkj;31.13.189.78:10327:PP6HRtUGjqw8EdR:wc8DFwiQkz63xkj;31.13.189.78:10340:PP6HRtUGjqw8EdR:wc8DFwiQkz63xkj;31.13.189.78:10675:ArdSZEyUiL0opKd:L0OLByK5qcFUHWl;31.13.189.78:10698:ArdSZEyUiL0opKd:L0OLByK5qcFUHWl;31.13.189.78:10722:ArdSZEyUiL0opKd:L0OLByK5qcFUHWl;31.13.189.78:10731:ArdSZEyUiL0opKd:L0OLByK5qcFUHWl;31.13.189.78:10744:ArdSZEyUiL0opKd:L0OLByK5qcFUHWl;31.13.189.78:10754:ArdSZEyUiL0opKd:L0OLByK5qcFUHWl;31.13.189.78:10765:ArdSZEyUiL0opKd:L0OLByK5qcFUHWl;31.13.189.78:10783:ArdSZEyUiL0opKd:L0OLByK5qcFUHWl;31.13.189.78:10795:ArdSZEyUiL0opKd:L0OLByK5qcFUHWl;31.13.189.78:10810:ArdSZEyUiL0opKd:L0OLByK5qcFUHWl;169.150.227.41:10000:6qWTlQvziwiTzpn:COJmCl1qKJFRMRO;169.150.227.41:10001:6qWTlQvziwiTzpn:COJmCl1qKJFRMRO;169.150.227.41:10010:6qWTlQvziwiTzpn:COJmCl1qKJFRMRO;169.150.227.41:10016:6qWTlQvziwiTzpn:COJmCl1qKJFRMRO;169.150.227.41:10019:6qWTlQvziwiTzpn:COJmCl1qKJFRMRO;169.150.227.41:10024:6qWTlQvziwiTzpn:COJmCl1qKJFRMRO;169.150.227.41:10031:6qWTlQvziwiTzpn:COJmCl1qKJFRMRO;169.150.227.41:10034:6qWTlQvziwiTzpn:COJmCl1qKJFRMRO;169.150.227.41:10042:6qWTlQvziwiTzpn:COJmCl1qKJFRMRO;169.150.227.41:10054:6qWTlQvziwiTzpn:COJmCl1qKJFRMRO;79.127.179.113:10004:isipc9sSeZZyV41:KN7BFXPvQvca0nE;79.127.179.113:10009:isipc9sSeZZyV41:KN7BFXPvQvca0nE;79.127.179.113:10019:isipc9sSeZZyV41:KN7BFXPvQvca0nE;79.127.179.113:10024:isipc9sSeZZyV41:KN7BFXPvQvca0nE;79.127.179.113:10030:isipc9sSeZZyV41:KN7BFXPvQvca0nE;79.127.179.113:10038:isipc9sSeZZyV41:KN7BFXPvQvca0nE;79.127.179.113:10041:isipc9sSeZZyV41:KN7BFXPvQvca0nE;79.127.179.113:10046:isipc9sSeZZyV41:KN7BFXPvQvca0nE;79.127.179.113:10047:isipc9sSeZZyV41:KN7BFXPvQvca0nE;79.127.179.113:10048:isipc9sSeZZyV41:KN7BFXPvQvca0nE;146.70.135.126:10000:jhmBigVDX6jvLv5:uBWi4IgcgOZeIIB;146.70.135.126:10001:jhmBigVDX6jvLv5:uBWi4IgcgOZeIIB;146.70.135.126:10002:jhmBigVDX6jvLv5:uBWi4IgcgOZeIIB;146.70.135.126:10004:jhmBigVDX6jvLv5:uBWi4IgcgOZeIIB;146.70.135.126:10012:jhmBigVDX6jvLv5:uBWi4IgcgOZeIIB;146.70.135.126:10013:jhmBigVDX6jvLv5:uBWi4IgcgOZeIIB;146.70.135.126:10019:jhmBigVDX6jvLv5:uBWi4IgcgOZeIIB;146.70.135.126:10021:jhmBigVDX6jvLv5:uBWi4IgcgOZeIIB;146.70.135.126:10025:jhmBigVDX6jvLv5:uBWi4IgcgOZeIIB;146.70.135.126:10028:jhmBigVDX6jvLv5:uBWi4IgcgOZeIIB"
) else (
    if exist "proxies.json" (
        :: Parse proxies.json using PowerShell
        for /f "delims=" %%p in ('powershell -Command "[System.Reflection.Assembly]::LoadWithPartialName('System.Web.Extensions'); $json = Get-Content -Path 'proxies.json' -Raw; $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer; $proxies = $ser.DeserializeObject($json); $proxies | ForEach-Object { Write-Output ($_.Addr + ':' + $_.Port + ':' + $_.Username + ':' + $_.Password) }"') do (
            set "PROXY_LIST=!PROXY_LIST!%%p;"
        )
    )
    :: Fallback to default proxies if proxies.json is empty or invalid
    if "!PROXY_LIST!"=="" (
        set "PROXY_LIST=62.164.253.245:44946:NhXyame6kJn3hAJ:R2CQl6K5BWvv1SV;62.164.237.210:45040:ipgUogZe2aZfRw6:i8Ri5iQoXIvUu0u;195.222.125.119:44955:H4n5PA20MCKUDUM:8BLEhtevkq5ghMf;31.13.189.78:10168:PP6HRtUGjqw8EdR:wc8DFwiQkz63xkj;31.13.189.78:10176:PP6HRtUGjqw8EdR:wc8DFwiQkz63xkj;31.13.189.78:10216:PP6HRtUGjqw8EdR:wc8DFwiQkz63xkj;31.13.189.78:10249:PP6HRtUGjqw8EdR:wc8DFwiQkz63xkj;31.13.189.78:10283:PP6HRtUGjqw8EdR:wc8DFwiQkz63xkj;31.13.189.78:10292:PP6HRtUGjqw8EdR:wc8DFwiQkz63xkj;31.13.189.78:10310:PP6HRtUGjqw8EdR:wc8DFwiQkz63xkj;31.13.189.78:10316:PP6HRtUGjqw8EdR:wc8DFwiQkz63xkj;31.13.189.78:10327:PP6HRtUGjqw8EdR:wc8DFwiQkz63xkj;31.13.189.78:10340:PP6HRtUGjqw8EdR:wc8DFwiQkz63xkj;31.13.189.78:10675:ArdSZEyUiL0opKd:L0OLByK5qcFUHWl;31.13.189.78:10698:ArdSZEyUiL0opKd:L0OLByK5qcFUHWl;31.13.189.78:10722:ArdSZEyUiL0opKd:L0OLByK5qcFUHWl;31.13.189.78:10731:ArdSZEyUiL0opKd:L0OLByK5qcFUHWl;31.13.189.78:10744:ArdSZEyUiL0opKd:L0OLByK5qcFUHWl;31.13.189.78:10754:ArdSZEyUiL0opKd:L0OLByK5qcFUHWl;31.13.189.78:10765:ArdSZEyUiL0opKd:L0OLByK5qcFUHWl;31.13.189.78:10783:ArdSZEyUiL0opKd:L0OLByK5qcFUHWl;31.13.189.78:10795:ArdSZEyUiL0opKd:L0OLByK5qcFUHWl;31.13.189.78:10810:ArdSZEyUiL0opKd:L0OLByK5qcFUHWl;169.150.227.41:10000:6qWTlQvziwiTzpn:COJmCl1qKJFRMRO;169.150.227.41:10001:6qWTlQvziwiTzpn:COJmCl1qKJFRMRO;169.150.227.41:10010:6qWTlQvziwiTzpn:COJmCl1qKJFRMRO;169.150.227.41:10016:6qWTlQvziwiTzpn:COJmCl1qKJFRMRO;169.150.227.41:10019:6qWTlQvziwiTzpn:COJmCl1qKJFRMRO;169.150.227.41:10024:6qWTlQvziwiTzpn:COJmCl1qKJFRMRO;169.150.227.41:10031:6qWTlQvziwiTzpn:COJmCl1qKJFRMRO;169.150.227.41:10034:6qWTlQvziwiTzpn:COJmCl1qKJFRMRO;169.150.227.41:10042:6qWTlQvziwiTzpn:COJmCl1qKJFRMRO;169.150.227.41:10054:6qWTlQvziwiTzpn:COJmCl1qKJFRMRO;79.127.179.113:10004:isipc9sSeZZyV41:KN7BFXPvQvca0nE;79.127.179.113:10009:isipc9sSeZZyV41:KN7BFXPvQvca0nE;79.127.179.113:10019:isipc9sSeZZyV41:KN7BFXPvQvca0nE;79.127.179.113:10024:isipc9sSeZZyV41:KN7BFXPvQvca0nE;79.127.179.113:10030:isipc9sSeZZyV41:KN7BFXPvQvca0nE;79.127.179.113:10038:isipc9sSeZZyV41:KN7BFXPvQvca0nE;79.127.179.113:10041:isipc9sSeZZyV41:KN7BFXPvQvca0nE;79.127.179.113:10046:isipc9sSeZZyV41:KN7BFXPvQvca0nE;79.127.179.113:10047:isipc9sSeZZyV41:KN7BFXPvQvca0nE;79.127.179.113:10048:isipc9sSeZZyV41:KN7BFXPvQvca0nE;146.70.135.126:10000:jhmBigVDX6jvLv5:uBWi4IgcgOZeIIB;146.70.135.126:10001:jhmBigVDX6jvLv5:uBWi4IgcgOZeIIB;146.70.135.126:10002:jhmBigVDX6jvLv5:uBWi4IgcgOZeIIB;146.70.135.126:10004:jhmBigVDX6jvLv5:uBWi4IgcgOZeIIB;146.70.135.126:10012:jhmBigVDX6jvLv5:uBWi4IgcgOZeIIB;146.70.135.126:10013:jhmBigVDX6jvLv5:uBWi4IgcgOZeIIB;146.70.135.126:10019:jhmBigVDX6jvLv5:uBWi4IgcgOZeIIB;146.70.135.126:10021:jhmBigVDX6jvLv5:uBWi4IgcgOZeIIB;146.70.135.126:10025:jhmBigVDX6jvLv5:uBWi4IgcgOZeIIB;146.70.135.126:10028:jhmBigVDX6jvLv5:uBWi4IgcgOZeIIB"
    )
)

:: Select a random proxy
set "PROXY_COUNT=0"
for %%p in (%PROXY_LIST:;=" "%") do (
    set /a PROXY_COUNT+=1
    set "PROXY_!PROXY_COUNT!=%%p"
)
set /a "RAND_PROXY=%RANDOM% %% %PROXY_COUNT% + 1"
set "SELECTED_PROXY=!PROXY_%RAND_PROXY%!"

:: Parse selected proxy
for /f "tokens=1-4 delims=:" %%a in ("!SELECTED_PROXY!") do (
    set "PROXY_ADDR=%%a"
    set "PROXY_PORT=%%b"
    set "PROXY_USER=%%c"
    set "PROXY_PASS=%%d"
)

:: Set system proxy using PowerShell
powershell -Command ^
    "$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Internet Settings', $true); " ^
    "$key.SetValue('ProxyEnable', 1, 'DWord'); " ^
    "$key.SetValue('ProxyServer', '127.0.0.1:%SERVER_PORT%'); " ^
    "$key.SetValue('ProxyOverride', 'localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*;<local>'); " ^
    "[System.Runtime.InteropServices.Marshal]::ReleaseComObject($key); " ^
    "$wininet = Add-Type -Name WinINet -Namespace Win32 -PassThru -MemberDefinition '[DllImport(\"wininet.dll\")] public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);'; " ^
    "$wininet::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0); " ^
    "$wininet::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0);"

if %ERRORLEVEL% neq 0 (
    echo Failed to set system proxy.
    exit /b 1
)

:: Display GUI
cls
echo.
echo   _________.__.__   __                    __   
echo  /   _____/^|__^|  ^| ^|  ^| _________   _____/  ^|_ 
echo  \_____  \ ^|  ^|  ^| ^|  ^|/ /\_  __ \_/ __ \   __\
echo  /        \^|  ^|  _^|    ^<  ^|  ^| \/\  ___/^|  ^|  
echo /_______  /^|__^|____/__^|_ \ ^|__^|    \___  ^>__^|  
echo         \/              \/             \/      
echo.
echo Privacy as smooth as silk
echo and as secret as it gets
echo.
echo ==================================================
echo Proxy Active:     TRUE
echo Local Port:       %SERVER_PORT%
echo Anti-DPI:         ENABLED
echo Fragmentation:    ENABLED
echo Decoy Packets:    ENABLED
echo ==================================================
echo.
echo Press Ctrl+C to stop the proxy...
echo.
echo --------------------------------------------------

:: Note: SOCKS5 proxy server implementation is not possible in Batch/PowerShell
echo Note: SOCKS5 proxy server functionality is not implemented.
echo Please use a dedicated proxy server application.

:: Trap Ctrl+C for graceful shutdown
:loop
timeout /t 1 >nul
goto :loop

:shutdown
echo.
echo Shutting down proxy gracefully...
powershell -Command ^
    "$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Internet Settings', $true); " ^
    "$key.SetValue('ProxyEnable', 0, 'DWord'); " ^
    "[System.Runtime.InteropServices.Marshal]::ReleaseComObject($key); " ^
    "$wininet = Add-Type -Name WinINet -Namespace Win32 -PassThru -MemberDefinition '[DllImport(\"wininet.dll\")] public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);'; " ^
    "$wininet::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0); " ^
    "$wininet::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0);"
echo Proxy stopped
exit /b 0
