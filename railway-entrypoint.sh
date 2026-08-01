#!/bin/sh
# Railway entrypoint for Metabase. Two fixes, then upstream's own launcher, unchanged.
set -e

# --- 1. Listen on the port Railway actually routes to --------------------------------
# Metabase reads MB_JETTY_PORT and ignores $PORT; upstream's run_metabase.sh defaults it
# to 3000. Railway injects PORT (8080) into the container and its edge targets that port
# unless the service pins a target port explicitly. templateGenerate drops a domain's
# target port when it publishes a template, so a template that relies on one 502s at the
# edge with "Application failed to respond" while the container looks perfectly healthy
# from the inside. Translating here means the published template needs no PORT variable
# and no pinned target port to route correctly.
export MB_JETTY_PORT="${MB_JETTY_PORT:-${PORT:-3000}}"

# --- 2. Size the JVM heap to the container -------------------------------------------
# The JVM reads Railway's cgroup memory limit correctly (UseContainerSupport is on), but
# MaxRAMPercentage defaults to 25, so Metabase gets a quarter of the RAM the deploy is
# billed for. Measured on Railway 2026-08-01 inside metabase/metabase:v0.63.2.7, cgroup
# memory.max = 8000000000:
#
#   default            MaxHeapSize = 2000683008   (1.86 GiB)
#   MaxRAMPercentage=70 MaxHeapSize = 5603590144  (5.22 GiB)
#
# That matters more here than the number suggests: upstream's launcher sets
# -XX:+CrashOnOutOfMemoryError, so a query or dashboard that outgrows the heap does not
# degrade, it kills the container. 70% leaves headroom for metaspace, code cache, thread
# stacks and direct buffers. Being a percentage, it scales with whatever plan the
# deployer is on rather than hardcoding one plan's memory.
#
# Skipped when the deployer has already expressed an opinion, so setting JAVA_OPTS with
# -Xmx or an explicit MaxRAMPercentage in the Railway variables panel still wins.
case " ${JAVA_OPTS} " in
    *-Xmx*|*MaxRAMPercentage*) ;;
    *) JAVA_OPTS="${JAVA_OPTS:+${JAVA_OPTS} }-XX:MaxRAMPercentage=70" ;;
esac
export JAVA_OPTS

echo "railway-entrypoint: MB_JETTY_PORT=${MB_JETTY_PORT} JAVA_OPTS=${JAVA_OPTS}"

# Upstream's launcher creates the metabase user, fixes up the H2 paths it still supports,
# and drops privileges with `su metabase`. It appends its own flags to $JAVA_OPTS, so the
# value exported above is kept, not replaced.
exec /app/run_metabase.sh "$@"
