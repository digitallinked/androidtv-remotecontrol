---
name: marketing-site
description: Use when working on the marketing website in web/ (Next.js, deployed on Vercel at remotely.newy.my), its legal pages, the support page, the domain, deploys, NEXT_PUBLIC_SITE_URL, app-ads.txt, or syncing docs/release values into web/content.
---

# Marketing site (`web/`)

## Overview
A static Next.js site: a home page whose hero is a working remote driving a simulated TV, plus `/support`, `/privacy` and `/terms`. It's the website on both store listings and hosts the legal pages the app links to. Decision #59 holds the reasons; `web/README.md` holds the commands.

## Facts (2026-11-11)
| Item | Value |
|---|---|
| Domain | `https://remotely.newy.my` (decision #61). `newy.my` uses Vercel's nameservers, but the domain isn't attached to the project yet: it answers `DEPLOYMENT_NOT_FOUND`. |
| Vercel | project `remotely`, team `newys-projects-9aa78c8d` ("Newy's projects"), linked in `web/.vercel/project.json`. Temporary address https://remotely-woad.vercel.app |
| App links | `AppLinks.privacyPolicy` / `terms` in `app/lib/app/app_links.dart` → `/privacy`, `/terms`; `SUPPORT_URL` → `/support` |
| Later | the owner moves the site to Coolify before launch; the site uses no Vercel-only feature |

## Rules
- **Hosting is the owner's exception to P9-R1** (Claude never hosts), for this site only. Deploying and changing the domain are outward-facing: confirm with the owner first unless they asked for it in this session. The auto-mode classifier blocks `vercel domains add` without the owner's approval.
- **Pushes don't deploy.** Deploy from `web/`: `vercel deploy --prod --scope newys-projects-9aa78c8d`. A deploy without `--prod` is only a preview.
- **`NEXT_PUBLIC_SITE_URL`** must be set on the host for production (`https://remotely.newy.my`). Without it, canonical links and the sitemap fall back to the Vercel address, or to localhost on another host.
- **`docs/release/` is the source** for the legal pages and public values (`placeholders.json`). After any change there, run `npm run sync:release` in `web/` and commit `web/content/` in the same commit. A test fails on drift.
- **Legal pages stay "Draft" and `noindex`** until the DRAFT line is removed from the source and every value is real. `/support` hides its contact section while `SUPPORT_EMAIL` is a placeholder.
- **No claims the app can't back:** no prices, ratings, download counts or competitor names. No third-party logos, no "Google" in the brand; the trademark notice stays in the footer.
- **No analytics or cookies.** Adding any means reviewing the privacy policy and adding consent first.
- **`app-ads.txt`** goes in `web/public/` once the AdMob publisher id exists (`docs/release/forms/app-ads-txt.md`), and must be served at the domain root.

## Changing the domain
1. Attach it: `vercel domains add <domain> remotely` (or the Vercel dashboard). A domain from another team may need a TXT record.
2. Set `NEXT_PUBLIC_SITE_URL` for Production, then deploy with `--prod`.
3. Update `PRIVACY_POLICY_URL`, `TERMS_URL` and `SUPPORT_URL` in `docs/release/placeholders.json` and `app/lib/app/app_links.dart`, run `npm run sync:release`, and run the app's release tests (`flutter test test/release test/tool`).
4. Check: `curl -sI https://<domain>/privacy` answers 200.

## Verify before claiming
`npm test`, `npm run typecheck` and `npm run build` in `web/`. After a deploy, fetch every route (`/`, `/support`, `/privacy`, `/terms`, an unknown path for 404).
