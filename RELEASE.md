# Nova Assistant Release

## Build

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build_installer.ps1 -BuildExe -CleanBuild -CreatePortableZip -OnlineBootstrapper -SkipInno
```

Artifacts are created in `outputs\installer`:

- `NovaAssistant-portable.zip` - application package for GitHub Release.
- `NovaSetupOnline.exe` - small online installer.
- `update_manifest.json` - updater manifest.

## Publish to GitHub

Set a GitHub token only in the current PowerShell session:

```powershell
$env:GH_TOKEN="paste_token_here"
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\publish_github_release.ps1 -Repository arcanuum/nova -Version 0.9.0
```

Stable updater manifest:

```text
https://raw.githubusercontent.com/arcanuum/nova/main/releases/stable/update_manifest.json
```

Release package URL:

```text
https://github.com/arcanuum/nova/releases/download/v0.9.0/NovaAssistant-portable.zip
```
