# Offline Vietnamese speech model

From the repository root, run:

```powershell
python backend/scripts/download_asr_model.py
python frontend/scripts/prepare_voice_assets.py
```

For private repositories, authenticate with `gh auth login` and add
`--github-cli` to the download command. The scripts verify SHA256 before
installing/bundling files for Android. Model binaries stay ignored by Git.
See [team setup](../../../../docs/MODEL3_SETUP.md).
