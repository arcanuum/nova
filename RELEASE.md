# Nova Assistant Release

## Build

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build_installer.ps1 -BuildExe -CleanBuild -CreatePortableZip -OnlineBootstrapper -SkipInno -Version 0.9.1
```

Artifacts are created in `outputs\installer`:

- `NovaAssistant-portable.zip` - application package for GitHub Release.
- `NovaSetupOnline.exe` - small online installer.
- `update_manifest.json` - updater manifest.

## Publish to GitHub

Create a GitHub token with repository contents and releases access. The safer publisher asks for the token in a hidden prompt:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\publish_github_release_prompt.ps1
```

The publisher uploads the ZIP to a GitHub Release, writes the stable updater manifest to:

```text
releases/stable/update_manifest.json
```

and rebuilds `NovaSetupOnline.exe` with the raw GitHub manifest URL.

## Current Stable

- Version: `0.9.1`
- Release: `https://github.com/arcanuum/nova/releases/tag/v0.9.1`
- Online installer: `https://github.com/arcanuum/nova/releases/download/v0.9.1/NovaSetupOnline.exe`
- Portable package: `https://github.com/arcanuum/nova/releases/download/v0.9.1/NovaAssistant-portable.zip`
- Update manifest: `https://raw.githubusercontent.com/arcanuum/nova/main/releases/stable/update_manifest.json`

## Code Signing

Install the Windows SDK so `signtool.exe` is available. For production, use a trusted code-signing certificate or Microsoft Azure Artifact Signing. A self-signed certificate is useful only for local tests and will not remove SmartScreen warnings for other users.

Typical PFX signing command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\sign_windows_release.ps1 -PfxPath C:\certs\nova-code-signing.pfx
```

Certificate from the Windows certificate store:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\sign_windows_release.ps1 -CertificateThumbprint YOUR_CERT_THUMBPRINT
```

Verify only:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\sign_windows_release.ps1 -VerifyOnly
```

Recommended release order with signing:

1. Build `dist\NovaAssistant\NovaAssistant.exe`.
2. Sign `dist\NovaAssistant\NovaAssistant.exe`.
3. Rebuild the portable ZIP and manifest from the signed `dist` folder.
4. Build and sign `outputs\installer\NovaSetupOnline.exe`.
5. Publish the signed assets and updated manifest.

Signed publish with a PFX certificate:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\publish_github_release_prompt.ps1 -Version 0.9.1 -SigningPfxPath C:\certs\nova-code-signing.pfx
```

Signed publish with a certificate thumbprint:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\publish_github_release_prompt.ps1 -Version 0.9.1 -SigningCertificateThumbprint YOUR_CERT_THUMBPRINT
```

## Prod Checklist

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\release_check.ps1 -Clean
```

- Confirm `outputs\installer\NovaAssistant-portable.zip` SHA256 matches `outputs\installer\update_manifest.json`.
- Confirm the raw GitHub manifest points to the same release ZIP and SHA256.
- Smoke-test the ZIP by extracting it and checking `NovaAssistant.exe`, `install_nova.ps1`, `uninstall_nova.ps1`, and `installer\update_nova.ps1`.
- Keep `NovaSetupOnline.exe` small; it downloads the portable package from the release during installation.
- For a fully trusted Windows release, sign `NovaSetupOnline.exe` and `NovaAssistant.exe` with a code-signing certificate.
