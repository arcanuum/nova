param(
    [string[]]$Files = @(
        "dist\NovaAssistant\NovaAssistant.exe",
        "outputs\installer\NovaAssistant\NovaAssistant.exe",
        "outputs\installer\NovaSetupOnline.exe"
    ),
    [string]$PfxPath = "",
    [string]$PfxPassword = "",
    [string]$CertificateThumbprint = "",
    [string]$CertificateSubject = "",
    [string]$TimestampUrl = "http://timestamp.digicert.com",
    [switch]$VerifyOnly
)

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch {}

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Find-SignTool {
    $cmd = Get-Command "signtool.exe" -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $kitRoot = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\bin"
    if (Test-Path -LiteralPath $kitRoot) {
        $candidate = Get-ChildItem -LiteralPath $kitRoot -Recurse -Filter "signtool.exe" -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match "\\x64\\signtool\.exe$" } |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($candidate) { return $candidate.FullName }
    }

    throw "signtool.exe not found. Install Windows SDK and rerun this script."
}

function Resolve-ReleaseFile {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Read-HiddenPassword {
    $fromEnv = [Environment]::GetEnvironmentVariable("NOVA_SIGN_PFX_PASSWORD")
    if ($fromEnv) { return $fromEnv }

    $secure = Read-Host "PFX password" -AsSecureString
    if ($secure.Length -eq 0) { return "" }

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        if ($bstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
}

function Invoke-SignTool {
    param([string[]]$Arguments)
    & $script:SignTool @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "signtool failed with exit code $LASTEXITCODE"
    }
}

$script:SignTool = Find-SignTool
Write-Host "SignTool: $script:SignTool"

$targets = @()
foreach ($file in $Files) {
    $resolved = Resolve-ReleaseFile $file
    if (Test-Path -LiteralPath $resolved) {
        $targets += $resolved
    } else {
        Write-Host "Skip missing: $resolved" -ForegroundColor Yellow
    }
}
$targets = $targets | Select-Object -Unique
if (-not $targets) {
    throw "No files to sign or verify."
}

if ($VerifyOnly) {
    foreach ($target in $targets) {
        Write-Host "Verify: $target"
        Invoke-SignTool -Arguments @("verify", "/pa", "/v", $target)
    }
    return
}

$signingArgs = @("sign", "/v", "/fd", "SHA256", "/tr", $TimestampUrl, "/td", "SHA256", "/d", "Nova Assistant", "/du", "https://github.com/arcanuum/nova")

if ($PfxPath) {
    $fullPfx = Resolve-ReleaseFile $PfxPath
    if (-not (Test-Path -LiteralPath $fullPfx)) {
        throw "PFX not found: $fullPfx"
    }
    if (-not $PfxPassword) {
        $PfxPassword = Read-HiddenPassword
    }
    $signingArgs += @("/f", $fullPfx)
    if ($PfxPassword) {
        $signingArgs += @("/p", $PfxPassword)
    }
} elseif ($CertificateThumbprint) {
    $signingArgs += @("/sha1", $CertificateThumbprint)
} elseif ($CertificateSubject) {
    $signingArgs += @("/n", $CertificateSubject)
} else {
    throw "Provide -PfxPath, -CertificateThumbprint, or -CertificateSubject."
}

foreach ($target in $targets) {
    Write-Host "Sign: $target"
    Invoke-SignTool -Arguments ($signingArgs + @($target))
    Write-Host "Verify: $target"
    Invoke-SignTool -Arguments @("verify", "/pa", "/v", $target)
}

Write-Host "Signing completed."
