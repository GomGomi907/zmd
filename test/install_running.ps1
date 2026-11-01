$ErrorActionPreference = 'Stop'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('zmd-install-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
$zig = if ($env:ZMD_TEST_ZIG) { $env:ZMD_TEST_ZIG } else { 'zig' }
$probe = Join-Path $fixture 'copy-probe.exe'
$hold = Join-Path $fixture 'target.exe'
$source = (Resolve-Path 'zig-out/bin/zmd.exe').Path
& $zig build-exe --dep setup '-Mroot=test/install_copy_probe.zig' '-Msetup=src/setup.zig' "-femit-bin=$probe"
if ($LASTEXITCODE -ne 0) { throw 'Could not build installation copy probe' }
& $zig build-exe test/install_hold_target.zig "-femit-bin=$hold"
if ($LASTEXITCODE -ne 0) { throw 'Could not build running target fixture' }
$fresh = Join-Path $fixture 'fresh.exe'
& $probe $source $fresh
if ($LASTEXITCODE -ne 0 -or (Get-FileHash -LiteralPath $fresh -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash) {
    throw 'A fresh installation copy failed'
}
$process = Start-Process -FilePath $hold -WindowStyle Hidden -PassThru
try {
    & $probe $source $hold
    if ($LASTEXITCODE -ne 0) { throw 'Copying to a running executable failed' }
    $process.Refresh()
    if ($process.HasExited) { throw 'The running target was unexpectedly closed' }
    if ((Get-FileHash -LiteralPath $hold -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash) {
        throw 'The installed file differs from the source'
    }
    Write-Output 'Installation replaced the executable while the old process remained running.'
} finally {
    if (-not $process.HasExited) { Stop-Process -Id $process.Id }
}
