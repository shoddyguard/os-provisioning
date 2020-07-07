#Requires -RunAsAdministrator
# Ensure our dependencies are present
. "$PSScriptRoot\dependencies.ps1"

# Import the provisioning module
Import-Module "$PSScriptRoot\Provisioning\Provisioning.psm1"

$env:PackerFilesPath = (get-item "$PSScriptRoot\..\packer")