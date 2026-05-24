param(
    [Parameter(Mandatory=$true)][string]$Repository,
    [string]$Version = "0.9.1",
    [string]$Channel = "stable",
    [string]$Branch = "",
    [string]$ReleaseNotes = "",
    [string]$SigningPfxPath = "",
    [string]$SigningCertificateThumbprint = "",
    [string]$SigningCertificateSubject = "",
    [string]$SigningTimestampUrl = "http://timestamp.digicert.com",
    [switch]$CreateRepo,
    [switch]$Private,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$OutputDir = Join-Path $Root "outputs\installer"
$PackagePath = Join-Path $OutputDir "NovaAssistant-portable.zip"
$BootstrapperPath = Join-Path $OutputDir "NovaSetupOnline.exe"
$ManifestPath = Join-Path $OutputDir "update_manifest.json"
$ManifestRepoPath = "releases/$Channel/update_manifest.json"

function Get-Token {
    $token = [Environment]::GetEnvironmentVariable("GH_TOKEN")
    if (-not $token) {
        $token = [Environment]::GetEnvironmentVariable("GITHUB_TOKEN")
    }
    if (-not $token) {
        $token = [Environment]::GetEnvironmentVariable("GH_TOKEN", "User")
    }
    if (-not $token) {
        $token = [Environment]::GetEnvironmentVariable("GITHUB_TOKEN", "User")
    }
    if (-not $token) {
        $token = [Environment]::GetEnvironmentVariable("GH_TOKEN", "Machine")
    }
    if (-not $token) {
        $token = [Environment]::GetEnvironmentVariable("GITHUB_TOKEN", "Machine")
    }
    if (-not $token) {
        Write-Host "GH_TOKEN/GITHUB_TOKEN is not set."
        Write-Host "Paste a GitHub token with Contents: Read and write. Input is hidden."
        $secure = Read-Host "GitHub token" -AsSecureString
        if ($secure.Length -gt 0) {
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
            try {
                $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
            } finally {
                if ($bstr -ne [IntPtr]::Zero) {
                    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
                }
            }
        }
    }
    if (-not $token) {
        throw "Set GH_TOKEN/GITHUB_TOKEN or paste a token when prompted."
    }
    $token = $token.Trim()
    return $token
}

function Invoke-GitHubJson {
    param(
        [string]$Method,
        [string]$Uri,
        $Body = $null,
        [switch]$Allow404
    )
    $headers = @{
        Authorization = "Bearer $script:Token"
        Accept = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
        "User-Agent" = "NovaAssistantReleasePublisher"
    }
    try {
        if ($null -eq $Body) {
            return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers
        }
        $json = $Body | ConvertTo-Json -Depth 20
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -Body $bytes -ContentType "application/json; charset=utf-8"
    } catch {
        $status = 0
        if ($_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
        }
        if ($Allow404 -and $status -eq 404) {
            return $null
        }
        if ($status -eq 403) {
            Write-Host ""
            Write-Host "GitHub returned 403 Forbidden." -ForegroundColor Yellow
            Write-Host "For fine-grained tokens, select repository arcanuum/nova and set Repository permissions -> Contents -> Read and write." -ForegroundColor Yellow
            Write-Host ""
        }
        if ($status -eq 401) {
            Write-Host ""
            Write-Host "GitHub returned 401 Unauthorized. The token is invalid, expired, or copied incorrectly." -ForegroundColor Yellow
            Write-Host ""
        }
        throw
    }
}

function Invoke-GitHubUpload {
    param(
        [string]$Uri,
        [string]$Path,
        [string]$ContentType
    )
    $headers = @{
        Authorization = "Bearer $script:Token"
        Accept = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
        "User-Agent" = "NovaAssistantReleasePublisher"
    }
    return Invoke-RestMethod -Method Post -Uri $Uri -Headers $headers -InFile $Path -ContentType $ContentType
}

function Remove-ReleaseAssetIfExists {
    param($Release, [string]$Name)
    $asset = $Release.assets | Where-Object { $_.name -eq $Name } | Select-Object -First 1
    if ($asset) {
        Invoke-GitHubJson -Method Delete -Uri $asset.url | Out-Null
    }
}

if ($Repository -notmatch "^[^/]+/[^/]+$") {
    throw "Repository must look like owner/name."
}
if (-not (Test-Path $PackagePath)) {
    throw "Package not found: $PackagePath. Run build_installer.ps1 first."
}

$owner, $repo = $Repository.Split("/", 2)
$tag = if ($Version.StartsWith("v")) { $Version } else { "v$Version" }
$plainVersion = $Version.TrimStart("v")
$releaseName = "Nova Assistant $plainVersion"
$notes = if ($ReleaseNotes) { $ReleaseNotes } else { "Nova Assistant release $plainVersion" }
$assetBase = "https://github.com/$Repository/releases/download/$tag"
$packageUrl = "$assetBase/NovaAssistant-portable.zip"
$rawManifestUrl = "https://raw.githubusercontent.com/$Repository/$Branch/$ManifestRepoPath"

if (-not $Branch) {
    $rawManifestUrl = ""
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $PackagePath).Hash.ToLowerInvariant()
$manifest = [ordered]@{
    version = $plainVersion
    channel = $Channel
    mandatory = $false
    notes = $notes
    package = [ordered]@{
        url = $packageUrl
        sha256 = $hash
        size = (Get-Item $PackagePath).Length
    }
}
[System.IO.File]::WriteAllText($ManifestPath, ($manifest | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))

if ($DryRun) {
    Write-Host "DRY RUN"
    Write-Host "Repository: $Repository"
    Write-Host "Tag:        $tag"
    Write-Host "Package:    $PackagePath"
    Write-Host "Manifest:   $ManifestPath"
    Write-Host "Package URL:$packageUrl"
    Write-Host "Branch:     $Branch"
    return
}

$script:Token = Get-Token

if ($CreateRepo) {
    $existing = Invoke-GitHubJson -Method Get -Uri "https://api.github.com/repos/$Repository" -Allow404
    if (-not $existing) {
        $visibilityPrivate = [bool]$Private
        Invoke-GitHubJson -Method Post -Uri "https://api.github.com/user/repos" -Body @{
            name = $repo
            private = $visibilityPrivate
            auto_init = $true
            description = "Nova Assistant desktop releases and updates"
        } | Out-Null
        Start-Sleep -Seconds 2
    }
}

$repoInfo = Invoke-GitHubJson -Method Get -Uri "https://api.github.com/repos/$Repository"
if (-not $Branch) {
    $Branch = [string]$repoInfo.default_branch
}
$rawManifestUrl = "https://raw.githubusercontent.com/$Repository/$Branch/$ManifestRepoPath"

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools\build_online_bootstrapper.ps1") -ManifestUrl $rawManifestUrl
if (-not (Test-Path $BootstrapperPath)) {
    throw "Bootstrapper was not created: $BootstrapperPath"
}
if ($SigningPfxPath -or $SigningCertificateThumbprint -or $SigningCertificateSubject) {
    $signArgs = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $Root "tools\sign_windows_release.ps1"),
        "-Files", $BootstrapperPath,
        "-TimestampUrl", $SigningTimestampUrl
    )
    if ($SigningPfxPath) {
        $signArgs += @("-PfxPath", $SigningPfxPath)
    } elseif ($SigningCertificateThumbprint) {
        $signArgs += @("-CertificateThumbprint", $SigningCertificateThumbprint)
    } elseif ($SigningCertificateSubject) {
        $signArgs += @("-CertificateSubject", $SigningCertificateSubject)
    }
    & powershell.exe @signArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Signing NovaSetupOnline.exe failed with exit code $LASTEXITCODE"
    }
}

$release = Invoke-GitHubJson -Method Get -Uri "https://api.github.com/repos/$Repository/releases/tags/$tag" -Allow404
if (-not $release) {
    $release = Invoke-GitHubJson -Method Post -Uri "https://api.github.com/repos/$Repository/releases" -Body @{
        tag_name = $tag
        name = $releaseName
        body = $notes
        draft = $false
        prerelease = $false
    }
}

$release = Invoke-GitHubJson -Method Get -Uri "https://api.github.com/repos/$Repository/releases/tags/$tag"
Remove-ReleaseAssetIfExists -Release $release -Name "NovaAssistant-portable.zip"
Remove-ReleaseAssetIfExists -Release $release -Name "NovaSetupOnline.exe"
Remove-ReleaseAssetIfExists -Release $release -Name "update_manifest.json"

$uploadBase = $release.upload_url -replace "\{\?name,label\}", ""
Invoke-GitHubUpload -Uri ($uploadBase + "?name=NovaAssistant-portable.zip") -Path $PackagePath -ContentType "application/zip" | Out-Null
Invoke-GitHubUpload -Uri ($uploadBase + "?name=NovaSetupOnline.exe") -Path $BootstrapperPath -ContentType "application/octet-stream" | Out-Null
Invoke-GitHubUpload -Uri ($uploadBase + "?name=update_manifest.json") -Path $ManifestPath -ContentType "application/json" | Out-Null

$content = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($ManifestPath))
$existingManifest = Invoke-GitHubJson -Method Get -Uri "https://api.github.com/repos/$Repository/contents/$ManifestRepoPath`?ref=$Branch" -Allow404
$body = @{
    message = "Update Nova $Channel manifest to $plainVersion"
    content = $content
    branch = $Branch
}
if ($existingManifest -and $existingManifest.sha) {
    $body.sha = $existingManifest.sha
}
Invoke-GitHubJson -Method Put -Uri "https://api.github.com/repos/$Repository/contents/$ManifestRepoPath" -Body $body | Out-Null

Write-Host "Published Nova Assistant $plainVersion"
Write-Host "Release:        https://github.com/$Repository/releases/tag/$tag"
Write-Host "Installer:      $assetBase/NovaSetupOnline.exe"
Write-Host "Update manifest:$rawManifestUrl"
