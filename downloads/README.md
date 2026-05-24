# downloads/ — public APK drop folder

Anything in this folder is served at `https://mood8.app/download/`.

Two APKs land here:

- `mood8.apk` — phone APK, served at `/download/mood8.apk`
- `mood8-wear.apk` — Wear OS APK, served at `/download/mood8-wear.apk`

Both are linked from the landing page: the phone APK is the primary
"Download for Android" CTA, the Wear APK is a smaller "Also available"
secondary tile with its own install note.

## Auto-pull from GitHub Actions

`scripts/fetch_apks.sh` (one level up) downloads the latest successful
build of each workflow and drops the APKs in place:

```bash
# one-time on the server
gh auth login

# any time (cron, or manually after a release)
./scripts/fetch_apks.sh
```

The script walks both `android-build.yml` and `wear-build.yml`,
picks the most recent success on `main`, grabs the matching artifact,
and writes `mood8.apk` + `mood8-wear.apk`. No nginx reload required —
the alias serves whatever's in this folder.

## Manual fallback

If `gh` isn't authed or you have a build sitting on your laptop, you
can drop APKs straight here:

```bash
scp ~/Downloads/mood8-<n>.apk        admin@servermood81:/home/admin/projects/mood8/downloads/mood8.apk
scp ~/Downloads/mood8-wear-<n>.apk   admin@servermood81:/home/admin/projects/mood8/downloads/mood8-wear.apk
```

## What's already in here

- `index.html` — a tiny "click to download" landing for the phone APK
  with a 2-second auto-redirect to `/download/mood8.apk`. Shown if a
  user lands on `/download/` without a filename.
- `mood8.apk` / `mood8-wear.apk` — the actual APKs (or placeholders
  until the script runs).
- `.gitignore` — keeps real APKs out of the repo.
