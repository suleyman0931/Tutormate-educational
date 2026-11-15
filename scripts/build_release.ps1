param(
    [string]$BuildName,
    [string]$BuildNumber,
    [switch]$NoSplit
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $repoRoot "pubspec.yaml"
$apkDir = Join-Path $repoRoot "build\app\outputs\flutter-apk"

if (-not (Test-Path -LiteralPath $pubspecPath)) {
    throw "pubspec.yaml not found at $pubspecPath"
}

$pubspec = Get-Content -LiteralPath $pubspecPath -Raw
if ($pubspec -notmatch '(?m)^version:\s*([^\s#]+)') {
    throw "Could not read version from pubspec.yaml"
}

$version = $Matches[1]
$versionName = $version.Split('+')[0]
if ($BuildName) {
    $versionName = $BuildName
}

$flutterArgs = @("build", "apk", "--release")
if (-not $NoSplit) {
    $flutterArgs += "--split-per-abi"
}
if ($BuildName) {
    $flutterArgs += @("--build-name", $BuildName)
}
if ($BuildNumber) {
    $flutterArgs += @("--build-number", $BuildNumber)
}

Push-Location -LiteralPath $repoRoot
try {
    & flutter @flutterArgs
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build failed with exit code $LASTEXITCODE"
    }

    if (-not (Test-Path -LiteralPath $apkDir)) {
        throw "APK output directory not found: $apkDir"
    }

    Get-ChildItem -LiteralPath $apkDir -Filter "TutorMate-*.apk" | Remove-Item -Force
    Get-ChildItem -LiteralPath $apkDir -Filter "TutorMate-*.apk.sha1" | Remove-Item -Force

    $pattern = if ($NoSplit) { "app-release.apk" } else { "app-*-release.apk" }
    $apks = @(Get-ChildItem -LiteralPath $apkDir -Filter $pattern)
    if ($apks.Count -eq 0) {
        throw "No release APKs found in $apkDir"
    }

    foreach ($apk in $apks) {
        $suffix = $apk.BaseName -replace '^app', '' -replace '-release$', ''
        $newName = "TutorMate-$versionName$suffix.apk"
        $newPath = Join-Path $apkDir $newName

        Move-Item -LiteralPath $apk.FullName -Destination $newPath -Force

        $oldSha = "$($apk.FullName).sha1"
        if (Test-Path -LiteralPath $oldSha) {
            Remove-Item -LiteralPath $oldSha -Force
        }

        $hash = (Get-FileHash -LiteralPath $newPath -Algorithm SHA1).Hash.ToLowerInvariant()
        [System.IO.File]::WriteAllText("$newPath.sha1", $hash)

        Write-Output "Built $(Join-Path 'build\app\outputs\flutter-apk' $newName)"
    }
}
finally {
    Pop-Location
}
