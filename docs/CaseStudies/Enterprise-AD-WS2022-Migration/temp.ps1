
    Get-ChildItem -Recurse -Filter *.ps1 |
    Select-String 'Get-Credential'