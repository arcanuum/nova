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

## Prod Checklist

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\release_check.ps1 -Clean
```

- Confirm `outputs\installer\NovaAssistant-portable.zip` SHA256 matches `outputs\installer\update_manifest.json`.
- Confirm the raw GitHub manifest points to the same release ZIP and SHA256.
- Smoke-test the ZIP by extracting it and checking `NovaAssistant.exe`, `install_nova.ps1`, `uninstall_nova.ps1`, and `installer\update_nova.ps1`.
- Keep `NovaSetupOnline.exe` small; it downloads the portable package from the release during installation.
- For a fully trusted Windows release, sign `NovaSetupOnline.exe` and `NovaAssistant.exe` with a code-signing certificate.
