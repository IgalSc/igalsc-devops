# Path to your base64 encoded SST file
$base64EncodedSSTPath = "C:\path\to\file.txt"

# Read the base64 encoded content from the file
$base64EncodedSST = Get-Content $base64EncodedSSTPath

# Decode the base64 string
$sstBytes = [Convert]::FromBase64String($base64EncodedSST)

# Path to the output SST file (you can change this)
$outputSSTPath = "C:\path\to\file.sst"

# Write the decoded bytes to a new SST file
[System.IO.File]::WriteAllBytes($outputSSTPath, $sstBytes)

Write-Host "Converted base64 encoded SST to $outputSSTPath"
