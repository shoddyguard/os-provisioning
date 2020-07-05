<#
.SYNOPSIS
    This cmdlet allows you to create/update a given WIM image in MDT.
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
    TODO:
        Remove output folder on failuers
        Remove PSDrives on completion/failures
#>
function Update-MDTWIM
{
    [CmdletBinding()]
    param 
    (
        # The Operating System WIM you want to import
        [Parameter(Mandatory = $true)]
        [string]
        $InputWIM,

        # The path to your deployment share (can either be network or local)
        [Parameter(Mandatory = $true)]
        [String]
        $MDTDeploymentShare,

        # The path to your MDT installation if different to standard
        [Parameter(Mandatory = $false)]
        [String]
        $MDTInstallationPath = 'C:\Program Files\Microsoft Deployment Toolkit',

        # If you need different credentials to connect to the share specify those here (not configured yet)
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential
    )
    if ($InputWIM.ToLower() -notmatch '\.wim$')
    {
        throw "InputWIM should be a WIM file"
    }
    if (!(Test-Path $InputWIM))
    {
        throw "Can't find $InputWIM"
    }
    $WIMName = (Split-Path $InputWIM -Leaf) -replace '\.wim', ''
    Write-Verbose "Importing MDT PoSh module from $MDTInstallationPath"
    try 
    {
        Import-Module "$MDTInstallationPath\bin\MicrosoftDeploymentToolkit.psd1" -ErrorAction Stop    
    }
    catch 
    {
        throw "Failed to import MDT PowerShell module.`n$($_.Exception.Message)"
    }
    Write-Verbose "Connecting to $MDTDeploymentShare"
    $PSDriveName = 'MDT'
    $PSDriveParams = @{
        Name        = $PSDriveName
        Root        = $MDTDeploymentShare
        PSProvider  = 'MDTProvider'
        ErrorAction = 'Stop'
    }
    if ($Credential)
    {
        $PSDriveParams.Add('Credential', $Credential)
    }
    try
    {
        New-PSDrive @PSDriveParams | Out-Null
    }
    catch
    {
        throw "Failed to create PSDrive for the $MDTDeploymentShare.`n$($_.Exception.Message)"
    }
    $OStoRemove = Get-ChildItem -Path "$($PSDriveName):\Operating Systems" | Where-Object { $_.Name -like "$WIMName in*" } | Select-Object -ExpandProperty Name
    if ($OStoRemove.Count -gt 1)
    {
        Remove-PSDrive $PSDriveName -ErrorAction SilentlyContinue
        throw "Got too many results, expected 0 or 1 got $($OStoRemove.Count)" # debugging
    }
    if ($OStoRemove)
    {
        # We've got a pre-existing OS image so we'll need to do some stuff
        Write-Verbose "Fetching pre-existing OS GUID"
        try
        {
            $ExistingWIMGUID = (Get-ItemProperty "$($PSDriveName):\Operating Systems\$OStoRemove").guid
        }
        catch
        {
            Remove-PSDrive $PSDriveName -ErrorAction SilentlyContinue
            throw "Failed to get old WIM GUID.`n$($_.Exception.Message)"
        }
        if (!$ExistingWIMGUID)
        {
            Remove-PSDrive $PSDriveName -ErrorAction SilentlyContinue
            throw "Empty WIM GUID"
        }
        Write-Debug "ExistingWINGUID set to: $ExistingWIMGUID"
        Write-Verbose "Removing pre-existing OS $OStoRemove"
        try
        {
            Remove-Item "$($PSDriveName):\Operating Systems\$OStoRemove" -Confirm:$false -ErrorAction Stop
        }
        catch
        {
            Remove-PSDrive $PSDriveName -ErrorAction SilentlyContinue
            throw "Failed to remove pre-exisitng OS $OStoRemove.`n$($_.Exception.Message)"
        }
    }
    try
    {
        Import-MDTOperatingSystem -Path "$($PSDriveName):\Operating Systems" -SourceFile $InputWIM -DestinationFolder $WIMName -ErrorAction Stop #| Out-Null
    }
    catch
    {
        Remove-PSDrive $PSDriveName -ErrorAction SilentlyContinue
        throw "Failed to Import OS $InputWIM.`n$($_.Exception.Message)"
    }
    Write-Verbose "Fetching updated WIM GUID"
    $NewWIM = Get-ChildItem -Path "$($PSDriveName):\Operating Systems" | Where-Object { $_.Name -like "$WIMName in*" } | Select-Object -ExpandProperty Name
    if ($NewWIM.count -ne 1)
    {
        Remove-PSDrive $PSDriveName -ErrorAction SilentlyContinue
        throw "Incorrect WIM amount returned. Expected 1 got $($NewWIM.count)"
    }
    try
    {
        $NewWIMGUID = (Get-ItemProperty "$($PSDriveName):\Operating Systems\$NewWIM").guid
    }
    catch
    {
        Remove-PSDrive $PSDriveName -ErrorAction SilentlyContinue
        throw "Failed to get GUID of new WIM.`n$($_.Exception.Message)"
    }
    if (!$NewWIMGUID)
    {
        Remove-PSDrive $PSDriveName -ErrorAction SilentlyContinue
        throw "GUID of new WIM appears to be empty"
    }
    Write-Debug "NewWIMGUID set to: $NewWIMGUID"
    if ($ExistingWIMGUID)
    {
        $UpdateParams = @{
            OldWIMGUID         = $ExistingWIMGUID
            NewWIMGUID         = $NewWIMGUID
            MDTDeploymentShare = $MDTDeploymentShare
            ErrorAction        = 'Stop'
        }
        if ($Credential)
        {
            $UpdateParams.Add('Credential', $Credential)
        }
        Write-Verbose "Updating Task Sequences"
        try
        {
            Update-MDTTaskSequencWIM @UpdateParams
        }
        catch
        {
            throw "Failed to update Task Sequences.`n$($_.Exception.Message)"
        }
    }
    try
    {
        Remove-PSDrive $PSDriveName -ErrorAction Stop
    }
    catch
    {
        Write-Error "Failed to remove PSDrive $PSDriveName"
    }
}