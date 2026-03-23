# Registry Hosting (GitHub Pages)

This repository is configured to publish the app's building registry JSON to GitHub Pages automatically when the local resource changes.

Where the published file will appear
- After GitHub Pages is enabled for this repository (see below), the registry will be available at:
  `https://<your-github-username>.github.io/<repo>/v1/registry.json`
  Example: `https://georgeclinkscales.github.io/Stamped-A-City-Passport/v1/registry.json`

How the automation works
1. When `Stamped! A City Passport/Resources/BuildingRegistry.json` is modified and pushed, the GitHub Actions workflow `publish-registry-to-gh-pages.yml` runs.
2. The workflow copies the file to `docs/v1/registry.json` and uses the `actions-gh-pages` action to push the `docs/` directory to the `gh-pages` branch.
3. GitHub Pages serves the file from the `gh-pages` branch.

Quick local publish steps (manual)
1. Copy the app resource into `docs/`:
```bash
mkdir -p docs/v1
cp "Stamped! A City Passport/Resources/BuildingRegistry.json" docs/v1/registry.json
```
2. Commit and push:
```bash
git add docs/v1/registry.json
git commit -m "ci: publish BuildingRegistry to GitHub Pages"
git push origin main
```
3. The GitHub Actions workflow will run and update the `gh-pages` branch. After a few seconds the file should be available at the Pages URL above.

Enable GitHub Pages for this repo (one-time setup)
1. Go to the repository on GitHub -> Settings -> Pages
2. Under "Build and deployment", choose "Deploy from a branch"
3. Select `gh-pages` branch and `/ (root)` folder. Save.

Verify the published file
```bash
curl -i https://<your-github-username>.github.io/<repo>/v1/registry.json
```
You should see `HTTP/1.1 200 OK` and the JSON body. Look for `ETag`, `Last-Modified`, or `Cache-Control` headers in the response.

Editing workflow (recommended)
- Edit `scripts/registry_editable.py` in VS Code to modify the registry comfortably.
- Run `./scripts/convert_registry.py import` to write `Stamped! A City Passport/Resources/BuildingRegistry.json`.
- Commit that file and push; the GitHub Actions workflow will publish to Pages.

Notes & considerations
- GitHub Pages serves content publicly. If your registry must be private, use S3 with signed URLs or a server that authenticates.
- Pages is cached by a CDN; updates usually propagate quickly but may occasionally take a short time to become visible. If you need strict immediate invalidation, consider S3 + CloudFront.
- After you enable GitHub Pages, add the Pages URL to your app's `Info.plist` under the key `BuildingRegistryRemoteURL` (one-time app update required). After that, the app will fetch this URL to update the registry.

Troubleshooting
- If the workflow fails, view the Actions tab in GitHub to inspect logs. Ensure `Stamped! A City Passport/Resources/BuildingRegistry.json` exists in the commit pushed.
- If the file doesn't appear, verify Pages is enabled and the `gh-pages` branch is configured as the source.

If you'd like, I can also:
- Create a PR that copies the current resource into `docs/v1/registry.json` and add the Pages workflow.
- Add a unit test that decodes `docs/v1/registry.json` in CI to catch schema issues before publish.
