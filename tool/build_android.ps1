param([string]$JavaDirectory)

$ErrorActionPreference = 'Stop'
$rideWorkspace = Split-Path -Parent $PSScriptRoot
$previousJava = $env:JAVA_HOME
$previousPath = $env:PATH

function Test-RideJava([string]$directory) {
    if (!$directory -or !(Test-Path -LiteralPath (Join-Path $directory 'bin\java.exe'))) { return $false }
    $versionText = (& (Join-Path $directory 'bin\java.exe') --version | Out-String)
    return $versionText -match '(?:openjdk|java)\s+(\d+)' -and [int]$Matches[1] -ge 21
}

if (!$JavaDirectory) {
    foreach ($candidate in @($env:JAVA_HOME, 'C:\Program Files\Android\Android Studio\jbr')) {
        if (Test-RideJava $candidate) { $JavaDirectory = $candidate; break }
    }
}
if (!(Test-RideJava $JavaDirectory)) {
    throw 'MapLibre requires JDK 21+. Pass -JavaDirectory with the path to a compatible JDK.'
}

Push-Location $rideWorkspace
try {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency/plugin setup failed.' }
    $env:JAVA_HOME = $JavaDirectory
    $env:PATH = (Join-Path $JavaDirectory 'bin') + ';' + $previousPath
    Push-Location (Join-Path $rideWorkspace 'android')
    try {
        & .\gradlew.bat "-Dorg.gradle.java.home=$JavaDirectory" '--console=plain' 'assembleDebug'
        if ($LASTEXITCODE -ne 0) { throw 'Android build failed.' }
    } finally { Pop-Location }
    Write-Output (Join-Path $rideWorkspace 'build\app\outputs\flutter-apk\app-debug.apk')
} finally {
    $env:JAVA_HOME = $previousJava
    $env:PATH = $previousPath
    Pop-Location
}
