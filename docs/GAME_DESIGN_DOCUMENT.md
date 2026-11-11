# Lucha Libre Clicker — Game Design Document v0

Nov 9, 2026 · @Alfredo

## Vision and pillars

Lucha Libre Clicker is a mobile active-idle clicker in pixel art. The player tap-fights through a comedic, over-the-top lucha libre league, hires help that fights automatically, and resets the career by changing masks. The genre reference is the tap-to-fight idle RPG clicker (tap to hit enemies, buy upgrades, hire helpers, fight bosses, prestige, earn while offline).

Three pillars guide every decision:

1. Tapping always matters. Active play (taps, combos, timed finishers) beats pure waiting, but the game keeps progressing while the app is closed.
2. Comedy first, epic at the peaks. Regular fights are funny and exaggerated; boss fights and mask-versus-hair fights get bigger sprites, music changes and screen shake.
3. Masks are the content. Each mask is a collectible, a gameplay bonus and a prestige choice, and masks are cheap to produce because they share a base body with a different palette.

## Scope and constraints

- Platform: Android first, portrait orientation only. iOS is a possible later port, so avoid Android-only code where a cross-platform option exists.
- Language: Spanish only (Mexican Spanish), including any text inside art. Keep all strings in one localization file so other languages can be added later.
- Engine: Flutter with the Flame game engine. Pixel art must render with image smoothing turned off (nearest-neighbor filtering) so sprites stay sharp.
- Monetization: optional rewarded ads and in-app purchases. No forced ads, ever (details in the Monetization section).
- Connectivity: fully playable offline. Ads and purchases are the only features that need a connection.
- Data-driven design: opponents, masks, trainers, upgrades and skills live in editable data files (JSON), not in code, so balancing never requires a code change.
- Out of scope for v1: multiplayer, leaderboards, cloud save, accounts, iOS.

## Tone and setting

The tone is comedic and exaggerated, with epic moments reserved for bosses. Lucha libre is already theatrical (pompous nicknames, absurd rivalries, dramatic entrances), so the game leans into that instead of playing it straight.

- Regular fights: silly opponents, neighborhood humor, short funny lines before and after each fight, big chunky hit effects.
- Boss fights and mask-versus-hair fights: the music changes, the opponent sprite grows, the screen shakes, and the intro is more dramatic. The contrast between funny and epic is what makes these moments special.
- Writing: Mexican Spanish, short lines, nicknames and wordplay. No real wrestlers, promotions or brands.

Legal rule: every character, mask, name and logo is original. Lucha libre is used as a genre and aesthetic only. Do not reference real luchadores (for example El Santo or Blue Demon) or real promotions.

## Core loop

The player's wrestler fights one opponent at a time. Each loop is about 10 to 30 seconds of active play.

1. Tap the opponent to deal damage. Every tap also adds to a combo meter.
2. Defeating an opponent pays out coins and advances the fight counter.
3. Spend coins on tap upgrades, trainers (automatic damage) and skills.
4. Fill the combo meter with well-timed taps to unlock the finisher: a single large hit with a short animation.
5. Every 10th fight is a boss with a countdown timer. Failing the timer drops the player back one fight to farm and try again.
6. Every 50th fight is a mask-versus-hair fight, a special boss that gates the first and each later prestige.
7. Prestige ("Change Mask") resets coins, upgrades and fight progress in exchange for a permanent currency and a new mask with its own bonus.

Idle layer: trainers and the gym keep dealing damage and fighting while the app is open and untouched, and offline earnings accrue while it is closed (see Systems).

Active skills have cooldowns and are the main reason to stay engaged during long sessions.

## Progression structure

Progress is measured in fights, grouped into stages and leagues.

- Fight: one opponent. Opponent health grows exponentially with the fight number.
- Stage: 10 fights. The 10th is a boss with a timer.
- League: 5 stages (50 fights). The last fight of a league is a mask-versus-hair fight. Each league has its own visual theme (neighborhood arena, market, stadium, and so on) and a pool of opponents.
- First prestige: available after the first mask-versus-hair fight, which should be reachable in about 20 to 30 minutes of active play so new players see the reset early.
- Later prestiges: each run should take longer and reach deeper than the one before, driven by the permanent currency and the mask bonus.
- Early game target: the first 10 minutes should hand out a new upgrade, trainer or unlock about every 30 to 60 seconds.

These timings are targets to test in the prototype, not final numbers.

## Systems

- Tap upgrades: spend coins to raise damage per tap. Cost rises with each level. Milestone levels (25, 50, 100, and so on) give a damage multiplier.
- Trainers (idle damage): hireable helpers such as the coach, the manager, the gym rat and the fan club. Each deals automatic damage per second, has its own cost curve, and gets milestone multipliers. Trainers are the idle backbone.
- Combo and finisher: consecutive taps within a short window build a combo meter. A full meter enables the finisher button, a large single hit with a cooldown. Tapping rhythm matters more than raw speed.
- Active skills: 4 to 6 skills with cooldowns (for example a damage burst, a coin bonus, an automatic-tap burst). Unlocked with coins or talent points, upgradable.
- Boss timer: boss fights have a countdown (30 seconds baseline). Beat it to advance; fail and the player returns to the previous fight.
- Lucky events: occasional random pickups on screen (a flying belt, a fan throwing money) that reward a quick tap, in the style of the golden cookie.
- Masks: each mask is a collectible with a passive bonus and a unique palette-swapped sprite. The player picks one on each prestige. Some masks come from random drops, some from achievements.
- Prestige ("Change Mask"): resets coins, upgrades, trainers and fight progress. Grants Belts (permanent currency) that feed a talent tree and a flat damage bonus.
- Talent tree: spend Belts on permanent bonuses (tap damage, trainer damage, coin gain, skill cooldown, offline cap, starting coins after prestige).
- Offline earnings: while the app is closed, trainers keep fighting. On return, show a summary popup with the coins earned. Base cap of 4 hours, extendable through the talent tree or a purchase. An optional rewarded ad doubles the collected amount.
- Achievements: simple milestones (fights won, taps made, masks owned) that pay small rewards and unlock some masks.
- Save: local save every few seconds and on app pause. Store the last-seen timestamp to compute offline earnings, and guard against obvious clock manipulation.

## Economy v0

Every number below is a starting value to tune in the prototype. Keep all of them in data files.

Currencies:

- Coins: soft currency, earned per fight, reset on prestige.
- Belts: prestige currency, permanent, spent in the talent tree.
- Gems: premium currency, bought with real money or earned rarely from events and rewarded ads. Used for cosmetics, extra offline cap and convenience, never for exclusive power that blocks progress.

Opponent health for fight number n (boss = 10 times):

```latex
HP(n) = 10 \cdot 1.55^{\,n-1}
```

Coins paid per normal opponent (boss pays 5 times):

```latex
Coins(n) = 0.15 \cdot HP(n)
```

Cost of the next level of a tap upgrade or trainer, with owned level k:

```latex
Cost(k) = base \cdot 1.15^{\,k}
```

Prestige reward, where C is the total coins earned in the run:

```latex
Belts = \lfloor \sqrt{C / 10^6} \rfloor
```

Each Belt gives +2% to all damage, plus whatever the talent tree adds.

Starting values to test: tap damage 1; first tap upgrade costs 10 coins; first trainer costs 50 coins and deals 1 damage per second; combo window 1.5 seconds; finisher hits for 20 times tap damage with a 20-second cooldown; boss timer 30 seconds.

Balance goals: the first prestige at 20 to 30 minutes, the second at roughly 40 to 60 minutes of play, and every fight number reachable in a reasonable time without paying.

## Screens and navigation

Portrait only. The main screen stays on the fight; everything else opens as a tab or a panel from a bottom bar so the player never fully leaves the fight.

| Screen | Purpose |
| --- | --- |
| Main fight | Opponent, player, health bar, combo meter, finisher button, coin counter, fight counter, skill buttons, lucky-event pickups |
| Upgrades panel | Tap upgrades and trainers with costs, levels and a buy-max toggle (x1, x10, x100, max) |
| Skills panel | Active skills, cooldowns, unlock and upgrade |
| Masks | Collection grid, equipped mask, bonuses, locked silhouettes |
| Prestige | Change Mask preview: Belts to be earned, mask selection, confirmation |
| Talent tree | Belt spending, permanent bonuses |
| Boss intro | Dramatic opponent introduction with timer starting after it |
| Offline earnings popup | Coins earned while away, optional rewarded ad to double |
| Shop | Gems, no-ads-style purchases if any, offline cap extensions |
| Achievements | List with progress and rewards |
| Settings | Sound, music, vibration, language note, privacy policy, restore purchases |

UI constraints: large touch targets (at least 48 dp), numbers shown in compact notation (1.2K, 3.4M, 5.6B, then scientific), clear feedback on every tap (hit flash, floating damage number, short vibration option).

## Monetization

Principle: nothing is forced. The game never interrupts play with an ad, and every paid or ad-supported feature is a convenience or a cosmetic, not a wall.

Rewarded ads (always optional, always player-initiated, with a clear label of the reward before the ad plays):

- Double the offline earnings popup.
- A temporary boost (for example 2x damage for a few minutes), limited per day.
- A free refresh of skill cooldowns.
- A small bonus after a failed boss fight.

In-app purchases:

- Gem packs in a few sizes.
- One-time starter bundle (gems, a boost and a cosmetic mask).
- Offline cap extensions and permanent convenience items (for example auto-buy for the cheapest upgrade).
- Cosmetic masks and arenas.

Rules for balance: free players can reach every fight and every mask that comes from gameplay; paid items save time or add cosmetics. Prices are configured in the Play Console in MXN to start, and the exact price points are still open.

Technical notes: use Google AdMob rewarded ads and Google Play Billing. Handle the no-fill and offline cases gracefully (hide the ad button or show a friendly message), and add a restore-purchases option in Settings.

## Art direction

Style: chunky, colorful pixel art with strong silhouettes and thick readable shapes. Humor comes from exaggerated proportions and expressive poses.

- Virtual resolution: 180 x 320 pixels in portrait, scaled by an integer factor (6x on a 1080 x 1920 screen) so pixels stay square and sharp. Letterbox or extend the background on other aspect ratios instead of stretching.
- Sprite sizes: player and regular opponents 32 x 32 or 48 x 48 pixels; bosses and mask-versus-hair opponents 64 x 64 pixels.
- Palette: one master palette of about 32 colors shared by the whole game, so everything looks consistent. UI uses the same palette.
- Animation per character, kept short: idle (2 to 4 frames), attack (3 to 4), hit (2), defeated (3), victory (2). Extra impact comes from effects (screen shake, flash, floating numbers), not from more frames.
- Masks are palette swaps and small overlay details on the same base body, so adding a mask is cheap.
- UI: pixel-style panels built with 9-slice sprites, buttons with pressed states, and a pixel font that supports Spanish accents and the characters n with tilde and inverted punctuation. No gradients, no rounded vector shapes.
- Backgrounds: one layered arena per league (static layers with small animated details such as a flashing crowd).
- Audio: chiptune-style music with a calmer track for normal fights and a more intense track for bosses, and punchy short sound effects for taps, hits and finishers.

Production notes: build the whole game first with placeholder rectangles and colors; replace with final art last. If AI tools generate the sprites, expect manual cleanup to keep the pixel grid, palette and frame-to-frame consistency. Every character is original.

## Starter content

All names are original placeholders to set the tone. Check name availability before release.

| Type | Name | Idea |
| --- | --- | --- |
| Opponent | El Taquero Cósmico | Uses a salsa so hot it burns the other wrestler's eyes |
| Opponent | La Abuela Fantasma | Her hugs lower the player's damage for a few seconds |
| Opponent | Mr. Aguacate | Gets stronger and riper with every hit he takes |
| Opponent | El Mariachi Furioso | Boss: plays a song that speeds up the timer |
| Opponent | Doña Chela Tornado | Spins and dodges every fifth tap |
| Mask | Jaguar Dorado | Bonus to tap damage |
| Mask | La Calaverita | Bonus to coins from bosses |
| Mask | Taco Supremo | Bonus to trainer damage |
| Mask | Luchador Nopal | Bonus to offline cap |
| Trainer | Don Chuy, the coach | First trainer, cheap, deals small steady damage |
| Trainer | La Licenciada, the manager | Raises coin gain |
| Trainer | Chema Pesas, the gym rat | Large damage, expensive |
| Trainer | Las Porras, the fan club | Damage grows with the combo meter |
| Trainer | Tortillería El Puño, the sponsor | Late-game coin multiplier |

Launch target to test: 3 leagues, around 6 opponents per league plus a league boss, 12 masks, 6 trainers, 5 skills. Start smaller for the prototype: one league, 5 opponents, 3 masks, 3 trainers, 3 skills.

## Build plan and open questions

The build runs in this order. Final art comes last, so the game can be played and balanced before any art money or time is spent.

1. Art style test: one player character, two opponents and one boss with all five animations, made with the planned pipeline (Gemini or ChatGPT, AutoSprite, pixel editor) and checked against the master palette. If it holds up, the pipeline is validated before any mockup or final art work.
2. Visual style guide: virtual resolution, palette, font, button sizes (this document's Art direction, made concrete).
3. UI mockups in Claude Design for the screens listed above, used as layout and hierarchy references, not as final art.
4. Technical specification for Claude Code: Flutter and Flame architecture, folder structure, data files, big-number handling, save and offline logic, ad and purchase stubs.
5. Prototype with placeholder art: one league, the full core loop, the first prestige, and the economy running from data files. Test and tune the numbers here.
6. Vertical slice: first prestige, talent tree, masks and offline popup complete and fun for 30 to 60 minutes.
7. Content expansion: remaining leagues, opponents, masks, trainers and skills.
8. Final art and audio replace the placeholders.
9. Monetization integration (AdMob rewarded ads, Google Play Billing) and Play Store preparation: privacy policy, data safety form, content rating.
10. Closed test, then launch on Android.

Open questions:

- App icon and Play Store subtitle (the game title is settled: Lucha Tap, Tap!).
- Whether the sprite pipeline (Gemini or ChatGPT, AutoSprite, pixel editor) holds the pixel grid and palette in the art style test.
- Which open-source music and sound packs to use (CC0 or CC-BY only).
- Price points for gem packs and the starter bundle. To be set after the prototype, in MXN, based on similar games.
