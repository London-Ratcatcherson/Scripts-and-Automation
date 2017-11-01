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

Get-VideoFileMetaDatum.ps1 gets the list of files in the current directory, then
calls getDetailsOf on each file for first 512 attributes.
( See more about getDetailsOf() here: 
https://msdn.microsoft.com/en-us/library/windows/desktop/bb775104(v=vs.85).aspx )
There are some "work-arounds" for a couple of problematc attributes.
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

