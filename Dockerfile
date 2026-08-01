# Railway-tuned Metabase image.
#
# FROM the pinned upstream release. Every other Metabase listing on the Railway
# marketplace ships `metabase/metabase:latest` or the bare `metabase/metabase` tag
# (checked 2026-08-01 across the five listings holding 271 of the category's 283 recent
# deploys). Metabase's application-database migrations are one-way: a redeploy that
# happens to pull a newer major migrates the app DB and there is no supported path back,
# so an unpinned tag turns an ordinary redeploy into an unscheduled upgrade.
FROM metabase/metabase:v0.63.2.7

COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

# --- Baked defaults ----------------------------------------------------------------
# These are ENV rather than Railway template variables on purpose: templateGenerate keeps
# a variable's default only when the live value is a Railway *expression*
# (${{secret(n)}}, ${{svc.VAR}}, ...). A literal is dropped and the variable publishes as
# required-with-no-value, so every literal shipped as a variable is one more box the
# deploy form asks the deployer to fill in. Baking them here is what leaves the form
# empty; only the four genuinely per-deploy values stay as variables.
#
# MB_DB_TYPE / MB_DB_USER / MB_DB_DBNAME / MB_DB_PORT — the template's paired Postgres
#   service runs the stock postgres:17 image with no POSTGRES_USER or POSTGRES_DB set, so
#   both default to `postgres` and it listens on 5432. Constants of this template, not
#   deployer choices.
# MB_JETTY_HOST=:: — dual-stack listener. Java opens an IPv6 socket that also accepts
#   IPv4-mapped connections, so this serves Railway's public edge and the IPv6-only
#   private network from one bind. Upstream's run_metabase.sh defaults to 0.0.0.0
#   (IPv4 only) when this is unset.
# MB_ANON_TRACKING_ENABLED=false — self-hosted analytics that phones home about itself is
#   a surprise, not a default.
# MB_PASSWORD_COMPLEXITY=strong — this instance gets a public domain the moment it
#   deploys, and the first account created on it owns every connected data source.
ENV MB_DB_TYPE=postgres \
    MB_DB_USER=postgres \
    MB_DB_DBNAME=postgres \
    MB_DB_PORT=5432 \
    MB_JETTY_HOST=:: \
    MB_ANON_TRACKING_ENABLED=false \
    MB_PASSWORD_COMPLEXITY=strong \
    JAVA_TIMEZONE=UTC

EXPOSE 3000

# railway-entrypoint.sh translates $PORT into MB_JETTY_PORT and sizes the JVM heap to the
# container, then execs upstream's /app/run_metabase.sh unchanged. Do NOT set a Railway
# start command on top of this image: a start command REPLACES the entrypoint, so it
# would skip both fixes and Metabase would listen on 3000 while Railway routed to 8080.
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
