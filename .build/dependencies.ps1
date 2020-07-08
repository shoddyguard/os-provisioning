#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Simple script for ensuring the dependencies for the build tasks are installed and working.
#>
[CmdletBinding()]
param ()
Write-Host "Ensuring dependencies are installed"
$requirements = @{
    mdt        = 'latest'
    virtualbox = 'latest'
    packer     = 'latest'
}
$AcceptedExitCodes = @(0,1641,3010)
Write-Verbose "Checking Chocolatey is available"
try
{
    # Cast to variable to stop superflous stdout
    $choco = Get-Command choco -ErrorAction stop
}
catch
{
    throw "Chocolatey not available, please ensure Chocolatey is installed"
}
foreach ($requirement in $requirements.GetEnumerator())
{
    Write-Verbose "Checking $($requirement.key) $($requirement.value) installed"
    $InstallCheck = choco list $requirement.key --local-only -r -e
    if ($InstallCheck)
    {
        Write-Verbose "$($requirement.key) already installed"
        $VersionCheck = $InstallCheck -replace ("^$($requiremnet.key)\|")
        $AvailableVersion = (choco list $requirement.key -r -e) -replace ("^$($requiremnet.key)\|")
    }
    else
    {
        Write-Verbose "$($requirement.key) requires installation"
        $installargs = @('install', $requirement.key,'-y')
        if ($requirement.value -ne 'latest')
        {
            $installargs += "--version $($requirement.value)"
        }
        Write-Debug "Install parameters:`n$($installargs)"
        $installresult = Start-Process "choco" -ArgumentList $installargs -PassThru -NoNewWindow -Wait
        if ($installresult.ExitCode -notin $AcceptedExitCodes)
        {
            throw "failed to install $($requirement.key)"
        }
        # move on to the next
        continue
    }
    if (($requirement.value -eq 'latest') -and ($VersionCheck -ne $AvailableVersion))
    {
        Write-Verbose "Version $VersionCheck installed, but $AvailableVersion is available, attempting to upgrade"
        $updateresult = Start-Process "choco" -ArgumentList "upgrade $($requirement.key) -y" -PassThru -NoNewWindow -Wait
        if ($updateresult.ExitCode -notin $AcceptedExitCodes)
        {
            throw "failed to upgrade $($requirement.key)"
        }
    } 
}