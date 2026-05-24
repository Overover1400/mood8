# downloads/ — public APK drop folder

Anything in this folder is served at `https://mood8.app/download/`.

## How to publish a new APK

1. The GitHub Actions workflow `.github/workflows/android-build.yml`
   builds the release APK on every push to `main`. Download the
   artifact (`mood8-android-apk`) from the run page.
2. Drop the APK into this folder as `mood8.apk` (the landing page +
   `index.html` here both link to that exact filename):

   ```bash
   scp ~/Downloads/mood8-<n>.apk admin@servermood81:/home/admin/projects/mood8/downloads/mood8.apk
   ```

3. No nginx reload needed — nginx just serves the new file.

## Why not pull automatically?

Two options that were considered and skipped for now:

- **`gh run download` cron** — needs a GitHub token on the box and
  has to know the latest run id. Worth doing if the cadence becomes
  more than weekly, but for now manual is one `scp`.
- **GitHub Releases + `wget` cron** — proper public-asset URL, but
  requires also adding a Release-publishing step to the workflow.
  Easy to add later if useful.

## What's already in here

- `index.html` — a tiny "click to download" landing with a 2s
  auto-redirect to `/download/mood8.apk`. Shown if a user lands on
  `/download/` without a trailing filename.
- `mood8.apk` — the actual APK. Replace with each release.
