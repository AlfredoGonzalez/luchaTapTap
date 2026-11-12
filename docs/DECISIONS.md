# Design decisions and open points

Decisions made while building M2 and M3 where the documents were silent or disagreed. Each one lives in JSON or in one small piece of code, so changing it is cheap. Review and overrule any of them.

## Decided by the designer

| Topic | Decision |
| --- | --- |
| Offline cap | 4 h base **plus** Siesta talent (+0.5 h per level, 4 levels) **plus** the "Más descanso" purchase (+2 h), never above 8 h. All values in `balance.json` and `talents.json`. |
| Build order | M2 and M3 built together. |

## Taken by Claude (please review)

| Topic | What was done | Where |
| --- | --- | --- |
| League structure | The Technical Spec says a league is its opponents in order plus a boss; the GDD says a boss every 10th fight. The prototype league lists its 3 opponents three times (9 fights) and then the boss, so the boss is fight 10. Leagues repeat forever after the last one. | `leagues.json` |
| `loopScale` | Multiplies opponent HP only, once per completed pass through all leagues. Coins already grow with the fight number. | `GameEngine._maxHpOf` |
| Prestige gate | Allowed when the run is worth at least 1 Belt (`prestige.minBelts`, about 1M coins earned). The GDD gates it behind mask-versus-hair fights; those are not built. | `balance.json` |
| Belt bonus | +2% damage per Belt **earned** (lifetime), not per Belt currently held, so spending Belts in the talent tree never lowers damage. | `GameState.lifetimeBelts` |
| What prestige resets | Coins, upgrades, trainers, fight number, combo, skill timers, lucky pickup. Keeps masks, talents, Belts, **skill levels** and achievements (the spec lists skills in neither group). | `GameEngine.prestige` |
| Masks and prestige | Prestige does not pick a mask; masks are equipped from the Máscaras tab. Unlock rules: `starter`, `belts` (price), `league` (beat that league's boss), `shop` (granted by a purchase). | `masks.json` |
| Skills | All 5 effects are implemented (Plancha, Furia, Suerte, Grito, Llave). They are learned and levelled with coins; a skill unlocks at a fight number. Timers pause while the app is closed. | `skills.json` |
| Talents | 8 talents in 3 branches, each level costs Belts from a `costs` list; a child needs 1 level of its parent. | `talents.json` |
| Finisher | Needs a full combo meter, then resets it. No extra cooldown (the GDD also mentions a 20 s cooldown). | `balance.json` `combo` |
| Boss countdown | Starts on the first tick of the boss fight. The dramatic boss intro screen belongs to M4. Failing returns to the previous fight with no other penalty. | `GameEngine._tickBossTimer` |
| Lucky events | One pickup at a time, reward is coins (a multiple of the current fight's reward). | `balance.json` `lucky` |
| Achievements | Pay their Belts automatically when reached; there is no achievements screen yet (it is not in the spec's 14 screens). | `achievements.json` |
| Offline earnings | Simulated against the current and next regular opponents and **stop before the next boss**. Earnings wait in the save until collected, so closing the app on the pop-up loses nothing. Away time under 60 s is paid silently. | `GameEngine.applyOffline` |
| Number format | After T the suffix continues with letters (1.2aa, 1.2ab); the Spec says "letters", the GDD says "scientific". | `number_format.dart` |
| Purchase prices | Costs are rounded up to a whole coin so the number on the button is what you need. | `Formulas.purchaseCost` |
| Don Chuy | Cost 50 and 1 damage per second from the GDD (the Spec example shows 150 and fight 8). | `trainers.json` |
| Save format | `saveVersion` 1, JSON file, written every 10 s and when the app goes to the background, with a backup of the previous save. Missing fields take defaults and unknown ids are dropped, so changing content never breaks a save. | `save_codec.dart`, `save_store.dart` |
| Rewarded ads | Behind an `AdService` interface with a fake that "watches" an ad; no SDK yet. A failed ad never blocks the base reward. | `ad_service.dart` |
| Debug panel | Long-press the fight number. Only in debug builds. | `dialogs.dart` |

## M4 decisions

| Topic | What was done | Where |
| --- | --- | --- |
| Studio name | "AM Studios Play" (answered by the designer). The splash is a placeholder; the studio video replaces it when ready. | `strings_es.json`, `intro_screens.dart` |
| Ad offer cooldowns | "Doble 2 min" every 10 min, free "Cinturón" every 30 min (answered by the designer). | `shop.json` |
| Font | Press Start 2P, bundled (SIL OFL). Checked: it has every glyph of the spanish test string (ÁÉÍÓÚÜÑ áéíóúüñ ¡! ¿?). Digits are monospaced. | `assets/fonts/` |
| Navigation | Mejoras is the fight screen; Habilidades, Máscaras, Talentos, Tienda replace the arena; the gear opens Ajustes (and Créditos). The fight stays mounted underneath, so the game keeps running. | `game_screen.dart` |
| Boss intro | The countdown starts only when "¡A PELEAR!" is pressed; until then nothing is damaged. Android back does not skip it. | `GameEngine.awaitingBossStart` |
| Mask grid | 3 x 4 slots; with only 2 masks in the data, the other 10 slots show a locked silhouette. | `masks_view.dart` |
| Talents | Each branch is a column of nodes; unlock order follows `parent`. The "Cambiar de máscara" button lives at the top of Talentos. | `talents_view.dart` |
| Shop | `shop.json` defines items; prices come from `BillingService` (fake: `$XX`) and the fake store grants purchases instantly, so it must never ship. Bought Belts are spendable but do not count for the permanent damage bonus. | `shop_view.dart`, `billing_service.dart` |
| Settings | Sound, music, vibration and notices are saved with the game. Vibration works; sound and music toggles wait for the audio milestone; "Avisos" waits for notifications. | `AppSettings` |
| Privacy | A placeholder text until the real policy and link exist (Play Store requirement). | `strings_es.json` |
| Credits | Built from `credits.json`. The "JUEGO" line comes from the mockup (Alfredo González); music and effects are `[Pista] · [Autor]` placeholders. | `credits.json` |
| App icon | Still Flutter's default (open question). | |
| Pixel rules | Icons come from the mockups' own pixel art, drawn at whole-pixel scale; masks recolor their three reserved colors per mask. | `pixel_icons.dart` |
| Web build | `web/` and a Pages workflow exist only for browser testing. The browser save uses local storage. | `pages.yml` |

## Changes after playtesting M4 (designer feedback)

| Topic | What was done | Where |
| --- | --- | --- |
| Boss on demand | The fight before a boss (fight 9) repeats forever, paying coins, until the player presses "¡JEFE!". Losing the boss returns to that fight and nothing restarts the boss by itself. The intro has a "Volver" button. Offline earnings farm that fight too (one division, not a loop). | `GameEngine.bossGateReady`, `challengeBoss` |
| Responsive screen | The canvas keeps whole *device* pixels per virtual pixel but now grows to fill the window: wider and taller than 180 x 320, up to 270 x 480 virtual pixels (the rest is a border). A narrow browser window or a tablet no longer leaves big empty bands. | `PixelLayout`, `balance.json` `ui` |
| Finisher gesture | The GOLPE button is replaced by a gesture once the combo is full: a clockwise circle, then a counterclockwise one (one stroke as a figure eight, or two strokes). Success lands the finisher; a wrong circle, a straight swipe or running out of time (5 s) resets the combo. A full combo no longer decays while it waits. Short taps keep fighting. | `finisher_gesture.dart`, `balance.json` `gesture` |

**Interpretation to confirm:** "de izquierda a derecha y de derecha a izquierda" was read as clockwise first, then counterclockwise (both go over the top, which makes a figure eight when drawn without lifting). To swap the order, set `gesture.firstDirection` to `counterclockwise` in `balance.json`. The size, roundness and time tolerances are in the same block.

## M5: balance pass

| Topic | What was done | Where |
| --- | --- | --- |
| Milestone multipliers | Added from the GDD (the spec is silent): upgrades and trainers are multiplied (x2) at levels 10, 25, 50, 100, 150, ... Without them the economy hit a wall at fight 19 that no constants could move. | `balance.json` `milestones` |
| Pacing targets | GDD windows (first prestige 20 to 35 min, second 32 to 60) measured for an attentive active player. These were not confirmed by the designer. | `docs/BALANCE.md` |
| Worst case | Tuned for a player who never catches lucky pickups; lucky pickups were cut from 8x to 0.75x so they are a bonus. | `balance.json` `lucky` |
| Prestige | `minBelts` (when) and `beltCoinDivisor` (how much) are now separate levers; the +2% per Belt is unchanged. | `balance.json` |
| Gesture value | The finisher is worth a little (about 10% speed) but is not needed; the bot loses its taps while drawing. | `lib/dev/balance_sim.dart` |
| Tests | The rules tests use a frozen copy of the economy (`test/fixtures/data/`) so tuning never breaks them; a separate pacing test guards the shipped numbers. | `test/test_content.dart` |

## M6/M7 start: milestones in the UI and talents
- Upgrade and trainer rows show a 1-pixel yellow bar with the progress to the next milestone level; upgrade rows also say the level ("Nv 12 > 25"). Milestone levels and multiplier stay in `balance.json`.
- Talents saturated (8 talents of 5 levels cost ~80 belts, one run pays dozens and later thousands). Now 10 levels each (siesta 6), with a two-phase cost curve in `talents.json`: ~x1.8 per level up to level 5, then x4 per level (last level ~10k-21k belts). Early game pacing is unchanged or slightly faster; the deep levels are the long-term belt sink.

## M6: vertical slice (what was built, what is still a stand-in)

**Audio.** `tools/make_placeholder_audio.py` synthesizes every effect and two music loops (main, boss) from scratch (square/triangle/noise), so they are original and CC0; the credits screen says "provisionales". Files are `assets/audio/sfx_<name>.ogg` and `music_<main|boss>.ogg`; replace any of them with the final pick (CC0 or CC-BY only, plus a `credits.json` entry) and nothing else changes. Playback goes through `AudioService` (`flame_audio`), silent in tests. Master, music and effects levels are in `balance.json` (`audio`); the player's switches stay the Sonido / Música toggles of the mockup (the spec also mentions volume sliders: **open question**, the settings mockup has none). Music pauses when the app loses focus; in a browser it starts on the first tap (autoplay rules).

**Haptics.** Which event vibrates, and how hard, is data (`balance.json` `haptics`: tap, crit, finisher, buy, bossIntro, victory). The Vibración switch still turns it all off.

**Sprites.** A sheet is `<key>.png`, one row per animation in the order of `balance.json` `animations.order` (idle 4 frames at 6 fps loop, attack 3 at 12, hit 2 at 12, defeated 3 at 10, victory 2 at 4 loop), one cell per frame (48x48, 64x64 for bosses). Opponent keys are the `sprite` field of `opponents.json`; the player's key is **`player`** (the spec names none: my choice). The game loads `assets/sprites/<key>.png` and falls back to `assets/sprites/placeholder/<key>.png`; with neither, the old rectangles are drawn. The player sheet is palette-swapped once per mask (Night Purple / Violet / Lilac -> the mask's three slot colors, in that order). `tools/validate_sprite.py` checks size, 32-color palette, alpha 0/255, mask-only colors and empty unused cells; `tools/pixelize.py` converts one image into one cell and assembles cells into a sheet. The placeholder sheets are drawn by `tools/make_placeholder_sprites.py` so the pipeline is tested end to end; they are not final art and the art style test is the designer's to do.

**Ads and store.** `PlayAdService` (AdMob rewarded only, never forced) and `PlayBillingService` (Play Billing) implement the existing interfaces; browsers and tests keep the fakes (`platform_services*.dart` pick by platform). Non-release builds use Google's test ad unit; a release build has **no ads** until `balance.json` `monetization.rewardedUnitId` is set. The Play product id of each item is its shop id (`mas_descanso`, `belts_20`, ...). A payment that completes while the app is closed is granted the next time the store reports it. **Not verified on a device:** there is no Android SDK in my environment, only analysis, unit tests with a fake store and a web build.

**Before release (checklist):** replace the sample AdMob app id in `AndroidManifest.xml` and set the real unit id; create the five Play products; real `applicationId`, signing and app icon; privacy policy text.

## M7: launch content

- **Roster:** 3 leagues (Arena del Barrio, Mercado Bravo, Estadio Monumental), 6 opponents plus a boss each (21 characters). New names and flavor lines are mine; none refers to real wrestlers or brands. Fights per league stay at 10 (the earlier decision): the 6 opponents appear in order and the last three repeat, then the boss. Arena colors (wall, ropes, floor) per league are in `leagues.json` (`theme`).
- **Endless leagues:** `loopScale` is 3 for every league (each pass through the 3 leagues makes opponents 3x tougher on top of the normal growth). With more trainers the economy no longer stalls by itself, so this is what keeps depth bounded. The designer may prefer other numbers; see `docs/BALANCE.md`.
- **Trainers (6):** Don Chuy, Chema Pesas, La Licenciada, Las Porras, Tortillería El Puño, Doctor Vendajes (names from the GDD, the last one is new). **All six only deal damage**, because the spec's trainer schema has no special effects; the GDD's special trainers (coin gain, damage that grows with the combo, late coin multiplier) would need an engine feature: **open question.**
- **Masks (12):** the four named in the GDD (Jaguar Dorado, La Calaverita, Taco Supremo, Luchador Nopal) plus eight with the motifs of the Art Prompt Book (Águila, Toro, Rayo, Cobra, Fénix, Tigre, Oso, Diablo). **The documents disagree on names and motifs** (the prompt book's list has Lobo, Sol and Hielo, which are not here), and its mask size is 24x24 against 16x16 in the style guide; my list is a proposal. Unlock: one starter, seven priced in Belts (3 to 2000), one per league boss. Every bonus kind appears at least twice. Icons for the new masks fall back to the jaguar shape recolored with the mask's own colors until art exists.
- **Skills (5) and talents (one tree of 8)** were already complete.
- **Not done:** final art, final audio, the Sol and Hielo masks, shop-unlocked masks, mask-versus-hair special fights.

## Ideas for later (not built)

- **One gesture per wrestler or mask, harder gesture = more damage** (designer idea after playtesting M4). Today every finisher is the same two circles for 20x tap damage. The recognizer is already pure Dart and its tolerances live in `balance.json`, so the natural step is to describe each gesture as data (a list of loops or shapes, each with a direction) and give each one a damage multiplier, tied to the equipped mask or the player's wrestler.
- Questions to settle before building it: which shapes exist besides circles (zigzag, triangle, swipes?), how difficulty is measured (number of shapes, tighter tolerances, shorter time), whether the gesture belongs to the mask, to the wrestler or to both, and how the on-screen guide shows a harder gesture.

## Still open (designer decides)

- Mask slot colors for trunks and cape, app icon, store title, `applicationId` (currently `com.example.lucha_tap_tap`).
- Mask names and the 24x24 vs 16x16 icon size; whether to add volume sliders; special trainers.
- Price points, rewarded-ad cooldowns, music and SFX packs.
- Tall-phone mockup (180 x 390) and whether the offline cap talent range should differ from the 8 h maximum.

## Pacing notes for the balance milestone (M5)

A bot that taps four times a second and buys everything reaches fight 20 within 10 minutes and the first prestige almost immediately, then climbs slowly (fight 30 after three hours across 18 prestiges). The starting numbers from the GDD are therefore too generous early and too flat later; tune `balance.json`, `talents.json` and `skills.json` with the debug panel.

## Tutorial (guided, data-driven)

- `assets/data/tutorial.json` lists the steps: lit targets, the coach's text key, what advances the step (`taps`, `defeats`, `upgradeBought`, `ok`) and an optional `ensureAffordable` upgrade (the missing coins are gifted, not counted as earned). Texts are in `strings_es.json` (`tut_*`).
- The screen is dimmed with only the targets lit and taps outside them are blocked (`lib/ui/tutorial_overlay.dart`); UI elements are marked with `TutorialTarget(id: ...)`.
- Progress is saved in the settings (`tutorialStep`). A save that already played never sees it. "Saltar" ends it; Ajustes > Tutorial plays it again.
- The coach's portrait is a placeholder wrestler until `assets/ui/coach.png` exists (it is picked up automatically).
- Steps 1-4 exist (tap, bars, gifted upgrade, panel). Later steps (trainers, finisher, lucky belt, skills, boss, prestige) only need new entries and trigger conditions.
