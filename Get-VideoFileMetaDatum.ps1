<# Get video file data #>
<# NOTE: you will see errors for line 19 when retrieving  #>
<#       getDetailsOf() for greater than item 200 (or so) #>

Function Get-FileMetaData
{
    <# The parameter is a string array #>
	Param([string[]]$folder)

	foreach($sFolder in $folder)
	{
		$a = 0
		$objShell = New-Object -ComObject Shell.Application
		$objFolder = $objShell.namespace($sFolder)
		foreach ($File in $objFolder.items())
		{
			$FileMetaData = New-Object PSOBJECT
			for ($a ; $a -le 512; $a++)
			{
                <# Skip problematic properties #>
                if ($a -eq 291) { $a++ }
				if($objFolder.getDetailsOf($File, $a))
				{
					<# The replace filters out '?' characters that come with the data #>
					$hash += @{
                        $($objFolder.getDetailsOf($objFolder.items, $a)) =
					        $($objFolder.getDetailsOf($File, $a)) -replace([char]8206,"") -replace([char]8207,"")  

                    } # Comment
				    $FileMetaData | Add-Member $hash
				    $hash.clear()
			    } #end if
		    } #end for

			$a=0
			$FileMetaData
		} #end foreach $file
	} #end foreach $sfolder
} #end Get-FileMetaData



<#
    Entry point to this script.
    $pwd (print working directory)

    Specify a hard coding place:
    $env:USERPROFILE\desktop

    Turn PowerShell ISE on (set trace to 0 to turn off)
    Set-PSDebug -Trace 2 

    Export an object to a dynamic view; a .CSV file; an HTML file :
    $PSobject | Out-GridView
    $PSobject | Export-csv .\exportfile.csv
    $PSobject | ConvertTo-HTML | Out-File .\serv.htm
#>

$picdata = Get-FileMetaData $pwd |
    select name, title,length,"Frame height",'Frame width','Frame rate','Bit rate', 'Data rate',Size,Year,Comments,Type
$picdata | Out-GridView
$picdata | Export-csv .\exportfile.csv
$picdata | ConvertTo-HTML | Out-File .\serv.htm


# SIG # Begin signature block
# MIIFugYJKoZIhvcNAQcCoIIFqzCCBacCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU/3j7vq4WcEE6TGPoIUlrI3/1
# mzqgggNPMIIDSzCCAjOgAwIBAgIQQ4UFNLMDcZFJWPkWb5NCqDANBgkqhkiG9w0B
# AQsFADAgMR4wHAYDVQQDDBV3d3cudGllcm5leXZpc2lvbi5jb20wHhcNMTcwNTA1
# MTkyNDA2WhcNMTgwNTA1MTk0NDA2WjAgMR4wHAYDVQQDDBV3d3cudGllcm5leXZp
# c2lvbi5jb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCi8uwq0osm
# RQjKgk2vdG2R1l0foVBIKx5em+G+j0jvx2ZZ3NSZA6vI4dBiaIv1pesXJMO90lK0
# EZszkwYYG/LisUpbzrathWleloI70MC7atov/SaSW1I5toU1K5yLKp3czqC50eJP
# 57Why1t03zCCdo64ywrGlsAtzgbtpc/KGOcTv4iWic/1wLN2OZb5LC73ZzPrYJoR
# LC5KwANHowJpr8O3CSLT2p60cTp4S2Vfjg/9vuvsgQIX2BmBYOdPTV9HzTKKvaoF
# 0Gy/a4o1eiqQ49Wm597krhsGZQ9soh0+mwvc/aw8sL6xzHC/nxOliLsaFkIfJnq6
# h48xO/BDwQaRAgMBAAGjgYAwfjAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYI
# KwYBBQUHAwMwOAYDVR0RBDEwL4IVd3d3LnRpZXJuZXl2aXNpb24uY29tghZ3d3cu
# dGllcm5leXZpc2lvbnMuY29tMB0GA1UdDgQWBBRc6RSBtYCAj3e/+DjJtcgwOVX3
# 8jANBgkqhkiG9w0BAQsFAAOCAQEABZRKqjq4WI95IhLaOB/+DEyndvw+PWKCtl9p
# UTeK9kF9K2a/Xn1tEFwpXjsafZ1WokncWwyJMDB2EBN2XefVNcN7zL77aT2gQGJ6
# +J2TCeAYndsE6zFTzh6MLqxTkAhsMWS1igQnuf7944u7jaLM6ys1wHEhsw+Wq7P8
# W3o5/1ZqeZ0egMW/znCjUHPdqwBGNtiODX1Y4uA2HHf8z+0/PZBB7wRQWVuMyGFM
# 1IkJmvlhU7ZbbxD7M1po96psVO+k3Eaq+M9p7lJnhp+MudyY0OjFtrzcEqQ3WxzW
# othDq2k/Ho+5W6gbx2TWagnSse5ZnZdV0hshyA4ig7HM5j5xjDGCAdUwggHRAgEB
# MDQwIDEeMBwGA1UEAwwVd3d3LnRpZXJuZXl2aXNpb24uY29tAhBDhQU0swNxkUlY
# +RZvk0KoMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkG
# CSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEE
# AYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSLN0iG7CNey1TdWYQUsGb+GkP/TTANBgkq
# hkiG9w0BAQEFAASCAQBri5swiFHbTRx1if0wzPDxRUBp+fonkfqtQrihS1q5hqc6
# nJWFK3qxYIOPxkrm1Nc+z9hhL6ezZOBCfIIPVG3CT/zPIrISnbXfs740Zs9QMPCL
# EkPg6Up7xSFkhGaa2sF0CDckP7P1YNfsVBMMDs2m9IxBLZImCCU5ZUzcLrhfsm1L
# 18a2Lk9gR43VyeM1+yyOW7PQTnwdpN0R1Fwf4RdsiHrjClaDYHe5nEO/p8HRV0Nv
# wPHD70d22o3RACE75hBMTw90cLouIGHjyUCOSgxTKlwnOeIfAZoKSzDGqqGQ8+Gp
# 2VeJSRKkIKGK7WpAQ8bRq1dUXu8dnVnSkJxrw0ud
# SIG # End signature block
