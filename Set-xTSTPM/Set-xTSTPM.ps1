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

[CMDLETBINDING()]
Param (

)

$Make = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty Manufacturer
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
    }
}