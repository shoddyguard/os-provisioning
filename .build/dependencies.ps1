<#
.SYNOPSIS
    Simple scr
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
#Requires -RunAsAdministrator
$requirements = @{
    mdt        = 'latest'
    virtualbox = 'latest'
    packer     = 'latest'
}
$AcceptedExitCodes = @(0,1641,3010)
try
{
    Get-Command choco -ErrorAction stop
}
catch
{
    throw "Chocolatey not available, please ensure Chocolatey is installed"
}
foreach ($requirement in $requirements.GetEnumerator())
{
    $InstallCheck = choco list $requirement.key --local-only -r -e
    if ($InstallCheck)
    {
        $VersionCheck = $InstallCheck -replace ("^$($requiremnet.key)\|")
    }
    else
    {
        $installargs = @('install', $requirement.key)
        if ($requirement.value -ne 'latest')
        {
            $installargs += "--version $($requirement.value)"
        }
        $installresult = Start-Process "choco" -ArgumentList $installargs -PassThru -NoNewWindow -Wait
        if ($installresult.ExitCode -notin $AcceptedExitCodes)
        {
            throw "failed to install $($requirement.key)"
        }
    }
    if (($requirement.value -eq 'latest') -and ($VersionCheck -ne $requirement.value))
    {
        $updateresult = Start-Process "choco" -ArgumentList "update $($requirement.key)" -PassThru -NoNewWindow -Wait
        if ($updateresult.ExitCode -notin $AcceptedExitCodes)
        {
            throw "failed to update $($requirement.key)"
        }
    }
}