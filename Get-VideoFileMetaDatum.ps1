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

