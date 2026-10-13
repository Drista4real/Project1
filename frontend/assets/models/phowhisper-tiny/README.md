# Offline Vietnamese speech model

Run `backend/scripts/prepare_asr_model.py`, then
`frontend/scripts/prepare_voice_assets.py` from the repository root.
The latter verifies the export manifest before copying the INT8 encoder,
decoder, tokens and manifest into this directory for the Android build.
Model binaries are generated locally and are ignored by Git.
