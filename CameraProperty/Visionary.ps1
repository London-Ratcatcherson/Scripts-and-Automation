
<#
.SYNOPSIS
    Run the Camera MediaFoundation Preview-Capture-Still smoke tests.

.PARAMETER Camera
    The user can request a single camera to test -Front, Rear, IR or other. 
    "All", "IR", "FFC", "RFC", or "EXT" can be used in upper or lower case.
    Example: -Camera RFC  (uses only the RFC camera if it is present)

    Default is All cameras on device.
.PARAMETER Test
    Select the type of test to run on all cameras under test.
    Stream   - run every Preview, Capture and Still MediaType.
    Property - get the MediaType, KSProperty and KSPropertyEx for every Camera. 

    Default is Property.
.PARAMETER Datafile
    Select a private datafile to use for the tests.
    The parameter must be the name of a .csv (comma delimited) file.
    Example: .\myFile.csv ; K:\MyDataFile\myFile.csv ; \\server1\share\myFile.csv

    Default is the datafile selected by this script for the DUT.
.PARAMETER Auto
	Auto - Skip interactive UI and start test immediately.
	Manual - 30 second timer before starting test.
	Repeat - Repeat the test forever, until user breaks at UI or terminates script.

	Default is Manual.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
        [ValidateSet("Auto", "Manual", "Repeat")] [string] $Auto='Manual',
    [Parameter(Mandatory=$false)]
        [ValidateSet("Stream", "Property")]  [string] $Test='Stream',
        [Parameter(Mandatory=$false)]
        [ValidateSet("ALL", "FFC", "RFC", "IR", "EXT", "WFOV")] [string] $Camera='ALL',
    [Parameter(Mandatory=$false)]
        [string] $Datafile=''
)

<##############################################################################>
<# Local variables #>

<#    Marketed Name,	        DeviceID.	Media.	    PreReleaseSKU ( 4 fields ).	PostReleaseSKU ( 6 fields ).	                                Sentinal #>
$script:SurfaceSkuDB = @(
    ( "Surface Book 1 ",	    "BOOK1",	"BOOK1",	"OEMCH", "i5", "i7", "",	"Surface Book", "i7", "", "", "", "",	                        -1 ),
    ( "Surface Book 2 (13`")",	"BOOK2.13",	"BOOK1",	"OEMSHZ", "i5", "", "",	    "Surface Book", "Model 1832", "i5", "i7", "", "",	            -1 ),
    ( "Surface Book 2 (15`")",	"BOOK2.15",	"BOOK1",	"OEMSHP", "i5", "", "",	    "Surface Book", "Model 1793", "i7", "", "", "",	                -1 ),
    ( "Surface Pro 4",	        "PRO4",	    "BOOK1",	"", "", "", "",	            "Surface Pro 4", "i5", "", "", "", "",	                        -1 ),
    ( "Surface Pro 5",	        "PRO5",	    "BOOK1",	"OEMCA", "m3", "", "",	    "Surface Pro", "Model 1796", "i5", "", "", "",	                -1 ),
    ( "Surface Pro 6",	        "PRO6",	    "BOOK1",	"OEMCA", "CZ", "i5", "i7",	"Surface Pro 6", "Consumer", "Model 1796", "i5", "i7", "",	    -1 ),
    ( "Surface Go ",	        "GO1",	    "GO1",	    "OEMTX", "LTE", "", "",	    "Surface Go", "Consumer", "Model 1824", "", "", "",	            -1 ),
    ( "Laptop 1",	            "LAP1",	    "LAP1",	    "OEMLA", "", "", "",	    "", "", "", "", "", "",	                                        -1 ),
    ( "Laptop 2",	            "LAP2",	    "LAP1",	    "OEMLA"," FX", "i5", "",	"Surface Laptop 2", "Consumer", "Model 1769", "i5", "i7 ", "",	-1 ),
    ( "Surface Pro 3",	        "PRO3",	    "PRO3",	    "OEMAP", "", "", "",	    "Surface Pro 3", "", "", "", "", "",                            -1 ),
    ( "Studio 1",	            "STUDIO1",	"STUDIO1",	"OEMNH", "MCRB", "i5", "",	"Surface Studio", "", "", "", "", "",	                        -1 ),
    ( "Studio 2",	            "STUDIO2",	"STUDIO1",	"OEMCR", "MCRB", "i5", "",	"", "", "", "", "", "",	                                        -1 ),
    ( "Lenovo P51s",	        "SELFHOST",	"SELFHOST",	"20HBCTO1WW", "", "", "",	"", "", "", "", "", "",	                                        -1 ),
    ( "non-Surface system",	    "NOTSURF",	"NOTSURF",	"", "", "", "",	            "", "", "", "", "", "",	                                        -1 )
);
<# Start and stop of the search fields (in case they change) #>
$betaStart = 3;
$releaseStart = 7;
$sentinal = 13;

$Script:LoggingDir = ".\";
$MFCaptureDir = "\Capture\Stream";
$PropertyDir = "\Capture\Property";
$PreviewTime = 5000;
$CaptureTime = 4000;
$SleepTime = 1000;
$NumPhotos = 2;

# Formatting
$underlinetitle = "-------------------------------------";

# UI timer
$SecondsToWait = 30;

# The test application. If the process is started in a 32bit window, picking the ARM.
$app = ".\MFCaptureEngineTestApp.exe";
if (($env:PROCESSOR_ARCHITECTURE -eq "ARM") -or ($env:PROCESSOR_ARCHITECTURE -eq "X86"))
{
    $app = ".\MFCaptureEngineTestApp_arm64fre.exe";
}

# Results log files
$ResultsFile = "_CameraPropertyResults_{0}.log";
$outputlog = "";

<#
    if ($script:thisSurface[8] -match "None") 
    Camera ain't there (8, 9, 10, 11). NOTE: EXT ALWAYS in [11] (even if no RFC)

    thisSurface[0] = DeviceID (from SurfaceSkuDB)
    thisSurface[1] = Network name
    thisSurface[2] = Serial
    thisSurface[3] = SKU string
    thisSurface[4] = UEFI string
    thisSurface[5] = Media
    thisSurface[6] = camera count
    thisSurface[7] = FFC index
    thisSurface[8] = IR name : IR is ALWAYS [8]
    thisSurface[9] = FFC name : FFC is ALWAYS [9]
    thisSurface[10] = RFC name : RFC is ALWAYS [10]
    thisSurface[11] = EXT name : EXT is [11] when there are 2 other RGB cams, but [10] on a 1 RGB cam system
    thisSurface[12] = Marketed name
#>
# Preface variables that will be changed by multiple functions with script: scope
$script:thisSurface = [System.Collections.ArrayList]@(
    "NOTSURF", "NOTSURF", "", "", "", "", 0, 0, "None", "None", "None", "None", "non-Surface system" 
);

# Name of the surface property file, and the data itself
$script:SurfPropname = ".\Property.csv";
$script:SurfProp = @();

# Name of the surface datafile, and the data itself
$script:SurfDBname = ".\Media.csv";
$script:SurfDB = @();

# Test states
$script:Fatal = 0;

# Verbose
$Verbose = $false;

# The final camera states to run. $I/F/R/X = IR/FFC/RFC/EXT ; P/C/S = Preview/Capture/Still ; z = final
$script:IPz = @();
$script:ICz = @();
$script:ISz = @();

$script:FPz = @();
$script:FCz = @();
$script:FSz = @();

$script:RPz = @();
$script:RCz = @();
$script:RSz = @();

$script:XPz = @();
$script:XCz = @();
$script:XSz = @();

# MediaType converters
$script:ldmt = @'
Pin Media Type #{Pinmediatype*:0}:
 >MF_MT_MAJOR_TYPE:         {Major:MFMediaType_Video}
 >MF_MT_SUBTYPE:            {Sub:MFVideoFormat_NV12}
 >MF_MT_AVG_BITRATE:        {Bitrate:746496000}
 >MF_MT_FRAME_SIZE:         {Framesize:1920x1080}
 >MF_MT_FRAME_RATE:         {[string]Framerate:30/1}
 >MF_MT_PIXEL_ASPECT_RATIO: {[string]Aspect:1:1}
 >MF_MT_INTERLACE_MODE:     {Interlace:MFVideoInterlace_Progressive}

Pin Media Type #{Pinmediatype*:1}:
 >MF_MT_MAJOR_TYPE:         {Major:MFMediaType_Video}
 >MF_MT_SUBTYPE:            {Sub:MFVideoFormat_NV12}
 >MF_MT_AVG_BITRATE:        {Bitrate:82944000}
 >MF_MT_FRAME_SIZE:         {Framesize:640x360}
 >MF_MT_FRAME_RATE:         {[string]Framerate:30/1}
 >MF_MT_PIXEL_ASPECT_RATIO: {[string]Aspect:1:1}
 >MF_MT_INTERLACE_MODE:     {Interlace:MFVideoInterlace_Progressive}
'@

<##############################################################################>
<# Functions #>

#
function Start-Log
{
    Param([Parameter(Mandatory=$true)] [string] $output)

    # Now that we have the data directory, create the full log file name AND embed the camera prefix
    $tFile = $ResultsFile -f $Camera;
    $logname = "{0}\{1}" -f $Script:LoggingDir, $tFile;
    $Script:ResultsFile = $logname;

    # Write the accumulated output
    Write-Output $output;
    $output | Out-File -FilePath $Script:ResultsFile;
}
# Now we just write line by line, to console and log
function Write-Log
{
    Param([Parameter(Mandatory=$true)] [string] $output)

    Write-Output $output;
    $output | Out-File -FilePath $Script:ResultsFile -Append;
}

<#
	This gets the metadata for a single file.
	Call with the filename and the metadata is returned as an object.
#>
Function Get-FileMetaData
{
    Param([Parameter(Mandatory=$true)] [string] $MediaDir, 
    [Parameter(Mandatory=$true)] [string] $MediaFile)

    $FileMetaData = New-Object PSOBJECT;
	$objShell = (New-Object -ComObject Shell.Application).namespace($MediaDir);
	foreach ($row in $objShell.items())
	{
        $rowName = Split-Path $row.path -leaf;
        if ($rowName -match "$MediaFile")
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

# Get the Greatest Common Divisor
## BUGBUG Need %modulus operator
function Get-GCD  {
    Param([Parameter(Mandatory=$true)] [int32] $x, 
    [Parameter(Mandatory=$true)] [int32] $y)

    if ($y -eq 0) { $x } else { Get-GCD $y ($x%$y) }
}


# A utility function for visual check of the tables
function DumpTestTables($CamIndex)
{
    switch ($CamIndex)
    {
        0 {
            if ($script:thisSurface[8] -notmatch "None") 
            {
                $out = "{0} states to test" -f $script:thisSurface[8];
                $script:IPz|Format-Table;
                $script:ICz|Format-Table;
                $script:ISz|Format-Table;
                $out;
                }
            break;
        }
        1 {
            if ($script:thisSurface[9] -notmatch "None") 
            {
                $out = "{0} states to test" -f $script:thisSurface[9];
                $script:FPz|Format-Table;
                $script:FCz|Format-Table;
                $script:FSz|Format-Table;
                $out;
                break;
            }
        }
        2 {
            if ($script:thisSurface[10] -notmatch "None") 
            {
                $out = "{0} states to test" -f $script:thisSurface[10];
                $script:RPz|Format-Table;
                $script:RCz|Format-Table;
                $script:RSz|Format-Table;
                $out;
            }
            break;
        }
        3 {
            if ($script:thisSurface[11] -notmatch "None") 
            {
                $out = "{0} states to test" -f $script:thisSurface[11];
                $script:RPz|Format-Table;
                $script:RCz|Format-Table;
                $script:RSz|Format-Table;
                $out;
            }
            break;
        }
    }
} # function DumpTestTables($CamIndex)



<#
    Identify the hardware and choose the appropriate datafile.
#>
function Get-DeviceID
{
    $Title = "function Get-DeviceID`r`nIdentify the device and select its datafile`r`n";

    # Get this device's info
    $w32_disp = Get-WmiObject -class win32_videocontroller;
    $w32_csp  = Get-WmiObject -class win32_computersystemproduct;
    $w32_sos  = Get-WmiObject -class win32_systemoperatingsystem;
    $w32_bios = Get-WmiObject -class win32_bios;
    # We call this later, but leaving as an example
    # $w32_drv  = Get-WmiObject -class win32_PnPSignedDriver;

    # Save the SKU
    $script:thisSurface[1] = $w32_sos.PSComputerName;       # Network name
    $script:thisSurface[2] = $w32_csp.IdentifyingNumber;    # Serial
    $script:thisSurface[3] = $w32_csp.Name;                 # SKU string
    $script:thisSurface[4] = $w32_bios.SMBIOSBIOSVersion;   # UEFI string

    # "Not a Surface", "Pre-Release Surface", "Release Surface"
    $SurfOrNot = "non-Surface product";

    # Search the SurfCodeNames for a match to the WMIC name. 
    # The WMIC name can have multiple strings, so award the name to the highest number of matches.
    $row = -1;
    $matchlast=0;
    foreach ($d in $script:SurfaceSkuDB)
    {
        $matchcount = 0;
        $row++;

        # Skip empty pre-release SKU's
        if ($d[$betaStart] -eq "") { continue; }
        # try to match DUT name with WMIC_name (in field $betaStart)
        if ($w32_csp.Name -match $d[$betaStart])
        {
            $matchcount += 1;
            # Now try any substring matches, starting in the next field
            for ($index = $betaStart + 1; $index -lt $releaseStart; $index++)
            {
                # Look for matches in substrings
                if ($w32_csp.Name -match $d[$index])
                {
                    # Show the match and update match count
                    $matchcount += 1;
                }
            } # Now try any substring matches
            # higher number of matches updates codename
            if ($matchcount -gt $matchlast)
            {
                $script:thisSurface[12] = $d[0]; # Marketed name
                $script:thisSurface[0]  = $d[1]; # DeviceID
                $script:thisSurface[5]  = $d[2]; # Media tag
                $matchlast = $matchcount;
                $SurfOrNot = "Pre-Release Surface";
            }
        } # try to match DUT name with WMIC_name
    } # We count the number of matches

    # If we didn't find the match, look again with the release Sku strings
    if ($script:thisSurface[0] -eq "NOTSURF")
    {
        $row = -1;
        $matchlast=0;
        foreach ($d in $script:SurfaceSkuDB)
        {
            $matchcount = 0;
            $row++;

            # Skip empty release SKU's
            if ($d[$releaseStart] -eq "") { continue; }
            # try to match DUT name with WMIC_name (in field $betaStart)
            if ($w32_csp.Name -match $d[$releaseStart])
            {
                $matchcount += 1;
                # Now try any substring matches, starting in the next field
                for ($index = $betaStart + 1; $index -lt $sentinal; $index++)
                {
                    # Look for matches in substrings
                    if ($w32_csp.Name -match $d[$index])
                    {
                        # Show the match and update match count
                        $matchcount += 1;
                    }
                } # Now try any substring matches
                # higher number of matches updates codename
                if ($matchcount -gt $matchlast)
                {
                    $script:thisSurface[12] = $d[0]; # Marketed name
                    $script:thisSurface[0]  = $d[1]; # DeviceID
                    $script:thisSurface[5]  = $d[2]; # Media tag
                    $matchlast = $matchcount;
                    $SurfOrNot = "Release Surface";
                }
            } # try to match DUT name with WMIC_name
        } # We count the number of matches
    } # If we didn't find the match, look again with the release Sku strings


    $myname = 
    "My Surface Name is`r`n               Name: {0}`r`n      Serial number: {1}`r`n                SKU: {2}`r`nEmbedded Controller: `r`n               UEFI: {3}`r`n              Touch: `r`n        WiFi driver:`r`n" `
        -f  $thisSurface[1],
            $thisSurface[2],
            $thisSurface[3],
            $thisSurface[4];
    $Script:outputlog += $myName;

    # OS version info
    $winversion = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion');
    $out = "   Operating System: {0}, Build {1}, BuildLab {2}`r`n" -f $winversion.ProductName, $winversion.CurrentBuild, $winversion.BuildLab;
    $Script:outputlog += $out;

    # Get the graphics driver names, versions
    # If there's more than 1 graphics, its an array, else a system object
    if ($null -eq $w32_disp[0])
    {
        $out = 
        "            Display: {0}  version {1}`r`n" -f $w32_disp.description, $w32_disp.driverversion;
        $Script:outputlog += $out;
    } else 
    {
        # Just show first 2 displays
        $out = 
        "          Display 1: {0}, version {1}`r`n" -f $w32_disp[0].description, $w32_disp[0].driverversion;
        $Script:outputlog += $out;
        $out = 
        "          Display 2: {0}, version {1}`r`n" -f $w32_disp[1].description, $w32_disp[1].driverversion;
        $Script:outputlog += $out;
    }

    # Check that app is present and functional 
    # Cast the command string to a scriptblock so we can execute with invoke-command
    $return = "";
    $cmdStr = "{0} 2>&1" -f $app;
    $scriptblock = [scriptblock]::Create("$cmdStr");
    $cmdTime = Measure-Command { $return = invoke-command $scriptblock; }
    if ($LASTEXITCODE -ne 0)
    {
        $script:Fatal += 1;
        $out = "Fatal error: The {0} app failed with exitcode 0x{1:x}.`r`n" -f $app, $LASTEXITCODE;
        Write-Output $out;
    }

    # Look for any IR cameras and then up to 3 possible RGB cameras
    $camcount  = 1;
    $IRcamName = "None";
    $AcamName  = "None";
    $BcamName  = "None";
    $CcamName  = "None";
    for ($index = 0; $index -le $camcount; $index++)
    {
        switch ($index)
        {
            0 { $cmdStr = "{0} -testsensorcameras -listksproperty 2>&1" -f $app; break; }
            1 { $cmdStr = "{0} -cameraindex 0 -listksproperty 2>&1" -f $app; break; }
            2 { $cmdStr = "{0} -cameraindex 1 -listksproperty 2>&1" -f $app; break; }
            3 { $cmdStr = "{0} -cameraindex 2 -listksproperty 2>&1" -f $app; break; }
        }
        # Cast the command string to a scriptblock so we can execute with invoke-command
        $scriptblock = [scriptblock]::Create($cmdStr);

        # Run the command and save the text output to a log
        $cmdTime = Measure-Command { $return = invoke-command $scriptblock; }

        ## Check the output of the app for number of cameras and determine the FFC index
        $camname = "None";
        if ($return.count -gt 0)
        {
            foreach($row in $return)
            {
                # Get the number of cameras. This string appears twice in the test output.
                if ($row -match "Cameras found")
                {
                    $camcount = ($row -split "\s")[0];
                }
                # Get name of first camera. This string appears twice in the test output.
                if ($row -match "Video Capture Device:")
                {
                    $camname = ($row -split ":")[1];
                }
            }
        }
        switch ($index)
        {
            0 { $IRcamName = $camname; break; }
            1 { $AcamName  = $camname; break; }
            2 { $BcamName  = $camname; break; }
            3 { $CcamName  = $camname; break; }
        }
    }

    # Add camera count, first cameraname (trim whitespace), and FFC index to SurfDeviceName array
    $script:thisSurface[6]  = $camcount;
    $script:thisSurface[8]  = $IRcamName.trim();

    # Only if first camera found is "Rear", set FFC index to 1
    if (($AcamName -match "Rear") -or ($AcamName -match "Back"))
    {
        $script:thisSurface[7] = 1;
        $script:thisSurface[9]  = $BcamName.trim();
        $script:thisSurface[10] = $AcamName.trim();
        $script:thisSurface[11] = $CcamName.trim();
        } else
    {
        $script:thisSurface[7] = 0;
        $script:thisSurface[9]  = $AcamName.trim();
        $script:thisSurface[10] = $BcamName.trim();
        $script:thisSurface[11] = $CcamName.trim();
    }

    $out = "          IR camera: {0}`r`n" -f $script:thisSurface[8];
    $Script:outputlog += $out;
    switch ($script:thisSurface[6])
    {
        0 {
            $out = "        RGB cameras: {0}`r`n" `
                -f $script:thisSurface[6];
        }
        1 {
            $out = "        RGB cameras: {0}  Front: {1}`r`n" `
                -f $script:thisSurface[6], $script:thisSurface[9];
        }
        2 {
            $out = "        RGB cameras: {0}  Front: {1} ; Rear: {2}`r`n" `
                -f $script:thisSurface[6], $script:thisSurface[9], $script:thisSurface[10];
        }
        3 {
            $out = "        RGB cameras: {0}  Front: {1} ; Rear: {2} ; External: {3}`r`n" `
                -f $script:thisSurface[6], $script:thisSurface[9], $script:thisSurface[10], $script:thisSurface[11];
        }
    }
    $Script:outputlog += $out;

    # Please tell me more about those cameras
    # Note that this filters for ".DeviceName" contains "*cam*" - some devices don't do this.
    $cams = Get-WmiObject -class win32_PnPSignedDriver|Select-Object devicename, driverversion, manufacturer|Where-Object { $_.devicename -like "*cam*"; };
    foreach ($row in $cams)
    {
        $out = "                   : {0}, {1}, {2}`r`n" -f $row.DeviceName, $row.Manufacturer, $row.DriverVersion;
        $Script:outputlog += $out;
    }
    # Fishing for other possible names
    $cams = Get-WmiObject -class win32_PnPSignedDriver|Select-Object devicename, driverversion, manufacturer|Where-Object { $_.devicename -like "*usb video*"; };
    foreach ($row in $cams)
    {
        $out = "                   : {0}, {1}, {2}`r`n" -f $row.DeviceName, $row.Manufacturer, $row.DriverVersion;
        $Script:outputlog += $out;
    }

    $out = "This is a {0} and is a {1}.`r`n" -f $script:thisSurface[12], $SurfOrNot;
    $Script:outputlog += $out;

    $Script:outputlog += "`r`n";

} # function GetDeviceID



function Initialize-Test
{
    $Title = "function Initialize-Test`r`nParse command line. Load MediaType and Property DB's. Try test app. `r`n" +`
		"Check local log locations valid. TODO check remote log locations valid.`r`n";

    $script:Fatal = 0;    
    # If the user entered a datafile, try to use that
    if ($Datafile.length -ne 0)
    {
        if (-not($Datafile|Test-Path))
        {
            $script:Fatal += 1;
            $out = "Fatal error: datafile {0} is not a valid file.`r`n" -f $Datafile;
            $Script:outputlog += $out;
        }
        if (-not($Datafile|Test-Path -PathType Leaf))
        {
            $script:Fatal += 1;
            $out = "Fatal error: datafile {0} must be an existing file, not a directory.`r`n" -f $Datafile;
            $Script:outputlog += $out;
        }
        # Datafile is an actual file, so use it.
        $script:SurfDBname = $Datafile;

        # Change the media field to DeviceID (because the datafile is probably from this DUT)
        $script:thisSurface[5] = $script:thisSurface[0];
    } 

    # load DB - File validation done in the parameters block
    $script:SurfDB = Import-Csv $script:SurfDBname;

    # Check that column 0 contains a valid ID. Get the first row
    $row = $script:SurfDB[0];

    # Validate datafile by checking first row, MajorPin field for "Pin 0"
    $mpOK = $row.MajorPin -match "Pin 0";
	if (-not ($mpOK))
	{
		$script:Fatal += 1;
		$out = "Fatal error: the datafile {0} is not a properly formatted SurfCam datafile.`r`n" -f $script:SurfDBname;
        $Script:outputlog += $out;
	}

    # If a single $camera was requested, check that it's in the datafile.
    if ($camera -ne "ALL")
    {
        $foundone = 0;
        foreach ($row in $script:SurfDB)
        { 
            if ($row.camera -eq $camera)
            {
                $foundone += 1;
            }
        }
       if ($foundone -eq 0)
        {
            $script:Fatal += 1;
            $out = "Fatal error: The {0} camera requested is not in the {1} datafile.`r`n" -f $camera, $script:SurfDBname;
            $Script:outputlog += $out;
        }
    }

    # Create our logging and data directory
    if ($Test -eq "Property") 
    { 
        $Script:LoggingDir = "{0}:{1}" -f (Get-Location).drive.name, $PropertyDir; 
    } else
    { 
        $Script:LoggingDir = "{0}:{1}" -f (Get-Location).drive.name, $MFCaptureDir; 
    } 

    if (! (Test-Path $script:LoggingDir))
    {
        New-Item -path $script:LoggingDir -ItemType Directory|Out-Null;
        if (Test-Path $script:LoggingDir)
        {
            $out = "Report directory {0} created." -f $script:LoggingDir;
            $Script:outputlog += $out;
        } else
        {
            $script:Fatal += 1;
            $out = "Fatal error: Report directory {0} could not be created." -f $script:LoggingDir;
            $Script:outputlog += $out;
        }
    } else 
    {
        $out = "Report directory {0} exists." -f $script:LoggingDir;
        $Script:outputlog += $out;
    }
    # Now we can initialize the summary log, and write to the console.
    Start-log $Script:outputlog;

    # Accumulate all the errors. On ANY FATAL, set the exit flag 
    # List all the errors and suggest corrections, then fail.
    # If no FATAL, no msg and onto next function()
    if ($script:Fatal -gt 0)
    {
        $out = "Fatal setup errors: {0}. Testing cannot continue.`r`n" -f $script:Fatal;
        Write-Output $out;
    }

    Write-Output "`r`n";
} # function Initialize-Test

function Show-Menu
{
     param (
           [string]$Title = 'Change Test?'
     )
     #cls
     Write-Host "================ $Title ================"
     
     Write-Host "S: Start the current test."
     <# Write-Host "O: Change to the 'OnePass' test and start." #>
     <# Write-Host "T: Change to the 'ThreeeState' test and start." #>
     <# Write-Host "F: Change to the 'FrameRate' test and start." #>
     <# Write-Host "H: Change to the 'Height' test and start." #>
     <# Write-Host "A: Change to the 'Aspect' test and start." #>
     Write-Host "Q: Quit."

     Write-Host "`r`nSeconds until test starts";
} # function Show-Menu

# Show the Menu choices, and set user choices / wait for timer
function Request-UserConfirm
{
    # Show-Menu shows the choices
    Show-Menu;
    $SecondsCounter = 0;
    $Quit = 0;
    # PowerShell does NOT handle interactive keyboard UI well
    do 
    {
        # Sleep for 1 second
        Start-Sleep -s 1;
        # RawUI doesn't work in PowerShell ISE, so don't try
        if ((! $psISE) -and ($host.ui.RawUI.KeyAvailable))
        {
            $key = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyUp");
            switch ($key.virtualKeyCode)
            {
                7  { $Out = "Quit"; $script:Fatal += 1;  $Quit = 1; break; }
                81 { $Out = "Quit"; $script:Fatal += 1;  $Quit = 1; break; }

                <# Disable switching tests (don't need, but keep code as example)
                79 { $Script:Test = $out = "OnePass";    $Quit = 2; break; }
                84 { $Script:Test = $out = "ThreeWay";   $Quit = 2; break; }
                70 { $Script:Test = $out = "FrameRate";  $Quit = 2; break; }
                72 { $Script:Test = $out = "Height";     $Quit = 2; break; }
                65 { $Script:Test = $out = "Aspect";     $Quit = 2; break; }
                #>

                83 { $Out = "Start"; $Quit = 3; break; }
            }
        }
        $SecondsCounter++;
        if (0 -eq ($SecondsCounter % 5))
        {
            $out = "{0} " -f ($script:SecondsToWait - $SecondsCounter);
            Write-Host -NoNewline $out;
        }

    } while (($SecondsCounter -lt $script:SecondsToWait) -and ($Quit -eq 0));

    if ($Quit -eq 1) { Write-Log "`r`nQuitting test "; }
    if ($Quit -eq 2) 
    { 
        $out = "`r`nTest changed to {0}" -f $out;
        Write-Log $out;
    }
    if ($Quit -eq 3) { Write-Output "`r`nStarting test "; }
} # function User-Confirm


function Select-Media
{

    $Title = "function Select-Media`r`nFind the Preview/Capture/Still for each camera on DUT`r`n" + `
        "Save as arrays for the Stream ";

    $plural = "";
    if ($Camera -match "ALL") { $plural="s"};
    $out = "Testing the {0} for {1} Camera{2}; Running {3} test; Using {4} Media file; {5} database."`
        -f $script:thisSurface[0], $Camera, $plural, $Test, $script:SurfDBname, $script:thisSurface[5];
    Write-Log $out;
    
    # Get the Media for this DUT
    $datablock = $script:SurfDB|Select-Object|Where-Object -Property DeviceID -eq $script:thisSurface[5];

    # Loop through all cameras
    for ($camIndex = 0 ; ($CamIndex -le $script:thisSurface[6]); $CamIndex++) {

        # Only test cameras present
        if ($script:thisSurface[8 + $CamIndex] -match "None") { continue; } 
        # Get camera specific strings and datastates
        switch ($CamIndex)
        {
            0 { $camPrefix = "IR"; break; }
            1 { $camPrefix = "FFC"; break; }
            2 { $camPrefix = "RFC"; break; }
            3 { $camPrefix = "EXT"; break; }
        }

        $thisCam = $datablock|Select-Object|Where-Object -Property Camera -eq $camPrefix;
        # Do we have any of these cameras?
        if ($thisCam.count -eq 0) { continue; } 

        # Look for Preview or Still pins
        $p = $thisCam|Select-Object|Where-Object -Property MajorPin -match "Preview";
        $s = $thisCam|Select-Object|Where-Object -Property MajorPin -match "Still";

        # Arrays with a single item (looking at YOU, IR) don't have a .count member
        # If the .camera member is missing, array is empty
        $pCount = 0;
        $sCount = 0;
        if ($p.count) {$pCount = $p.count;} else { if ($p.camera) {$pCount = 1;}}
        if ($s.count) {$sCount = $s.count;} else { if ($s.camera) {$sCount = 1;}}

        if (($pCount -ne 0) -or ($sCount -ne 0))
        {
            # Classic Preview, Capture, Still OR Capture, Still
            $c = $thisCam|Select-Object|Where-Object -Property MajorPin -match "Capture";
        } else
        {
            # Studio. Get the first Capture pin only
            $c = $thisCam|Select-Object|Where-Object -Property MajorPin -match "Pin 0 Capture";
        }

        # Arrays with a single item (looking at YOU, IR) don't have a .count member
        # If the .camera member is missing, array is empty
        $cCount = 0;
        if ($c.count) {$cCount = $c.count;} else { if ($c.camera) {$cCount = 1;}}

        $out = "{0} has {1} Preview, {2} Capture, {3} Still pins from {4} MediaTypes" -f `
            $camPrefix, $pCount, $cCount, $sCount, $thisCam.count; 
        $out;

        # Always a Capture pin. If no Preview, use the Capture. If no Still, use the Capture.
        switch ($CamIndex)
        {
            0 { 
                $script:ICz = $c;
                if ($pCount -eq 0) { $script:IPz = $c; } else { $script:IPz = $p; }
                if ($sCount -eq 0) { $script:ISz = $c; } else { $script:ISz = $s; }
                break; 
            }
            1 { 
                $script:FCz = $c;
                if ($pCount -eq 0) { $script:FPz = $c; } else { $script:FPz = $p; }
                if ($sCount -eq 0) { $script:FSz = $c; } else { $script:FSz = $s; }
                break; 
            }
            2 { 
                $script:RCz = $c;
                if ($pCount -eq 0) { $script:RPz = $c; } else { $script:RPz = $p; }
                if ($sCount -eq 0) { $script:RSz = $c; } else { $script:RSz = $s; }
                break; 
            }
            3 { 
                $script:XCz = $c;
                if ($pCount -eq 0) { $script:XPz = $c; } else { $script:XPz = $p; }
                if ($sCount -eq 0) { $script:XSz = $c; } else { $script:XSz = $s; }
                break; 
            }
        } # Always a Capture pin. ...
   
    } # Loop through all cameras

} # function Select-Media



###########################################################################################
#################### Start-Stream ########################################################
function Start-Stream
{
    $Title = "function Start-Stream`r`nRun the One pass through each Preview, Capture, Still state";

    $PassFail = "Pass";
    $PassCount = 0;
    $FailCount = 0;

    # Start the clock
    $startTime = Get-Date;

    ###############################################
    # Start of the "test all chosen cameras" loop
    $CamIndex = 0;
    switch ($camera)
    {
        "ffc"  { $CamIndex = 1; break; }
        "rfc"  { $CamIndex = 2; break; }
        "ext"  { $CamIndex = 3; break; }
    }

    for ( ; ($CamIndex -le $script:thisSurface[6]); $CamIndex++) {

        # Only test cameras present
        if ($script:thisSurface[8 + $CamIndex] -match "None") { continue; } 

        # Get camera specific strings and datastates
        # Get camera specific strings and datastates
        $p = @();
        $c = @();
        $s = @();
        switch ($CamIndex)
        {
            0 { $CamPrefix = "IR"; 
                $CamString = "-testSensorCameras"; 
                $p = $script:IPz;
                $c = $script:ICz;
                $s = $script:ISz;
                break; }
            1 { $CamPrefix = "FFC"; 
                $CamString = "-cameraIndex {0}" -f $script:thisSurface[7]; 
                $p = $script:FPz;
                $c = $script:FCz;
                $s = $script:FSz;
                break; }
            2 { $CamPrefix = "RFC"; 
                $rindex = 0; if ($script:thisSurface[7] -eq 0) { $rindex = 1; }    
                $CamString = "-cameraIndex {0}" -f $rindex; 
                $p = $script:RPz;
                $c = $script:RCz;
                $s = $script:RSz;
                break; }
            3 { $CamPrefix = "EXT"; 
                $CamString = "-cameraIndex 2"; 
                $p = $script:XPz;
                $c = $script:XCz;
                $s = $script:XSz;
                break; }
        }

        # Loop through Preview, Capture and Still
        for ($streamIndex = 0; $streamIndex -lt 3; $streamIndex++)
        {
            switch ($streamIndex)
            {
                0 { $Stream = "Preview"; $state = $p; }
                1 { $Stream = "Capture"; $state = $c; }
                2 { $Stream = "Still";   $state = $s; }
            }
            # Display a log banner for new camera and new streams
            $out = "`r`n{0}`r`n{1} {2}`r`n{0}" -f $underlinetitle, $CamPrefix, $stream, $underlinetitle;
            Write-Log $out;

            # Run the test for each row of the current P,C,S data 
            $cmdStr = "";
            $rowIndex = 0;
            foreach ($row in $state)
            {
                # Get strings for Framerate, SubFormat and AspectRatio
                $fps = "{0}to{1}" -f ($row.Framerate -split("/"))[0], ($row.Framerate -split("/"))[1];
                $sub = ($row.Sub -split("_"))[1];
                if ($sub -match "MJPG") { $sub = "MJPEG";}
                $width = ($row.Framesize -split("x"))[0];
                $height = ($row.Framesize -split("x"))[1];
                # Calculate the Aspect Ratio : width/GreatestCommonDenomination(w,h) : height/GCD(w,h)
                $gcd = Get-GCD $width $height;
                $aspect = "{0}:{1}" -f ($width/$gcd), ($height/$gcd);

                # Going with "NV12" for -recordedVideoFormat and "JPEG" for -photoFormat
                $capFormat = "NV12";
                $photoFormat = "JPEG";

                # Fill in the iteration title, command string and log filename
                switch ($streamIndex)
                {
                    0 { 
                        $testTitle1 = "`r`n{0} {1}: Camera: {2}, {3} # {4}, Format: {5}, Framerate: {6}, AspectRatio: {7}, Resolution {8}";
                        $itertitle = $testTitle1 -f $Stream, $rowIndex, $row.Camera, $row.MajorPin, $row.Pinmediatype, $sub, $fps, $aspect, $row.Framesize ;  

                        #log = "FFC_Prev_NV12_30/1_fps_p1920x1080_c1920x1080_s1920x1080" .log, .avi, .jpg 
                        $logName1 = "{0}\{1}_{2}_{3}_{4}fps_p{5}";
                        $logName = $logName1 -f $Script:LoggingDir, $CamPrefix, $Stream, $sub, $fps, $row.Framesize;
                        #Base name for media verification
                        $logNameV = "{1}_{2}_{3}_{4}fps_p{5}";
                        $logNameV = $logNameV -f $Script:LoggingDir, $CamPrefix, $Stream, $sub, $fps, $row.Framesize;
                        # Test cmd lines. The 2>&1 redirects app error messages into the output stream.
                        $cmdStr1 = " {0} -VideoOnly {1} -cameraFrameRate {2} -preview Video -videoFormat {3} -cameraPinResolution {4} -previewDuration {5} 2>&1";
                        $cmdStr = $cmdStr1 -f $script:app, $CamString, $row.Framerate, $sub, $row.Framesize, $script:PreviewTime; 
                        break; 
                    }
                    1 { 
                        $testTitle1 = "`r`n{0} {1}: Camera: {2}, {3} # {4}, Format: {5}, Framerate: {6}, AspectRatio: {7}, Resolution {8}";
                        $itertitle = $testTitle1 -f $Stream, $rowIndex, $row.Camera, $row.MajorPin, $row.Pinmediatype, $sub, $fps, $aspect, $row.Framesize ;  

                        $logName1 = "{0}\{1}_{2}_{3}_{4}fps_c{5}";
                        $logName = $logName1 -f $Script:LoggingDir, $CamPrefix, $Stream, $sub, $fps, $row.Framesize;
                        #Base name for media verification
                        $logNameV = "{1}_{2}_{3}_{4}fps_c{5}";
                        $logNameV = $logNameV -f $Script:LoggingDir, $CamPrefix, $Stream, $sub, $fps, $row.Framesize;
                        # Test cmd lines. The 2>&1 redirects app error messages into the output stream.
                        $cmdStr1 = " {0} -VideoOnly {1} -cameraFrameRate {2} -record Video -deviceFrameRate {2} -recordDuration {3} -capturePinFormat {4} -recordedVideoFormat {5} -cameraResolution {6} -recordToFile {7}.avi 2>&1";
                        $cmdStr = $cmdStr1 -f $script:app, $CamString, $row.Framerate, $script:CaptureTime, $sub, $capFormat, $row.Framesize, $logname; 

                        break; 
                    }
                    2 { 
                        $testTitle1 = "`r`n{0} {1}: Camera: {2}, {3} # {4}, Format: {5}, Framerate: {6}, AspectRatio: {7}, Resolution {8}";
                        $itertitle = $testTitle1 -f $Stream, $rowIndex, $row.Camera, $row.MajorPin, $row.Pinmediatype, $sub, $fps, $aspect, $row.Framesize ;  

                        $logName1 = "{0}\{1}_{2}_{3}_{4}fps_s{5}";
                        $logName = $logName1 -f $Script:LoggingDir, $CamPrefix, $Stream, $sub, $fps, $row.Framesize;
                        #Base name for media verification
                        $logNameV = "{1}_{2}_{3}_{4}fps_s{5}";
                        $logNameV = $logNameV -f $Script:LoggingDir, $CamPrefix, $Stream, $sub, $fps, $row.Framesize;
                        # Stills taken with Capture pin or Still-Dependent don't use the independentImagePin 
                        if (($row.MajorPin -match "Capture") -or ($row.MajorPin -match "Dependent"))
                        {
                            # This is a Studio. Change output format specifier to JPEG if only YUY2 available
                            $format = $row.SubFormat;
                            if ($format -match "YUY2") { $format = "JPEG"; }
                            $cmdStr1 = " {0} -takePhoto {1} -photoFormat {2} -numPhotos {3} -photoResolution {4} -photoFileName {5}_0.jpg 2>&1";
                            $cmdStr = $cmdStr1 -f $script:app, $CamString, 
                                $photoFormat, $script:numphotos, $row.Framesize, $logname;
 
                        } else
                        {
                            $cmdStr1 = " {0} -takePhoto {1} -photoFormat {2} -numPhotos {3} -imagePinResolution {4} -takePhotoFrom independentImagePin -photoFileName {5}_0.jpg 2>&1";
                            $cmdStr = $cmdStr1 -f $script:app, $CamString, 
                                $photoFormat, $script:numphotos, $row.Framesize, $logname;
                        }
                        break; 
                    }
                } # Fill in the iteration title, command string and log filename

                # Cast the command string to a scriptblock so we can execute with invoke-command
                $scriptblock = [scriptblock]::Create($cmdStr);
                $out = $itertitle + "`r`n" + $underlinetitle;
                Write-Log $out;
                $out =  "Command Line: " + $cmdStr;
                Write-Log $out;
    
                # Run the command and save the text output to a log
                $return = "";
                $cmdTime = Measure-Command { $return = invoke-command $scriptblock; }

                # Persist the testapp exitcode!
                $saveLASTEXITCODE = $LASTEXITCODE;
    
                # Verify the media
                $verify = $true;
                switch ($streamIndex)
                {
                    0 {
                        # Need a blank $mediaVerify for Preview
                        $logNameVFull = $logNameV + ".log";
                        $meta = Get-FileMetaData $Script:LoggingDir $logNameVFull ;
                        $mediaVerify = "";
                    }
                    1 {
                        # Check the avi for length, 'frame height', 'frame width', 'Frame rate', 
                        # '00.00.02', 720, 1280, '30.00 frames/second'

                        # Convert milliseconds to seconds
                        $captime = $script:CaptureTime / 1000;
                        $logNameVFull = $logNameV + ".avi";
                        $meta = Get-FileMetaData $Script:LoggingDir $logNameVFull ;
                        $outWidth = "Width: [{0}] <{1}>" -f $meta.'frame width', $width;
                        $outHeight = "Height: [{0}] <{1}>" -f $meta.'frame height', $height;
                        $outLength = "Length: [{0}] <{1}> (allowing 3 seconds latency)" -f $meta.'length', $captime;
                        $outFrameRate = "FPS: [{0}] <{1}>" -f $meta.'frame rate', $row.Framerate;
                        
                        if ($width -notmatch $meta.'frame width')
                        {
                            $verify = $false;
                        }
                        if ($height -notmatch $meta.'frame height')
                        {
                            $verify = $false;
                        }
                        # $row.Framerate = "30/1" and $meta.'frame rate' = "30.00 frames/second"
                        $rowFrame = ($row.Framerate -split("/"))[0];
                        $metaFrame = ($meta.'frame rate' -split("f"))[0];
                        $rowFrameDenominator = ($row.Framerate -split("/"))[1];
                        # We are searching for substring $rowFrame ("30") in string $metaFrame ("30.00") IF denominator = 1 
                        if (($rowFrameDenominator -eq 1) -and ($metaFrame -notmatch $rowFrame))
                        {
                            $verify = $false;
                        }
                        # or the calculated $rowFPS ("10000000/1333333" = ".75") to "7.50 fram"
                        # Is this an odd FPS, like "10000000/1333333"? ( .75 or "7.50 frames/second" )
                        if ($rowFrameDenominator -ne 1)
                        {
                            $rowFPS = $rowFrame / $rowFrameDenominator;     # Integer 7.500087 ..
                            # Convert "7.50" to "750" and ".75" to "75"
                            $m2 = $metaFrame.split(".")[0] + $metaFrame.split(".")[1];    # "750"
                            $r2 = $rowFPS.ToString().split(".")[0] + $rowFPS.ToString().split(".")[1]; # "7500087 .."
                            $r2 = $r2.split("0")[0];    # "75"
                            # Now look for "75" in "750"
                            if ($m2 -notmatch $r2)
                            {
                                $verify = $false;
                            }
                        }

                        # $script:CaptureTime = "4000" and $meta.Length = "00:00:04"
                        # This gives us JUST seconds. For hours/minutes, we need to parse [0] and [1]
                        $metaLength = ($meta.length -split(":"))[2];
                        $metaLength = [convert]::ToInt32($metaLength, 10);
                        # We're allowing up to 3 seconds latency for the captured movie length 
                        if ($metaLength -lt ($captime - 3))
                        {
                            $verify = $false;
                        }

                        $out = $mediaVerify = "AVI verification - [actual] <should be>:`r`n{0} ; {1} ; {2} ; {3}" -f $outWidth, $outHeight, $outFrameRate, $outLength;
                        Write-Log $out;
                    }
                    2 {
                        # Check the jpg for 'width', 'height'
                        # '2560 pixels', 1440 pixels'
                        $logNameVFull = $logNameV + "_0.jpg";
                        $meta = Get-FileMetaData $Script:LoggingDir $logNameVFull ;
                        $outWidth = "Width: [{0}] <{1}>" -f $meta.'width', $width;
                        $outHeight = "Height: [{0}] <{1}>" -f $meta.'height', $height;

                        # We are searching for substring $row.Width ("2560") in string $meta.width ("2560 pixels")
                        if ($meta.Width -notmatch $width)
                        {
                            $verify = $false;
                        }
                        if ($meta.height -notmatch $height)
                        {
                            $verify = $false;
                        }
                        # $row.width -eq "720" $meta.'width' -eq '720 pixels'
                        $logNameVFull = $logNameV + "_01.jpg";
                        $meta = Get-FileMetaData $Script:LoggingDir $logNameVFull ;
                        $outWidth2 = "Width: [{0}] <{1}>" -f $meta.'width', $width;
                        $outHeight2 = "Height: [{0}] <{1}>" -f $meta.'height', $height;

                        $out = $mediaVerify = "JPG 0 verification - [actual] <should be>:`r`n{0} ; {1}`r`nJPG 1 verification - [actual] <should be>:`r`n{2} ; {3}`r`n" `
                            -f $outWidth, $outHeight, $outWidth2, $outHeight2;
                        Write-Log $out;
                    }
                } # Verify the media

                # Calculate PASS / FAIL the test ( Write to log inside, to add _ERROR to title)
                if (($saveLASTEXITCODE -EQ 0) -and ($verify -EQ $true))
                { 
                    $PassFail = "PASS";
                    $PassCount += 1;
                    $logNameFinal = "{0}.log" -f $logName;
                    $logName = $logNameFinal;
                } else 
                { 
                    $PassFail = "FAIL";
                    $FailCount += 1;
                    $logNameFinal = "{0}_Error.log" -f $logName;
                    $logName = $logNameFinal;
                };
                $out = $result = "Result: {0} (return code 0x{1:x}) in {2:ss} seconds and {2:ff} milliseconds" `
                    -f $PassFail, $saveLASTEXITCODE, $cmdTime;
                Write-log $out;

                # Create the log, write this TC criteria, the command line, the testapp log, results and media verification
                $itertitle   | out-file -filepath $logname;
                $cmdStr      | out-file -filepath $logname -Append;
                $return      | out-file -filepath $logname -Append;
                $result      | out-file -filepath $logname -Append;
                $mediaVerify | out-file -filepath $logname -Append;

                # End of this row. Next row!
                $rowIndex++;
            } # Run the test for each row of the current P,C,S data 
        } # Loop through Preview, Capture and Still

        # Finished if this is an individual camera test
        if ($camera -ne "all") { break; }
    } 
    # End of the "test all chosen cameras" loop
    ###############################################

    # Stop the clock
    $stopTime = Get-Date;  
    $totalTime = $stopTime - $startTime;

    # Final results
    $out = "There were {0} PASS and {1} FAIL results in {3:dd} days, {3:hh} hours, {3:mm} minutes, {3:ss} seconds and {3:ff} milliseconds.`n" `
        -f $PassCount, $FailCount, $index, $totalTime;
    Write-Log $out;

} # function Start-Stream


function Start-TestThree
{
    $Title = "function Start-TestThree`r`nRun the Threeway/FrameRate/Height/Aspect test simultaneously streaming Preview, Capture and Still";
    $Title;

}

function Stop-Test
{
    $Title = "function Stop-Test`r`nTest is done, final reports";
    $Title;

} # function Stop-Test

function Resolve-Error
{
    $Title = "function Resolve-Error`r`nError case handler";
    $Title;
} # function Resolve-Error

function Update-Report
{
    $Title = "function Update-Report`r`nPeriodic report update while Job is running";
    $Title;
} # function Update-Report

function Start-Property
{
    $Title = "function Start-Property`r`nQuery each Camera for MediaTypes, KSProperty, KSPropertyEx`r`nWrite those to files, then compare to LKG`r`n";
    $out = "`r`n";
    Write-Log $out;

    # For each camera under test, run through the tests
    # IR = 0, FFC =1, RFC =2. 'all' and 'ir' start at 0

    # Containers for the Media and Property
    $MediaAll = [System.Collections.ArrayList]@();
    $PropertyAll = [System.Collections.ArrayList]@();
    # Logs = [DeviceID].Media.csv, [DeviceID].Property.csv
    $logNameMedia    = "{0}\{1}.Media.csv"    -f $Script:LoggingDir, $Script:thisSurface[0];
    $logNameProperty = "{0}\{1}.Property.csv" -f $Script:LoggingDir, $Script:thisSurface[0];

    ###############################################
    # Start of the "get properties of all cameras" loop

    for ($camIndex = 0 ; ($CamIndex -le $script:thisSurface[6]); $CamIndex++) {

        # Only test cameras present
        if ($script:thisSurface[8 + $CamIndex] -match "None") { continue; } 

        # Get camera specific strings and datastates
        switch ($CamIndex)
        {
            0 { $CamPrefix = "IR"; 
                $CamString = "-testSensorCameras"; break; }
            1 { $CamPrefix = "FFC"; 
                $CamString = "-cameraIndex {0}" -f $script:thisSurface[7]; break; }
            2 { $CamPrefix = "RFC"; 
                $rindex = 0; if ($script:thisSurface[7] -eq 0) { $rindex = 1; }    
                $CamString = "-cameraIndex {0}" -f $rindex; break; }
            3 { $CamPrefix = "EXT"; 
                $CamString = "-cameraIndex 2"; break; }
        }

        $testTitle = "Saving the {0} {1} {2} to {3}";
        
        # Loop through MediaType, KSProperty, KSPropertyEx
        for ($streamIndex = 0; $streamIndex -lt 3; $streamIndex++)
        {
            switch ($streamIndex)
            {
                0 { $Stream = "MediaTypes";   $state = "-listDeviceMediaTypes"; }
                1 { $Stream = "KSProperty";   $state = "-listKsProperty"; }
                2 { $Stream = "KSPropertyEx"; $state = "-listKsPropertyEx"; }
            }
            #log = "[$SurfCodeName].[$camTLA].[$prop].txt" 
            $logName1 = "{0}\{1}.{2}.{3}.{4}";
            $logName = $logName1 -f `
                $Script:LoggingDir, $script:thisSurface[0], $CamPrefix, $Stream, "txt";
            
            # The 2>&1 redirects app error messages into the output stream.
            $cmdStr1 = " {0} {1} {2} 2>&1";
            $cmdStr = $cmdStr1 -f $script:app, $CamString, $state;

            # Cast the command string to a scriptblock so we can execute with invoke-command
            $scriptblock = [scriptblock]::Create($cmdStr);
            $iterTitle = $testTitle -f `
                $script:thisSurface[0], $CamPrefix, $Stream, $logName;
            Write-Log $iterTitle;
            $out =  "Command Line: " + $cmdStr + "`r`n";
            Write-Log $out;

            # Run the command and save the text output to a log
            $return = "";
            $cmdTime = Measure-Command { $return = invoke-command $scriptblock; }

            # Persist the testapp exitcode!
            $saveLASTEXITCODE = $LASTEXITCODE;

            # log the result to a file
            $return|Out-File -FilePath $logname;

            # MediaTypes - Convert the raw ldmt to a .csv
            if ($streamIndex -eq 0)
            {
                $return|ConvertFrom-String -TemplateContent $script:ldmt -OutVariable MediaLDMT|Out-Null;

                # Get rid of any audio capture devices, and add the SKU, Camera, MajorPin columns
                $t = $MediaLDMT|Select-Object DeviceID, Camera, MajorPin, *|Where-Object -Property "Major" -NotMatch "Audio";
                #$t2 = $t|Select-Object Camera, MajorPin, *;

                # Get the MajorPins from the raw ldmt call
                $MajorP = [System.Collections.ArrayList]@();
                # Look for Pin 0, 1 .. up to Pin 4 and build the pinname string
                $pin = "(Pin 0)";
                foreach ($row in $return)
                {
                    if ($row -match $pin) 
                    { 
                        $pinString = ($row -split ":")[1];
                        if ($pinString -match "MF_CAPTURE_ENGINE_STREAM_CATEGORY_VIDEO_PREVIEW") 
                        { $pinName = "Pin {0} {1}" -f $MajorP.Count, "Preview"; }
                        if ($pinString -match "MF_CAPTURE_ENGINE_STREAM_CATEGORY_VIDEO_CAPTURE") 
                        { $pinName = "Pin {0} {1}" -f $MajorP.Count, "Capture"; }
                        if ($pinString -match "MF_CAPTURE_ENGINE_STREAM_CATEGORY_PHOTO_INDEPENDENT") 
                        { $pinName = "Pin {0} {1}" -f $MajorP.Count, "Still"; }
                        if ($pinString -match "MF_CAPTURE_ENGINE_STREAM_CATEGORY_PHOTO_DEPENDENT") 
                        { $pinName = "Pin {0} {1}" -f $MajorP.Count, "Still-Dependent"; }
                        if ($pinString -match "MF_CAPTURE_ENGINE_STREAM_CATEGORY_UNSUPPORTED") 
                        { $pinName = "Pin {0} {1}" -f $MajorP.Count, "Unsupported"; }
                        if ($pinString -match "MF_CAPTURE_ENGINE_STREAM_CATEGORY_AUDIO") 
                        { $pinName = "Pin {0} {1}" -f $MajorP.Count, "Audio"; }

                        $MajorP.add($pinName)|Out-Null;
                        $pin = "(Pin {0})" -f (0 + $MajorP.Count);
                    }
                    # if ($MajorP.Count -gt 4) {break;}
                } # Look for Pin 0, 1 .. up to Pin 4 and build the pinname string

                # Fill in DeviceID, Camera, MajorPin fields
                $pinIndex = -1;
                foreach($row in $t)
                {
                    if ($row.Pinmediatype -eq "0") { $pinIndex++; }
                    $row.DeviceID = $Script:thisSurface[0];
                    $row.Camera   = $CamPrefix;
                    $row.MajorPin = $MajorP[$pinIndex];
                }
                # Add result to $MediaAll ArrayList
                $MediaAll += $t;
            } # MediaTypes - Convert the raw ldmt to a .csv

            # KSProps - Convert both to .csv
            if (($streamIndex -eq 1) -or ($streamIndex -eq 2))
            {
                # $return is the current log
                # Set up an arraylist to hold the converted results
                $tArray = [System.Collections.ArrayList]@();

                # Parse the raw log
                $flagParentIndex = 0;
                foreach ($line in $return)
                {
                    # Flag for whether to add this line
                    $addaline = $false;
                    $tCam = $CamPrefix;
                    $tProp = $tSupp = $tFlag = $tMax = $tMin = $tStep = $tDef = $tCur = $tAuto = $tMan = [string] "";

                    if ($line -match "PROPSETID_") 
                    {
                        $tProp = ($line -split " ")[0];
                        if ($line -match "NOT") { $tSupp = "NO"; } else { $tSupp = "Y"; }
                        $addaline = $true;
                    }
                    if ($line -match "^KSPROPERTY_") 
                    {
                        $tProp = ($line -split " ")[0];
                        if ($line -match "NOT") { $tSupp = "NO"; } else { $tSupp = "Y"; }
                        $flagParentIndex = $tArray.Count;
                        $addaline = $true;
                    }
                    if ($line -match "FLAG:") 
                    {
                        $tProp = ($line -split ": ")[1];
                        $tProp = ($tProp -split " ")[0];
                        if ($line -match "NOT") { $tSupp = "NO"; } else { $tSupp = "Y"; }
                        $tFlag = $tArray[$flagParentIndex].Property;
                        $addaline = $true;
                    }
                    # MAX: -5, MIN: -13, STEP: 1, DEFAULT: -6, CURRENT VALUE: -6, AutoSupported: 1, ManualSupported: 1
                    if ($line -match "MAX:") 
                    {
                        $tMax = ($line -split "MAX: ")[1];
                        $tMax = ($tMax -split ",")[0];
                        $tArray[$tArray.Count - 1].Max = $tMax;

                        $tMin = ($line -split "MIN: ")[1];
                        $tMin = ($tMin -split ",")[0];
                        $tArray[$tArray.Count - 1].Min = $tMin;

                        $tStep = ($line -split "STEP: ")[1];
                        $tStep = ($tStep -split ",")[0];
                        $tArray[$tArray.Count - 1].Step = $tStep;

                        $tDef = ($line -split "DEFAULT: ")[1];
                        $tDef = ($tDef -split ",")[0];
                        $tArray[$tArray.Count - 1].Default = $tDef;

                        $tCur = ($line -split "VALUE: ")[1];
                        $tCur = ($tCur -split ",")[0];
                        $tArray[$tArray.Count - 1].Current = $tCur;

                        $tAuto = ($line -split "AutoSupported: ")[1];
                        $tAuto = ($tAuto -split ",")[0];
                        $tArray[$tArray.Count - 1].Auto = $tAuto;

                        $tMan = ($line -split "ManualSupported: ")[1];
                        $tMan = ($tMan -split " ")[0];
                        $tArray[$tArray.Count - 1].Manual = $tMan;

                        # We don't add this line; we edit the previous
                        $addaline = $false;
                    }
                    if ($addaline -eq $true)
                    {
                        # Create the row in our desired order and add to array 
                        $hash = [ordered] @{ 
                            DeviceID = $Script:thisSurface[0]
                            Camera = $tCam
                            Property = $tProp
                            Supported = $tSupp
                            FlagParent = $tFlag
                            Max = $tMax
                            Min = $tMin
                            Step = $tStep
                            Default = $tDefault
                            Current = $tCurrent
                            Auto = $tAuto
                            Manual = $tMan
                        }
                        $tArray += New-Object PsObject -Property $hash;
                    }
                } # Parse the raw log

                # Add result to $PropertyAll Arraylist
                $PropertyAll += $tArray;
            } # KSProps - Convert both to .csv
        } # Loop through MediaType, KSProperty, KSPropertyEx
    } # Start of the "get properties of all cameras" loop

    # Show our work
    $MediaAll|Format-Table -AutoSize| Out-String -Width 4096;

    # log the result to a file
    $MediaAll|Export-Csv -Path $logNameMedia;
    # Get rid of the #TYPE line at the top
    if (Test-Path -Path $logNameMedia)
    {
        # Read the file, copy lines 1 to the second to last (last is empty)
        $t2 = Get-Content -Path $logNameMedia;
        $last = $t2.count -1;
        $t3 = $t2[1..$last];
        # Excel needs the file in ANSI
        $t3|Out-File -Encoding ASCII -FilePath $logNameMedia;
    }

    # Show our work
    $PropertyAll|Format-Table -AutoSize| Out-String -Width 4096;

    # log the result to a file
    $PropertyAll|Export-Csv -Path $logNameProperty;
    # Get rid of the #TYPE line at the top
    if (Test-Path -Path $logNameProperty)
    {
        # Read the file, copy lines 1 to the second to last (last is empty)
        $t2 = Get-Content -Path $logNameProperty;
        $last = $t2.count -1;
        $t3 = $t2[1..$last];
        # Excel needs the file in ANSI
        $t3|Out-File -Encoding ASCII -FilePath $logNameProperty;
    }

} # function Start-Property


<##############################################################################>
<# Test execution starts here. #>

# Setup and initialization
Get-DeviceID;
Initialize-Test;
# Exit the script if setup found problems
if ($script:Fatal -gt 0) { return; }
$runIteration = 1;

do 
{

    # How long will the selected tests take on this system?
    Select-Media;

    #$ Exit if user chose to Cancel
    if ($script:Fatal -gt 0) { return; }

    # 30 second timer
    if ($Auto -ne "Auto")
    {
        Request-UserConfirm;
    }

    # The actual test execution
    # OnePass is sufficiently different that it needs its own function
    # ThreeWay, FrameRate, Height and Aspect are the same test, with different data
    switch ($Test)
    {
        "Stream"   { Start-Stream; break; }
        "Property" { Start-Property; break; }
        # default    { Start-TestThree; break; }
    }

    $out = "{0} Iteration {1}`r`n" -f (Get-Date).ToString(), $runIteration++;
    Write-Log $out;

    #And the wrap up
    #Stop-Test;

    # Repeat the test cycle on -Auto Repeat parameter
} while ($Auto -eq "Repeat");


<# End of the script. #>
<##############################################################################>
