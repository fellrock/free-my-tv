# Build the current local checkout and install it on the TV.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$build = Join-Path $repo 'webos\build.py'
$install = Join-Path $repo 'webos\install-windows.ps1'
if (-not (Test-Path $install)) { throw 'Save install-windows.ps1 in the webos folder first.' }

$buildArgs = @($build)
if (-not (Test-Path (Join-Path $repo 'config.properties'))) {
    Write-Host 'No personal configuration found; building with TV time-zone defaults.'
    $buildArgs += '--generic'
} else {
    Write-Host 'Building with your existing config.properties.'
}

if (Get-Command py -ErrorAction SilentlyContinue) {
    & py -3 @buildArgs
} elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
    & python3 @buildArgs
} else {
    throw 'Python 3 was not found. Install it and try again.'
}
if ($LASTEXITCODE -ne 0) { throw "Build failed with exit code $LASTEXITCODE. The TV was not updated." }

& $install
