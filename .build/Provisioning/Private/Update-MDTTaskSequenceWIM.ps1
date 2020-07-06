<#
.SYNOPSIS
    Updates the XML in a task sequence to ensure the new value replaces the old.
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
function Update-MDTTaskSequencWIM
{
    [CmdletBinding()]
    param
    (
        # The GUID of the WIM you want to search for
        [Parameter(Mandatory = $true)]
        [string]
        $OldWIMGUID,

        # Parameter help description
        [Parameter(Mandatory = $true)]
        [string]
        $NewWIMGUID,

        # The path to the deployment share
        [Parameter(Mandatory = $true)]
        [string]
        $MDTDeploymentShare,

        # The parent folder containing the task sequences
        [Parameter(Mandatory = $false)]
        [string]
        $TaskSequenceFolder = 'Control',

        # The credentials to use if required
        [Parameter(Mandatory = $false)]
        [pscredential]
        $Credential
    )
    $PSDriveName = 'MDTShare'
    Write-Verbose "Checking for presence of $OldWIMGUID in task sequences"
    # Old method
    # $TaskSequenceFolders = Get-ChildItem "$MDTDeploymentShare\$TaskSequenceFolder" | Where-Object {$_.PSIsContainer -eq $true }
    $PSDriveParams = @{
        Name        = $PSDriveName
        PSProvider  = 'FileSystem'
        Root        = $MDTDeploymentShare
        ErrorAction = 'Stop'
    }
    if ($Credential)
    {
        $PSDriveParams.Add('Credential',$Credential)
    }
    try
    {
        New-PSDrive @PSDriveParams
    }
    catch
    {
        throw "Failed to connect to deployment share.$($_.Exception.Message)"
    }
    $TaskSequences = Get-ChildItem -Path "$($PSDriveName):\$TaskSequenceFolder" -Recurse -Filter "ts.xml"
    if ($ErrorActionPreference -eq 'Stop' -and !($TaskSequences))
    {
        Remove-PSDrive $PSDriveName -ErrorAction SilentlyContinue
        throw "No task sequences found"
    }
    foreach ($TaskSequence in $TaskSequences)
    {
        Write-Verbose "Checking $($TaskSequence.PSPath)"
        try
        {
            $TSXML = [xml](Get-Content $TaskSequence.PSPath)  
        }
        catch
        {
            Remove-PSDrive $PSDriveName -ErrorAction SilentlyContinue
            throw "Failed to get task sequence XML"
        }
        if (!$TSXML)
        {
            Remove-PSDrive $PSDriveName -ErrorAction SilentlyContinue
            throw "Task Sequence XML Appears to be blank"
        }
        $OSGUID = $TSXML.sequence.globalVarList.variable | Where-Object { $_.name -eq "OSGUID" } | Select-Object "#text"
        if ($OSGUID."#text" -contains $OldWIMGUID)
        {
            Write-Verbose "Found $OldWIMGUID in $($TaskSequence.PSPath) updating to $NewWIMGUID"
            $TSXML.sequence.globalVarList.variable | Where-Object { $_.name -eq "OSGUID" } | ForEach-Object { $_."#text" = $NewWIMGUID }
            $TSXML.sequence.group | Where-Object { $_.Name -eq "Install" } | ForEach-Object { $_.step } | Where-Object {
                $_.Name -eq "Install Operating System" } | ForEach-Object { $_.defaultVarList.variable } | Where-Object {
                $_.name -eq "OSGUID" } | ForEach-Object { $_."#text" = $NewWIMGUID }
            $TSXML.Save(($TaskSequence.PSPath | Convert-Path))
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