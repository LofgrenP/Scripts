<#
Created:     2018-06-05
Version:     2.0
Author :     Peter Lofgren
Twitter:     @LofgrenPeter
Blog   :     http://syscenramblings.wordpress.com

Disclaimer:
This script is provided "AS IS" with no warranties, confers no rights and 
is not supported by the author

Updates
1.0 - Initial release
2.0 - Updated with error handeling logic and patches for x86

#>

Function Import-SMSTSENV{
    try
    {
        $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
        Write-Output "$ScriptName - tsenv is $tsenv "
        $MDTIntegration = "YES"
        
        #$tsenv.GetVariables() | % { Write-Output "$ScriptName - $_ = $($tsenv.Value($_))" }
    }
    catch
    {
        Write-Output "$ScriptName - Unable to load Microsoft.SMS.TSEnvironment"
        Write-Output "$ScriptName - Running in standalonemode"
        $MDTIntegration = "NO"
    }
    Finally
    {
    if ($MDTIntegration -eq "YES"){
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
          $LogPath = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\SMS\Client\Configuration\Client Properties' -Name 'Local SMS Path' -ErrorAction Stop)."Local SMS Path"
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
Function Get-OSVersion([ref]$OSv){
    $OS = Get-WmiObject -class Win32_OperatingSystem
    Switch -Regex ($OS.Version)
    {
    "6.1"
        {If($OS.ProductType -eq 1)
            {$OSv.value = "Windows 7 SP1"}
                Else
            {$OSv.value = "Windows Server 2008 R2"}
        }
    "6.2"
        {If($OS.ProductType -eq 1)
            {$OSv.value = "Windows 8"}
                Else
            {$OSv.value = "Windows Server 2012"}
        }
    "6.3"
        {If($OS.ProductType -eq 1)
            {$OSv.value = "Windows 8.1"}
                Else
            {$OSv.value = "Windows Server 2012 R2"}
        }
    "10."
        {If($OS.ProductType -eq 1)
            {$OSv.value = "Windows 10"}
                Else
            {$OSv.value = "Windows Server 10"}
        }
    DEFAULT { "Version not listed" }
    } 
}
Function Invoke-Exe{
    [CmdletBinding(SupportsShouldProcess=$true)]

    param(
        [parameter(mandatory=$true,position=0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Executable,

        [parameter(mandatory=$false,position=1)]
        [string]
        $Arguments
    )

    if($Arguments -eq "")
    {
        Write-Verbose "Running $ReturnFromEXE = Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru"
        $ReturnFromEXE = Start-Process -FilePath $Executable -NoNewWindow -Wait -Passthru
    }else{
        Write-Verbose "Running $ReturnFromEXE = Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru"
        $ReturnFromEXE = Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru
    }
    Write-Verbose "Returncode is $($ReturnFromEXE.ExitCode)"
    Return $ReturnFromEXE.ExitCode
}
Function Start-Logging{
    start-transcript -path $LogFile -Force
}
Function Stop-Logging{
    Stop-Transcript
}
Function Get-TSxExitCode {
    [CmdletBinding(SupportsShouldProcess=$true)]

    param (
        [parameter(mandatory=$true,position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$ExitCode,

        [parameter(mandatory=$false,position=1)]
        [ValidateNotNullOrEmpty()]
        $ReturnCodes = $("0","3010")
    )

    If ($ReturnCodes -contains $ExitCode) {
        Write-Output "Valid exitcode found, continuing"
    }
    Else {
        Write-Output "Faulty exitcode found, exiting using exitcode"
        Exit $ExitCode
    }
    
}

# Set Vars
$SCRIPTDIR = split-path -parent $MyInvocation.MyCommand.Path
$SCRIPTNAME = split-path -leaf $MyInvocation.MyCommand.Path
$SOURCEROOT = "$SCRIPTDIR\Source"
$SettingsFile = $SCRIPTDIR + "\" + $SettingsName
$LANG = (Get-Culture).Name
$OSV = $Null
$ARCHITECTURE = $env:PROCESSOR_ARCHITECTURE
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


#Actuall Install
$MBAMClientInstallState = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\MBAM" -Name Installed -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Installed
if ($MBAMClientInstallState -eq 1) {
    $Products = Get-CimInstance -ClassName Win32_Product
    $MsiCode = ($Products | Where-Object -Property Name -eq "MDOP MBAM").IdentifyingNumber
    Write-Output "Uninstall current version of MBAM client"
    $Arg = "/x $MsiCode /qn Reboot=ReallySuppress"
    $ExitCode = Invoke-Exe -Executable msiexec.exe -Arguments $Arg
    Write-Output "Uninstall finished with exitcode $ExitCode"
    Get-TSxExitCode -ExitCode $ExitCode
}

$InstallerName = "MbamClientSetup.exe"
$InstallSwitches = "/AcceptEULA=YES"

Write-Output "Starting install $Name with: $SOURCEROOT\$InstallerName $InstallSwitches"
$ExitCode = Invoke-Exe -Executable $SOURCEROOT\$InstallerName -Arguments $InstallSwitches
Write-Output "Finsihed installing $Name with exitcode $ExitCode"
Get-TSxExitCode -ExitCode $ExitCode

if ($ARCHITECTURE -eq "AMD64") {
    $InstallerName = "MBAM2.5_Client_x64_KB4041137.msp"
    $InstallSwitches = "/qb Reboot=ReallySuppress"
    Write-Output "Starting install $Name with: msiexec /p $SOURCEROOT\$InstallerName $InstallSwitches"
    $Arg = "/p " + '"' + $SOURCEROOT + "\" + $InstallerName + '" ' + $InstallSwitches
    $ExitCode = Invoke-Exe -Executable msiexec.exe -Arguments $Arg
    Write-Output "Finsihed installing $Name with exitcode $ExitCode"  
    Get-TSxExitCode -ExitCode $ExitCode
}
if ($ARCHITECTURE -eq "x86") {
    $InstallerName = "MBAM2.5_Client_x86_KB4041137.msp"
    $InstallSwitches = "/qb Reboot=ReallySuppress"
    Write-Output "Starting install $Name with: msiexec /p $SOURCEROOT\$InstallerName $InstallSwitches"
    $Arg = "/p " + '"' + $SOURCEROOT + "\" + $InstallerName + '" ' + $InstallSwitches
    $ExitCode = Invoke-Exe -Executable msiexec.exe -Arguments $Arg
    Write-Output "Finsihed installing $Name with exitcode $ExitCode"  
    Get-TSxExitCode -ExitCode $ExitCode
}


#Stop Logging
. Stop-Logging