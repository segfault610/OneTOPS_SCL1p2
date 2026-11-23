#!/usr/bin/env bash
# Run pnr/flow.tcl in the persistent librelane container (started once: see docs). Usage: STAGE=place DIE=5000 scripts/run_pnr.sh
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
docker start scl_pnr >/dev/null 2>&1 || docker run -d --name scl_pnr -u "$(id -u):$(id -g)" -v "$ROOT:/work" -w /work --entrypoint sleep ghcr.io/librelane/librelane:3.0.16 infinity >/dev/null
docker exec -e STAGE -e DIE -e CLK_NS scl_pnr openroad -exit -no_splash /work/pnr/flow.tcl 2>&1 | tee "$ROOT/pnr/last.log" | tail -${TAIL:-40}
