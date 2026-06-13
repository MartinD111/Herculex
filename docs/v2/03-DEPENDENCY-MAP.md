# Herculex V2 — Feature Dependency Map

```
                         ┌──────────────────────────────────────┐
                         │  Schema v10 logging foundation (§1,  │
                         │  §5–§11, §15, §17 data)   [PHASE 1]  │
                         └──────┬───────────────────────────────┘
                                │
        ┌───────────────┬───────┴────────┬──────────────────┐
        ▼               ▼                ▼                  ▼
  EffectiveLoad    Hevy-style UX    Gym selector +     Measurements/
  + SetTypes       (§26, §14, §15   machine configs    photos UI (§17)
  (domain)          UI) [PHASE 2]   UI (§10–§11)       [PHASE 2]
        │               │            [PHASE 2]
        │               │
        ▼               ▼
  ┌─────────────────────────────────────────────┐
  │ Engines [PHASE 3]                            │
  │  Recovery v3 (§2) ◀─ fat-grip multiplier (§8)│
  │  CNS v2 + deload (§3)                        │
  │  Per-variant/accessory PRs & 1RM (§1, §5)    │
  │  Progressive overload + plate rounding (§16) │
  │  Volume/MRV analyzer (§2)                    │
  └──────┬──────────────────────────────────────┘
         │
         ├────────────────────────┬──────────────────────┐
         ▼                        ▼                      ▼
  Programs & periodization   Nutrition expansion    Analytics & dashboard
  + rotation + Excel I/O     + carb cycling (§19    (§18, §23) — consumes
  + CrossFit + micro-        needs CNS/compound     everything  [PHASE 6]
  workouts (§12,§13,§20)     density from Phase 3)         │
  [PHASE 4]                  + food-log bug (§22)          ▼
         │                   [PHASE 5]              Native home widgets,
         └──────────────────────┴────────────────▶  notifications (§18,§21)
                                                    [PHASE 6]
```

Key constraints:
- **Everything depends on Phase 1.** Equipment variants, accessories, bands, set types, gyms, and machine configs are *log-time* data; engines and analytics are meaningless for V2 until logs carry them.
- **Carb cycling (§19)** reads CNS load + compound density → needs Phase 3 engines.
- **Smart workout launcher widget (§18)** reads `ScheduledWorkouts` → needs Phase 4 scheduling to be authoritative.
- **Micro workouts (§20)** feed recovery/volume → must write ordinary `SetEntries` (auto-created mini-sessions), not a parallel data path.
- **Excel import/export (§12)** is leaf-node — pure I/O over Phase 4 models (`excel` package).
- **Independent / parallelizable:** measurements & photos (§17), food-log bug fix (§22), design-system unification (§22) — no engine dependencies.
```
