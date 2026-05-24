param(
    [string]$Repository = "arcanuum/nova",
    [string]$Version = "0.9.1",
    [string]$Branch = "main",
    [string]$ReleaseNotes = "Nova 0.9.1: event center, command teaching, voice confidence, fallback actions, improved onboarding, and updated voice HUD.",
    [string]$SigningPfxPath = "",
    [string]$SigningCertificateThumbprint = "",
    [string]$SigningCertificateSubject = ""
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$logDir = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")) "data\logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logPath = Join-Path $logDir "publish_github_release_last.log"

try {
    Start-Transcript -Path $logPath -Force | Out-Null
    $script = Join-Path $PSScriptRoot "publish_github_release.ps1"
    $publishArgs = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $script,
        "-Repository", $Repository,
        "-Version", $Version,
        "-Branch", $Branch,
        "-ReleaseNotes", $ReleaseNotes
    )
    if ($SigningPfxPath) {
        $publishArgs += @("-SigningPfxPath", $SigningPfxPath)
    } elseif ($SigningCertificateThumbprint) {
        $publishArgs += @("-SigningCertificateThumbprint", $SigningCertificateThumbprint)
    } elseif ($SigningCertificateSubject) {
        $publishArgs += @("-SigningCertificateSubject", $SigningCertificateSubject)
    }
    & powershell.exe @publishArgs
} catch {
    Write-Host ""
    Write-Host "Publish failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
} finally {
    try { Stop-Transcript | Out-Null } catch {}
}

Write-Host ""
Write-Host "Log: $logPath"
Read-Host "Press Enter to close"
