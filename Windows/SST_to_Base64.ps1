$certificates = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
$certificates.Import("C:\path\to\file.sst")
$certificatesSST = $certificates.export([Security.Cryptography.X509Certificates.X509ContentType]::serializedstore)
$deviceValue = [System.Convert]::ToBase64String($certificatesSST)
$deviceValue | out-file .\file.txt