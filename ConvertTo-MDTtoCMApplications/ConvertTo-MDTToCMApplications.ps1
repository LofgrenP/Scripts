<#
Created:    2018-06-25
Updated:    2018-06-25
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
param (
    [Parameter(Mandatory=$true)]
    $MDTRoot = "C:\MDTBuildLab",

    [Parameter(Mandatory=$True)]
    $CMContentLocation =  "\\cm01.corp.viamonstra.com\Sources$\Software"
)
try {
    #Import MDT module
    Import-Module "C:\Program Files\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1" -ErrorAction Stop
    New-PSDrive -Name "DS001" -PSProvider MDTProvider -Root $MDTRoot -ErrorAction Stop

    #Import ConfigMgr Module
    $CMModule = $env:SMS_ADMIN_UI_PATH.Substring(0, $env:SMS_ADMIN_UI_PATH.Length - 5) + "\ConfigurationManager.psd1"
    Import-Module $CMModule -ErrorAction Stop
    $Drive = (Get-PSDrive -PSProvider CMSite -ErrorAction Stop).Name
    Set-Location $($Drive + ":")
}
Catch {
    Write-Error "Failed stuff, troubleshoot please!"
}


$Applications = Get-ChildItem -Path DS001:\Applications
foreach ($Application in $Applications) { 
    $ApplicationInfo = Get-ItemProperty -Path DS001:\Applications\$($Application.Name)
    #Create application
    New-CMApplication `
    -Name $ApplicationInfo.ShortName `
    -Publisher $ApplicationInfo.Publisher `
    -SoftwareVersion $ApplicationInfo.Version `
    -LocalizedName $ApplicationInfo.ShortName `
    -AutoInstall $true
    
    #Copy content
    $CMAppContentLocation = "$CMContentLocation\$($ApplicationInfo.ShortName)"
    RoboCopy "$MDTRoot\$($ApplicationInfo.Source)" $CMAppContentLocation /MIR
    
    #Create detectionmethod
    $ScriptBlock = @"
try {
    `$Version = (Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$($ApplicationInfo.ShortName) -Name DisplayVersion -ErrorAction Stop).DisplayVersion
}
Catch {
    `$Version = "NA"
}
switch (`$Version) {
    "NA" { return `$false }
    Default { return `$true }
}
"@

    #Create deploymenttype
    Add-CMScriptDeploymentType `
    -ContentLocation $CMAppContentLocation `
    -DeploymentTypeName "$($ApplicationInfo.ShortName) - Script" `
    -InstallCommand $ApplicationInfo.CommandLine `
    -ApplicationName $($ApplicationInfo.ShortName) `
    -ScriptLanguage PowerShell `
    -ScriptText $ScriptBlock `
    -LogonRequirementType WhetherOrNotUserLoggedOn `
    -UserInteractionMode Hidden `
    -InstallationBehaviorType InstallForSystem
}