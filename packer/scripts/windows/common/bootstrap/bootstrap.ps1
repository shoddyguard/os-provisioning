Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force -ErrorAction Ignore
$ErrorActionPreference = 'Stop'

# dot source our functions
. a:\functions.ps1

Install-Chocolatey


### THIS SHOULD ALWAYS BE THE LAST STEP ###
Enable-WinRM
### This is because once WinRM is enabled it signals packer to continue on with provisioning. ###