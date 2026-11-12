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

## Still open (designer decides)

- Mask slot colors for trunks and cape, app icon, store title, studio name, `applicationId` (currently `com.example.lucha_tap_tap`).
- Price points, rewarded-ad cooldowns, music and SFX packs.
- Tall-phone mockup (180 x 390) and whether the offline cap talent range should differ from the 8 h maximum.

## Pacing notes for the balance milestone (M5)

A bot that taps four times a second and buys everything reaches fight 20 within 10 minutes and the first prestige almost immediately, then climbs slowly (fight 30 after three hours across 18 prestiges). The starting numbers from the GDD are therefore too generous early and too flat later; tune `balance.json`, `talents.json` and `skills.json` with the debug panel.
