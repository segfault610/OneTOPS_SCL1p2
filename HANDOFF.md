# Handoff log (state as of 2026-11-25)

OneTOPS-SCL: DVS-LDO plus a self-testing INT8 accelerator (`accel_top`) on the SCL 1.2 um (C1D) PDK.

**Do not commit or push PDK files or anything derived from them** (see `.gitignore`).

## What git does not carry

Get these from the previous owner. They are gitignored.

| Path | What it is | Needed? |
|---|---|---|
| `pdk_kit/` | NDA PDK kit (`analog/`, `digital/`, dated vendor drop) | Yes, only through channels your PDK licence allows |
| `docs/model_notes.txt` | **Read first:** device-model pitfall, synthesis notes, area estimates | Yes |
| `results/`, `char/` | Simulation logs, device characterisation data | Reference |
| `pnr/out/`, `pnr/*.txt`, `pnr/last.log` | Layout, databases, DRC reports, logs | Reference (rebuildable) |
| `comp/poster.png` | Image | Optional |
| `sim/dbg.sh` | Helper: rerun a netlisted testbench with your own ngspice control commands | Optional |
| `syn/`, `xschem/`, rest of `sim/` | Generated | No, rebuild them |

`xschem/` matched the output of `scripts/gen_xschem.py` exactly on 2026-11-25. Hand edits there are not tracked and
the generator overwrites them.

## Tools used

yosys 0.64 with the slang plugin, Icarus Verilog 14 (devel), Verilator 5.047, ngspice 46+, xschem 3.4.8RC,
KLayout 0.30.0, Docker image `ghcr.io/librelane/librelane:3.0.16`.
`run_tb.sh` also copies a `spinit` from `/usr/local/share/pdk/sky130A/`, and `build_ams.sh` uses
`/usr/local/share/ngspice/scripts/vlnggen`.

## Digital flow

```bash
scripts/syn_accel.sh          # RTL -> syn/accel_net.v (default N=2, DW=8)
scripts/build_lef.sh          # syn/*.lef and fillers
scripts/run_pnr.sh            # floorplan -> PDN -> place -> CTS -> fill -> route (route takes about 1 h)
klayout -b -r scripts/def2gds.py                       # -> pnr/out/accel_top.gds
scripts/drc.sh pnr/out/accel_top.gds accel_top pnr/out/drc.lyrdb
```

- Partial run: `STAGE=fp|place|cts scripts/run_pnr.sh`. Other variables: `DIE` (um, default 4200), `CLK_NS` (default 40).
- Reroute only, from `pnr/out/cts.odb`: `docker exec scl_pnr openroad -exit -no_splash /work/pnr/route.tcl > pnr/route_run.txt 2>&1`
- `cts.odb` stores the cell LEF. After any LEF change, rerun CTS before rerouting.
- The container `scl_pnr` mounts the repo path it was created with. If the repo moves, run `docker rm -f scl_pnr`.

## Status

| Item | State |
|---|---|
| `tb_accel_top`, `tb_dvs_ctrl` (RTL, Icarus) | Both PASS on 2026-11-25 |
| Synthesis | Done (netlist from 2026-11-24, not re-run since) |
| Place and route (v5) | Router: 0 violations, 0 pin-access errors, about 25% utilisation |
| KLayout DRC (v5) | **9 violations**, report `pnr/out/drc_v5.lyrdb` |
| `scripts/build_lef.sh` | Reproduces the v5 LEF files byte for byte |
| Analog | Logs exist for bias_mirror, vset_gen, rdac4, ldo_core dc/ac/tran (not re-run or reviewed for this log) |

### DRC history

| Run | Total | Change |
|---|---|---|
| v3 | 363 | 4.2 um site, custom fillers, signal pins on metal2 |
| v4 | 244 | `-dont_use` cells, placement padding, metal1 pin fallback |
| v5 | 9 | `scripts/lef_obs.py` |

### The 9 remaining violations

| Rule | Cells (count) |
|---|---|
| 9.4.1 via to poly (4) | XNR201 (2), AND201 (1), NND501 (1) |
| Guideline 6, vias on diffusion edges (5) | AND501 (2), AOI401 (2), AND201 (1) |

## Why the flow looks like this

- The vendor LEF does not match what the router needs, so `snap_lef.py` snaps it to grid, moves signal pins to
  metal2 and widens the CORE site. `mkfill.py` makes fillers that fit that site.
- `PIN_FALLBACK` (list in `build_lef.sh`) keeps metal1 pin access on cells that fail pin access without it.
  Narrowing it to single pins was tried: the pin-access errors moved to other pins of the same cells.
- The vendor LEF also omits some metal1 that is in the GDS. The router dropped vias there, mostly under NND201 IN2.
  `lef_obs.py` adds the missing metal1 as obstruction. Many added rectangles are thin (about 0.1 um) edge
  mismatches; no router or pin-access errors came from them.
- `syn_accel.sh` excludes MX2101, MX201B, TBUF01 (off-grid widths) and MX4122 (pin access).
- `route.tcl`/`flow.tcl` use `-congestion_iterations 0` because more iterations crashed this OpenROAD build.

## Next steps

1. Fix the 4 via-to-poly violations. Not yet investigated. Start by comparing GDS and LEF geometry at the markers
   in `drc_v5.lyrdb`, as was done for NND201.
2. Check with the foundry whether Guideline 6 must be clean.

## Not done or not checked

- LVS, antenna checks, gate-level simulation of the netlist or layout.
- Timing: the flow sets constraints but writes no timing report. The library is characterised at a higher voltage than
  the LDO supplies (see `docs/model_notes.txt`), so its timing is optimistic.
- Power grid connectivity. The flow deletes every other cell row, so check that every rail is connected.
- Analog testbenches with no log in `results/`: `tb_ams_dvs_ctrl`, `tb_chip_workload`, `tb_ldo_top_dvs`.
- Load-transient under/overshoot in `results/tb_ldo_core_tran.log` is large (hundreds of mV). Compare with your spec.
- `scripts/run_corners.sh` is left over from the sky130 version (sky130 corner names, 1.8 V supply). Port it before use.
- No pad ring, and no integration of the analog and digital layouts, is in this repo.
