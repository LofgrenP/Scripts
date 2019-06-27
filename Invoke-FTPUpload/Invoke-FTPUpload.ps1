<#
Created:    2019-06-27
Author :    Peter Lofgren
Twitter:    @LofgrenPeter
Blog   :    http://syscenramblings.wordpress.com

Disclaimer:
This script is provided "AS IS" with no warranties, confers no rights and
is not supported by the author

Updates
1.0 - (2019-06-27) Initial release

License:

The MIT License (MIT)

Copyright (c) 2019 Peter Lofgren

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
    # Sepcifiy the source director for files to upload
    [Parameter(Mandatory = $true, Position = 0)]
    [string]
    $Source = "C:\MyFiles",

    # Specify FTP address, format ftp://ftp.viamonstra.com/
    # note the trailing /
    [Parameter(Mandatory = $true, Position = 1)]
    [string]
    $FTPSite = "ftp://ftp.viamonstra.com/",

    # Parameter help description
    [Parameter(Mandatory = $true, Position = 2)]
    [string]
    $UserName = "ftpuser@viamonstra.com",

    # Parameter help description
    [Parameter(Mandatory = $false, Position = 3)]
    [string]
    $Password = 'P@ssw0rd'
)

#Create Webclient
try {
    $webclient = New-Object System.Net.WebClient -ErrorAction Stop
}
Catch {
    Write-Output "Failed to create system.net.webclient"
    Exit 1
}
#Connect to
try {
    $webclient.Credentials = New-Object System.Net.NetworkCredential($UserName, $Password)  -ErrorAction Stop
}
Catch {
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    Write-Output "ErrorMsg: $ErrorMessage"
    Write-Output "Failed: $FailedItem"
}

#Get source files and upload to FTP server
foreach ($item in (Get-ChildItem -path $Source)) {
    "Uploading $item..."
    try {
        $uri = New-Object System.Uri($FTPSite + $item.Name) -ErrorAction Stop
        $webclient.UploadFile($uri, $item.FullName)
    }
    Catch {
        $UploadErrorMsg = $_.Exception.Message
        Write-Output "Failed to upload file $($item.name) with error: $UploadErrorMsg"
    }
}