function Write-Log
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true)]
        [string] $message
    )
    $logfile = "$env:SystemDrive\packer.log"
    Add-Content $logfile -value "$(Get-Date -format s) $message"
    Write-Host $message
}

function Install-Chocolatey
{
    if (([Enum]::GetNames([Net.SecurityProtocolType]) -contains 'Tls12') -ne $true)
    {
        throw "TLS 1.2 either not supported or cannot be enabled on your system"
    }
    if (([System.Net.ServicePointManager]::SecurityProtocol.HasFlag([Net.SecurityProtocolType]::Tls12)) -ne $true)
    {
        try 
        {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        }
        catch 
        {
            throw "Failed to set TLS 1.2.`n$($_.Exception.Message)"
        }
    }
    if (([System.Net.ServicePointManager]::SecurityProtocol.HasFlag([Net.SecurityProtocolType]::Tls12)) -ne $true)
    {
        throw "Tried to set TLS 1.2 but it still isn't active."
    }
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))   
}

function Enable-WinRM 
{
    # WinRM needs to be running before you can configure WinRM...go figure
    if ((Get-Service -Name 'WinRM' | Select-Object -ExpandProperty Status) -ne 'Running')
    {
        try 
        {
            Start-Service 'WinRM'  
        }
        catch 
        {
            throw "Failed to start WinRM service."
        }
    }

    # Remove HTTP listener
    Remove-Item -Path WSMan:\Localhost\listener\listener* -Recurse -ErrorAction Ignore

    # Create a self-signed certificate to let ssl work
    $Cert = New-SelfSignedCertificate -CertstoreLocation Cert:\LocalMachine\My -DnsName "packer"
    New-Item -Path WSMan:\LocalHost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $Cert.Thumbprint -Force
    Enable-PSRemoting -Force -SkipNetworkProfileCheck

    # WinRM
    Write-Output "Setting up WinRM"
    Write-Host "(host) setting up WinRM"

    # Configure WinRM to allow unencrypted communication, and provide the
    # self-signed cert to the WinRM listener.
    winrm quickconfig -q
    winrm set "winrm/config/service" '@{AllowUnencrypted="true"}'
    winrm set "winrm/config/client" '@{AllowUnencrypted="true"}'
    winrm set "winrm/config/service/auth" '@{Basic="true"}'
    winrm set "winrm/config/client/auth" '@{Basic="true"}'
    winrm set "winrm/config/service/auth" '@{CredSSP="true"}'
    winrm set "winrm/config/listener?Address=*+Transport=HTTPS" "@{Port=`"5986`";Hostname=`"packer`";CertificateThumbprint=`"$($Cert.Thumbprint)`"}"

    # Make sure appropriate firewall port openings exist
    cmd.exe /c netsh advfirewall firewall set rule group="remote administration" new enable=yes
    New-NetFirewallRule -DisplayName 'WinRM (HTTPS)' -LocalPort 5986 -Direction Inbound -Protocol TCP -Action Allow

    # Restart WinRM, and set it so that it auto-launches on startup.
    if ((Get-Service -Name 'WinRM' | Select-Object -ExpandProperty Status) -eq 'Running')
    {
        Stop-Service 'WinRM'
    }
    Set-Service 'WinRM' -StartupType Automatic
    Start-Service 'WinRM'   
}