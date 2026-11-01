$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
$workflowPath = Join-Path $repoRoot '.github/workflows/release.yml'
$workflowLines = Get-Content -LiteralPath $workflowPath
$stepIndex = [Array]::IndexOf($workflowLines, '      - name: Publish GitHub release')
if ($stepIndex -lt 0) { throw 'Publish GitHub release step was not found' }

$runIndex = -1
for ($index = $stepIndex + 1; $index -lt $workflowLines.Count; $index++) {
  if ($workflowLines[$index] -eq '        run: |') {
    $runIndex = $index
    break
  }
}
if ($runIndex -lt 0) { throw 'Publish GitHub release script was not found' }

$scriptLines = [System.Collections.Generic.List[string]]::new()
for ($index = $runIndex + 1; $index -lt $workflowLines.Count; $index++) {
  $line = $workflowLines[$index]
  if ($line.Length -gt 0 -and -not $line.StartsWith('          ')) { break }
  if ($line.Length -eq 0) {
    $scriptLines.Add('')
  } else {
    $scriptLines.Add($line.Substring(10))
  }
}
if ($scriptLines.Count -eq 0) { throw 'Publish GitHub release script was empty' }

$versionStepIndex = [Array]::IndexOf($workflowLines, '      - name: Validate release version')
if ($versionStepIndex -lt 0) { throw 'Validate release version step was not found' }
$versionRunIndex = -1
for ($index = $versionStepIndex + 1; $index -lt $workflowLines.Count; $index++) {
  if ($workflowLines[$index] -eq '        run: |') {
    $versionRunIndex = $index
    break
  }
}
if ($versionRunIndex -lt 0) { throw 'Validate release version script was not found' }
$versionScriptLines = [System.Collections.Generic.List[string]]::new()
for ($index = $versionRunIndex + 1; $index -lt $workflowLines.Count; $index++) {
  $line = $workflowLines[$index]
  if ($line.Length -gt 0 -and -not $line.StartsWith('          ')) { break }
  if ($line.Length -eq 0) {
    $versionScriptLines.Add('')
  } else {
    $versionScriptLines.Add($line.Substring(10))
  }
}

$versionTestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "zmd-version-policy-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $versionTestRoot | Out-Null
$versionScript = Join-Path $versionTestRoot 'validate-version.ps1'
Set-Content -LiteralPath $versionScript -Value $versionScriptLines -Encoding utf8
$expectedVersion = ([regex]::Match((Get-Content (Join-Path $repoRoot 'build.zig') -Raw), '(?m)^const app_version = "([^"]+)";\s*$')).Groups[1].Value
$previousLocation = Get-Location
$previousTag = $env:GITHUB_REF_NAME
try {
  Set-Location $repoRoot
  $env:GITHUB_REF_NAME = "v$expectedVersion"
  & $versionScript
  $env:GITHUB_REF_NAME = 'v999.0.0'
  $mismatchRejected = $false
  try { & $versionScript } catch { $mismatchRejected = $true }
  if (-not $mismatchRejected) { throw 'Version mismatch was not rejected' }
  $env:GITHUB_REF_NAME = "v$expectedVersion-rc.1"
  $prereleaseRejected = $false
  try { & $versionScript } catch { $prereleaseRejected = $true }
  if (-not $prereleaseRejected) { throw 'Prerelease tag was not rejected' }
} finally {
  Set-Location $previousLocation
  $env:GITHUB_REF_NAME = $previousTag
  Remove-Item -LiteralPath $versionTestRoot -Recurse -Force
}

$assetNames = @(
  'zmd-setup-windows-x86_64.exe',
  'zmd-setup-windows-x86_64.exe.sha256'
)

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Invoke-PublishScenario {
  param(
    [Parameter(Mandatory)] [string]$Name,
    [bool]$ReleaseExists = $false,
    [bool]$ReleaseIsDraft = $false,
    [hashtable]$ExistingAssets = @{},
    [int]$FailAfterUploadCount = 0,
    [bool]$ExpectFailure = $false
  )

  $scenarioRoot = Join-Path ([System.IO.Path]::GetTempPath()) "zmd-release-policy-$Name-$([guid]::NewGuid())"
  $workDir = Join-Path $scenarioRoot 'work'
  $runnerTemp = Join-Path $scenarioRoot 'runner'
  New-Item -ItemType Directory -Path $workDir, $runnerTemp | Out-Null
  $publishScript = Join-Path $scenarioRoot 'publish.ps1'
  Set-Content -LiteralPath $publishScript -Value $scriptLines -Encoding utf8

  $localAssets = @{
    $assetNames[0] = [System.Text.Encoding]::UTF8.GetBytes("$Name executable")
    $assetNames[1] = [System.Text.Encoding]::ASCII.GetBytes("$Name checksum`n")
  }
  foreach ($asset in $assetNames) {
    [System.IO.File]::WriteAllBytes((Join-Path $workDir $asset), $localAssets[$asset])
  }

  $state = @{
    Exists = $ReleaseExists
    IsDraft = $ReleaseIsDraft
    Assets = @{}
    Events = [System.Collections.Generic.List[string]]::new()
    UploadCount = 0
  }
  foreach ($entry in $ExistingAssets.GetEnumerator()) {
    $state.Assets[$entry.Key] = [byte[]]$entry.Value
  }

  function gh {
    param([Parameter(ValueFromRemainingArguments)] [string[]]$GhArgs)

    $action = "$($GhArgs[0]) $($GhArgs[1])"
    switch ($action) {
      'release view' {
        if (-not $state.Exists) {
          $global:LASTEXITCODE = 1
          return
        }
        $global:LASTEXITCODE = 0
        return (@{ isDraft = $state.IsDraft } | ConvertTo-Json -Compress)
      }
      'release create' {
        $notesIndex = [Array]::IndexOf($GhArgs, '--notes')
        if ($notesIndex -lt 0 -or $GhArgs[$notesIndex + 1] -notmatch 'Code signing policy: https://github\.com/GomGomi907/zmd/blob/main/docs/SIGNING\.md') {
          throw 'New release is missing its code signing policy link'
        }
        $state.Exists = $true
        $state.IsDraft = $true
        $state.Events.Add('create-draft')
        $global:LASTEXITCODE = 0
        return
      }
      'release download' {
        $patternIndex = [Array]::IndexOf($GhArgs, '--pattern')
        $dirIndex = [Array]::IndexOf($GhArgs, '--dir')
        $asset = $GhArgs[$patternIndex + 1]
        if (-not $state.Assets.ContainsKey($asset)) {
          $global:LASTEXITCODE = 1
          return
        }
        $destination = Join-Path $GhArgs[$dirIndex + 1] $asset
        [System.IO.File]::WriteAllBytes($destination, $state.Assets[$asset])
        $state.Events.Add("download:$asset")
        $global:LASTEXITCODE = 0
        return
      }
      'release upload' {
        for ($index = 3; $index -lt $GhArgs.Count; $index++) {
          $asset = $GhArgs[$index]
          $state.Assets[$asset] = [System.IO.File]::ReadAllBytes((Join-Path $workDir $asset))
          $state.UploadCount++
          $state.Events.Add("upload:$asset")
          if ($FailAfterUploadCount -gt 0 -and $state.UploadCount -ge $FailAfterUploadCount) {
            $global:LASTEXITCODE = 1
            return
          }
        }
        $global:LASTEXITCODE = 0
        return
      }
      'release edit' {
        $state.IsDraft = $false
        $state.Events.Add('publish')
        $global:LASTEXITCODE = 0
        return
      }
      default { throw "Unexpected gh invocation: $($GhArgs -join ' ')" }
    }
  }

  $previousLocation = Get-Location
  $previousTag = $env:GITHUB_REF_NAME
  $previousRunnerTemp = $env:RUNNER_TEMP
  $failed = $false
  try {
    Set-Location $workDir
    $env:GITHUB_REF_NAME = 'v9.8.7'
    $env:RUNNER_TEMP = $runnerTemp
    try {
      & $publishScript
    } catch {
      $failed = $true
    }
  } finally {
    Set-Location $previousLocation
    $env:GITHUB_REF_NAME = $previousTag
    $env:RUNNER_TEMP = $previousRunnerTemp
    Remove-Item -LiteralPath $scenarioRoot -Recurse -Force
  }

  Assert-True ($failed -eq $ExpectFailure) "$Name failure result did not match expectation"
  return @{ State = $state; LocalAssets = $localAssets }
}

$newRelease = Invoke-PublishScenario -Name 'new'
Assert-True $newRelease.State.Exists 'new release was not created'
Assert-True (-not $newRelease.State.IsDraft) 'verified new release was not published'
Assert-True ($newRelease.State.Events[0] -eq 'create-draft') 'new release was not created as a draft first'
Assert-True ($newRelease.State.Events[$newRelease.State.Events.Count - 1] -eq 'publish') 'new release was published before verification completed'
foreach ($asset in $assetNames) {
  Assert-True ([System.Linq.Enumerable]::SequenceEqual[byte]($newRelease.State.Assets[$asset], $newRelease.LocalAssets[$asset])) "new release asset differs: $asset"
}

$identicalAssets = @{}
$identicalAssets[$assetNames[0]] = [System.Text.Encoding]::UTF8.GetBytes('identical executable')
$identicalAssets[$assetNames[1]] = [System.Text.Encoding]::ASCII.GetBytes("identical checksum`n")
$identical = Invoke-PublishScenario -Name 'identical' -ReleaseExists $true -ExistingAssets $identicalAssets
Assert-True (-not ($identical.State.Events -match '^upload:')) 'identical rerun uploaded an asset'
Assert-True (-not ($identical.State.Events -contains 'publish')) 'published release was edited during identical rerun'

$differentAssets = @{}
$differentAssets[$assetNames[0]] = [System.Text.Encoding]::UTF8.GetBytes('old executable')
$differentAssets[$assetNames[1]] = [System.Text.Encoding]::ASCII.GetBytes("different checksum`n")
$different = Invoke-PublishScenario -Name 'different' -ReleaseExists $true -ExistingAssets $differentAssets -ExpectFailure $true
Assert-True (-not ($different.State.Events -match '^upload:')) 'mismatched release asset was overwritten'
Assert-True (-not ($different.State.Events -contains 'publish')) 'mismatched release was edited'

$partial = Invoke-PublishScenario -Name 'partial' -FailAfterUploadCount 1 -ExpectFailure $true
Assert-True $partial.State.Exists 'partial upload did not retain the draft release'
Assert-True $partial.State.IsDraft 'partially uploaded release was made public'
Assert-True (-not ($partial.State.Events -contains 'publish')) 'partial upload reached publication'

$global:LASTEXITCODE = 0
Write-Output 'release workflow policy tests passed'
