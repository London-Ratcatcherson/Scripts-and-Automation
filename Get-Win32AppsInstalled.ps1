Function Get-FileMetaData
{
    $colSoftware = Get-WmiObject -Class Win32_Product

} #end Get-FileMetaData

$picdata = Get-WmiObject -Class Win32_Product |
    select Name,Version,Vendor,InstallDate,InstallLocation, IdentifyingNumber,InstallState 
$picdata | Out-GridView
$picdata | Export-csv .\exportfile.csv
$picdata | ConvertTo-HTML | Out-File .\serv.htm

<#
    $colSoftware = Get-WmiObject -Class Win32_Product

    foreach ($colItem in $colSoftware)
    {
        "Name: " + $colItem.Name
        "Version: "+ $colItem.Version
        "ProductID: "+ $colItem.ProductID
        "Vendor: " + $colItem.Vendor
        "InstallDate: " + $colItem.InstallDate
        "InstallState: " + $colItem.InstallState
        "InstallLocation: " + $colItem.InstallLocation
        "IdentifyingNumber: " + $colItem.IdentifyingNumber
    }
#>

