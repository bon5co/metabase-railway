# metabase-railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/metabase-v063-or-open-source-bi-encrypte?referralCode=Z1xivh&utm_medium=integration&utm_source=template&utm_campaign=generic)

**Deploy on Railway:** [Metabase template](https://railway.com/deploy/metabase-v063-or-open-source-bi-encrypte?referralCode=Z1xivh&utm_medium=integration&utm_source=template&utm_campaign=generic)

Railway-tuned [Metabase](https://www.metabase.com/) image: pinned upstream release,
`$PORT` honoured, JVM heap sized to the container, and every literal baked in so the
Railway deploy form stays empty.

Image: `ghcr.io/bon5co/metabase-railway:latest`
Base: `metabase/metabase:v0.63.2.7`

Used by the Railway template
**Metabase v0.63 | Open Source BI, Encrypted Credentials + Tuned JVM**.

## What this changes, and why

| Change | Reason |
|---|---|
| Pinned to `v0.63.2.7` | Metabase's application-DB migrations are one-way. Every other listing in the category ships `latest`, so an ordinary redeploy can migrate the app DB to a new major with no supported way back. |
| `MB_JETTY_PORT` ← `$PORT` | Metabase reads `MB_JETTY_PORT`, never `$PORT`. `templateGenerate` drops a service domain's target port when it publishes, so a template that pins port 3000 serves 502 `Application failed to respond` at the edge while looking healthy inside. |
| `JAVA_OPTS=-XX:MaxRAMPercentage=70` | The JVM defaults to 25% of the cgroup limit. Measured on Railway (`memory.max` = 8 GB): **1.86 GiB** default heap vs **5.22 GiB** at 70%. Upstream sets `-XX:+CrashOnOutOfMemoryError`, so outgrowing the heap kills the container rather than slowing down. Skipped if the deployer sets their own `-Xmx` / `MaxRAMPercentage`. |
| `MB_JETTY_HOST=::` | Dual-stack bind — one socket serves Railway's public edge and the IPv6-only private network. Upstream defaults to `0.0.0.0`. |
| `MB_DB_TYPE/USER/DBNAME/PORT` baked | Constants of the paired stock `postgres:17` service, not deployer choices. A literal shipped as a template variable loses its default in `templateGenerate` and publishes as required-with-no-value. |
| `MB_ANON_TRACKING_ENABLED=false` | Self-hosted analytics should not phone home about itself by default. |
| `MB_PASSWORD_COMPLEXITY=strong` | The instance is publicly reachable from first deploy, and the first account created owns every connected data source. |

## What the template sets, and this image deliberately does not

These are per-deploy values, expressed as Railway expressions so their defaults survive
publishing:

| Variable | Value |
|---|---|
| `MB_ENCRYPTION_SECRET_KEY` | `${{secret(48)}}` — encrypts data-source credentials at rest in the app DB. Set it **before** connecting any database; Metabase encrypts on write, so anything saved beforehand stays in plaintext. |
| `MB_DB_HOST` | `${{postgres.RAILWAY_PRIVATE_DOMAIN}}` |
| `MB_DB_PASS` | `${{postgres.POSTGRES_PASSWORD}}` |
| `MB_SITE_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` |

## Not fixed here, because it is not broken

The JVM reads Railway's cgroup **CPU** quota correctly — `ParallelGCThreads` came back as
8 on an 8-vCPU cgroup even though `nproc` reports the host's 32 cores (measured
2026-08-01). No `ActiveProcessorCount` override is needed; unlike the llama.cpp / torch
case, this runtime is already container-aware for CPU.
