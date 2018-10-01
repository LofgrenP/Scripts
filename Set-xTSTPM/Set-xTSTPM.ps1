<#
Created:    2018-08-23
Updated:    2018-08-23
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

[CMDLETBINDING(SupportsShouldProcess=$true)]
Param (

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
    Start-transcript -path $LogFile -Force
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
Function Get-xTSDellExitCode {
    [CmdletBinding(SupportsShouldProcess=$true)]

    param (
        [parameter(mandatory=$true,position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$ExitCode
    )

    if ($ExitCode -eq "0") {
        Write-Output "Successfully configured bios setting"    
    }
    else {
        Write-Output "Failed with exitcode: $ExitCode"
    }
}

#Set general script information
$SCRIPTDIR = split-path -parent $MyInvocation.MyCommand.Path
$SCRIPTNAME = split-path -leaf $MyInvocation.MyCommand.Path
$SOURCEROOT = "$SCRIPTDIR\Source"
$ARCHITECTURE = $env:PROCESSOR_ARCHITECTURE
$LogName = $SCRIPTNAME

#Try to Import SMSTSEnv
. Import-SMSTSENV

#Start Transcript Logging
. Start-Logging

#Output base info
Write-Output "$ScriptName - ScriptDir: $ScriptDir"
Write-Output "$ScriptName - SourceRoot: $SOURCEROOT"
Write-Output "$ScriptName - ScriptName: $ScriptName"
Write-Output "$ScriptName - Architecture: $ARCHITECTURE"
Write-Output "$ScriptName - Integration with MDT(LTI/ZTI): $MDTIntegration"
Write-Output "$ScriptName - Log: $LogFile"

#Get Manufacturer
$Make = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty Manufacturer
#Normalize manufacturer name
Switch ($Make) {
    "Hewlett-Packard" { $Make = "HP"}
    "Dell Inc." { $Make = "Dell" }
    "VmWare Inc." { $make = "VmWare" }
    Default { $Make = $Make }
}

Write-Output "Make is currently: $Make"
Switch ($Make) {
    "HP" {
        $Model = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty Model
        Write-Output "Model is currently: $Model"
        Switch ($Model) {
            "HP EliteBook 840 G5" {
                Write-Output "Getting TPM information"
                $Bios = Get-WmiObject -Namespace root\hp\instrumentedbios -Class HP_BIOSSetting
                Write-Output "TPM State: $($Bios | Where-Object Name -EQ "TPM State" | Select-Object -ExpandProperty CurrentValue)"
                Write-Output "TPM Device: $($Bios | Where-Object Name -EQ "TPM Device" | Select-Object -ExpandProperty CurrentValue)"
                Write-Output "TPM Activation Policy: $($Bios | Where-Object Name -EQ "TPM Activation Policy" | Select-Object -ExpandProperty CurrentValue)"
                Write-Output "Setting desired values"
                $SetBios = Get-WmiObject -Namespace root\hp\instrumentedbios -Class HP_BIOSSettingInterface
                $Return = $SetBios.SetBIOSSetting("TPM State", "Enable")
                switch ($Return.Return) {
                    0 { Write-Output "Setting: Success" }
                    1 { Write-Output "Setting: Not Supported" }
                    2 { Write-Output "Setting: Unspecified Error" }
                    3 { Write-Output "Setting: Timeout" }
                    4 { Write-Output "Setting: Failed" }
                    5 { Write-Output "Setting: Invalid Parameter" }
                    6 { Write-Output "Setting: Access Denied" }
                    Default { Write-Output "Setting: Failed with Unknown reason" }
                }
                $Return = $SetBios.SetBIOSSetting("TPM Device", "Available")
                switch ($Return.Return) {
                    0 { Write-Output "Setting: Success" }
                    1 { Write-Output "Setting: Not Supported" }
                    2 { Write-Output "Setting: Unspecified Error" }
                    3 { Write-Output "Setting: Timeout" }
                    4 { Write-Output "Setting: Failed" }
                    5 { Write-Output "Setting: Invalid Parameter" }
                    6 { Write-Output "Setting: Access Denied" }
                    Default { Write-Output "Setting: Failed with Unknown reason" }
                }
                $Return = $SetBios.SetBIOSSetting("TPM Activation Policy", "No prompts")
                switch ($Return.Return) {
                    0 { Write-Output "Setting: Success" }
                    1 { Write-Output "Setting: Not Supported" }
                    2 { Write-Output "Setting: Unspecified Error" }
                    3 { Write-Output "Setting: Timeout" }
                    4 { Write-Output "Setting: Failed" }
                    5 { Write-Output "Setting: Invalid Parameter" }
                    6 { Write-Output "Setting: Access Denied" }
                    Default { Write-Output "Setting: Failed with Unknown reason" }
                }
            }
            Default {
                Write-Output "No previously specified model found, using default section"
                $Bios = Get-WmiObject -Namespace root\hp\instrumentedbios -Class HP_BIOSSetting
                Write-Output "TPM State: $($Bios | Where-Object Name -EQ "TPM State" | Select-Object -ExpandProperty CurrentValue)"
                Write-Output "TPM Device: $($Bios | Where-Object Name -EQ "TPM Device" | Select-Object -ExpandProperty CurrentValue)"
                Write-Output "TPM Activation Policy: $($Bios | Where-Object Name -EQ "TPM Activation Policy" | Select-Object -ExpandProperty CurrentValue)"
                Write-Output "Setting desired values"
                $SetBios = Get-WmiObject -Namespace root\hp\instrumentedbios -Class HP_BIOSSettingInterface
                $Return = $SetBios.SetBIOSSetting("TPM State", "Enable")
                switch ($Return.Return) {
                    0 { Write-Output "Setting: Success" }
                    1 { Write-Output "Setting: Not Supported" }
                    2 { Write-Output "Setting: Unspecified Error" }
                    3 { Write-Output "Setting: Timeout" }
                    4 { Write-Output "Setting: Failed" }
                    5 { Write-Output "Setting: Invalid Parameter" }
                    6 { Write-Output "Setting: Access Denied" }
                    Default { Write-Output "Setting: Failed with Unknown reason" }
                }
                $Return = $SetBios.SetBIOSSetting("TPM Device", "Available")
                switch ($Return.Return) {
                    0 { Write-Output "Setting: Success" }
                    1 { Write-Output "Setting: Not Supported" }
                    2 { Write-Output "Setting: Unspecified Error" }
                    3 { Write-Output "Setting: Timeout" }
                    4 { Write-Output "Setting: Failed" }
                    5 { Write-Output "Setting: Invalid Parameter" }
                    6 { Write-Output "Setting: Access Denied" }
                    Default { Write-Output "Setting: Failed with Unknown reason" }
                }
                $Return = $SetBios.SetBIOSSetting("TPM Activation Policy", "No prompts")
                switch ($Return.Return) {
                    0 { Write-Output "Setting: Success" }
                    1 { Write-Output "Setting: Not Supported" }
                    2 { Write-Output "Setting: Unspecified Error" }
                    3 { Write-Output "Setting: Timeout" }
                    4 { Write-Output "Setting: Failed" }
                    5 { Write-Output "Setting: Invalid Parameter" }
                    6 { Write-Output "Setting: Access Denied" }
                    Default { Write-Output "Setting: Failed with Unknown reason" }
                }
            }
        }
    }
    "Lenovo" {
        $Model = Get-WmiObject -Class Win32_ComputersystemProduct | Select-Object -ExpandProperty Version
        Write-Output "Model is currently: $Model"
        Switch ($Model) {
            "ThinkPad W520" {
                $Bios = Get-WmiObject -Namespace root\wmi -Class lenovo_BiosSetting
                Write-Output "TPM State: $(($Bios | Where-Object CurrentSetting -like "SecurityChip*" | Select-Object -ExpandProperty CurrentSetting).Split(",")[1])"
                $SetBios = Get-WmiObject -Namespace root\wmi -Class lenovo_SetBiosSetting
                $SetResult = $SetBios.SetBiosSetting("SecurityChip,Active")
                Write-Output "Setting SecurityChip: $($SetResult.return)"
                $SaveResult = (Get-WmiObject -namespace root\wmi -Class Lenovo_SaveBiosSettings).SaveBiosSettings()
                Write-Output "Saving settings: $($SaveResult.return)"
            }
            Default {
                $Bios = Get-WmiObject -Namespace root\wmi -Class lenovo_BiosSetting
                Write-Output "TPM State: $(($Bios | Where-Object CurrentSetting -like "SecurityChip*" | Select-Object -ExpandProperty CurrentSetting).Split(",")[1])"
                $SetBios = Get-WmiObject -Namespace root\wmi -Class lenovo_SetBiosSetting
                $SetResult = $SetBios.SetBiosSetting("SecurityChip,Enable")
                Write-Output "Setting SecurityChip: $($SetResult.return)"
                $SaveResult = (Get-WmiObject -namespace root\wmi -Class Lenovo_SaveBiosSettings).SaveBiosSettings()
                Write-Output "Saving settings: $($SaveResult.return)"
            }
        }
    }
    "Dell" {
        $Model = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty Model
        Write-Output "Model is currently: $Model"
        if ($clear) {
            Write-Output "Quering Win32_TPM WMI object..."	
            $oTPM = Get-WmiObject -Class "Win32_Tpm" -Namespace "ROOT\CIMV2\Security\MicrosoftTpm"
             
            Write-Output "Clearing TPM ownership....."
            $tmp = $oTPM.SetPhysicalPresenceRequest(5)
            If ($tmp.ReturnValue -eq 0) {
                Write-Output "Successfully cleared the TPM chip. A reboot is required."
                
            } 
            Else {
                Write-Warning "Failed to clear TPM ownership. Exiting..."
            }
        }
        switch ($Model) {
            "Latitude E7440" {
                Write-Output "Dell requires the CCTK for BIOS modifications, will install needed components"

                #Installing HAPI components
                $InstallerName = "HAPI\hapint64.exe"
                $InstallSwitches = "-i -K CCTK -p " + '"' + "$SOURCEROOT\HAPI" + '"'
                Write-Output "Starting install $InstallerName with: $SOURCEROOT\$InstallerName $InstallSwitches"
                $ExitCode = Invoke-Exe -Executable $SOURCEROOT\$InstallerName -Arguments $InstallSwitches
                Write-Output "Finsihed installing $InstallerName with exitcode $ExitCode"
                Get-TSxExitCode -ExitCode $ExitCode

                #Set Locations settings
                $CurrentLocation = (Get-Location).Path
                Set-Location $SOURCEROOT

                #Get current settings
                Write-Output ""
                Write-Output "Current settings"
                $tpm = .\cctk.exe --tpm
                $tpmactivation = .\cctk.exe --tpmactivation
                $tpmppiacpi =.\cctk.exe --tpmppiacpi
                $tpmppidpo = .\cctk.exe --tpmppidpo
                $tpmppipo = .\cctk.exe --tpmppipo
                Write-Output "TPM State: $(($tpm).Split("=")[1])"
                Write-Output "TPM Activation: $(($tpmactivation).Split("=")[1])"
                Write-Output "TPM Physical Precense API: $(($tpmppiacpi).Split("=")[1])"
                Write-Output "TPM Physical Precense deprovision: $(($tpmppidpo).Split("=")[1])"
                Write-Output "TPM Phyiscal Precense provision: $(($tpmppipo).Split("=")[1])"
        
                #Setting BIOS settings
                Write-Output "Configuring BIOS"
                $ExitCode = Invoke-Exe $SOURCEROOT\cctk.exe -Arguments "--setuppwd=Password01"
                Get-xTSDellExitCode -ExitCode $ExitCode
                $ExitCode = Invoke-Exe $SOURCEROOT\cctk.exe -Arguments "--tpm=on --valsetuppwd=Password01"
                Get-xTSDellExitCode -ExitCode $ExitCode
                $ExitCode = Invoke-Exe $SOURCEROOT\cctk.exe -Arguments "--tpmactivation=activate --valsetuppwd=Password01"
                Get-xTSDellExitCode -ExitCode $ExitCode
                $ExitCode = Invoke-Exe $SOURCEROOT\cctk.exe -Arguments "--tpmppiacpi=enable --valsetuppwd=Password01"
                Get-xTSDellExitCode -ExitCode $ExitCode
                $ExitCode = Invoke-Exe $SOURCEROOT\cctk.exe -Arguments "--tpmppidpo=enable --valsetuppwd=Password01"
                Get-xTSDellExitCode -ExitCode $ExitCode
                $ExitCode = Invoke-Exe $SOURCEROOT\cctk.exe -Arguments "--tpmppipo=enable --valsetuppwd=Password01"
                Get-xTSDellExitCode -ExitCode $ExitCode
                $ExitCode = Invoke-Exe $SOURCEROOT\cctk.exe -Arguments "--setuppwd= --valsetuppwd=Password01"
                Get-xTSDellExitCode -ExitCode $ExitCode

                #Verify settings
                Write-Output ""
                Write-Output "Verifying settings"
                $tpm = .\cctk.exe --tpm
                $tpmactivation = .\cctk.exe --tpmactivation
                $tpmppiacpi =.\cctk.exe --tpmppiacpi
                $tpmppidpo = .\cctk.exe --tpmppidpo
                $tpmppipo = .\cctk.exe --tpmppipo
                Write-Output "TPM State: $(($tpm).Split("=")[1])"
                Write-Output "TPM Activation: $(($tpmactivation).Split("=")[1])"
                Write-Output "TPM Physical Precense API: $(($tpmppiacpi).Split("=")[1])"
                Write-Output "TPM Physical Precense deprovision: $(($tpmppidpo).Split("=")[1])"
                Write-Output "TPM Phyiscal Precense provision: $(($tpmppipo).Split("=")[1])"
                Set-Location $CurrentLocation
            }
            Default {
                Write-Output "Running in default mode"
                Write-Output "Dell requires the CCTK for BIOS modifications, will install needed components"

                #Installing HAPI components
                $InstallerName = "HAPI\hapint64.exe"
                $InstallSwitches = "-i -K CCTK -p " + '"' + "$SOURCEROOT\HAPI" + '"'
                Write-Output "Starting install $InstallerName with: $SOURCEROOT\$InstallerName $InstallSwitches"
                $ExitCode = Invoke-Exe -Executable $SOURCEROOT\$InstallerName -Arguments $InstallSwitches
                Write-Output "Finsihed installing $InstallerName with exitcode $ExitCode"
                Get-TSxExitCode -ExitCode $ExitCode

                #Set Locations settings
                $CurrentLocation = (Get-Location).Path
                Set-Location $SOURCEROOT

                #Get current settings
                Write-Output ""
                Write-Output "Current settings"
                $tpm = .\cctk.exe --tpm
                $tpmactivation = .\cctk.exe --tpmactivation
                $tpmppiacpi =.\cctk.exe --tpmppiacpi
                $tpmppidpo = .\cctk.exe --tpmppidpo
                $tpmppipo = .\cctk.exe --tpmppipo
                Write-Output "TPM State: $(($tpm).Split("=")[1])"
                Write-Output "TPM Activation: $(($tpmactivation).Split("=")[1])"
                Write-Output "TPM Physical Precense API: $(($tpmppiacpi).Split("=")[1])"
                Write-Output "TPM Physical Precense deprovision: $(($tpmppidpo).Split("=")[1])"
                Write-Output "TPM Phyiscal Precense provision: $(($tpmppipo).Split("=")[1])"
        
                #Setting BIOS settings
                Write-Output "Configuring BIOS"
                $ExitCode = Invoke-Exe $SOURCEROOT\cctk.exe -Arguments "--setuppwd=Password01"
                Get-xTSDellExitCode -ExitCode $ExitCode
                $ExitCode = Invoke-Exe $SOURCEROOT\cctk.exe -Arguments "--tpm=on --valsetuppwd=Password01"
                Get-xTSDellExitCode -ExitCode $ExitCode
                $ExitCode = Invoke-Exe $SOURCEROOT\cctk.exe -Arguments "--tpmactivation=activate --valsetuppwd=Password01"
                Get-xTSDellExitCode -ExitCode $ExitCode
                $ExitCode = Invoke-Exe $SOURCEROOT\cctk.exe -Arguments "--tpmppiacpi=enable --valsetuppwd=Password01"
                Get-xTSDellExitCode -ExitCode $ExitCode
                $ExitCode = Invoke-Exe $SOURCEROOT\cctk.exe -Arguments "--tpmppidpo=enable --valsetuppwd=Password01"
                Get-xTSDellExitCode -ExitCode $ExitCode
                $ExitCode = Invoke-Exe $SOURCEROOT\cctk.exe -Arguments "--tpmppipo=enable --valsetuppwd=Password01"
                Get-xTSDellExitCode -ExitCode $ExitCode
                $ExitCode = Invoke-Exe $SOURCEROOT\cctk.exe -Arguments "--setuppwd= --valsetuppwd=Password01"
                Get-xTSDellExitCode -ExitCode $ExitCode

                #Verify settings
                Write-Output ""
                Write-Output "Verifying settings"
                $tpm = .\cctk.exe --tpm
                $tpmactivation = .\cctk.exe --tpmactivation
                $tpmppiacpi =.\cctk.exe --tpmppiacpi
                $tpmppidpo = .\cctk.exe --tpmppidpo
                $tpmppipo = .\cctk.exe --tpmppipo
                Write-Output "TPM State: $(($tpm).Split("=")[1])"
                Write-Output "TPM Activation: $(($tpmactivation).Split("=")[1])"
                Write-Output "TPM Physical Precense API: $(($tpmppiacpi).Split("=")[1])"
                Write-Output "TPM Physical Precense deprovision: $(($tpmppidpo).Split("=")[1])"
                Write-Output "TPM Phyiscal Precense provision: $(($tpmppipo).Split("=")[1])"
                Set-Location $CurrentLocation
            }
        }
    }
    Default {
        $Model = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty Model
        Write-Output "Model is currently: $Model"
        Write-Output "This models does not have scripted support for BIOS settings."
    }
}

#Stop Transcript logging
. Stop-Logging