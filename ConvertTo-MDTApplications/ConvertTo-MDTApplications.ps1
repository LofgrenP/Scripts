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
    $MDTRoot = "C:\MDTBuildLab"
)
try {
    Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1) -ErrorAction Stop
    Import-Module "C:\Program Files\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1" -ErrorAction Stop
    New-PSDrive -Name "DS001" -PSProvider MDTProvider -Root $MDTRoot -ErrorAction Stop
    Set-Location "$((Get-PSDrive -PSProvider CMSite).Name):" -ErrorAction Stop
}
Catch {
    Write-Error "Failed stuff, troubleshoot please!"
}

#Get CM Applications
$CMApplications = Get-CMApplication
Write-Output "Found $(($CMApplications | Measure-Object).Count) applications"
Foreach ($CMApplication in $CMApplications) {
    #Get Local CM Application Name
    $CMAppDeploymentTypes = Get-CMDeploymentType -ApplicationName $CMApplication.LocalizedDisplayName
    Write-Output "Found $(($CMAppDeploymentTypes | Measure-Object).Count) deployment types"
    foreach ($CMAppDeploymentType in $CMAppDeploymentTypes) {
        [xml]$CMAPPDTXML = $CMAppDeploymentType.SDMPackageXML
        $CommandLine = ($CMAPPDTXML.AppMgmtDigest.DeploymentType.Installer.InstallAction.Args.Arg | Where-Object -Property Name -eq InstallCommandLine)."#text"
        $ContentLocation = $CMAPPDTXML.AppMgmtDigest.DeploymentType.Installer.Contents.Content.Location
        Write-Output "Adding applications to MDT"
        Import-MDTApplication -path "DS001:\Applications" -enable "True" -Name $CMApplication.LocalizedDisplayName -ShortName $CMApplication.LocalizedDisplayName -Version $CMApplication.SoftwareVersion -Publisher "" -Language "" -CommandLine $CommandLine -WorkingDirectory $ContentLocation -NoSource
    }

}