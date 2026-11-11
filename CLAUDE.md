# Instructions for Claude Code

Project: Lucha Tap, Tap! (Flutter + Flame, Android only, Spanish only). Read `docs/TECHNICAL_SPEC.md` first; it is the source of truth for architecture, schemas and milestones.

## Hard rules

1. **No balance number in Dart.** Every cost, multiplier, cap, time and effect timing comes from `assets/data/*.json` (global constants in `balance.json`). If code needs a number, add it to the JSON and read it through `Balance`.
2. **Game rules stay pure Dart** in `lib/core` (no Flutter imports) and are covered by unit tests.
3. **Palette:** only the 32 colors in `lib/core/palette.dart`, used by name. Night Purple, Violet and Lilac are reserved for masks.
4. **Pixel rules:** integer scale only, whole-pixel positions, no anti-aliasing, touch targets at least 24 virtual pixels.
5. **Player-facing text is Spanish** and goes through `strings_es.json`. Code and comments are English.
6. **Open questions in the spec (section 9) are the designer's to decide.** Ask; do not guess.
7. If the documents disagree, ask before choosing.
8. Never reference real wrestlers, promotions or brands.

## Web build

`web/` and `.github/workflows/pages.yml` exist only so the game can be tested in a browser through GitHub Pages. The product is Android; do not add web-only features, and keep every plugin usable on both (`kIsWeb` picks the save store).

## Workflow

- Work milestone by milestone (spec section 9). When a milestone passes its checks, stop and show the designer before starting the next one.
- Before committing: `flutter analyze` and `flutter test` must pass.
- Commit and push work to a branch; do not open a pull request unless asked.
