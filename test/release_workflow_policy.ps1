$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
$workflowPath = Join-Path $repoRoot '.github/workflows/release.yml'
$workflowLines = Get-Content -LiteralPath $workflowPath
$workflowText = $workflowLines -join "`n"

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Get-StepScript([string]$StepName) {
  $stepIndex = [Array]::IndexOf($workflowLines, "      - name: $StepName")
  if ($stepIndex -lt 0) { throw "$StepName step was not found" }
  $runIndex = -1
  for ($index = $stepIndex + 1; $index -lt $workflowLines.Count; $index++) {
    if ($workflowLines[$index] -eq '        run: |') {
      $runIndex = $index
      break
    }
    if ($workflowLines[$index].StartsWith('      - ')) { break }
  }
  if ($runIndex -lt 0) { throw "$StepName script was not found" }

  $result = [System.Collections.Generic.List[string]]::new()
  for ($index = $runIndex + 1; $index -lt $workflowLines.Count; $index++) {
    $line = $workflowLines[$index]
    if ($line.Length -gt 0 -and -not $line.StartsWith('          ')) { break }
    if ($line.Length -eq 0) { $result.Add('') } else { $result.Add($line.Substring(10)) }
  }
  if ($result.Count -eq 0) { throw "$StepName script was empty" }
  return $result
}

$scriptLines = Get-StepScript 'Publish GitHub release'
$versionScriptLines = Get-StepScript 'Validate release version'
$sourceScriptLines = Get-StepScript 'Validate release source'
$configurationScriptLines = Get-StepScript 'Validate SignPath configuration'
$signedValidationScriptLines = Get-StepScript 'Validate signed installer and create checksum'

Assert-True ($workflowText -match '(?m)^\s*workflow_dispatch:\s*$') 'release workflow is not manually dispatched'
Assert-True ($workflowText -notmatch '(?m)^\s*push:\s*$') 'tag pushes must not publish a release'
Assert-True ($workflowText -match 'fetch-depth:\s*0') 'release checkout must include full history'
Assert-True ($workflowText -match '(?m)^\s*actions:\s*read\s*$') 'SignPath connector cannot read Actions metadata'
Assert-True ($workflowText -match '(?m)^\s*contents:\s*write\s*$') 'release workflow cannot publish assets'
Assert-True ($workflowText -match 'uses:\s*actions/upload-artifact@v[4-9]') 'unsigned artifact is not uploaded with upload-artifact v4+'
Assert-True ($workflowText -match 'SignPath artifact configuration must use <zip-file> as its root') 'default ZIP artifact configuration requirement is not documented'
Assert-True ($workflowText -match 'uses:\s*signpath/github-action-submit-signing-request@v3') 'SignPath v3 action is not used'
Assert-True ($workflowText -match 'github-artifact-id:\s*\$\{\{ steps\.upload-unsigned-artifact\.outputs\.artifact-id \}\}') 'SignPath does not consume the uploaded workflow artifact'
Assert-True ($workflowText -match 'output-artifact-directory:') 'signed artifact is not downloaded from SignPath'
Assert-True ($workflowText -match 'wait-for-completion-timeout-in-seconds:\s*9000') 'manual approval wait is too short or unspecified'
Assert-True ($workflowText -match 'SIGNPATH_API_TOKEN:\s*\$\{\{ secrets\.SIGNPATH_API_TOKEN \}\}') 'SignPath API token is not a repository secret'
foreach ($name in @('ORGANIZATION_ID', 'PROJECT_SLUG', 'SIGNING_POLICY_SLUG', 'ARTIFACT_CONFIGURATION_SLUG')) {
  Assert-True ($workflowText -match "SIGNPATH_${name}:\s*\`$\{\{ vars\.SIGNPATH_${name} \}\}") "SIGNPATH_$name is not a repository variable"
}

$buildIndex = $workflowText.IndexOf('zig build -Dtarget=x86_64-windows')
$uploadIndex = $workflowText.IndexOf('name: Upload unsigned artifact for SignPath')
$signIndex = $workflowText.IndexOf('name: Submit SignPath signing request')
$validateSignedIndex = $workflowText.IndexOf('name: Validate signed installer and create checksum')
$publishIndex = $workflowText.IndexOf('name: Publish GitHub release')
Assert-True ($buildIndex -ge 0 -and $buildIndex -lt $uploadIndex) 'unsigned artifact was uploaded before the release build'
Assert-True ($uploadIndex -lt $signIndex -and $signIndex -lt $validateSignedIndex -and $validateSignedIndex -lt $publishIndex) 'release signing and publication steps are out of order'

$sourceScriptText = $sourceScriptLines -join "`n"
Assert-True ($sourceScriptText -match "refs/heads/main") 'release source is not restricted to main'
Assert-True ($sourceScriptText -match 'git ls-remote --exit-code origin refs/heads/main') 'current remote main is not verified'
Assert-True ($sourceScriptText -match 'refs/tags/\$\{tag\}:refs/tags/\$\{tag\}') 'release tag is not fetched explicitly'
Assert-True ($sourceScriptText -match '\$tagSha -ne \$headSha') 'release tag is not required to point to the dispatch commit'

$signedValidationScriptText = $signedValidationScriptLines -join "`n"
Assert-True ($signedValidationScriptText -match 'Get-AuthenticodeSignature') 'signed installer Authenticode status is not checked'
Assert-True ($signedValidationScriptText -match 'SignatureStatus\]::Valid') 'only valid Authenticode signatures must be accepted'
Assert-True ($signedValidationScriptText -match 'SignPath Foundation') 'the expected SignPath Foundation publisher is not checked'
Assert-True ($signedValidationScriptText -match 'FileVersionInfo') 'signed installer version metadata is not checked'
Assert-True ($signedValidationScriptText.IndexOf('Get-FileHash') -gt $signedValidationScriptText.IndexOf('Get-AuthenticodeSignature')) 'checksum is not generated from verified signed bytes'
$publishScriptText = $scriptLines -join "`n"
Assert-True (([regex]::Matches($publishScriptText, 'Assert-ReleaseTagStillMatches')).Count -ge 3) 'release tag is not rechecked before publication'
Assert-True ($publishScriptText -match [regex]::Escape('Free code signing provided by SignPath.io, certificate by SignPath Foundation.')) 'required SignPath Foundation attribution is missing from release notes'
Assert-True ($publishScriptText -match [regex]::Escape('https://signpath.io/')) 'SignPath.io URL is missing from release notes'
Assert-True ($publishScriptText -match [regex]::Escape('https://signpath.org/')) 'SignPath Foundation URL is missing from release notes'

$versionTestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "zmd-version-policy-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $versionTestRoot | Out-Null
$versionScript = Join-Path $versionTestRoot 'validate-version.ps1'
Set-Content -LiteralPath $versionScript -Value $versionScriptLines -Encoding utf8
$expectedVersion = ([regex]::Match((Get-Content (Join-Path $repoRoot 'build.zig') -Raw), '(?m)^const app_version = "([^"]+)";\s*$')).Groups[1].Value
$previousLocation = Get-Location
$previousVersion = $env:RELEASE_VERSION
try {
  Set-Location $repoRoot
  $env:RELEASE_VERSION = $expectedVersion
  & $versionScript
  $env:RELEASE_VERSION = '999.0.0'
  $mismatchRejected = $false
  try { & $versionScript } catch { $mismatchRejected = $true }
  if (-not $mismatchRejected) { throw 'Version mismatch was not rejected' }
  $env:RELEASE_VERSION = "$expectedVersion-rc.1"
  $prereleaseRejected = $false
  try { & $versionScript } catch { $prereleaseRejected = $true }
  if (-not $prereleaseRejected) { throw 'Prerelease version was not rejected' }
} finally {
  Set-Location $previousLocation
  $env:RELEASE_VERSION = $previousVersion
  Remove-Item -LiteralPath $versionTestRoot -Recurse -Force
}

$sourceTestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "zmd-release-source-policy-$([guid]::NewGuid())"
$sourceRemote = Join-Path $sourceTestRoot 'origin.git'
$sourceRepo = Join-Path $sourceTestRoot 'work'
New-Item -ItemType Directory -Path $sourceTestRoot | Out-Null
git init --bare $sourceRemote | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Unable to create source-policy bare repository' }
git init -b main $sourceRepo | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Unable to create source-policy work repository' }
git -C $sourceRepo config user.name 'zmd policy test'
git -C $sourceRepo config user.email 'policy-test@example.invalid'
Set-Content -LiteralPath (Join-Path $sourceRepo 'source.txt') -Value 'first' -Encoding ascii
git -C $sourceRepo add source.txt
git -C $sourceRepo commit -m first | Out-Null
$firstSha = (git -C $sourceRepo rev-parse HEAD).Trim()
git -C $sourceRepo remote add origin $sourceRemote
git -C $sourceRepo push -u origin main | Out-Null
git -C $sourceRepo tag "v$expectedVersion" $firstSha
git -C $sourceRepo push origin "v$expectedVersion" | Out-Null
$sourceScript = Join-Path $sourceTestRoot 'validate-source.ps1'
Set-Content -LiteralPath $sourceScript -Value $sourceScriptLines -Encoding utf8
$previousRef = $env:GITHUB_REF
$previousRefName = $env:GITHUB_REF_NAME
$previousSha = $env:GITHUB_SHA
$previousVersion = $env:RELEASE_VERSION
$previousLocation = Get-Location
try {
  Set-Location $sourceRepo
  $env:GITHUB_REF = 'refs/heads/main'
  $env:GITHUB_REF_NAME = 'main'
  $env:GITHUB_SHA = $firstSha
  $env:RELEASE_VERSION = $expectedVersion
  & $sourceScript

  $env:GITHUB_REF = "refs/tags/v$expectedVersion"
  $wrongRefRejected = $false
  try { & $sourceScript } catch { $wrongRefRejected = $true }
  Assert-True $wrongRefRejected 'non-main workflow dispatch was not rejected'
  $env:GITHUB_REF = 'refs/heads/main'

  Set-Content -LiteralPath (Join-Path $sourceRepo 'source.txt') -Value 'second' -Encoding ascii
  git add source.txt
  git commit -m second | Out-Null
  $secondSha = (git rev-parse HEAD).Trim()
  git tag --force "v$expectedVersion" $secondSha | Out-Null
  git push --force origin "v$expectedVersion" | Out-Null
  git reset --hard $firstSha | Out-Null
  $tagMismatchRejected = $false
  try { & $sourceScript } catch { $tagMismatchRejected = $true }
  Assert-True $tagMismatchRejected 'release tag on a different commit was not rejected'

  git tag --force "v$expectedVersion" $firstSha | Out-Null
  git push --force origin "v$expectedVersion" | Out-Null
  git reset --hard $secondSha | Out-Null
  git push origin main | Out-Null
  git reset --hard $firstSha | Out-Null
  $movedMainRejected = $false
  try { & $sourceScript } catch { $movedMainRejected = $true }
  Assert-True $movedMainRejected 'dispatch commit behind current origin/main was not rejected'
} finally {
  Set-Location $previousLocation
  $env:GITHUB_REF = $previousRef
  $env:GITHUB_REF_NAME = $previousRefName
  $env:GITHUB_SHA = $previousSha
  $env:RELEASE_VERSION = $previousVersion
  Remove-Item -LiteralPath $sourceTestRoot -Recurse -Force
}

$versionTestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "zmd-signpath-policy-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $versionTestRoot | Out-Null
$configurationScript = Join-Path $versionTestRoot 'validate-signpath-configuration.ps1'
Set-Content -LiteralPath $configurationScript -Value $configurationScriptLines -Encoding utf8
$configurationNames = @(
  'SIGNPATH_API_TOKEN',
  'SIGNPATH_ORGANIZATION_ID',
  'SIGNPATH_PROJECT_SLUG',
  'SIGNPATH_SIGNING_POLICY_SLUG',
  'SIGNPATH_ARTIFACT_CONFIGURATION_SLUG'
)
$previousConfiguration = @{}
try {
  foreach ($name in $configurationNames) {
    $previousConfiguration[$name] = [Environment]::GetEnvironmentVariable($name)
    [Environment]::SetEnvironmentVariable($name, 'configured-for-policy-test')
  }
  & $configurationScript
  [Environment]::SetEnvironmentVariable('SIGNPATH_API_TOKEN', '')
  $missingConfigurationRejected = $false
  try { & $configurationScript } catch { $missingConfigurationRejected = $true }
  Assert-True $missingConfigurationRejected 'missing SignPath API token was not rejected'
} finally {
  foreach ($name in $configurationNames) {
    [Environment]::SetEnvironmentVariable($name, $previousConfiguration[$name])
  }
  Remove-Item -LiteralPath $versionTestRoot -Recurse -Force
}

$signedTestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "zmd-signed-policy-$([guid]::NewGuid())"
$signedScript = Join-Path $signedTestRoot 'validate-signed.ps1'
$signedDirectory = Join-Path $signedTestRoot 'signed'
New-Item -ItemType Directory -Path $signedDirectory | Out-Null
Set-Content -LiteralPath $signedScript -Value $signedValidationScriptLines -Encoding utf8
$previousRequestId = $env:SIGNING_REQUEST_ID
$previousSignedDirectory = $env:SIGNED_ARTIFACT_DIRECTORY
$previousVersion = $env:RELEASE_VERSION
$previousLocation = Get-Location
try {
  Set-Location $signedTestRoot
  $env:SIGNED_ARTIFACT_DIRECTORY = $signedDirectory
  $env:RELEASE_VERSION = $expectedVersion
  $env:SIGNING_REQUEST_ID = ''
  $emptyRequestRejected = $false
  try { & $signedScript } catch { $emptyRequestRejected = $true }
  Assert-True $emptyRequestRejected 'empty SignPath signing request ID was not rejected'

  $env:SIGNING_REQUEST_ID = 'policy-test-request'
  $missingSignedFileRejected = $false
  try { & $signedScript } catch { $missingSignedFileRejected = $true }
  Assert-True $missingSignedFileRejected 'missing signed installer was not rejected'

  Set-Content -LiteralPath (Join-Path $signedDirectory 'zmd-setup-windows-x86_64.exe') -Value 'unsigned test bytes' -Encoding ascii
  $unsignedFileRejected = $false
  try { & $signedScript } catch { $unsignedFileRejected = $true }
  Assert-True $unsignedFileRejected 'unsigned installer was not rejected'
} finally {
  Set-Location $previousLocation
  $env:SIGNING_REQUEST_ID = $previousRequestId
  $env:SIGNED_ARTIFACT_DIRECTORY = $previousSignedDirectory
  $env:RELEASE_VERSION = $previousVersion
  Remove-Item -LiteralPath $signedTestRoot -Recurse -Force
}

$assetNames = @(
  'zmd-setup-windows-x86_64.exe',
  'zmd-setup-windows-x86_64.exe.sha256'
)

function Invoke-PublishScenario {
  param(
    [Parameter(Mandatory)] [string]$Name,
    [bool]$ReleaseExists = $false,
    [bool]$ReleaseIsDraft = $false,
    [hashtable]$ExistingAssets = @{},
    [int]$FailAfterUploadCount = 0,
    [bool]$TagMatches = $true,
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

  function git {
    param([Parameter(ValueFromRemainingArguments)] [string[]]$GitArgs)
    if ($GitArgs[0] -eq 'fetch') {
      $global:LASTEXITCODE = 0
      return
    }
    if ($GitArgs[0] -eq 'rev-parse') {
      $global:LASTEXITCODE = 0
      if ($TagMatches) { return $env:GITHUB_SHA }
      return 'ffffffffffffffffffffffffffffffffffffffff'
    }
    throw "Unexpected git invocation: $($GitArgs -join ' ')"
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
        $notes = if ($notesIndex -ge 0) { $GhArgs[$notesIndex + 1] } else { '' }
        if (
          $notes -notmatch [regex]::Escape('Free code signing provided by SignPath.io, certificate by SignPath Foundation.') -or
          $notes -notmatch [regex]::Escape('https://signpath.io/') -or
          $notes -notmatch [regex]::Escape('https://signpath.org/') -or
          $notes -notmatch 'Code signing policy: https://github\.com/GomGomi907/zmd/blob/main/docs/SIGNING\.md'
        ) {
          throw 'New release is missing required signing attribution or policy links'
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
  $previousSha = $env:GITHUB_SHA
  $previousRunnerTemp = $env:RUNNER_TEMP
  $failed = $false
  try {
    Set-Location $workDir
    $env:GITHUB_REF_NAME = 'v9.8.7'
    $env:GITHUB_SHA = '1111111111111111111111111111111111111111'
    $env:RUNNER_TEMP = $runnerTemp
    try {
      & $publishScript
    } catch {
      $failed = $true
    }
  } finally {
    Set-Location $previousLocation
    $env:GITHUB_REF_NAME = $previousTag
    $env:GITHUB_SHA = $previousSha
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

$movedTag = Invoke-PublishScenario -Name 'moved-tag' -TagMatches $false -ExpectFailure $true
Assert-True ($movedTag.State.Events.Count -eq 0) 'release operations started after the tag moved'

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

$publishedIncompleteAssets = @{}
$publishedIncompleteAssets[$assetNames[0]] = [System.Text.Encoding]::UTF8.GetBytes('published-incomplete executable')
$publishedIncomplete = Invoke-PublishScenario -Name 'published-incomplete' -ReleaseExists $true -ExistingAssets $publishedIncompleteAssets -ExpectFailure $true
Assert-True (-not ($publishedIncomplete.State.Events -match '^upload:')) 'missing asset was added to an already published release'
Assert-True (-not ($publishedIncomplete.State.Events -contains 'publish')) 'incomplete published release was edited'

$draftIncompleteAssets = @{}
$draftIncompleteAssets[$assetNames[0]] = [System.Text.Encoding]::UTF8.GetBytes('draft-incomplete executable')
$draftIncomplete = Invoke-PublishScenario -Name 'draft-incomplete' -ReleaseExists $true -ReleaseIsDraft $true -ExistingAssets $draftIncompleteAssets
Assert-True ($draftIncomplete.State.Events -contains "upload:$($assetNames[1])") 'missing draft asset was not uploaded'
Assert-True ($draftIncomplete.State.Events[$draftIncomplete.State.Events.Count - 1] -eq 'publish') 'completed draft release was not published'

$partial = Invoke-PublishScenario -Name 'partial' -FailAfterUploadCount 1 -ExpectFailure $true
Assert-True $partial.State.Exists 'partial upload did not retain the draft release'
Assert-True $partial.State.IsDraft 'partially uploaded release was made public'
Assert-True (-not ($partial.State.Events -contains 'publish')) 'partial upload reached publication'

$global:LASTEXITCODE = 0
Write-Output 'release workflow policy tests passed'
