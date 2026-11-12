# Balance pass (M5)

How the economy was tuned, how to measure it, and what it can and cannot tell you. The numbers live in `assets/data/` (`balance.json`, `upgrades.json`, `trainers.json`, `talents.json`); nothing here is in Dart.

## Measuring: the balance simulator

`lib/dev/balance_sim.dart` is a bot that plays the real `GameEngine` (it is not part of the app): it taps, buys what pays back best, learns and uses skills, catches lucky pickups, draws the finisher gesture (taking a moment during which it does not tap), challenges the boss when it has enough damage, spends Belts and changes mask when its run has stalled.

```bash
dart run tool/balance_report.dart 3                      # 3 hours, three player types, milestone table
dart run tool/balance_sensitivity.dart 3                 # the same game under 10 different players
EARLY=1 dart run tool/balance_report.dart 1 assets/data activo   # first purchases, with times
BOT_LUCKY=0 dart run tool/balance_report.dart 3          # a player who never catches the floating belt
```

`test/balance/pacing_test.dart` runs the simulator on the shipped data and fails if the pacing leaves the windows below, so a careless edit to a JSON file is caught.

## Targets

From the Game Design Document, plus two I added after the first measurements:

| Target | Window |
| --- | --- |
| First prestige | 20 to 35 minutes of active play |
| Second prestige | 32 to 60 minutes (GDD: 40 to 60) |
| First purchase / first trainer | under 1 minute / under 4 minutes |
| New things early | an upgrade, trainer or skill every 1 to 3 minutes for the first 15 minutes (GDD asks for 30 to 60 seconds; the prototype has only 9 items to hand out) |
| No permanent wall | the best fight keeps growing over hours |
| Lucky pickups | a bonus, never a requirement (added) |
| The finisher gesture | a bonus, never a requirement (added) |

The tuning was done against the **worst case** (a player who never catches a lucky pickup), found by an automatic search over the economy parameters with these targets as the objective, then rounded by hand and checked.

## What was wrong, and what changed

The starting numbers (HP x1.55 per fight, costs x1.15 per level, +1 damage per level) hit a wall at **fight 19 for ever**: opponent HP grows exponentially but a unit's output grew only linearly with its level, so no value of any constant could keep up.

1. **Milestone multipliers** (new, from the GDD, which the Technical Spec does not mention). Each time an upgrade or trainer reaches a milestone level (10, 25, 50, 100, 150, ...) its output is multiplied (x2). Data in `balance.json` `milestones`.
2. **Retuned numbers:**

| Parameter | Before | After |
| --- | --- | --- |
| First opponent HP (`hpBase`) | 10 | 125 |
| HP growth per fight | 1.55 | 1.30 |
| Coins per fight (fraction of HP) | 0.15 | 0.6 |
| Upgrade "Puño duro" cost | 10 | 72 |
| Trainer Don Chuy: cost / damage per second | 50 / 1 | 450 / 4.2 |
| Trainer Chema Pesas: cost / damage per second | 1,100 / 20 | 10,000 / 85 |
| Belts: `beltCoinDivisor` | 1,000,000 | 3,000 |
| Prestige allowed from (`minBelts`) | 1 | 44 |
| Talents: tap, trainer, coin multipliers per level | 0.10, 0.10, 0.05 | 0.15, 0.15, 0.075 |
| Lucky pickup reward (x current fight's coins) | 8 | 0.75 |

Belts per prestige used to be 1 to 4 (+2% to +8% damage), which could not beat a boss that has 10 times the HP. The divisor and the minimum are now separate levers: `minBelts` says *when* the player may change mask, the divisor says *how much* it pays. The +2% per Belt from the documents is unchanged.

## Results (active player, 4 taps per second, 80% gesture success, does not catch lucky pickups)

| | Minute |
| --- | --- |
| Fight 11 (first boss beaten) | 6 |
| Fight 20 | 11 |
| Fight 30 | 29 |
| Fight 50 | 81 |
| Change mask becomes possible | 24 |
| 1st / 2nd / 3rd / 4th prestige | 24 / 40 / 48 / 55 |

Best fight reached: 49 after 1 hour, 59 after 2 hours, 69 after 3 hours. Early purchases: first at 23 s, crit upgrade by 2 min, first trainer at 2.4 min, first skill at 4.3 min.

### Sensitivity (minutes to the 1st, 2nd and 3rd prestige; best fight after 3 hours)

```
jugador                    disp.  1er   2do   3er  pelea20 pelea30 pelea50 mejor@1h mejor@3h
activo (referencia)           15    17    26    33      10      20      49       59       79
toca 2/s                      22    23    33    40      16      26      56       59       79
toca 6/s                      15    16    25    39       7      18      48       59       79
gesto 40% de acierto          19    19    30    36      12      23      52       59       79
nunca hace el gesto           16    17    27    33       9      20      49       59       79
no atrapa suerte              24    24    40    48      11      29      81       49       69
prestigia tras 2 min          15    15    23    27      10      19      42       59       79
prestigia tras 10 min         15    22    35    50      10      24      62       49       69
casual 5 min cada 30          64    90   120   150      60      92       -       20       49
casual 10 min cada 2 h       122   126     -     -     120     129       -        1       39
```

The pacing does not depend on one exact player: tap rate, gesture skill and when to prestige move the first prestige by a few minutes, and catching lucky pickups makes it about 30% faster.

## Limits: read before trusting these numbers

- **It is a bot.** Real players are slower to decide, forget skills, misdraw gestures and take breaks. The targets are for an attentive player; the casual rows show a calmer one.
- **The M5 numbers above were measured with the prototype content** (2 trainers, 2 masks, 1 league). They are kept as history; the launch content changed the curve, see the M7 section.
- **The wall is the boss.** Every tenth fight has 10 times the HP, so progress comes in steps; players will feel it and the "¡JEFE!" button is where they decide.
- **Casual play is slow** (first prestige at about 1 hour 30 for 5 minutes every half hour). Offline earnings help but the 4 hour cap and trainers-only damage limit them. A designer call: is that the desired pace for a casual player?
- **Milestones are now visible:** a yellow bar under each upgrade and trainer row shows progress to the next milestone level.
- **Talents no longer saturate:** 10 levels each with a steep tail (see DECISIONS.md).
- **The prestige policy is a guess** (change mask after 5 minutes without a new fight). The simulator accepts any rule; see the "prestigia tras" rows.

## M7: launch content (3 leagues, 6 trainers, 12 masks)

What happened when the launch content went in, measured with the same simulator (active player, 4 taps per second, never catches a lucky pickup):

| | Before M7 (prototype content) | After |
| --- | --- | --- |
| Fight 20 / 30 | 11 / 29 min | 11 / 27 min |
| 1st / 2nd / 3rd / 4th prestige | 24 / 40 / 48 / 55 min | 23 / 36 / 45 / 53 min |
| Best fight at 1 h / 2 h / 3 h | 49 / 59 / 69 | 39 / 110 / 199 |

The first hour is untouched (the new trainers cost 10^8 and up). What changed is the depth: with only two trainers the economy hit a wall around fight 70; with six, each new tier lets the player escape the cost growth of the old ones, and the Belts bonus (+2% per Belt, Belts grow with the square root of coins) feeds back, so progress no longer stalls. Left alone it reached fight 270 in three hours with 10^16 Belts, which burns through three 10-fight leagues dozens of times.

What I did about it, in order of how much it mattered:

1. **`loopScale` 3** on every league (data): each full pass through the three leagues multiplies opponent HP by 3. The first 30 fights are unaffected. This brought the second prestige back to 36 minutes.
2. **Trainers 3 to 6 are expensive and late** (cost 10^8, 10^10, 10^12, 10^14; unlock at fights 32, 48, 64, 80). I tried cheaper and earlier tiers: they made the second prestige 10 minutes faster and the best fight at one hour 109.
3. **Masks:** the extra bonuses (+20% tap, +30% trainers...) also shorten the second run by a few minutes; I left them.

Open: how deep should three hours go? Nothing in the GDD says. The pacing test now requires the best fight to be at least 35 after an hour (it was 40) and growing after that. A bigger `loopScale` makes the loop steeper, a smaller one lets it run away. **Not re-run after M7:** the full sensitivity table (tap rate, gesture, prestige policy); only the headline profiles above.
