#Requires -RunAsAdministrator
# Ensure our dependencies are present
. "$PSScriptRoot\dependencies.ps1"

# Import the provisioning module
Import-Module "$PSScriptRoot\Provisioning\Provisioning.psm1"

Write-Host "This is a test: %env.test_string%"