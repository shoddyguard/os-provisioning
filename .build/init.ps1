#Requires -RunAsAdministrator
[CmdletBinding()]
param ()
# Ensure chocolatey doesn't display downloads on Teamcity builds
if ($env:TEAMCITY_VERSION -ne $null)
{
    choco feature disable -n=showDownloadProgress
}

# Ensure our dependencies are present
. "$PSScriptRoot\dependencies.ps1"

# Reload PATH in case it's changed
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# Import the provisioning module
Import-Module "$PSScriptRoot\Provisioning\Provisioning.psm1"

$env:PackerFilesPath = (get-item "$PSScriptRoot\..\packer")
$env:BuildOutputPath = (get-item "$PSScriptRoot\output")