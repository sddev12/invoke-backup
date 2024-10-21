<#
.SYNOPSIS
  This script copies the contents of specified input folders to the specified output folder

.DESCRIPTION
  The script reads in a json config file in which you declare the input folders you would like to copy the contents of
  and the output folder to copy the content to. 

  The config file should be structured as below where inputs declare the folders to copy from and output declares the foler to copy to:

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

#TODO: Switch to using yaml config file as it is cleaner than having to write json
function Read-ConfigFile($ConfigFile) {
  if (-not(Test-Path $ConfigFile)) {
    Write-Error "Config file does not exist`n"
    exit 1
  }

  $jsonConfig = Get-Content -Path $ConfigFile
  if ($jsonConfig.Length -eq 0) {
    Write-Error "Empty config file provided"
    exit 1
  }

  try {
    $parsedConfigFile = $jsonConfig | ConvertFrom-Json
  }
  catch {
    Write-Error ("Config file is not valid Json: {0}" -f $_)
    exit 1
  }
  return $parsedConfigFile
}

function Test-InputFolders($InputFolders) {
  foreach ($folder in $InputFolders) {
    if (-not(Test-Path $folder)) {
      Write-Error ("Input folder {0} does not exist`n" -f $folder)
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
  foreach ($folder in $Config.inputs) {
    # Build outpath
    $outFolder = Split-Path -Path $folder -Leaf
    $outPath = "{0}\{1}" -f $Config.output, $outFolder
    Write-Host ("Copying contents of {0} to {1}`n" -f $folder, $outPath) -ForegroundColor Cyan
    try {
      Copy-Item -Path $folder -Destination $outPath -Recurse -Force
      Write-Host ("Copy of {0} to {1} successful`n" -f $folder, $outPath) -ForegroundColor Green
    }
    catch {
      Write-Error ("Failed to backup {0}: {1}`n" -f $folder, $_)
      exit 1
    }
  }
}

## Main Execution - Start

# Read and parse Json config file
$Config = Read-ConfigFile -ConfigFile $ConfigFile

# Validate input and output folders
Test-InputFolders -InputFolders $config.inputs
Test-OutputFolder -OutputFolder $config.output

Write-Host "`nInput and output folders validated`n" -ForegroundColor Green

# Start backup
Copy-Content -Config $Config

Write-Host "Backup successful" -ForegroundColor Green