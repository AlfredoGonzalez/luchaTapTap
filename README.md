# Lucha Tap, Tap!

Offline-first Android clicker with a comedic lucha libre theme and pixel art. Flutter + Flame, Riverpod, Spanish only.

## Documents

All in [`docs/`](docs/). The Technical Spec is the entry point for building; if documents disagree, ask the designer before choosing.

| File | What it is |
| --- | --- |
| [`TECHNICAL_SPEC.md`](docs/TECHNICAL_SPEC.md) | Architecture, data schemas, systems, save and offline logic, milestones M1 to M8 |
| [`GAME_DESIGN_DOCUMENT.md`](docs/GAME_DESIGN_DOCUMENT.md) | Vision, core loop, economy v0, monetization, build plan |
| [`VISUAL_STYLE_GUIDE.md`](docs/VISUAL_STYLE_GUIDE.md) | Canvas, pixel rules, 32-color palette, UI components, layout |
| [`AI_ART_PROMPT_BOOK.md`](docs/AI_ART_PROMPT_BOOK.md) | Prompts and pipeline for the art style test and masks |

## Status

**M1 to M4 are built**, pending the designer's review and a run on a real Android device. Next: M5 (balance pass). See the milestone list in the Technical Spec, section 9, and [`docs/DECISIONS.md`](docs/DECISIONS.md) for the choices made where the documents were silent.

- **M1:** `Big` number type, economy formulas, game engine, JSON content.
- **M2:** combo and finisher, 5 skills, bosses with a countdown, lucky pickups, prestige with Belts, talent tree, masks, achievements, endless leagues.
- **M3:** save and load (atomic write, backup, migrations), offline earnings with the pop-up and a rewarded-ad double, debug panel.
- **M4:** the 14 screens of the UI mockups with the Press Start 2P font and pixel icons: studio splash, loading, fight, boss intro, upgrades, skills, masks, talents, prestige, offline pop-up, shop, settings and credits. Store purchases and ads run on fake services until M7/M8.

## Play it in the browser

Every push to `main` publishes a web build to GitHub Pages: <https://alfredogonzalez.github.io/luchaTapTap/>. It is only for testing (the game itself is Android); the save lives in the browser's local storage. One-time setup: **Settings > Pages > Build and deployment > Source: GitHub Actions**.

## Layout

```
lib/
  core/       pure Dart (no Flutter): Big, formulas, GameEngine, GameState, save codec, seeded RNG
  data/       JSON models, validation, loader
  game/       Flame arena (placeholder art)
  ui/         Flutter screens, panels, dialogs and widgets
  services/   game controller (Riverpod), save store, ad service, strings
assets/data/  balance, opponents, leagues, trainers, upgrades, skills, talents, masks,
              achievements and strings_es (all JSON)
test/         unit, data and widget tests
docs/         design documents
```

## Rules that matter

- No balance number lives in Dart. Every cost, multiplier, cap and time comes from `assets/data/`. To tune the game, edit the JSON.
- Only the 32 palette colors (`lib/core/palette.dart`). The mask colors Night Purple, Violet and Lilac are reserved for masks.
- Game rules stay in `lib/core` so they can be tested without a device.
- All player-facing text is Spanish and lives in `strings_es.json`. Code and comments are English.

## Develop

Requires the Flutter stable SDK (Dart 3.13).

```bash
flutter pub get
flutter analyze
flutter test
flutter run            # on an Android device or emulator
flutter run -d chrome  # in the browser (testing only)
```

In a debug build, long-press the fight number to open the debug panel (add coins, skip fights, fast-forward time, simulate an absence).
