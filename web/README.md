# Marketing site

Next.js, static. Live on Vercel for now and moving to Coolify at launch; it uses no Vercel-only feature. Decision #59 in `docs/knowledge/decisions.md` explains the choices.

To deploy, run `vercel deploy --prod --scope newys-projects-9aa78c8d` from this folder. Pushes don't deploy, because the repo isn't connected to the Vercel project.

```
npm install
npm run dev            # http://localhost:3000
npm test
npm run typecheck
npm run build
```

- **Environment:** set `NEXT_PUBLIC_SITE_URL` to the final address, for example `https://example.org`. Canonical links, the sitemap and the legal pages use it.
- **Legal pages and public values:** `docs/release/` is the source. After changing them there, run `npm run sync:release`. A test fails until `web/content/` matches. Pages stay labelled Draft and out of search until the source's DRAFT line is gone and every value is real.
- **Store links:** set `site.stores` in `lib/site.ts` at launch. Until then the page says "coming soon".
- **`app-ads.txt`:** add it to `public/` once the AdMob publisher id exists (`docs/release/forms/app-ads-txt.md`).
- **Claims:** feature copy comes from `docs/release/store-listing/en.md`. No third-party logos, no "Google" in the brand, and the trademark notice stays in the footer.
