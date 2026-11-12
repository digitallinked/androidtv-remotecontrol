# Marketing site

Next.js, static, live at https://remotely.newy.my. Decisions #59 and #62 in `docs/knowledge/decisions.md` explain the choices.

It runs as a Docker image (`Dockerfile`, standalone Next server, `/api/health`) on Coolify. **A push to `main` that changes `web/` deploys it** (`.github/workflows/deploy-web.yml`). Hosting, ids and rules: `docs/hosting.md`.

```
npm install
npm run dev            # http://localhost:3000
npm test
npm run typecheck
npm run build
```

- **Environment:** `NEXT_PUBLIC_SITE_URL` is the public address used by canonical links, the sitemap and the legal pages. It's fixed at build time; the Dockerfile defaults it to `https://remotely.newy.my`, and a local build without it uses `http://localhost:3000`.
- **Container build:** `docker build -t remotely-web .` then `docker run --rm -p 3100:3000 remotely-web`. Without Docker: `NEXT_OUTPUT_STANDALONE=1 npm run build`, copy `.next/static` to `.next/standalone/.next/static`, run `node .next/standalone/server.js`.
- **Tests on Windows:** run them from an upper-case drive path (`D:\...`, e.g. PowerShell). From Git Bash's `d:` every suite fails with "Cannot read properties of undefined (reading 'config')".
- **Legal pages and public values:** `docs/release/` is the source. After changing them there, run `npm run sync:release`. A test fails until `web/content/` matches. Pages stay labelled Draft and out of search until the source's DRAFT line is gone and every value is real.
- **Store links:** set `site.stores` in `lib/site.ts` at launch. Until then the page says "coming soon".
- **`app-ads.txt`:** add it to `public/` once the AdMob publisher id exists (`docs/release/forms/app-ads-txt.md`).
- **Claims:** feature copy comes from `docs/release/store-listing/en.md`. No third-party logos, no "Google" in the brand, and the trademark notice stays in the footer.
