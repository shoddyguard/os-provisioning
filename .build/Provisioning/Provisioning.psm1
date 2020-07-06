$PublicCmdlets =@()
# Import our modules and export public functions
"$PSScriptRoot\Private\" |
    Resolve-Path |
    Get-ChildItem -Filter *.ps1 -Recurse |
    ForEach-Object {
      . $_.FullName
    }

"$PSScriptRoot\Public\" |
    Resolve-Path |
    Get-ChildItem -Filter *.ps1 -Recurse |
    ForEach-Object {
      . $_.FullName
      Export-ModuleMember -Function $_.BaseName
      $PublicCmdlets += Get-Help $_.BaseName
    }

Write-Host "The following cmldets are now available for use:" -ForegroundColor White
$PublicCmdlets | ForEach-Object { Write-Host "    $($_.Name) " -ForegroundColor Yellow -NoNewline; Write-Host "|  $($_.Synopsis)" -ForegroundColor White} 