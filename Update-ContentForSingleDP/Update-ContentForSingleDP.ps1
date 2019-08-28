<#
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
<#
.SYNOPSIS
	Redistribute failed packages for specified DP

.DESCRIPTION
    The script will check specified DP for packages that has failed according to summarizer events and redist any failed packages.

.PARAMETER Sitecode
	Enter SiteCode

.PARAMETER DPFQDN
    Enter FQDN for DP with failed packages.

.EXAMPLE
	Update-ContentForSingleDP.ps1 -SiteCode PS1 -DPFQDN cmdp01.corp.viamonstra.com

.NOTES
    FileName:    Update-ContentForSingleDP.ps1
    Author:      Peter Löfgren
    Contact:     @LofgrenPeter
    Created:     2018-03-01
    Updated:     2018-03-01

    Version history:
    1.0.0 - (2018-03-01) Script created
    1.1.0 - (2019-08-28) Updated for faster detection logic, thanks @jarwidmark

#>

param (
    [Parameter(Mandatory = $true)]
    [ValidateNotnullorEmpty()]
    $SiteCode,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $DPFQDN

)

$failures = Get-WmiObject -Namespace root\sms\site_$SiteCode -Query "select * from SMS_PackageStatusDistPointsSummarizer where State='1' and SourceNALPath like '%$DPFQDN%'"
foreach ($Failure in $Failures) {
    $PackageID = $Failure.PackageID
    Write-Output "Failed PackageID: $PackageID"
    $DP = Get-WmiObject -Namespace root\sms\site_$SiteCode -Class sms_distributionpoint | Where-Object ServerNalPath -match $DPFQDN | Where-Object PackageID -EQ $PackageID
    $DP.RefreshNow = $true
    $DP.put()
}
