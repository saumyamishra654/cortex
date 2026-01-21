---
description: how to update GitHub Pages docs for cortex
---
# Update GitHub Pages Docs

Run this workflow after making significant changes to the Flutter web app to deploy updates to GitHub Pages.

## Steps

1. Navigate to the Flutter app directory:
   ```bash
   cd cortex_app
   ```

2. Build the web release with the correct base href:
   ```bash
   flutter build web --release --base-href "/cortex/"
   ```

3. Copy build output to the docs folder:
   ```bash
   rm -rf ../docs/* 2>/dev/null; cp -r build/web/* ../docs/
   ```

4. Commit and push the changes:
   ```bash
   cd .. && git add docs/ && git commit -m "Update GitHub Pages deployment" && git push
   ```

## Notes
- The `--base-href "/cortex/"` flag is required because the repo is hosted at `github.io/cortex/`
- The `docs/` folder is configured as the GitHub Pages source in the repository settings
- After pushing, changes will be live within a few minutes at https://saumyamishra654.github.io/cortex/
