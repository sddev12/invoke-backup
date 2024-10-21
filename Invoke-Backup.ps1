<#
.SYNOPSIS
  This script copies the contents of specified input folders to the specified output folder

.DESCRIPTION
  The script reads in a json config file in which you declare the input folders you would like to copy the contents of
  and the output folder to copy the content to. 

  The config file should be structured as below where inputs declare the folders to copy from and output declares the folder to copy to:

  {
    "inputs": [
      "<Path to first folder>",
      "<path to second folder>",
      "..."
    ],
    "output": "<path to destination folder>"
  }

.PARAMETER ConfigFile
  Path to your config file

.EXAMPLE
  .\Invoke-Backup.ps1 -ConfigFile <PATH_TO_CONFIG_FILE>
#>

[CmdletBinding()]
param (
  [Parameter(Mandatory)]
  [string]
  $ConfigFile
)

$ErrorActionPreference = 'Stop'

function Remove-TrailingBackslash($Config) {
  for ($i = 0; $i -lt $Config.inputs.Length; $i++) {
    if ($Config.inputs[$i] -like "*\") {
      $Config.inputs[$i] = $Config.inputs[$i].TrimEnd('\')
    }
  }

  return $Config
}

#TODO: Switch to using yaml config file as it is cleaner than having to write json
function Read-ConfigFile($ConfigFile) {
  if (-not(Test-Path $ConfigFile)) {
    Write-Error ("Config file {0} does not exist`n" -f $ConfigFile)
    exit 1
  }

  $JsonConfig = Get-Content -Path $ConfigFile
  if ($JsonConfig.Length -eq 0) {
    Write-Error "Empty config file provided"
    exit 1
  }

  try {
    $Config = $JsonConfig | ConvertFrom-Json
  }
  catch {
    Write-Error ("Config file is not valid Json: {0}" -f $_)
    exit 1
  }

  $Config = Remove-TrailingBackslash -Config $Config

  return $Config
}

function Test-InputFolders($InputFolders) {
  foreach ($Folder in $InputFolders) {
    if (-not(Test-Path $Folder)) {
      Write-Error ("Input folder {0} does not exist`n" -f $Folder)
      exit 1
    }
  }
}

function Test-OutputFolder($OutputFolder) {
  if (-not(Test-Path $OutputFolder)) {
    try {
      Write-Host "`nOutput folder not found. Attempting to create output folder...`n" -ForegroundColor Cyan
      New-Item -ItemType File -Path $OutputFolder
      Write-Host "Output folder created successfully`n" -ForegroundColor Green
    }
    catch {
      Write-Error ("Cannot create output folder: {0}`n" -f $_)
      exit 1
    }
  }
}

#TODO: Implement multi-threading using PowerShell Jobs as this is slow for large sets of files
function Copy-Content($Config) {
  foreach ($Folder in $Config.inputs) {
    # Build outpath
    $OutFolder = Split-Path -Path $Folder -Leaf
    $OutPath = "{0}\{1}" -f $Config.output, $OutFolder
    Write-Host ("Copying contents of {0} to {1}`n" -f $Folder, $OutPath) -ForegroundColor Cyan
    try {
      Copy-Item -Path $Folder -Destination $OutPath -Recurse -Force
      Write-Host ("Copy of {0} to {1} successful`n" -f $Folder, $OutPath) -ForegroundColor Green
    }
    catch {
      Write-Error ("Failed to backup {0}: {1}`n" -f $Folder, $_)
      exit 1
    }
  }
}

## Main Execution - Start

# Read and parse Json config file
$Config = Read-ConfigFile -ConfigFile $ConfigFile

# Validate input and output folders
Test-InputFolders -InputFolders $Config.inputs
Test-OutputFolder -OutputFolder $Config.output

Write-Host "`nInput and output folders validated`n" -ForegroundColor Green

# Start backup
Copy-Content -Config $Config

Write-Host "Backup successful" -ForegroundColor Green