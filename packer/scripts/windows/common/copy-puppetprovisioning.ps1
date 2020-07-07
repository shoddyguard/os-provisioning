<#
.SYNOPSIS
    Copies the latest PowerShell script from my Puppet Provisioning repo.
.DESCRIPTION
    Seeing as many of these builds will end up being Puppeted it's useful to copy this now to save time later.
#>

New-Item "$env:SystemDrive\scripts" -ItemType Directory

# Seeing as most servers get Puppeted this will save us some time
$url = 'https://raw.githubusercontent.com/shoddyguard/Puppet-Provisioning/master/puppet-windows.ps1'
$output = "$env:SystemDrive\scripts\puppet-windows.ps1"
(New-Object System.Net.WebClient).DownloadFile($url, $output)