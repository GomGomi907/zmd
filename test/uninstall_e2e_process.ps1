param(
  [Parameter(Mandatory)] [string]$FixtureExe,
  [Parameter(Mandatory)] [string]$HoldExe
)

$ErrorActionPreference = 'Stop'
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('zmd-uninstall-e2e-' + [guid]::NewGuid().ToString('N'))
$resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
if (-not $resolvedFixture.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Refusing to create an uninstall fixture outside the temporary directory'
}

$localAppData = Join-Path $fixtureRoot '한글 사용자 with space'
$installDir = Join-Path $localAppData 'Programs\zmd'
$installedExe = Join-Path $installDir 'zmd.exe'
$helperExe = Join-Path $fixtureRoot 'zmd-uninstall-helper.exe'
$personalDocument = Join-Path $installDir '개인 문서.md'
$registryRoot = 'Software\zmd-uninstall-e2e-' + [guid]::NewGuid().ToString('N')
$hold = $null
$helper = $null

try {
  New-Item -ItemType Directory -Path $installDir | Out-Null
  Copy-Item -LiteralPath $FixtureExe -Destination $installedExe
  Copy-Item -LiteralPath $FixtureExe -Destination $helperExe
  Set-Content -LiteralPath $personalDocument -Value 'keep this document' -Encoding utf8

  & $FixtureExe seed $registryRoot $installDir '9.8.7'
  if ($LASTEXITCODE -ne 0) { throw 'Could not seed isolated uninstall registration' }

  $hold = Start-Process -FilePath $HoldExe -WindowStyle Hidden -PassThru
  $helperArguments = 'apply "{0}" {1} "{2}" "{3}"' -f $registryRoot, $hold.Id, $installDir, $helperExe
  $helper = Start-Process -FilePath $helperExe -ArgumentList $helperArguments -WindowStyle Hidden -PassThru
  Start-Sleep -Milliseconds 300
  $helper.Refresh()
  if ($helper.HasExited) { throw 'Uninstall helper did not wait for its parent process' }
  if (-not (Test-Path -LiteralPath $installedExe -PathType Leaf)) { throw 'Installed executable was removed before the parent exited' }

  Stop-Process -Id $hold.Id
  [void]$hold.WaitForExit(5000)
  if (-not $helper.WaitForExit(15000)) { throw 'Timed out waiting for uninstall helper' }
  if ($helper.ExitCode -ne 0) { throw "Uninstall helper failed with exit code $($helper.ExitCode)" }
  if (Test-Path -LiteralPath $installedExe) { throw 'Installed executable remains after helper success' }
  if (-not (Test-Path -LiteralPath $personalDocument -PathType Leaf)) { throw 'Uninstall removed a personal document' }

  & $FixtureExe verify-absent $registryRoot
  if ($LASTEXITCODE -ne 0) { throw 'Owned registry entries remain after helper success' }
  Write-Output 'Uninstall helper waited for its parent, removed owned files and registration, and preserved the document.'
} finally {
  if ($helper -and -not $helper.HasExited) { Stop-Process -Id $helper.Id -Force }
  if ($hold -and -not $hold.HasExited) { Stop-Process -Id $hold.Id -Force }
  & $FixtureExe cleanup $registryRoot
  if (Test-Path -LiteralPath $resolvedFixture) {
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
  }
}
