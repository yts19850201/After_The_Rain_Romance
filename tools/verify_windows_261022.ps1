param([switch]$CaptureScreenshots)
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$zipFile = Join-Path $projectDirectory 'builds/AfterTheRain_Windows_v0.1.0_261022.zip'
$expectedHash = ((Get-Content -LiteralPath (Join-Path $projectDirectory 'builds/SHA256SUMS_261022.txt') -Raw).Trim() -split '\s+')[0]
$actualHash = (Get-FileHash -LiteralPath $zipFile -Algorithm SHA256).Hash
if ($expectedHash -ne $actualHash) { throw 'Package checksum mismatch.' }
$qaParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$qaDirectory = [IO.Path]::GetFullPath((Join-Path $qaParent ('AfterTheRain_QA_' + [guid]::NewGuid().ToString('N').Substring(0,8) + '_261022')))
if (-not $qaDirectory.StartsWith($qaParent, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected QA path.' }
if (Test-Path -LiteralPath $qaDirectory) { throw 'QA path already exists.' }
New-Item -ItemType Directory -Path $qaDirectory | Out-Null
$checks = @()
try {
    Expand-Archive -LiteralPath $zipFile -DestinationPath $qaDirectory
    $manifest = Get-Content -LiteralPath (Join-Path $qaDirectory 'BUILD_MANIFEST_261022.json') -Raw | ConvertFrom-Json
    foreach ($file in $manifest.files) {
        $filePath = [IO.Path]::GetFullPath((Join-Path $qaDirectory $file.path))
        if (-not $filePath.StartsWith($qaDirectory + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Package manifest contains an invalid path.' }
        if ((Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash -ne $file.sha256) { throw ('Packaged file mismatch: ' + $file.path) }
    }
    foreach ($mode in @('write', 'read', 'render')) {
        if ($mode -eq 'render' -and -not $CaptureScreenshots) { continue }
        $logFile = Join-Path $qaDirectory ('verify_' + $mode + '_261022.log')
        $arguments = @('--fixed-fps','60','--quit-after','4000','--log-file',('"'+$logFile+'"'))
        if ($mode -ne 'render') { $arguments = @('--headless') + $arguments }
        $dataFolder = Join-Path $qaDirectory $(if ($mode -eq 'render') { 'render_data' } else { 'qa_data' })
        $arguments += @('--','--verify-release','--qa-data',('"'+$dataFolder+'"'))
        if ($mode -eq 'read') { $arguments += '--read' }
        if ($mode -eq 'render') {
            $screenshots = Join-Path $projectDirectory 'distribution/screenshots'
            New-Item -ItemType Directory -Path $screenshots -Force | Out-Null
            $arguments += @('--screenshots',('"'+$screenshots+'"'))
        }
        $process = Start-Process -FilePath (Join-Path $qaDirectory 'AfterTheRain_261022.exe') -ArgumentList $arguments -WorkingDirectory $qaDirectory -WindowStyle Hidden -PassThru
        if (-not $process.WaitForExit(30000)) { $process.Kill(); throw ('Package verification timed out: ' + $mode) }
        $log = Get-Content -LiteralPath $logFile -Raw
        if ($process.ExitCode -ne 0 -or $log -notmatch 'RELEASE_SMOKE: PASS' -or $log -match '(SCRIPT ERROR|ERROR:)') { throw ('Package verification failed: ' + $mode + "`n" + $log) }
        $checks += [ordered]@{ mode = $mode; passed = $true; result = 'RELEASE_SMOKE: PASS (0 failures)' }
        Write-Output ('Package verification ' + $mode + ': PASS')
    }
    $report = [ordered]@{ verified_on = '2026-10-22'; version = '0.1.0'; archive_sha256 = $actualHash; separate_extracted_folder = $true; editor_required = $false; verified_manifest_files = $manifest.files.Count; checks = $checks; human_reading_minutes = $null; external_player_feedback = 'not_collected' }
    $report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $projectDirectory 'distribution/validation_results_261022.json') -Encoding utf8
} finally {
    # This exact, newly created directory is the only recursive deletion target.
    $resolvedQa = [IO.Path]::GetFullPath($qaDirectory)
    if ($resolvedQa.StartsWith($qaParent, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $resolvedQa) -match '^AfterTheRain_QA_[a-f0-9]{8}_261022$') {
        Remove-Item -LiteralPath $resolvedQa -Recurse -Force
    }
}
