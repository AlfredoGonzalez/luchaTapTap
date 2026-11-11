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

## Still open (designer decides)

- Pixel font and the Spanish glyph test. The tab label "Habilidades" is a tight fit in the placeholder font.
- Mask slot colors for trunks and cape, app icon, store title, studio name, `applicationId` (currently `com.example.lucha_tap_tap`).
- Price points, rewarded-ad cooldowns, music and SFX packs.
- Tall-phone mockup (180 x 390) and whether the offline cap talent range should differ from the 8 h maximum.

## Pacing notes for the balance milestone (M5)

A bot that taps four times a second and buys everything reaches fight 20 within 10 minutes and the first prestige almost immediately, then climbs slowly (fight 30 after three hours across 18 prestiges). The starting numbers from the GDD are therefore too generous early and too flat later; tune `balance.json`, `talents.json` and `skills.json` with the debug panel.
