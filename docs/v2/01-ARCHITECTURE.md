# Herculex V2 — Architecture Review & Target Architecture

Date: 2026-06-12 · Baseline: schema v9, Flutter/Drift/Riverpod, local-first.

## 1. Current-state review

### What already exists (do NOT rebuild)

| V2 spec section | Current status |
|---|---|
| §1 Exercise Intelligence | **~80% done.** `ExerciseCatalog` (v8) carries `aka`, `category`, `movementPattern`, `modality`, `cnsScore`, `recoveryImpact`, `loggingMetric`, `supportsWeightedBodyweight`. Normalized `ExerciseMuscles` (primary/secondary/stabilizer × contribution) and `ExerciseAliases` exist. Alias-aware search already shows only canonical names (`WorkoutsRepository.watchExercises`). **Missing:** equipment/modality prompt at log time, per-variant history/PRs. |
| §2 Recovery Engine | **v2 exists** (`muscle_recovery.dart`): role-weighted, RPE-scaled, exponential decay, advisories. **Missing:** effective-load input (bands/chains/bodyweight), forearm multiplier (fat grips), weekly MRV warnings, 19-muscle granular output (currently folds to 9 display groups). |
| §3 CNS Management | **v1 exists** (`cns_fatigue.dart`): per-set load = base × cnsScore × RPE factor × decay. **Missing:** weekly/monthly trends, dashboard, deload suggestions. |
| §4 Custom Exercise Creator | **Done** (`createCustomExercise` + `custom_exercise_builder_view.dart`) — full field coverage incl. CNS, recovery impact, aliases, muscles. |
| §5–§8 Accessories/Bands/Chains/Fat Grips | **Not started.** |
| §9 Weighted bodyweight | Flag exists on catalog; **no bodyweight inclusion in load math, no logging field.** |
| §10–§11 Multi-gym / Machine configs | **Not started.** |
| §12 Periodization | Basic `Programs/ProgramWeeks/ProgramDays/ProgramDayExercises/ScheduledWorkouts` exist with `type` + `progressionStrategy` columns. **Missing:** block/concurrent/max-effort semantics, exercise rotation, Excel import/export. |
| §13 CrossFit | **Not started.** |
| §14 Workout modes | Classic only. |
| §15 Set types | Only standard + warmup + supersetGroup. |
| §16 Progressive overload | 1RM math exists (`one_rep_max.dart`); no progression engine. |
| §17 Measurements/photos | Only `DailySummaries.weighInKg`. |
| §18 Dashboard/widgets | Static dashboard; no native home-screen widgets. |
| §19 Nutrition expansion | Calories + macros + fiber per-100g; targets from Mifflin-St Jeor. **Missing:** micros, day-specific targets, diet automation, carb cycling. |
| §20 Micro workouts | **Not started.** |
| §21 Notifications | **Not started** (no `flutter_local_notifications` dependency yet). |
| §22 Food log date bug | `FoodEntries.dateIso` is a timezone-stable `yyyy-mm-dd` text key; a regression test exists (`test/food_log_day_test.dart`). Re-audit UI date switching in the nutrition phase. |

### Architecture strengths to preserve
- **Repository facade rule:** UI never imports Drift; everything flows through `*_repository.dart`.
- **`Clock` abstraction** for all time math (testability).
- **Drift watch-streams** drive live UI; no manual cache invalidation.
- **Importer is idempotent** and re-runs on upgrade; `assets/data/exercises.json` stays the exercise source of truth.

### Architecture gaps
- No concept of a *log-time variant*: equipment, accessories, gym, and machine config are properties of *how an exercise was performed*, not of the catalog row. V2's core data change is attaching variant data to `WorkoutExercises`/`SetEntries`.
- Volume/1RM math uses raw `weightKg`; V2 needs a single **`EffectiveLoad`** function used by *every* engine (recovery, CNS, analytics, progression) so bands/chains/bodyweight count exactly once.
- Heavy calculations run on the main isolate today (fine at current data sizes; engines must move to `compute()` once 19-muscle × 30-day windows land).

## 2. Target component architecture

```
┌────────────────────────────  Presentation (Riverpod)  ───────────────────────────┐
│ Dashboard │ Workouts (Classic/Dynamic) │ Nutrition │ Programs │ Insights │ Profile │
│           │  + accessory tray          │ + targets │ + period-│ + recovery│ + gyms │
│  widgets  │  + set-type menu           │ + carb    │   ization│   heatmap │ + meas.│
│           │  + equipment prompt        │   cycling │ + rotation│ + CNS    │ + photos│
└───────┬───────────────┬───────────────────┬────────────┬───────────┬─────────────┘
        │               │                   │            │           │
┌───────▼───────────────▼───────────────────▼────────────▼───────────▼─────────────┐
│                              Domain engines (pure Dart)                           │
│ EffectiveLoad ◀── SetTypes meta      MuscleRecovery v3   CnsFatigue v2 + Deload   │
│ ProgressionEngine (plate rounding)   CarbCycling          PeriodizationModels     │
│ OneRepMax (per-variant)              VolumeAnalyzer (MRV) ExerciseRotation        │
└───────┬───────────────────────────────────────────────────────────────────────────┘
        │
┌───────▼───────────────────────────────────────────────────────────────────────────┐
│                          Repositories (only DB gateway)                            │
│ WorkoutsRepository (+variants/accessories/gym)  GymsRepository  BandsRepository    │
│ MeasurementsRepository  ProgramsRepository(+periodization)  NutritionRepository    │
└───────┬───────────────────────────────────────────────────────────────────────────┘
        │
┌───────▼───────────────────────────────────────────────────────────────────────────┐
│ Drift AppDatabase (schema v10+)  ·  ExerciseImporter (exercises.json, unchanged)   │
│ path_provider file store (progress photos — device only, never synced)             │
└───────────────────────────────────────────────────────────────────────────────────┘
```

New modules (all additive): `features/gyms/`, `features/measurements/`, `features/workouts/domain/effective_load.dart`, `set_type.dart`, `progression_engine.dart`, `features/analytics/domain/volume_analyzer.dart`.
