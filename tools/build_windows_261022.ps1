param(
    [string]$GodotExe = $env:GODOT_ROMANCE_EXE,
    [string]$ReleaseTemplate = $env:GODOT_ROMANCE_RELEASE_TEMPLATE
)
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$projectText = Get-Content -LiteralPath (Join-Path $projectDirectory 'project.godot') -Raw
if ($projectText -notmatch 'config/version="0\.1\.0"') {
    throw 'This packager targets v0.1.0. Development builds use the editor or run_game_261022.cmd; prepare the next release package in stage 35.'
}
$exportDirectory = Join-Path $projectDirectory 'builds/Windows_261022'
$exportBinary = Join-Path $exportDirectory 'AfterTheRain_261022.exe'
if (-not $GodotExe) {
    $GodotExe = Join-Path $projectDirectory '../Game_Edu_step1/.tools/Godot_261021/Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $GodotExe)) { throw 'Set GODOT_ROMANCE_EXE to Godot 4.7.2 Standard.' }
$versionOutput = & $GodotExe --version
if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch '^4\.7\.2\.stable') { throw 'This build requires Godot 4.7.2 stable Standard.' }
$localTemplate = Join-Path $projectDirectory '.tools/windows_templates_261022/windows_release_x86_64.exe'
if (-not (Test-Path -LiteralPath $localTemplate)) {
    if (-not $ReleaseTemplate) {
        $templateCandidates = @(
            (Join-Path $projectDirectory '../Game_Edu_step1/.tools/windows_templates_261021/windows_release_x86_64.exe'),
            (Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable/windows_release_x86_64.exe')
        )
        $ReleaseTemplate = $templateCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }
    if (-not $ReleaseTemplate -or -not (Test-Path -LiteralPath $ReleaseTemplate)) { throw 'Set GODOT_ROMANCE_RELEASE_TEMPLATE to the matching Windows x86_64 release template.' }
    New-Item -ItemType Directory -Path (Split-Path -Parent $localTemplate) -Force | Out-Null
    Copy-Item -LiteralPath $ReleaseTemplate -Destination $localTemplate
}
New-Item -ItemType Directory -Path $exportDirectory -Force | Out-Null
& $GodotExe --headless --path $projectDirectory --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
& $GodotExe --headless --path $projectDirectory --script res://tools/export_notices_261022.gd
if ($LASTEXITCODE -ne 0) { throw 'Engine notice generation failed.' }
& $GodotExe --headless --path $projectDirectory --export-release 'Windows Desktop' $exportBinary
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exportBinary)) { throw 'Windows export failed.' }
Copy-Item -LiteralPath (Join-Path $projectDirectory 'distribution/PLAY_261022.txt') -Destination $exportDirectory
Copy-Item -LiteralPath (Join-Path $projectDirectory 'distribution/RELEASE_NOTES_261022.md') -Destination $exportDirectory
Copy-Item -LiteralPath (Join-Path $projectDirectory 'distribution/licenses') -Destination $exportDirectory -Recurse -Force
Copy-Item -LiteralPath (Join-Path $projectDirectory 'assets/fonts/NotoSansKR_OFL_261022.txt') -Destination (Join-Path $exportDirectory 'licenses')
Copy-Item -LiteralPath (Join-Path $projectDirectory 'assets/ASSET_SOURCES_261022.md') -Destination (Join-Path $exportDirectory 'licenses')
$manifest = [ordered]@{ version = '0.1.0'; built_on = '2026-10-22'; engine = $versionOutput.Trim(); architecture = 'x86_64'; files = @() }
foreach ($file in Get-ChildItem -LiteralPath $exportDirectory -File -Recurse | Where-Object { $_.Name -ne 'BUILD_MANIFEST_261022.json' }) {
    $manifest.files += [ordered]@{ path = [IO.Path]::GetRelativePath($exportDirectory, $file.FullName).Replace('\','/'); bytes = $file.Length; sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }
}
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $exportDirectory 'BUILD_MANIFEST_261022.json') -Encoding utf8
$zipFile = Join-Path $projectDirectory 'builds/AfterTheRain_Windows_v0.1.0_261022.zip'
Compress-Archive -Path (Join-Path $exportDirectory '*') -DestinationPath $zipFile -CompressionLevel Optimal -Force
$hash = (Get-FileHash -LiteralPath $zipFile -Algorithm SHA256).Hash
Set-Content -LiteralPath (Join-Path $projectDirectory 'builds/SHA256SUMS_261022.txt') -Value ($hash + '  ' + (Split-Path -Leaf $zipFile)) -Encoding ascii
Write-Output ('Windows package: ' + $zipFile)
Write-Output ('SHA256: ' + $hash)
