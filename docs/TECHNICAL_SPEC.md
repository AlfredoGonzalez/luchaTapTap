# Lucha Tap, Tap! — Technical Spec v0 (for Claude Code)

Nov 10, 2026 · @Alfredo

## 1. Overview and goals

Build "Lucha Tap, Tap!", an offline-first Android clicker with a lucha libre theme and pixel art, as a Flutter + Flame app. Companion docs: Game Design Document v0, Visual Style Guide v0 and the 14 UI mockups (canvas "Lucha Tap, Tap! — UI Mockups"). If this spec and those disagree, ask before choosing.

- Platform: Android only, portrait only, Spanish only (all player-facing strings in Spanish, code and comments in English).
- Play style: active tapping with idle income (trainers) and offline earnings.
- No backend, no accounts, no analytics in v0. Everything runs and saves locally.
- Content is data, not code: opponents, masks, trainers, upgrades, skills and talents live in JSON files.
- Real wrestlers, promotions and brands must never appear. All characters are original.

**First deliverable: the prototype.** It uses placeholder art (flat colored rectangles or the mockup SVG figures) and proves the loop and the balance, not the look.

Definition of done for the prototype:

1. A player can start, tap, buy upgrades and trainers, beat opponents, beat a league boss, change mask (prestige) and come back later to offline earnings.
2. Closing and reopening the app restores the exact state.
3. All numbers come from JSON and a single balance file, so tuning needs no code change.
4. A debug panel can add coins, skip fights and fast-forward time.

## 2. Tech stack and architecture

Keep game rules in pure Dart, separate from rendering, so they can be unit-tested and tuned without a device.

| Layer | Choice | Notes |
| --- | --- | --- |
| Framework | Flutter (stable) + Flame | Flame draws the arena; Flutter widgets draw menus, HUD and pop-ups |
| State | Riverpod | One `GameState` provider, UI watches slices of it |
| Core logic | Pure Dart package `core/` | No Flutter imports; deterministic; covered by tests |
| Big numbers | Own `Big` type (mantissa + exponent) | Endless leagues will exceed double precision; show as 1.2K, 3.4M, 5.6B, then letters |
| Save | JSON file in app documents dir | Versioned schema, atomic write (temp file then rename) |
| Content | JSON assets under `assets/data/` | Loaded at startup, validated, exposed read-only |
| Ads | `google_mobile_ads` | Rewarded only, never forced; use Google test ad IDs until release |
| Purchases | `in_app_purchase` (Google Play Billing) | Restore purchases supported |
| Audio | `flame_audio` | Music loop + short SFX |

**Game loop.** One fixed tick (10 per second) advances idle income, cooldowns, boss timer and combo decay. Taps are applied immediately, not on the tick. Rendering runs at the display rate and only interpolates visuals.

**Rule for Claude Code:** never put a balance number in Dart. Every cost, multiplier, cap and time comes from JSON or `balance.json`.

Suggested structure:

```
lib/
  core/        # pure Dart: Big, formulas, GameState, systems, save model
  data/        # JSON loading + validation, content models
  game/        # Flame: arena, sprites, animations, effects
  ui/          # Flutter screens and widgets (one folder per screen)
  services/    # save, ads, billing, audio, haptics
  app.dart, main.dart
assets/
  data/        # opponents.json, masks.json, trainers.json, upgrades.json, skills.json, talents.json, leagues.json, balance.json, strings_es.json
  sprites/  audio/  fonts/
test/          # unit tests for core/ and data validation
```

## 3. Rendering and art rules

The look comes from strict pixel rules. Full detail is in the Visual Style Guide; this is what the code must enforce.

- Virtual canvas 180 x 320 (portrait). On taller phones the height grows up to about 390; the extra space goes to the arena, never to stretching.
- Scale by an integer factor only (6x on a 1080-px-wide screen). Letterbox the remainder with Ink (#1B1230). Nearest-neighbor filtering, whole-pixel positions, no anti-aliasing, alpha 0 or 255 only.
- 1 virtual pixel is about 2 dp. Every touch target is at least 24 virtual pixels (48 dp).
- Layout bands (virtual px): top safe area, HUD 12-36, opponent bar 36-52, arena 52-154, combo row, skills row, buy panel, nav bar, bottom safe area. The mockups show these at 3x (540 x 960).
- Pop-ups use a 1-px checkerboard of Ink over the screen instead of transparency.
- Buttons and panels have stepped (notched) corners, not rounded ones.

**Palette.** 32 colors, defined once in `palette.dart` and used by name. No other color may appear in code or assets: Ink #1B1230, Night Purple #2E1F4A, Slate #4A3B6B, Dust #7C7396, Fog #B8B2CC, Bone #F6F0E4, White #FFFFFF, Wine #5E1230, Lucha Red #C8283A, Coral #F2545B, Pink #FF8FB1, Blush #FFD0DC, Chocolate #4B2A1E, Skin Deep #8F5A3C, Skin Mid #D9915E, Skin Light #F7C9A0, Sand #E8D3A2, Burnt Orange #E2661B, Marigold #FFB627, Sun Yellow #FFE066, Forest #1F5A3A, Nopal #2E9E5B, Lime #8FD14F, Mint #C5F0A4, Navy #1D2F6F, Royal #2F5BEA, Sky #5BB8FF, Teal #1FA6A0, Aqua #8FF0E0, Violet #7A3FD1, Lilac #B993F5, Magenta #D12FA0.

Text rules: Bone on Ink or Night Purple for body text; do not use White on Nopal or Lucha Red on Night Purple (too low contrast).

**Font.** Pixel font at multiples of its native size (8 px body, 16 px titles). The mockups use Press Start 2P (OFL license). Before finalizing, test that it renders á é í ó ú ñ ü ¡ ¿ correctly; if not, switch to Silkscreen or Pixelify Sans.

**Sprites.**

| Asset | Size (px) | Notes |
| --- | --- | --- |
| Player, regular opponents | 48 x 48 | Opponents drawn facing right, flipped at runtime |
| Bosses | 64 x 64 | Same rules |
| Trainer portraits | 24 x 24 |  |
| Icons | 16 x 16 (inline 8 x 8) |  |

Animations: idle 4 frames at 6 fps (loop), attack 3 at 12, hit 2 at 12, defeated 3 at 10, victory 2 at 4 (loop). Sprite sheets are PNG, one row per animation, frame size fixed per asset class.

**Mask recolor.** Masks are palette-swapped at runtime using three reserved colors that appear only on masks: Night Purple (shadow), Violet (base), Lilac (light). Implement as a shader or per-pixel remap keyed on those three values.

**Placeholders.** Until final art exists, load the same file names from a `placeholder/` folder so swapping art later needs no code change.

## 4. Data schemas (JSON)

Every file has a `schemaVersion`. The loader validates on startup (unique ids, valid references, no missing sprites) and fails loudly in debug builds. Display text is stored in Spanish. Launch content: 3 leagues, 6 opponents plus 1 boss per league, 12 masks, 6 trainers, 5 skills, one talent tree.

| File | One entry holds |
| --- | --- |
| `leagues.json` | id, name, order, arena theme (crowd and wall palette), opponent ids in fight order, boss id, loopScale (stat multiplier applied each time the leagues repeat) |
| `opponents.json` | id, name, sprite, size (48 or 64), isBoss, hpMultiplier, coinMultiplier, flavor line, optional boss timer override |
| `masks.json` | id, name, rarity, bonus (type and value), unlock rule (starter, league, belts, shop), slot colors |
| `trainers.json` | id, name, portrait, baseCost, baseDps, unlock condition (fight number) |
| `upgrades.json` | id, name, icon, baseCost, effect type (tapDamage, critChance, ...) and per-level value |
| `skills.json` | id, name, icon, cooldown, duration, effect, per-level scaling, unlock condition, upgrade cost |
| `talents.json` | branches (Daño, Idle, Suerte), nodes: id, name, icon, maxLevel, cost per level, effect, parent node |
| `balance.json` | all global constants (formulas in section 5) |
| `strings_es.json` | all UI text, keyed by id |

Example opponent and trainer entries:

```json
{ "id": "mr_aguacate", "name": "Mr. Aguacate", "sprite": "opp_mr_aguacate", "size": 48,
  "isBoss": false, "hpMultiplier": 1.0, "coinMultiplier": 1.0 }

{ "id": "don_chuy", "name": "Don Chuy", "portrait": "tr_don_chuy",
  "baseCost": 150, "baseDps": 1, "unlockFight": 8 }
```

The first boss is "El Mariachi Furioso" (league 1, fight 40 in the mockups) and the first upgrade is "Puño duro". The full opponent, mask and trainer lists are a content task for after the prototype; the prototype needs only 3 opponents, 1 boss, 2 masks, 2 trainers, 2 upgrades and 2 skills to prove the loop.

## 5. Game systems and formulas

These are the v0 numbers from the Game Design Document. They are starting points: put every constant in `balance.json` and expect to tune them in the prototype.

**Economy**

```latex
HP(n) = 10 \cdot 1.55^{\,n-1}
```

```latex
Coins(n) = 0.15 \cdot HP(n)
```

```latex
Cost(k) = base \cdot 1.15^{\,k}
```

```latex
Belts = \lfloor \sqrt{C / 10^{6}} \rfloor
```

- n = fight number. Boss fights: HP x 10 and coins x 5.
- k = levels already owned of an upgrade or trainer; `base` is its base cost.
- C = total coins earned in the current run. Each Belt gives +2% damage, permanently.

**Systems**

1. **Tap.** Each tap deals tap damage (base plus upgrades, talents, mask, belts) and shows a floating damage number. A small chance of a critical hit (talent-driven) multiplies it.
2. **Upgrades.** Spend coins to raise tap damage and related stats. The buy selector (x1, x10, x100, MAX) buys that many levels at the summed cost; MAX buys as many as affordable.
3. **Trainers.** Each adds damage per second (idle). Their DPS applies on every tick, including offline.
4. **Combo.** Consecutive taps fill a combo meter that decays if the player stops. At full, the GOLPE (finisher) button becomes ready: one big hit, then the meter resets.
5. **Skills.** Five active skills with cooldowns and a short duration; cooldowns and active effects pause while the app is closed. Examples: Plancha (big single hit), Furia (tap multiplier), Suerte (more lucky events), Grito (trainer multiplier), Llave (extends boss timer).
6. **Fights.** Defeating an opponent pays coins and starts the next one. Defeats do not require the screen to stay on: idle damage progresses the fight.
7. **Boss timer.** Bosses have a 30 s timer. If it ends, the player drops back to the previous regular fight and can retry; no penalty beyond lost time.
8. **Lucky events.** Random pickups in the arena (for example a belt) that must be tapped before they vanish. Rewards are small and never required.
9. **Prestige ("Cambiar de máscara").** Resets fight number, coins, upgrades and trainers. Keeps masks, talents and belts, and grants the belts computed by the formula above. The confirmation pop-up shows the belts to be earned before the player confirms.
10. **Endless leagues.** After league 3 the leagues repeat in order with `loopScale` applied to opponent stats, so there is no final fight.
11. **Achievements.** Simple counters (taps, defeats, bosses, prestiges) with small belt rewards; data-driven like everything else.

All randomness uses a seeded generator stored in the save, so tests and replays are reproducible.

## 6. Save system and offline progression

**Save.** One JSON file with `saveVersion`, a `lastSeen` UTC timestamp, the RNG seed and the full player state (coins, belts, fight number, upgrade and trainer levels, skills, masks owned and equipped, talents, achievements, settings, purchases). Write it every 10 seconds while playing, and immediately when the app goes to the background. Write to a temp file and rename so a crash never leaves a half-written save. Keep one previous copy as a backup and fall back to it if the main file fails to parse. Provide migration functions keyed on `saveVersion`.

**Offline earnings.** On resume or cold start:

1. elapsed = now - `lastSeen`. If it is negative (clock changed), treat it as 0.
2. Apply the cap: base 4 hours, raised by the Siesta talent and by the shop purchase "Más descanso" (the exact combination is an open question below; both come from JSON).
3. Simulate idle progress only: trainer DPS against the current and following regular opponents, paying coins per defeat with the normal formulas. Stop before the next boss: bosses need active play.
4. Show the "Ganancias sin conexión" pop-up if elapsed is over 1 minute: time away, coins earned, the cap note, a button to collect, and a rewarded-ad button that doubles the amount. Declining or failing the ad still lets the player collect the base amount.
5. Skills, cooldowns and lucky events do not progress offline.

The simulation must be a closed-form or batched loop (not one iteration per second) so 8 hours of offline time computes in well under 100 ms.

**Anti-tamper (light).** No server, so do not try to be strict. Ignore backward clock jumps and keep the cap. A player who edits their clock forward gets at most one cap of extra coins per app open.

## 7. Screens and navigation

The mockup canvas is the visual reference for layout, hierarchy and copy (Spanish text in the mockups is the starting copy). Match positions at 3x scale; art is placeholder.

App flow: Splash del estudio, then Carga (progress bar, then "Toca para continuar", which blinks), then the main fight. The bottom bar has five tabs: Mejoras, Habilidades, Máscaras, Talentos, Tienda. The gear in the HUD opens Ajustes.

| # | Screen | Reached from | Key behavior |
| --- | --- | --- | --- |
| 1 | Pelea principal | Carga, any tab | Tap the arena to attack; HUD shows coins, fight number, belts; combo meter and GOLPE; 5 skill buttons; buy panel below |
| 2 | Pelea contra jefe | Fight 40 and every boss | Adds boss health bar and 30 s timer bar, boss name overlay; combo full shows ready state |
| 3 | Mejoras (estados) | Tab Mejoras | Row states: normal, pressed, just bought (flash), not enough coins, locked ("???" plus unlock fight) |
| 4 | Intro del jefe | Before each boss | Full-screen reveal with boss sprite and name; "¡A PELEAR!" starts the 30 s timer |
| 5 | Habilidades | Tab Habilidades | Skill list with level and cooldown, upgrade buttons, detail panel for the selected skill |
| 6 | Máscaras | Tab Máscaras | 3 x 4 grid, locked masks show "???", detail panel with bonus and Equipar button |
| 7 | Cambiar de máscara | Button in Máscaras or Talentos | Modal: what resets, what stays, belts to earn; Volver or ¡Cambiar! |
| 8 | Talentos | Tab Talentos | Three branches, node states (maxed, owned, available, locked), detail panel with belt cost |
| 9 | Ganancias sin conexión | App resume | Modal from section 6: collect, or watch an ad to double |
| 10 | Tienda | Tab Tienda | Permanent purchases, belt packs, free rewarded-ad offers; prices shown from Play Billing |
| 11 | Ajustes | HUD gear | Toggles (sound, music, vibration, notices), restore purchases, Créditos, privacy, delete data (confirm first) |
| 12 | Créditos | Ajustes | Credits and license list generated from `credits.json` |
| 13 | Splash del estudio | App start | Studio name, about 2 s, skippable |
| 14 | Carga | After splash | Logo, loading bar, "Toca para continuar" |

Behavior rules: pop-ups close with the Android back button; destructive actions (Borrar datos, Cambiar de máscara) always ask for confirmation; every tappable element gives a pressed state, a short sound and optional haptics.

## 8. Monetization, audio and licenses

**Principle.** Ads and purchases are optional and only add convenience or cosmetics. No forced ads, no banners, no interstitials, and no content is locked behind payment. Put all monetization behind interfaces (`AdService`, `BillingService`) with fake implementations for the prototype, so the game runs fully offline with no SDK.

**Rewarded ads (AdMob).**

- Offline earnings: double the amount (screen 9).
- Tienda: "Doble 2 min" (coins x2 for 2 minutes) and "Cinturón +1".
- Each reward has a cooldown set in JSON. If an ad fails to load, hide or disable the button with a short message; never block the base reward.
- Use Google test ad unit IDs in all non-release builds.

**Purchases (Play Billing).** Non-consumable: "Más descanso" (larger offline cap) and "Doble moneda". Consumable: three belt packs (Puñado +20, Montón +100, Baúl +500). Prices come from Play Billing, never hard-coded; the mockups show `$XX` placeholders. Final MXN price points are decided after the prototype, looking at similar games. Support restore purchases. Verify entitlements locally from the store response; there is no server.

**Audio.** One music loop for the main fight, one for boss fights, and short SFX for tap, hit, critical, buy, error, boss intro, victory and pop-up open/close. Master, music and SFX volumes plus mute live in Ajustes. Duck or pause music when the app loses focus.

**Licenses.** Use only CC0 or CC-BY audio. For every third-party asset, add an entry to `credits.json` (title, author, license, source URL). The Créditos screen renders that file, so attribution is automatic. Also credit Press Start 2P (CodeMan38, OFL). Do not include any asset whose license is unclear.

## 9. Milestones and open questions

Build in this order. Each milestone must run on a real Android device and pass its checks before the next starts.

1. **M1 – Core loop.** Project setup, `core/` with `Big`, formulas and tick, one arena screen with tapping, coins, one upgrade, one trainer, fights. Unit tests for formulas and the buy-multiple math.
2. **M2 – Systems.** Combo and GOLPE, skills, boss with timer, lucky events, prestige with belts, talents, masks, achievements. All from JSON.
3. **M3 – Save and offline.** Save and load with backup and migration, offline earnings pop-up, debug panel (add coins, skip fights, fast-forward time).
4. **M4 – UI to mockups.** All 14 screens in the nav structure of section 7, Spanish strings in `strings_es.json`, pressed states, back-button handling.
5. **M5 – Balance pass.** Play-test with the debug panel; tune `balance.json` until a first prestige lands near the target pace (to be set by the designer after M3).
6. **M6 – Vertical slice.** Real art for the art style test (1 player, 2 opponents, 1 boss, 5 animations), audio, animations, haptics, fake ads and billing replaced by real SDKs with test IDs.
7. **M7 – Content.** Fill the launch content (3 leagues, 12 masks, 6 trainers, 5 skills), final art and audio, credits file.
8. **M8 – Release.** Play Store listing, closed test, fixes, launch.

**Acceptance checks for M1–M3.**

- 10 minutes of play with no crash; kill the app at a random moment and the save restores within 10 seconds of progress.
- Changing a value in JSON changes the game with no code change.
- 8 hours of offline time computes in under 100 ms and never grants more than the cap.
- Frame rate holds 60 fps on a mid-range Android phone with 20 on-screen effects.

**Open questions (ask the designer, do not guess).**

- How exactly do Siesta (talent) and "Más descanso" (purchase) combine into the offline cap? The shop mockup says up to 8 h.
- Font check: do á é í ó ú ñ ü ¡ ¿ render in Press Start 2P?
- Mask slot colors and a second slot set for trunks and cape.
- App icon, Play Store title and subtitle, studio name.
- Price points (after the prototype) and which rewarded-ad cooldowns to use.
- Music and SFX pack selection (CC0 or CC-BY only).
- Tall-phone variant of the main screen (180 x 390) is not mocked yet.
