# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

```bash
# Compile TypeScript to dist/ (esbuild, IIFE format, browser platform)
npm run compile

# Full build: compile + package into .eext ZIP
npm run build

# Watch mode (rebuild on change)
npx ts-node ./config/esbuild.prod.ts --watch

# Lint and format
npm run fix

# Start the Python bridge server (from ./bridge_server/)
cd bridge_server && python server.py
# or: bridge_server/start_server.bat
```

The final artifact is `kicad-routing-bridge_v{version}.eext` — a ZIP containing `dist/`, `locales/`, `iframe/`, `images/`, and `extension.json`.

## Architecture

This is a bridge system connecting **EasyEDA Pro** (PCB editor) to **KiCadRouting Tools** (Rust-accelerated A* router). Two codebases cooperate:

### Extension (this repo — TypeScript)

Single entry point `src/index.ts` compiled to `dist/index.js`. Runs inside EasyEDA Pro as a plugin.

- **BridgeClient**: HTTP client talking to localhost:8765 (the Python server)
- **Data collection**: Reads PCB state via `@jlceda/pro-api-types` API — components, pads, nets, tracks, vias, board outline
- **Result application**: Writes routed tracks/vias back to the PCB editor
- **iframe UI** (`iframe/index.html`): Routing parameter dialog with net selection, layer config, progress display. Communicates with extension via MessageBus pub/sub.

### Bridge Server (`./bridge_server/` — Python/FastAPI)

- **server.py**: Job-based async routing. POST /api/route → background thread → poll /api/status → GET /api/result
- **routing_runner.py**: Orchestrates the pipeline: validate params → convert format → invoke router → diff results
- **easyeda_to_kicad.py**: Converts PCBJsonData (EasyEDA JSON) → .kicad_pcb (KiCad S-expression)
- **kicad_diff.py**: Compares input/output .kicad_pcb to extract only new tracks/vias
- **models.py**: Pydantic models shared across the server (PCBJsonData, RoutingConfig, TrackData, ViaData, etc.)

### KiCadRouting Tools (`../KiCadRoutingTools/`)

External routing engine. Called via `route.batch_route()` (direct Python import) or subprocess fallback. Key internals:
- `obstacle_cache.py`: Builds clearance-expanded obstacle map. Expansion formula: `track_width/2 + clearance + track_width/2`
- Grid-based A* with MPS (Maximum Planar Subset) net ordering
- Defaults in `routing_defaults.py`: TRACK_WIDTH=0.3mm, CLEARANCE=0.25mm, GRID_STEP=0.1mm

## Key Conventions

- **Units**: The extension UI accepts mm, converts to mils (1 mil = 0.0254mm) for the bridge server. The bridge server converts mils back to mm before calling KiCadRouting Tools.
- **Coordinate system**: EasyEDA uses mils with top-left origin. KiCad uses mm with bottom-left origin. Conversion handled in `coord_transform.py`.
- **Layer mapping**: EasyEDA layer IDs (1=F.Cu, 2=B.Cu, 15-44=In1-In30.Cu) mapped in both `src/index.ts` and `layer_mapping.py`.
- **Standalone pads**: Sent separately via `/api/extra-components` in chunks before the main `/api/route` call. Must preserve net names.
- **Board edge clearance**: Must be ≥ 0.5mm to avoid staircase routing artifacts.
- **Concurrency**: Only one routing job runs at a time (`_routing_lock`). Submitting a new job auto-cancels the previous one.

## Extension API Usage

The extension uses `@jlceda/pro-api-types` which provides:
- `pcb_Objects`: Query/create/delete PCB objects (tracks, vias, pads)
- `pcb_Nets`: Net connectivity information
- `pcb_Drc`: DRC rule configuration for parameter validation
- `eda_MessageBus`: Pub/sub communication with iframe UI
- `eda_Dialogs`: Modal dialogs (iframe hosting)

## Parameter Validation

`routing_runner.py` enforces minimums before routing:
- track_width ≥ 0.05mm, clearance ≥ 0.05mm
- via_size ≥ 0.2mm, via_drill ≥ 0.1mm
- grid_step ≥ 0.01mm, board_edge_clearance ≥ 0.5mm

The extension also validates against EasyEDA's DRC rules (`pcb_Drc.getCurrentRuleConfiguration()`) before submission.
