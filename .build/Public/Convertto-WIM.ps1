<#
.SYNOPSIS
    Converts packer VMDK output into a WIM.
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
function ConvertTo-WIM 
{
    [CmdletBinding()]
    param
    (
        # The path to the file that Packer has generated
        [Parameter(Mandatory = $true)]
        [string]
        $PackerOutput,

        # The path to where the WIM should be stored
        [Parameter(Mandatory = $true)]
        [string]
        $WIMPath,

        # Operating System
        [Parameter(Mandatory = $true)]
        [ValidateSet('Server 2019', 'Windows 10', 'Server 2016', 'Server 2012r2', 'Server 2012')]
        [String]
        $OperatingSystem,
        
        # This acts as a way of differentiating different WIM images that use the same Operating System
        # eg setting this to 'Standard' with $OperatingSystem set to 'Server 2019' would result in a WIM titled: 'Server-2019-Standard.WIM'
        [Parameter(Mandatory = $false)]
        [String]
        $OSIndentifier,

        # The location to where VirtualBox is installed
        [Parameter(Mandatory = $false)]
        [String]
        $VBoxLocation = 'C:\Program Files\Oracle\VirtualBox'
    )
    $VBoxManage = "$VboxLocation\VBoxManage.exe"
    if (!(Test-Path $VBoxManage))
    {
        throw "Couldn't fine VBoxManage.exe in $VboxLocation"
    }
    if ($WimPath.ToLower() -match '\.wim$')
    {
        throw "WimPath should be a directory, not a WIM image"
    }
    $VMDKName = Split-Path $PackerOutput -Leaf
    $PackerFile = Get-ChildItem $PackerOutput -Filter "*.vmdk" | Select-Object -ExpandProperty FullName
    If ($PackerFile.count -gt 1)
    {
        throw "Too many VMDKs in $PackerOutput, expected 1 got $($PackerFile.count)"
    }
    Write-Host "Converting $VMDKName to WIM"

    $TempDirName = ( -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count 8 | ForEach-Object { [char]$_ }))
    $TempDir = "$PSScriptRoot\..\output\$TempDirName"
    $Count = 0
    while ((Test-Path $TempDir) -and $Count -lt 10) 
    {
        Write-Verbose "Temp directory $TempDir already exists, choosing another name."
        $Count = $Count + 1
        $TempDirName = ( -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count 8 | ForEach-Object { [char]$_ }))
        $TempDir = "$PSScriptRoot\..\output\$TempDirName"
    }
    if ($Count -ge 10)
    {
        throw "Failed to create a unique temp directory."
    }

    Write-Verbose "Creating temp directory $TempDir"
    try
    {
        New-Item $TempDir -ItemType Directory -ErrorAction Stop | Out-Null
    }
    catch
    {
        throw "Failed to create Temp dir.$($_.Exception.Message)"
    }
    # This will be used to form our filenames
    $OSString = $OperatingSystem
    if ($OSIndentifier)
    {
        $OSString += "-$OSIndentifier"
    }
    $OSString = $OSString.Replace(' ', '-')
    $VHDPath = "$TempDir\$OSString.vhd"
    $MountPath = "$TempDir\Mount"
    $DateString = (Get-Date -Format yyyy-MM-dd).ToString()
    $WIMOutput = "$WimPath\$OSString.WIM"
    Write-Verbose "Creating temporary mount at $MountPath to be used for the WIM"
    try
    {
        New-Item $MountPath -ItemType Directory -ErrorAction Stop | Out-Null
    }
    catch
    {
        throw "Failed to create temp mount directory.$($_.Exception.Message)"
    }
    Write-Verbose "Running VBoxManage to convert VMDK to VHD"
    $Proc = Start-Process $VBoxManage -ArgumentList "clonehd $PackerFile $VHDPath --format vhd" -NoNewWindow -PassThru -Wait
    if ($Proc.ExitCode -ne 0)
    {
        Remove-Item $TempDir -Force -Recurse -ErrorAction SilentlyContinue
        throw "Failed to convert to VHD - Unexpected exit code: $($Proc.ExitCode).`n$($Proc.StandardError)"
    }
    Write-Verbose "Mounting $VHDPath to $MountPath"
    try
    {
        Mount-WindowsImage -ImagePath $VHDPath -Path $MountPath -Index 1 -ErrorAction Stop | Out-Null
    }
    catch
    {
        Remove-Item $TempDir -Force -Recurse -ErrorAction SilentlyContinue
        throw "Failed to mount VHD.$($_.Exception.Message)"
    }
    Write-Verbose "Creating a WIM from mounted VHD"
    if ((Test-Path $WIMOutput))
    {
        try
        {
            Remove-Item $WIMOutput -Confirm:$false -ErrorAction Stop
        }
        catch
        {
            "Unable to remove existing WIM.`n$($_.Exception.Message)"
        }
    }
    try
    {
        New-WindowsImage -CapturePath $MountPath -Name $OSString -ImagePath $WIMOutput -Description "$OSString Created: $DateString" -Verify -ErrorAction Stop | Out-Null
    }
    catch
    {
        Dismount-WindowsImage -Path $MountPath -Discard -ErrorAction SilentlyContinue
        Remove-Item $TempDir -Force -Recurse -ErrorAction SilentlyContinue
        throw "Failed to create WIM.`n$($_.Exception.Message)"
    }
    Write-Verbose "Dismounting VHD from $MountPath"
    try
    {
        Dismount-WindowsImage -Path $MountPath -Discard -ErrorAction Stop | Out-Null
    }
    catch
    {
        throw "Failed to dismount WIM. Manual cleanup fo $TempDir will be required.`n$($_.Exception.Message)"
    }
    Write-Verbose "Starting clean-up of temporary files"
    Write-Verbose "Removing $MountPath"
    try
    {
        Remove-Item $MountPath -Force -Recurse -Confirm:$false -ErrorAction Stop
    }
    catch
    {
        Write-Warning "Failed to cleanup temporary mount path.$($_.Exception.Message)"
    }
    Write-Verbose "Removing $VHDPath"
    try
    {
        Remove-Item $VHDPath -Force -Confirm:$false -ErrorAction Stop
    }
    catch
    {
        Write-Warning "Failed to clear out VHD.$($_.Exception.Message)"
    }
    Write-Verbose "Running VBoxManage to remove $VHDPath"
    $Remove = Start-Process $VBoxManage -ArgumentList "closemedium $vhdpath" -PassThru -NoNewWindow -Wait -ErrorAction Stop
    if ($Remove.ExitCode -ne 0)
    {
        Write-Warning "VboxManage returned exit code: $($Remove.ExitCode).`n$($Remove.StandardError)"
    }
    try
    {
        Remove-Item $TempDir -Recurse -Force -Confirm:$false 
    }
    catch
    {
        Write-Warning "Failed to remove tempdir $TempDir. Manual cleanup required."
    }
    Return $WIMOutput
}