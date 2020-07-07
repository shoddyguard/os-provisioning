<#
.SYNOPSIS
    Starts a Packer build
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
function Invoke-PackerBuild
{
    [CmdletBinding()]
    param
    (
        # The name of the Packer template file to build.
        [Parameter(Mandatory = $true)]
        [string]
        $TemplateName,

        # The path to the ISO file (supports same formats as packer)
        [Parameter(Mandatory = $true)]
        [string]
        $ISOURL,

        # The checksum for the ISO, optional - helps to ensure peace of mind
        [Parameter(Mandatory = $false)]
        [string]
        $ISOChecksum,

        # The checksum type to use, default is to let Packer work it out itself but can be overriden if that doesn't work
        [Parameter(Mandatory = $false)]
        [string]
        $ISOChecksumType,

        # Any additonal variables you'd like to pass to Packer
        [Parameter(Mandatory = $false)]
        [array]
        $PackerVariables,

        # The directory that contains all the Packer templates
        [Parameter(Mandatory = $false)]
        [string]
        $TemplateDirectory = "$env:PackerFilesPath\packer_templates",

        # The output directory to use
        [Parameter(Mandatory = $false)]
        [string]
        $OutputPath = "$env:PackerFilesPath\output"
    )
    if (!(Test-Path $TemplateDirectory))
    {
        throw "Template directory $TemplateDirectory does not exist"
    }
    if (!(Test-Path $OutputPath))
    {
        throw "Output directory $OutputPath does not exist"
    }
    if ($TemplateName -match ".json$")
    {
        Write-Verbose "Correcting template name."
        $TemplateName = $TemplateName -replace ".json$", ''
    }
    Write-Verbose "Searching for template file $TemplateName.json in $TemplateDirectory and subfolders"
    try
    {
        $TemplatePath = Get-ChildItem $TemplateDirectory -Filter "$TemplateName.json" -Recurse -ErrorAction Stop
    }
    catch
    {
        throw "Failed to get template.`n$($_.Exception.Message)"
    }
    if (!$TemplatePath)
    {
        throw "No templates found."
    }
    # With how we currently have our naming set-up we could indeed get multiple templates with the same name.
    # We will need to come up with a better way of filtering this in the future - perhaps drop "windows-" from the start of the template and have it start "sysprepped-" or similar?
    if ($TemplatePath.count -gt 1)
    {
        throw "Too many templates returned, expected: 1, got: $($TemplatePath.count)"
    }
    $OutputDirectory = "$OutputPath\$TemplateName"
    $Vars = @("iso_url=$ISOURL","output_directory=$OutputDirectory")
    if ($ISOChecksum)
    {
        if ($ISOChecksumType)
        {
            $Vars += "iso_checksum=$($ISOChecksumType):$ISOChecksum"
        }
        else
        {
            $Vars += "iso_checksum=$ISOChecksum"
        }
    }
    if ($PackerVariables)
    {
        # Woule be nice to just remove these in future, but for now we'll throw an exception.
        foreach ($PackerVariable in $PackerVariables)
        {
            if ($PackerVariable -match "(^\`"|^\')|(\`"$|\'$)")
            {
                throw "Variable $PackerVariable appears to contain $($Matches.0), variables must not start/end with a single/double quotation or contain -var."
            }
        }
        $Vars += $PackerVariables
    }
    $PackerArgs = @("build")
    foreach ($Var in $Vars)
    {
        $PackerArgs += "-var `"$var`""
    }
    $PackerArgs += (Convert-Path $TemplatePath.PSPath).ToString()
    Write-Debug "Packer arguments:`n$PackerArgs"
    try
    {
        $PackerProc = Start-Process "packer" -ArgumentList $PackerArgs -Wait -PassThru -NoNewWindow -ErrorAction Stop
    }
    catch
    {
        throw "Failed to start Packer.$($_.Exception.Message)"
    }
    if ($PackerProc.ExitCode -ne 0)
    {
        throw "Packer returned a non-zero exit code: $($PackerProc.ExitCode).`nstderr: $($PackerProc.StandardError)"
    }
    if (!(Test-Path $OutputDirectory))
    {
        throw "$OutputDirectory appears to be missing"
    }
    Return $OutputDirectory
}