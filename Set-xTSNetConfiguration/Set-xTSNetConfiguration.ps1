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
	Set networkadapter IPs based of XML file and name
	
.DESCRIPTION
    The script will determine static IP addresses to use based of computername and information in xml settings file.
	
.PARAMETER Path
	Set a path to the xml file.

.EXAMPLE
	Set-xTSNetConfiguration.ps1 -Path .\NetConfiguration.xml
	
.NOTES
    FileName:    Set-xTSNetConfiguration.ps1
    Author:      Peter Löfgren
    Contact:     @LofgrenPeter
    Created:     2017-12-28
    Updated:     2018-01-12
	
    Version history:
    1.0.0 - (2017-12-28) Script created
    1.0.1 - (2018-01-12) Bugfix for ipranges starting with same number.
    1.1.0 - (2018-01-23) Added task sequence integration and ConfigMgr Logging.
    1.2.0 - (2018-01-29) Fixed unhandled error in clearing gateway
    1.3.0 - (2018-02-01) Added features to disable IPv6
    1.4.0 - (2018-02-16) Added network metric cabailites
    1.5.0 - (2018-02-16) Added options to disable dns registration
    1.5.1 - (2018-02-20) Added option to reenable dns registration and metric

#>

param (
    [Parameter(Mandatory=$false)]
    $Path = ".\NetConfiguration.xml"
)

begin {

}
Process {
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
            Else {
                $Logpath = $env:TEMP
                $LogFile = $Logpath + "\" + "$LogName.log"
            }
        }
    }
    Function Start-Logging{
        Start-Transcript -path $LogFile -Force
    }
    Function Stop-Logging{
        Stop-Transcript
    }
    # Set Vars
    $SCRIPTDIR = split-path -parent $MyInvocation.MyCommand.Path
    $SCRIPTNAME = split-path -leaf $MyInvocation.MyCommand.Path
    $LogName = $SCRIPTNAME

    #Try to Import SMSTSEnv
    . Import-SMSTSENV

    #Start Transcript Logging
    . Start-Logging

    #Output base info
    Write-Output ""
    Write-Output "$SCRIPTNAME - ScriptDir: $ScriptDir"
    Write-Output "$SCRIPTNAME - SourceRoot: $SOURCEROOT"
    Write-Output "$SCRIPTNAME - ScriptName: $ScriptName"
    Write-Output "$SCRIPTNAME - Integration with MDT(LTI/ZTI): $MDTIntegration"
    Write-Output "$SCRIPTNAME - Log: $LogFile"
    Write-Output "$SCRIPTNAME - XML Path: $Path"

   If (-not(Test-Path $Path)) {
        Write-Warning "XML File not found, check path: $Path"
        Exit 1
    }

    [xml]$XMLContent = Get-Content -Path $Path

    #Verify Computername is in XML file
    $ComputerName = $env:COMPUTERNAME

    if ($($XMLContent.xml.Computer | Where-Object Name -eq $computerName | Measure-Object).Count -eq 1) {
        Write-Output "$SCRIPTNAME - Found computer $computerName"
        $LastIP = $($XMLContent.xml.Computer | Where-Object Name -eq $computerName).Ip
    }
    Else {
        Write-Warning "$SCRIPTNAME - No Computer found exiting"
        break
    }

    #Find all adapters
    Foreach ($NetworkRange in $XMLContent.xml.networkrange) {
        Write-Output "$SCRIPTNAME - Working on range: $($NetworkRange.name)"
        #Check each network rang in the xml file
            Foreach ($NetAdapter in $(Get-NetAdapter -Physical)) {
            Write-Output "$SCRIPTNAME - Working on Adapter: $($NetAdapter.Name)"
            $IpAddress = $NetAdapter | Get-NetIPAddress -AddressFamily IPv4 | Select-Object -Unique
            #Match current network address with range in xmlfile
        
            $SplitIP = $IpAddress.IPAddress.Split(".")
            $SplitIP = $SplitIP[0] + "." + $SplitIP[1] + "." + $SplitIP[2]
            If ($SplitIP -match "$($NetworkRange.Subnet)$") {
                Write-Output "$SCRIPTNAME - Found IP Match, clearing existing configuration"
                #Clear current configuration
                Remove-NetIPAddress -InterfaceIndex $NetAdapter.InterfaceIndex -Confirm:$false
                try {
                    $ClearGateway = Remove-NetRoute -InterfaceIndex $NetAdapter.InterfaceIndex -DestinationPrefix 0.0.0.0/0 -Confirm:$false -ErrorAction Stop
                }
                catch {
                    Write-Output "$SCRIPTNAME - No Gateway found, clear unneded"
                }
                #Input new configuration for netadapter
                if ($NetworkRange.Gateway -eq "") {
                    Write-Output "$SCRIPTNAME - Seting IP without Default Gateway"
                    New-NetIPAddress -IPAddress "$($NetworkRange.Subnet + "." + $LastIP)" -InterfaceIndex $NetAdapter.InterfaceIndex -PrefixLength $NetworkRange.Length | Out-Null
                    Set-DnsClientServerAddress -InterfaceIndex $NetAdapter.InterfaceIndex -ServerAddresses $NetworkRange.DNSPri,$NetworkRange.DNSSec
                    if ($NetworkRange.DisableIPv6 -eq "True") {
                        Disable-NetAdapterBinding -InterfaceAlias $NetAdapter.InterfaceAlias –ComponentID ms_tcpip6
                    }
                    if ($NetworkRange.NetworkMetric -ne 0) {
                        Set-NetIPInterface -InterfaceIndex $NetAdapter.InterfaceIndex -InterfaceMetric $NetworkRange.NetworkMetric
                    }
                    If ($NetworkRange.NetworkMetrix -eq 0) {
                        Set-NetIPInterface -InterfaceIndex $NetAdapter.InterfaceIndex -AutomaticMetric Enabled
                    }
                    if ( $NetworkRange.RegisterInDNS -eq "False") {
                        Get-NetAdapter -InterfaceIndex $NetAdapter.InterfaceIndex | Set-DnsClient -RegisterThisConnectionsAddress $false
                    }
                    if ( $NetworkRange.RegisterInDNS -eq "True") {
                        Get-NetAdapter -InterfaceIndex $NetAdapter.InterfaceIndex | Set-DnsClient -RegisterThisConnectionsAddress $true
                    }
                    $NetAdapter | Rename-NetAdapter -NewName $NetworkRange.name -ErrorAction SilentlyContinue
                }
                Else {
                    Write-Output "$SCRIPTNAME - Setting IP with Default Gateway"
                    New-NetIPAddress -IPAddress "$($NetworkRange.Subnet + "." + $LastIP)" -DefaultGateway $NetworkRange.Gateway -InterfaceIndex $NetAdapter.InterfaceIndex -PrefixLength $NetworkRange.Length | Out-Null
                    Set-DnsClientServerAddress -InterfaceIndex $NetAdapter.InterfaceIndex -ServerAddresses $NetworkRange.DNSPri,$NetworkRange.DNSSec
                    if ($NetworkRange.DisableIPv6 -eq "True") {
                        Disable-NetAdapterBinding -InterfaceAlias $NetAdapter.InterfaceAlias –ComponentID ms_tcpip6
                    }
                    if ($NetworkRange.NetworkMetric -ne 0) {
                        Set-NetIPInterface -InterfaceIndex $NetAdapter.InterfaceIndex -InterfaceMetric $NetworkRange.NetworkMetric
                    }
                    If ($NetworkRange.NetworkMetrix -eq 0) {
                        Set-NetIPInterface -InterfaceIndex $NetAdapter.InterfaceIndex -AutomaticMetric Enabled
                    }
                    if ( $NetworkRange.RegisterInDNS -eq "False") {
                        Get-NetAdapter -InterfaceIndex $NetAdapter.InterfaceIndex | Set-DnsClient -RegisterThisConnectionsAddress $false
                    }
                    if ( $NetworkRange.RegisterInDNS -eq "True") {
                        Get-NetAdapter -InterfaceIndex $NetAdapter.InterfaceIndex | Set-DnsClient -RegisterThisConnectionsAddress $true
                    }
                    $NetAdapter | Rename-NetAdapter -NewName $NetworkRange.name -ErrorAction SilentlyContinue
                }
            }
            #Output simple no match data
            Else {
                Write-Output "$SCRIPTNAME - No IP Match, skipping"
            }
        }
    }

    #Stop Logging
    . Stop-Logging
}