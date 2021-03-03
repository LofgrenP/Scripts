<#
.SYNOPSIS

.DESCRIPTION

.LINK
    http://syscenramblings.wordpress.com
.NOTES
    FileName: Enable-WoL.ps1
    Author: Peter Lofgren
    Contact: @Lofgren Peter
    Created: 2021-03-02

    Version - 0.0.1 - 2021-03-02
    Version - 0.0.2 - 2021-03-03

    License Info:
    MIT License
    Copyright (c) 2021 TRUESEC

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


.EXAMPLE

#>

[cmdletbinding()]
param()
begin {}
process {

    #Disable Windows 10 Fast Startup
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value "0" -PropertyType dword -Force

    #Balanced Power Plan AC Sleep Timeout
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\238C9FA8-0AAD-41ED-83F4-97BE242C8F20\7bc4a2f9-d8fc-4469-b07b-33eb785aaca0\DefaultPowerSchemeValues\381b4222-f694-41f0-9685-ff5bb260df2e" -Name AcSettingIndex -Value 3600 -PropertyType DWORD -Force

    #Balanced Power Plan DC Sleep Timeout
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\238C9FA8-0AAD-41ED-83F4-97BE242C8F20\7bc4a2f9-d8fc-4469-b07b-33eb785aaca0\DefaultPowerSchemeValues\381b4222-f694-41f0-9685-ff5bb260df2e" -Name DcSettingIndex -Value 3600 -Force

    #High Performance Power Plan AC Sleep Timeout
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\238C9FA8-0AAD-41ED-83F4-97BE242C8F20\7bc4a2f9-d8fc-4469-b07b-33eb785aaca0\DefaultPowerSchemeValues\8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" -Name AcSettingIndex -Value 3600 -Force 

    #High Performance Plan DC Sleep Timeout
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\238C9FA8-0AAD-41ED-83F4-97BE242C8F20\7bc4a2f9-d8fc-4469-b07b-33eb785aaca0\DefaultPowerSchemeValues\8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" -Name DcSettingIndex -Value 3600 -Force

    #Power Saver Power Plan AC Sleep Timeout
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\238C9FA8-0AAD-41ED-83F4-97BE242C8F20\7bc4a2f9-d8fc-4469-b07b-33eb785aaca0\DefaultPowerSchemeValues\a1841308-3541-4fab-bc81-f71556f20b4a" -Name AcSettingIndex -Value 3600 -Force 

    #Power Saver Plan DC Sleep Timeout
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\238C9FA8-0AAD-41ED-83F4-97BE242C8F20\7bc4a2f9-d8fc-4469-b07b-33eb785aaca0\DefaultPowerSchemeValues\a1841308-3541-4fab-bc81-f71556f20b4a" -Name DcSettingIndex -Value 3600 -Force

    #Configure Energy Efficient Ethernet
    $FindEEELinkAd = Get-ChildItem "hklm:\SYSTEM\ControlSet001\Control\Class" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { Get-ItemProperty $_.pspath } -ErrorAction SilentlyContinue | Where-Object { $_.EEELinkAdvertisement } -ErrorAction SilentlyContinue
    If ($FindEEELinkAd.EEELinkAdvertisement -eq 1) {
        Set-ItemProperty -Path $FindEEELinkAd.PSPath -Name EEELinkAdvertisement -Value 0
        # Check again
        $FindEEELinkAd = Get-ChildItem "hklm:\SYSTEM\ControlSet001\Control\Class" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { Get-ItemProperty $_.pspath } | Where-Object { $_.EEELinkAdvertisement }
        If ($FindEEELinkAd.EEELinkAdvertisement -eq 1) {
            Write-Output "$($env:computername) - ERROR - EEELinkAdvertisement set to $($FindEEELinkAd.EEELinkAdvertisement)"
        }
        Else {
            Write-Output "$($env:computername) - SUCCESS - EEELinkAdvertisement set to $($FindEEELinkAd.EEELinkAdvertisement)"
        }
    }
    Else {
        Write-Output "EEELinkAdvertisement is already turned OFF"
    }

    #Configure Generic NIC WOL Setting
    $nic = Get-NetAdapter | Where-Object { ($_.MediaConnectionState -eq "Connected") -and (($_.name -like "Ethernet*") -or ($_.name -match "local area connection")) }
    $nicPowerWake = Get-WmiObject MSPower_DeviceWakeEnable -Namespace root\wmi | Where-Object { $_.instancename -match [regex]::escape($nic.PNPDeviceID) }
    If ($nicPowerWake.Enable -eq $true) {
        # All good here
        Write-Output "MSPower_DeviceWakeEnable is TRUE"
    }
    Else {
        Write-Output "MSPower_DeviceWakeEnable is FALSE. Setting to TRUE..."
        $nicPowerWake.Enable = $True
        $nicPowerWake.psbase.Put()
    }

    #Configure NIC Magic Package Setting
    $nic = Get-NetAdapter | Where-Object { ($_.MediaConnectionState -eq "Connected") -and (($_.name -like "Ethernet*") -or ($_.name -match "local area connection")) }
    $nicMagicPacket = Get-WmiObject MSNdis_DeviceWakeOnMagicPacketOnly -Namespace root\wmi | Where-Object { $_.instancename -match [regex]::escape($nic.PNPDeviceID) }
    If ($nicMagicPacket.EnableWakeOnMagicPacketOnly -eq $true) {
        Write-Output "EnableWakeOnMagicPacketOnly is TRUE"
    }
    Else {
        Write-Output "EnableWakeOnMagicPacketOnly is FALSE. Setting to TRUE..."
        $nicMagicPacket.EnableWakeOnMagicPacketOnly = $True
        $nicMagicPacket.psbase.Put()
    } 
}