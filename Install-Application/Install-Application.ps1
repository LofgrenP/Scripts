<#
Created:     2018-01-23
Version:     5.0
Author :     Peter Lofgren
Twitter:     @LofgrenPeter
Blog   :     http://syscenramblings.wordpress.com

Disclaimer:
This script is provided "AS IS" with no warranties, confers no rights and 
is not supported by the author

Updates
1.0 - Initial release
2.0 - Added better logging for use with SCCM, files will now be places correctly even when run as a standalone application
3.0 - Added support for .msp files
4.0 - Added support for .vbs and .ps1 files
5.0 - Fixed ConfigMgr Logging path.
#>


Param (
    [Parameter(Mandatory=$false)]
    $SettingsName = "Settings.xml"
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


# Set Vars
$SCRIPTDIR = split-path -parent $MyInvocation.MyCommand.Path
$SCRIPTNAME = split-path -leaf $MyInvocation.MyCommand.Path
$SOURCEROOT = "$SCRIPTDIR\Source"
$SettingsFile = $SCRIPTDIR + "\" + $SettingsName
$LANG = (Get-Culture).Name
$OSV = $Null
$ARCHITECTURE = $env:PROCESSOR_ARCHITECTURE

Try { [xml]$Settings = Get-Content $SettingsFile }
Catch { 
      $ErrorMsg = $_.Exception.Message
      Write-Output "Failed to get Settings from $SettingsFile with error $ErrorMsg"
      Exit 1
}

$LogName = $Settings.xml.Application.Name

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

foreach ($App in $Settings.xml.Application) {

    $InstallerName = $App.InstallerName
    $InstallerType = $App.InstallerType
    $InstallSwitches = $App.InstallSwitches
    $Name = $App.Name


    if ($InstallerType -like "EXE") {
        Write-Output "Starting install $Name with: $SOURCEROOT\$InstallerName $InstallSwitches"
        $ExitCode = Invoke-Exe -Executable $SOURCEROOT\$InstallerName -Arguments $InstallSwitches
        Write-Output "Finsihed installing $Name with exitcode $ExitCode"
    }
    Elseif ($InstallerType -like "MSI") {
        Write-Output "Starting install $Name with: msiexec /i $SOURCEROOT\$InstallerName $InstallSwitches"
        $Arg = "/i " + '"' + $SOURCEROOT + "\" + $InstallerName + '" ' + $InstallSwitches
        $ExitCode = Invoke-Exe -Executable msiexec -Arguments $Arg
        Write-Output "Finsihed installing $Name with exitcode $ExitCode"
    }
    Elseif ($InstallerType -like "MSP") {
        Write-Output "Starting install $Name with: msiexec /p $SOURCEROOT\$InstallerName $InstallSwitches"
        $Arg = "/p " + '"' + $SOURCEROOT + "\" + $InstallerName + '" ' + $InstallSwitches
        $ExitCode = Invoke-Exe -Executable msiexec.exe -Arguments $Arg
        Write-Output "Finsihed installing $Name with exitcode $ExitCode"  
    }
    Elseif ($InstallerType -like "VBS") {
        Write-Output "Starting install $Name with: cscript.exe $SOURCEROOT\$InstallerName $InstallSwitches"
        $Arg = '"' + $SOURCEROOT + "\" + $InstallerName + '" ' + $InstallSwitches
        $ExitCode = Invoke-Exe -Executable cscript.exe -Arguments $Arg
        Write-Output "Finsihed installing $Name with exitcode $ExitCode"  
    }
    Elseif ($InstallerType -like "PS1") {
        Write-Output "Starting install $Name with: PowerShell.exe -ExecutionPolicy ByPass -File "$SOURCEROOT\$InstallerName""
        $Arg = '-ExecutionPolicy ByPass -File "' + $SOURCEROOT + "\" + $InstallerName + '" '
        $ExitCode = Invoke-Exe -Executable PowerShell.exe -Arguments $Arg
        Write-Output "Finsihed installing $Name with exitcode $ExitCode"  
    }
    Elseif ($InstallerType -like "MSU") {
        Write-Output "Starting install $Name with: Wusa.exe " + '"' + $SOURCEROOT + '\' + $InstallerName + '" /quiet /Norestart'
        $Arg = '"' + $SOURCEROOT + "\" + $InstallerName + '" /quiet /norestart'
        $ExitCode = Invoke-Exe -Executable WUSA.exe -Arguments $Arg
        Write-Output "Finsihed installing $Name with exitcode $ExitCode"  
    }
}

#Stop Logging
. Stop-Logging