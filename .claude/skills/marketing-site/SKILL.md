---
name: marketing-site
description: Use when working on the marketing website in web/ (Next.js, a Docker image on Coolify at remotely.newy.my), its legal pages, the support page, the domain, deploys, the Dockerfile or deploy workflow, NEXT_PUBLIC_SITE_URL, app-ads.txt, or syncing docs/release values into web/content.
---

# Marketing site (`web/`)

## Overview
A static Next.js site: a home page whose hero is a working remote driving a simulated TV, plus `/support`, `/privacy` and `/terms`. It's the website on both store listings and hosts the legal pages the app links to. Decision #59 holds the reasons; `web/README.md` holds the commands.

## Facts (2026-11-12)
| Item | Value |
|---|---|
| Address | `https://remotely.newy.my`, live since 2026-11-12 (decision #62) |
| Hosting | Coolify app `newy-remotely` (`dfxb7lvq0um2lt8xebxnxjfy`) in project Newy, on the droplet CargoLinked shares with other products. **`docs/hosting.md` has every id, the deploy steps and the server rules: read it before any production action.** |
| Image | `web/Dockerfile` → `registry.digitalocean.com/cargolinked/newy:remotely-<sha>` and `remotely-latest` (shared with Newy: the registry plan has no free repository) |
| Deploys | `.github/workflows/deploy-web.yml`: every push to `main` touching `web/` (variable `WEB_AUTODEPLOY=on`), or by hand from Actions |
| DNS | Newy's Cloudflare zone `newy.my`, one proxied A record `remotely` |
| App links | `AppLinks.privacyPolicy` / `terms` in `app/lib/app/app_links.dart` → `/privacy`, `/terms`; `SUPPORT_URL` → `/support` |
| App screens | `public/screens/*.webp`, rendered from the real app by `tool/web_screens.ps1` / `.sh` (`app/test/store_assets/web_screens_test.dart`, then `web/scripts/screens.mjs`). Regenerate and commit after a visible change to those screens (decision #63). Never hand-draw app UI or use a device screenshot with real TV names or addresses. |
| Old | Vercel project `remotely` (team `newys-projects-9aa78c8d`, https://remotely-woad.vercel.app) is unused; nothing deploys there |

## Rules
- **Hosting is the owner's exception to P9-R1** (Claude never hosts), for this site only. Every production action (DNS, Coolify changes, a deploy by hand of something user-visible) needs the owner's go-ahead unless they asked for it in this session. A push to `main` that touches `web/` deploys by itself.
- **The server is shared.** Touch only `newy-remotely`, the `remotely-*` registry tags and the `remotely` DNS record. Never restart Docker, Coolify or the proxy, never touch other projects or the `newy-*` apps. Cloudflare only through `CLOUDFLARE_API_TOKEN_NEWY`, never the `cloudflare-api` MCP server (another account).
- **The address is baked in at build time:** `NEXT_PUBLIC_SITE_URL` is a Dockerfile build argument defaulting to `https://remotely.newy.my` (sitemap, robots and canonical links are prerendered). Changing the Coolify env var alone does nothing.
- **`/api/health`** must stay dependency-free: the container health check and Coolify use it.
- **`docs/release/` is the source** for the legal pages and public values (`placeholders.json`). After any change there, run `npm run sync:release` in `web/` and commit `web/content/` in the same commit. A test fails on drift.
- **Legal pages stay "Draft" and `noindex`** until the DRAFT line is removed from the source and every value is real. `/support` hides its contact section while `SUPPORT_EMAIL` is a placeholder.
- **No claims the app can't back:** no prices, ratings, download counts or competitor names. No third-party logos, no "Google" in the brand; the trademark notice stays in the footer.
- **No analytics or cookies.** Adding any means reviewing the privacy policy and adding consent first.
- **`app-ads.txt`** goes in `web/public/` once the AdMob publisher id exists (`docs/release/forms/app-ads-txt.md`), and must be served at the domain root.
- **On Windows, run vitest from an upper-case drive path** (`D:\...`, e.g. from PowerShell). From Git Bash's `d:` it loads vitest twice and every suite fails with "Cannot read properties of undefined (reading 'config')".

## Changing the domain
1. Change the Dockerfile's `NEXT_PUBLIC_SITE_URL` default, the Coolify app's domain and env var, and the DNS record (owner's go-ahead).
2. Update `PRIVACY_POLICY_URL`, `TERMS_URL` and `SUPPORT_URL` in `docs/release/placeholders.json` and `app/lib/app/app_links.dart`, run `npm run sync:release`, and run the app's release tests (`flutter test test/release test/tool`).
3. Deploy, then run the checks in `docs/hosting.md` → "Verify a deploy".

## Verify before claiming
`npm test`, `npm run typecheck` and `npm run build` in `web/`. For the container: `NEXT_OUTPUT_STANDALONE=1 npm run build` and run `.next/standalone/server.js` (or `docker build -t remotely-web web` with Docker running). After a deploy, the checks in `docs/hosting.md` → "Verify a deploy": every route, a 404, the sitemap's host, `running:healthy`.
