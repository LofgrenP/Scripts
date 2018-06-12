<#
Created:     2018-06-12
Version:     1.1
Author :     Peter Lofgren
Twitter:     @LofgrenPeter
Blog   :     http://syscenramblings.wordpress.com

Disclaimer:
This script is provided "AS IS" with no warranties, confers no rights and 
is not supported by the author

This script takes inspiration and basics from https://blogs.msdn.microsoft.com/laps/2015/05/06/laps-and-machine-reinstalls/
Script has been modified to including logging. All credit for original script goes to Author Jiri FormacekMay

Updates
1.0 - Initial release
1.1 - Stop Logging missing

License:

The MIT License (MIT)

Copyright (c) 2017 Peter Lofgren

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
    Start-Transcript -Path $LogFile -Force
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
Write-Output "$ScriptName - ScriptName: $ScriptName"
Write-Output "$ScriptName - Current Culture: $LANG"
Write-Output "$ScriptName - Integration with MDT(LTI/ZTI): $MDTIntegration"
Write-Output "$ScriptName - Log: $LogFile"

#Get NetBIOS domain name
$Info=New-Object -ComObject ADSystemInfo
$Type=$Info.GetType()

$domainName=$Type.InvokeMember("DomainShortName","GetProperty",$null,$info,$null)
Write-Output  "$ScriptName - DomainName: $domainName"
$computerName=$env:computerName
Write-Output "$SCRIPTNAME - Computername: $Computername"

#translate domain\computername to distinguishedName
$Translator = New-Object -ComObject NameTranslate
$Type = $Translator.GetType()
$Type.InvokeMember(“Init”,”InvokeMethod”,$null,$Translator,(3,$null)) #resolve via GC
$Type.InvokeMember(“Set”,”InvokeMethod”,$null,$Translator,(3,”$DomainName\$ComputerName`$”))
$ComputerDN=$t.InvokeMember(“Get”,”InvokeMethod”,$null,$Translator,1)
Write-Output "$Scriptname - ComputerDN: $ComputerDN"

#connect to computer object
try {
    $computerObject= New-Object System.DirectoryServices.DirectoryEntry("LDAP://$computerDN")
}
Catch {
    Write-Output "$ScriptName - Failed to connect to computer in AD, exiting."
    Write-Output "$ScriptName - Do not forgett to manually reset AdmPwd expire time"
    Break
}

#clear password expiration time
try {
    ($computerObject.'ms-Mcs-AdmPwdExpirationTime').Clear()
    $computerObject.CommitChanges()
    Write-Output "$SCRIPTNAME - Reset AdmPwdExpirationTime on $computerName"
}
Catch {
    Write-Output "$SCRIPTNAME - Failed to reset password in AD, exiting"
    Write-Output "$ScriptName - Do not forgett to manually reset AdmPwd expire time"
}

. Stop-Logging