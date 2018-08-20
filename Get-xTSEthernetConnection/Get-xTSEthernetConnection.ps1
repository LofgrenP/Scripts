<#
Created:    2018-08-20
Updated:    2018-08-20
Version:    1.0
Author :    Peter Lofgren
Twitter:    @LofgrenPeter
Blog   :    http://syscenramblings.wordpress.com

Disclaimer:
This script is provided "AS IS" with no warranties, confers no rights and
is not supported by the author

Updates
1.0 - Initial release

License:

The MIT License (MIT)

Copyright (c) 2018 Peter Lofgren

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>

[CMDLETBINDING()]

Param(

) 

Function Import-SMSTSENV{
    try {
        $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
        Write-Output "$ScriptName - tsenv is $tsenv "
        $MDTIntegration = "YES"
    }
    catch {
        Write-Output "$ScriptName - Unable to load Microsoft.SMS.TSEnvironment"
        Write-Output "$ScriptName - Running in standalonemode"
        $MDTIntegration = "NO"
    }
    Finally {
        if ($MDTIntegration -eq "YES") {
            if ($tsenv.Value("LogPath") -ne "") {
                $Logpath = $tsenv.Value("LogPath")
                $LogFile = $Logpath + "\" + "$LogName.log"
            }
            Elseif ($tsenv.Value("_SMSTSLogPath") -ne "") {
                $Logpath = $tsenv.Value("_SMSTSLogPath")
                $LogFile = $Logpath + "\" + "$LogName.log"
            }
        }
        elseif ($env:USERNAME = "System") {
            try {
                $LogPath = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\SMS\Client\Configuration\Client Properties' -Name 'Local SMS Path' -ErrorAction Stop)."Local SMS Path" + "Logs"
                $LogFile = $Logpath + "\" + "$LogName.log"
            }
            Catch {
                $Logpath = $env:TEMP
                $LogFile = $Logpath + "\" + "$LogName.log"
            }
        }
        Else{
            $Logpath = $env:TEMP
            $LogFile = $Logpath + "\" + "$LogName.log"
        }
    }
}

Function Start-Logging{
    start-transcript -path $LogFile -Force
}
Function Stop-Logging{
    Stop-Transcript
}

# Set Vars
$SCRIPTDIR = split-path -parent $MyInvocation.MyCommand.Path
$SCRIPTNAME = split-path -leaf $MyInvocation.MyCommand.Path
$LANG = (Get-Culture).Name
$LogName = $SCRIPTNAME

#Try to Import SMSTSEnv
. Import-SMSTSENV

#Start Transcript Logging
. Start-Logging

#Output base info
Write-Output ""
Write-Output "$ScriptName - ScriptDir: $ScriptDir"
Write-Output "$ScriptName - SourceRoot: $SOURCEROOT"
Write-Output "$ScriptName - ScriptName: $ScriptName"
Write-Output "$ScriptName - SettingsFile: $SettingsFile"
Write-Output "$ScriptName - Current Culture: $LANG"
Write-Output "$ScriptName - Integration with MDT(LTI/ZTI): $MDTIntegration"
Write-Output "$ScriptName - Log: $LogFile"


#Custom Code    
Write-Output "Getting network adapters"
$Adapters = Get-NetAdapter -Physical | Where-Object -Property MediaType -EQ "802.3"
If ($($Adapters | Measure-Object).Count -eq 0) {
    Write-Output "No valid adapters found, exiting with exitcode 1"
    . Stop-Logging
    Exit 1
}
$Count = 0
foreach ($Adapter in $Adapters) {
    Write-Output "Checking adapter $($Adapter.InterfaceDescription)"
    if ($Adapter.State -eq "Up") {
        Write-Output "Found connected adapter, will continue"
        $Count = 1
    }
}
if ($Count -ne 1) {
    Write-Output "No wired connection found, will exit with exitcode 2"
    . Stop-Logging
    exit 2
}


#Stop Logging
. Stop-Logging