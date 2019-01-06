<# Three functions to get file metadata #>

<# 
	This gets the Titles for the current folder's metadata (can be different for folder types). 
	The information is written to .\MetaData.txt.
#>
Function Get-FileMetaTitles
{
	Param([string[]] $folder)

    $out = "Metadata available for files in this directory`r`n";
    Write-Output $out|Out-File ".\MetaData.txt";
	$objShell = (New-Object -ComObject Shell.Application).namespace($pwd.path);
	for ($j = 0; $j -le 350; $j++)
	{
		# Calling GetDetailsOf on a null gives that folder's metadata titles
		$detail = $objShell.GetDetailsOf($null, $j);
		if (($null -eq $detail) -or ($detail -eq ""))
		{
			continue;
		}
        $out = "[ " + $j + " ] " + $detail;
		Write-Output $out|Out-File ".\MetaData.txt" -append;
	}
}

<#
	This gets the metadata for a single file.
	Call with the filename and the metadata is returned as an object.
#>
Function Get-FileMetaDataOne
{
	Param([string[]] $MediaFile)

	$FileMetaData = New-Object PSOBJECT;
	$objShell = (New-Object -ComObject Shell.Application).namespace($pwd.path);
	foreach ($row in $objShell.items())
	{
		if ($row.Name -match "$MediaFile")
		{
			for ($a = 0; $a -le 400; $a++)
			{
				# Skip problematic metadata
				if ($a -eq 291) { continue; }
				if ($a -eq 296) { continue; }
				if ($a -eq 297) { continue; }

				if($objShell.getDetailsOf($row, $a))
				{
					<# The -replace filters out '?' characters that sometimes come with the data #>
					$hash += @{
                        $($objShell.getDetailsOf($objShell.items, $a)) =
					        $($objShell.getDetailsOf($row, $a)) -replace([char]8206,"") -replace([char]8207,"") };

				    $FileMetaData | Add-Member $hash|Out-Null;
				    $hash.clear();
                }
			}
			# This is the return from function!
			$FileMetaData;
		}	
	}
}


<# 
	Get file metadata for all files in a directory.
	The metadata is returned as an object.
#>
Function Get-FileMetaDataAll
{
    <# The parameter is a string array #>
	Param([string[]] $folder)

	foreach($item in $folder)
	{
		$objShell = (New-Object -ComObject Shell.Application).namespace($item);
		foreach ($File in $objShell.items())
		{
			$FileMetaData = New-Object PSOBJECT
			for ($a = 0; $a -le 512; $a++)
			{
				<# Skip problematic properties. 291 is <unreadable>, 296 is "Not shared", 297 is "Available"#>
				<# When Add-Member hits an empty name, it errors but goes on #>
				if ($a -eq 291) { continue; }
				if ($a -eq 296) { continue; }
				if ($a -eq 297) { continue; }
				if($objShell.getDetailsOf($File, $a))
				{
					<# The -replace filters out '?' characters that come with the data #>
					$hash += @{
                        $($objShell.getDetailsOf($objShell.items, $a)) =
							$($objShell.getDetailsOf($File, $a)) -replace([char]8206,"") -replace([char]8207,"") };
							
				    $FileMetaData | Add-Member $hash|Out-Null;
				    $hash.clear()
			    } #end if
		    } #end for
			# This is the return from function!
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

<#
# Sample data for the single file function
$movie = "NV12_30fps_FFC_Record_640x360.AVI";
$photo = "WIN_20180817_12_29_17_Pro.jpg";
$bright = "Brightness.PNG";
$b = Get-FileMetaDataOne $bright;
$p = Get-FileMetaDataOne $photo;
$m = Get-FileMetaDataOne $movie;
#>

Get-FileMetaTitles;
$md = Get-FileMetaDataAll $pwd;

# ALL the metadata is retrieved for each file, but what we care about is within the subset below.
$pdata = $md |
	Select-Object name,Size,'Date created',Type,length,'Frame width','Frame height','Frame rate','Bit rate', 'Data rate',Dimensions,Width,Height,'Horizontal resolution','Vertical resolution','Bit depth';
	
<#
	The filemeta data is output in four different formats.
	- A text file with ALL the metadata for EACH file
	- An .html page with the preferred subset 
	- A comma delimited page with the preferred subset
	- An interactive viewer with the preferred subset (only available if you run in a PowerShell window)
#>
$md|Out-File -filepath ".\sample-metadata.txt"
$pdata | ConvertTo-HTML | Out-File .\sample-metadata.html;
$pdata | Export-Csv .\sample-metadata.csv;
$pdata | Out-GridView;





