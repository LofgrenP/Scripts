<#
Created:    2018-09-11
Updated:    2018-09-11
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
Param (
    [Parameter(Mandatory=$False,Position=0)]
    [ValidateScript({Test-Path -Path $_})]
    $ReportPath = "C:\Script",

    [Parameter(Mandatory=$False,Position=1)]
    $ComputerName,
    
    [Parameter(Mandatory=$False,Position=2)]
    [Int]$Days = 7
)



#Set the Basics
$htmlreport = @()
$htmlbody = @()
$spacer = "<br />"

#Set the header for the html report
$subhead = "<h3>Logon Information</h3>"
$htmlbody += $subhead

#Get the raw events
if ([string]::IsNullOrEmpty($ComputerName)) {
   try {
       if ($Days -eq 0) { 
            $Events = Get-WinEvent -FilterHashtable @{LogName='Security';ID='4625'}
       }
       Else {
            $StartTime = (Get-Date).AddDays(-$Days)
            $Events = Get-WinEvent -FilterHashtable @{LogName='Security';ID='4625';StartTime=$StartTime}
       }
   }
   Catch {
       Write-Warning $_.Exception.Message
       $htmlbody += "<p>Failed to get events from eventlog</p>"
       $htmlbody += "<p>An error was encountered. $($_.Exception.Message)</p>"
       $htmlbody += $spacer
       Break
   }
}
Else {
    try {
        if ($Days -eq 0) { 
             $Events = Get-WinEvent -ComputerName $ComputerName -FilterHashtable @{LogName='Security';ID='4625'}
        }
        Else {
             $StartTime = (Get-Date).AddDays(-$Days)
             $Events = Get-WinEvent -ComputerName $ComputerName -FilterHashtable @{LogName='Security';ID='4625';StartTime=$StartTime}
        }
    }
    Catch {
        Write-Warning $_.Exception.Message
        $htmlbody += "<p>Failed to get events from eventlog</p>"
        $htmlbody += "<p>An error was encountered. $($_.Exception.Message)</p>"
        $htmlbody += $spacer
        Break
    }
}

#Convert events to XML and create the hashtable
$Result = Foreach ($event in $Events) {
    [xml]$XMLEvent = $Event.ToXml()
    $Hash = [Ordered]@{ 
        Created = $XMLEvent.Event.System.TimeCreated.SystemTime | Get-Date
        SecurityID = $XMLEvent.Event.EventData.Data[0].'#text'
        UserDomain = $XMLEvent.Event.EventData.Data[6].'#text'
        UserName = $XMLEvent.Event.EventData.Data[5].'#text'
        WorkstationName = $XMLEvent.Event.EventData.Data[13].'#text'
        FailureReason = $(
            Switch ($XMLEvent.Event.EventData.Data[8].'#text') {
                "%%2313" { "Unknown user name or bad password." }
                Default { $XMLEvent.Event.EventData.Data[8].'#text' }
            }
        )
    }
    $AuditData = New-Object PSobject -Property $Hash
    $AuditData
}

$UserNames = $Result | Select-Object -Property UserName -Unique -ExpandProperty UserName
$ResultData = foreach ($UserName in $UserNames) {
    $DataObjects = $Result | Where-Object -Property UserName -EQ $UserName | Sort-Object Created
    $Count = 1
    foreach ($DataObject in $DataObjects) {
        $Hash = [Ordered]@{
            Created = $DataObject.Created
            SecurityID = $DataObject.SecurityID
            UserDomain = $DataObject.UserDomain
            UserName = $DataObject.UserName
            WorkstationName = $DataObject.WorkstationName
            FailureReason = $DataObject.FailureReason
            Count = $Count
        }
        $Count++
        $OutPutData = New-Object psobject -Property $Hash
        $OutPutData
    }
}

#Generate the HTML body
$htmlbody += $ResultData | Sort-Object -Property Created -Descending | ConvertTo-Html -Fragment
$htmlbody += $spacer



#------------------------------------------------------------------------------
# Generate the HTML report and output to file
$reportime = Get-Date

#Common HTML head and styles
$htmlhead="<html>
            <style>
            BODY{font-family: Arial; font-size: 8pt;}
            H1{font-size: 20px;}
            H2{font-size: 18px;}
            H3{font-size: 16px;}
            H4{font-size: 14px;}
            TABLE{border: 1px solid black; border-collapse: collapse; font-size: 8pt;}
            TH{border: 1px solid black; background: #dddddd; padding: 5px; color: #000000;}
            TD{border: 1px solid black; background: #ADD8E6; padding: 5px; color: #000000;}
            td.pass{background: #7FFF00;}
            td.warn{background: #FFE600;}
            td.fail{background: #FF0000; color: #ffffff;}
            td.info{background: #85D4FF;}
            </style>
            <body>
            <h1 align=""center"">Logon Information</h1>
            <h3 align=""center"">Generated: $reportime</h3>"
$htmltail = "</body>
        </html>"

$htmlreport = $htmlhead + $htmlbody + $htmltail

$htmlfile = "$ReportPath" + "\LogonInformation.html"
$htmlreport | Out-File $htmlfile -Encoding Utf8 -Force

#------------------------------------------------------------------------------
# Generate the CSV report and output to file
$ResultData | Sort-Object -Property Created -Descending | Export-Csv -Path "$ReportPath\LogonInformation.csv" -NoTypeInformation -Force