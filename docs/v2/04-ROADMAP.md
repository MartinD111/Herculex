# Herculex V2 — Phased Implementation Roadmap

## Phase 1 — Data Foundation (schema v10)  ← STARTED 2026-06-12
**Milestone: every new log can carry variant/accessory/gym/set-type data; old data untouched.**
- New tables: `gyms`, `accessories`, `bands`, `set_accessories`, `set_bands`, `machine_settings`, `body_measurements`, `progress_photos`.
- New columns: `workout_sessions.gymId`, `workout_exercises.equipmentVariant/machineConfigJson`, `set_entries.setType/setTypeMetaJson/bodyweightKg/chainsKg`.
- Seed default accessories + common bands.
- Domain: `SetType` registry (+volume factors), `EffectiveLoad` calculator.
- Repository APIs: gyms CRUD, bands CRUD, set accessory/band toggles, measurement writes.
- Tests: fresh-schema seed test, effective-load unit tests, existing suites stay green.

## Phase 2 — Hevy-Style Logging UX (§26, §14, §15, §10, §11, §17 UI)
**Milestone: log a squat with belt+sleeves+bands at Gym B with machine config in <10 taps.**
- Equipment prompt on add-exercise (large tappable modality buttons; saved per log entry).
- Accessory quick-tray on the set row; band picker with mode toggle.
- Set-type tap menu with per-type metadata sheets.
- Gym selector at workout start (onboarding question "Do you train in multiple gyms?").
- Machine-config entry + recall of last config per exercise×gym.
- Weighted-bodyweight logging: BW auto-snapshot into `bodyweightKg`; "(Weighted)" naming; +2 CNS at engine level.
- Dynamic full-screen workout mode (one-tap switch).
- Measurements & progress-photos screens (photos local-only via `path_provider` + `image_picker`).

## Phase 3 — Intelligence Engines (§2, §3, §1/§5 analytics, §16)
**Milestone: recovery heatmap over 19 muscle groups; per-variant PRs; next-workout targets.**
- Recovery v3: EffectiveLoad input, 19-group output, fat-grip forearm multiplier, weekly MRV warnings, contextual advisories; recompute after every logged set (off main isolate via `compute`).
- CNS v2: session/weekly/monthly load series, dashboard graph, deload suggestions.
- Per-variant + per-accessory-combo PR/1RM breakdowns; gym-filtered machine analytics.
- Progressive overload engine: goal presets, per-exercise overrides, plate rounding (1.25/2.5/5/10/20/25 kg), suggested next targets.

## Phase 4 — Programs, Periodization & CrossFit (§12, §13, §20)
**Milestone: build a 12-week block program with rotating max-effort lifts; import/export via Excel.**
- Periodization models: linear, concurrent, block (acc/trans/real), max-effort (Westside).
- Exercise rotation pools with cross-rotation progression tracking.
- CrossFit structures: AMRAP, EMOM, For Time, chippers, benchmarks → tonnage conversion into the same engines.
- Micro workouts: scheduled reminders that write real `SetEntries` into auto mini-sessions.
- Excel/CSV template import/export (`excel` package).

## Phase 5 — Nutrition Expansion (§19, §22)
**Milestone: day-specific targets, automated cut schedule, generated weekly carb cycle.**
- Micronutrients, sodium/potassium/cholesterol; OFF mapping extension.
- Global + day-specific targets; automated calorie-reduction schedules.
- Carb-cycling engine (reads CNS load + compound density from Phase 3).
- Food-log date bug root-cause audit + fix; bottom-anchored edit/save/delete actions.

## Phase 6 — Dashboard, Widgets, Notifications & Polish (§18, §21, §23, §24)
**Milestone: editable dashboard; 3 native home-screen widgets; workout lock-screen notification.**
- Editable dashboard widget grid (7 widget types).
- Native home widgets (`home_widget` package): fasting timer, nutrition overview, smart workout launcher.
- `flutter_local_notifications`: active-workout lock-screen status, 20-min inactivity prompt with finish-time correction.
- Unified design system pass across all tabs; integration-test suite; migration tests on a copied v9 fixture DB.
