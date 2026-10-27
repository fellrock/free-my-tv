# Run from the repository root in PowerShell. The installer asks for the TV's
# passphrase interactively; do not put it in this script.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $repo 'webos\install.py'
if (-not (Test-Path $installer)) { throw 'Cannot find webos/install.py.' }

$privateTemp = Join-Path $env:TEMP ('freemytv-' + [guid]::NewGuid())
$oldTemp = $env:TEMP
$oldTmp = $env:TMP
New-Item -ItemType Directory -Path $privateTemp | Out-Null
try {
    $account = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    & icacls.exe $privateTemp /inheritance:r /grant:r "${account}:(OI)(CI)F" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not secure the temporary folder.' }
    $env:TEMP = $privateTemp
    $env:TMP = $privateTemp

    Write-Host 'When prompted below, type the passphrase shown on your TV and press Enter.'
    Write-Host 'Your typing will not be displayed.'
    if (Get-Command py -ErrorAction SilentlyContinue) {
        & py -3 $installer '10.0.0.130'
    } elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
        & python3 $installer '10.0.0.130'
    } else {
        throw 'Python 3 was not found. Install it and try again.'
    }
    if ($LASTEXITCODE -ne 0) { throw "The installer failed with exit code $LASTEXITCODE." }
} finally {
    $env:TEMP = $oldTemp
    $env:TMP = $oldTmp
    Remove-Item -LiteralPath $privateTemp -Recurse -Force -ErrorAction SilentlyContinue
}
