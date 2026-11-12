# Hosting: the marketing site

The website in `web/` is live at **https://remotely.newy.my**, self-hosted since 12 Nov 2026 on the
same stack as Newy (decision #62). The Vercel deployment (https://remotely-woad.vercel.app,
project `remotely`, team `newys-projects-9aa78c8d`) still exists but nothing points at it.

No secret values belong in this file. It says where each one lives.

```
visitor ──> Cloudflare (Newy's account, zone newy.my: DNS, proxy, TLS Full strict, HSTS)
              └──> DigitalOcean droplet cargolinked-prod-1 (174.138.20.56, shared with other products)
                     └──> Coolify 4, project "Newy" / production
                            └── newy-remotely   one container, port 3000   remotely.newy.my
Image built by GitHub Actions in this repo, stored in the DigitalOcean registry. Nothing is built
on the droplet. The site has no database and no runtime secrets.
```

## What was created (12 Nov 2026)

| Piece | Value |
|---|---|
| Coolify app | `newy-remotely`, uuid `dfxb7lvq0um2lt8xebxnxjfy`, in project Newy (`wrlhqg3vbfqtdznzv7ydia4w`) / production, server `localhost` (`7lker6c7d9nrcuhdfhbr7lje`), destination `coolify` |
| App settings | Docker image `registry.digitalocean.com/cargolinked/newy:remotely-latest`, port 3000, health check HTTP GET `127.0.0.1:3000/api/health` → 200, memory limit 384 MB, domain `https://remotely.newy.my` |
| App env | `NEXT_PUBLIC_SITE_URL=https://remotely.newy.my` (the image already has it baked in; see below) |
| Registry | repository `cargolinked/newy` (shared with Newy), tags `remotely-<12-char sha>` and `remotely-latest`, newest 10 kept |
| DNS | zone `newy.my` (`41068969ef738ad44528e28299e0344d`): one proxied `A remotely → 174.138.20.56`, record id `977702f2b4f49fa0d101efd3a78dce78`. Nothing else changed; the mail records were compared with Newy's export afterwards and all match |
| GitHub secrets | `DIGITALOCEAN_ACCESS_TOKEN`, `COOLIFY_API_TOKEN` (deploy-only, Newy's), `CF_ACCESS_CLIENT_ID`, `CF_ACCESS_CLIENT_SECRET` (Cloudflare Access service token `github-deploy-newy`, expires Nov 2027) |
| GitHub variables | `COOLIFY_URL=https://coolify.cargolinked.com`, `COOLIFY_REMOTELY_UUID=dfxb7lvq0um2lt8xebxnxjfy`, `WEB_AUTODEPLOY=on` |

**Why the shared registry repository:** the registry is on DigitalOcean's Basic plan (5 repositories)
and all 5 were in use. Newy's prune step (`C:\projects\newy_my\.github\workflows\deploy-selfhost.yml`)
only deletes `web-`, `admin-` and `app-` tags; ours only deletes `remotely-` tags. If either prune
step changes, check it still leaves the other's tags alone.

## Deploying

`.github/workflows/deploy-web.yml` runs the site's tests and typecheck, builds `web/Dockerfile`, pushes
both tags, triggers Coolify, waits for the rollout and checks `https://remotely.newy.my/api/health`.

- **Automatic:** a push to `main` that changes `web/**` (except Markdown) or the workflow deploys, while the variable
  `WEB_AUTODEPLOY` is `on`. Set it to anything else to pause.
- **Manual:** Actions → **Deploy website** → Run workflow (`ref`, `deploy`), or
  `gh workflow run deploy-web.yml -f ref=main -f deploy=true`.
- The repository is public. The workflow never runs on pull requests, so forks never see the secrets.
- **A push fails with `401 Unauthorized`** from the registry auth endpoint: CargoLinked's deploys
  garbage-collect the shared registry, which makes it read-only for a few minutes. Wait and re-run.
- **Rolling back:** run the workflow by hand with `ref` set to the last good commit, then revert the
  bad commit on `main`. Or Coolify → newy-remotely → Deployments → Rollback.
- **If the Coolify trigger breaks** (token or Access): run with `deploy=false`, then deploy from the
  droplet over SSH: `curl -X POST -H "Authorization: Bearer $COOLIFY_TOKEN" "http://127.0.0.1:8000/api/v1/deploy?uuid=dfxb7lvq0um2lt8xebxnxjfy"`.

**The site address is fixed at build time.** Canonical links, the sitemap and robots.txt are
prerendered, so `NEXT_PUBLIC_SITE_URL` is a Dockerfile build argument that defaults to
`https://remotely.newy.my`. The Coolify env var is there for completeness; changing it alone changes
nothing. To move the site, change the build argument (or its default) and rebuild.

### Verify a deploy

```bash
curl -s https://remotely.newy.my/api/health                    # {"ok":true}
for p in / /privacy /terms /support /sitemap.xml /robots.txt; do curl -s -o /dev/null -w "%{http_code} $p\n" https://remotely.newy.my$p; done
curl -s https://remotely.newy.my/sitemap.xml | grep -oE "<loc>https?://[^/<]+" | sort -u   # only https://remotely.newy.my
```

Coolify must show `running:healthy`.

### Local image build

Docker Desktop must be running. `docker build -t remotely-web web`, then
`docker run --rm -p 3100:3000 remotely-web` and open http://localhost:3100. Without Docker, the same
server: `NEXT_OUTPUT_STANDALONE=1 npm run build` in `web/`, copy `.next/static` into
`.next/standalone/.next/`, then `node .next/standalone/server.js`.

## The shared server: rules

The droplet runs CargoLinked, Barberpro, PropGo, Newy and others. From this repository touch only the
`newy-remotely` app, the `remotely-*` registry tags and the `remotely` DNS record.

- Never restart Docker, Coolify or `coolify-proxy`; never reboot or resize the droplet; never change
  the firewall, other Coolify projects or the three `newy-*` apps. Those need the owner of the server.
- Each production change (DNS, a new app, a deploy of something user-visible) needs the owner's
  go-ahead.
- **Cloudflare:** only the user env var `CLOUDFLARE_API_TOKEN_NEWY` through the REST API (Newy zone
  only). Never `CLOUDFLARE_API_TOKEN` or the `cloudflare-api` MCP server: they belong to CargoLinked's
  account. After any DNS edit, compare the mail records (Zoho MX ×3, SPF, `zoho-verification`,
  `zmail._domainkey`; Resend `send` MX + SPF, `resend._domainkey`; `_dmarc`) with
  `C:\projects\newy_my\docs\superpowers\plans\newy-dns-records.csv`.
- **Secrets never pass through a session.** Read them from Windows user env vars inside the command
  (`[Environment]::GetEnvironmentVariable(name,'User')`) and print statuses only. Set GitHub secrets
  from Git Bash (`gh secret set NAME`, value on stdin); a PowerShell pipe adds a byte-order mark.

Newy's full runbook (firewall, SSH, monitoring, Cloudflare settings): `C:\projects\newy_my\docs\hosting.md`.

## Where credentials live

| Credential | Location |
|---|---|
| Registry push | GitHub secret `DIGITALOCEAN_ACCESS_TOKEN`; owner's copy in user env var `DIGITALOCEAN_ACCESS_TOKEN` |
| Coolify deploy trigger | GitHub secret `COOLIFY_API_TOKEN`; owner's copy `COOLIFY_DEPLOY_TOKEN_NEWY` |
| Coolify full API | owner's user env var `COOLIFY_TOKEN`, or the `coolify` MCP server |
| Cloudflare Access (Coolify API) | GitHub secrets `CF_ACCESS_CLIENT_ID` / `CF_ACCESS_CLIENT_SECRET`; owner's copy `CF_ACCESS_CLIENT_ID_NEWY` / `CF_ACCESS_CLIENT_SECRET_NEWY` |
| Cloudflare DNS (newy.my) | owner's user env var `CLOUDFLARE_API_TOKEN_NEWY` |
| SSH | owner's key `~/.ssh/id_ed25519`, `root@174.138.20.56` (firewall admits the owner's home IPs only) |
