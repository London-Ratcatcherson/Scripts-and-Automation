# Scripts-and-Automation
Some of my PowerShell and MSDOS batch file scripts to automate lab work.

I wrote two PowerShell scripts to help with some projects.
There was a large number of video files I downloaded, and I needed to organize them.
Media files have a lot of interesting attributes
- Height, width in pixels of the video
- File size
- Compression type (AVI, DV, mp4, wma)
- Temporal length
And more, of which only the file size shows up in a standard console or explorer directory
list.

Get-FileMeta.ps1 gets the list of files in the current directory, then
calls getDetailsOf on each file for first 512 attributes.
( See more about getDetailsOf() here: 
https://msdn.microsoft.com/en-us/library/windows/desktop/bb775104(v=vs.85).aspx )
There are some "work-arounds" for a couple of problematic attributes.
Results are then filtered by the datum that I actually want.

The final results are output in three different ways.
1) A comma-delimited file suitable for a spreadsheet
2) An HTML page
3) A dynamic GridView

Each output has its own advantages. 

=======================================================================

Get-Win32Apps.ps1 is much simpler. 
It just lists the Win32 apps installed on the current system and outputs the results
in the same three ways.
( A fourth simpler output is there, commented out )

=======================================================================

"Adventures in Automating Complex Installs.pdf" and the accompanying AutoInstaller
folder are some sample scripts and discussion of a difficult installation 
scenario I worked on. The WinPE "emergency boot" OS has a spare set of utilities
and only the MSDOS batch file language for scripting. I have included some samples
from that work for anyone who needs them. 

Note that the sample .BAT and .CMD scripts have a .TXT file name extension added 
to prevent accidental running.

=======================================================================

"CameraProperty" is a PowerShell script to automate Windows 10 camera testing.
There is an internal Microsoft tool that can get camera media types and properties.
That tool has a complex command line, and an older MSDOS command shell script.

I wrote a new PowerScript from scratch that greatly improved on the old script.
I don't have rights to the internal tool, but I do to the script, which
has a wealth of code that does a number of interesting things.

o Uses Parameters
o Includes a logger for display and to a file
o File and directory creation 
o Uses WMI to retrieve device and OS characteristics
o Lots of data manipulation








