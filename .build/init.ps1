#Requires -RunAsAdministrator
# Ensure our dependencies are present
"$PSScriptRoot\dependencies.ps1"

# Import the provisioning module
Import-Module '.\Provisioning\Provisioning.psm1'
