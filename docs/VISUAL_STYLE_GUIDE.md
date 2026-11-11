# Lucha Tap, Tap! — Visual Style Guide v0

Nov 9, 2026 · @Alfredo

## Purpose and how to use this guide

This guide is the single visual reference for Lucha Tap, Tap!. The same rules apply to the UI mockups (Claude Design), the final art (Gemini, ChatGPT, AutoSprite and a pixel editor) and the code (Claude Code). If a mockup or an asset breaks a rule here, the rule wins or this guide is updated first.

Everything in this version is a proposal to react to. The numbers (resolution, palette, sizes) are chosen to be small and consistent so that AI-generated art and placeholder art can be checked against them. Items that still need a decision are listed in the last section.

## Canvas and scaling

- Virtual canvas: 180 pixels wide. Height is 320 pixels at 16:9 and grows up to about 390 pixels on tall phones (19.5:9). The game is always portrait.
- Scaling: the whole canvas is scaled by one integer factor so every virtual pixel is a square block of screen pixels. A 1080-pixel-wide screen uses 6x. If the screen width is not an exact multiple of 180, pick the largest integer factor that fits and fill the leftover border with the background color.
- Density: at 6x on a 1080-pixel screen (about 360 dp wide), one virtual pixel is about 2 dp. Rule of thumb: dp = virtual pixels x 2.
- Extra height on tall phones goes to the arena background (it stretches vertically); the HUD stays anchored to the top and the panels and navigation stay anchored to the bottom.
- Safe areas: keep 12 virtual pixels free at the top and 8 at the bottom for the status bar, camera cutouts and gesture bar.
- Rendering: nearest-neighbor filtering only, no smoothing, no sub-pixel positions for sprites and UI (round to whole virtual pixels).

## Pixel rules

These rules apply to every sprite, background and UI element. They are what makes AI-generated and hand-made art look like one game.

- Everything is drawn on the 180-pixel virtual grid at 1x. No asset is blurred, rotated or scaled by a non-integer factor in the engine, because that creates pixels of different sizes. Rotations are drawn frames. The only allowed scaling is an exact 2x for boss intros.
- Transparency is on or off. Alpha is 0 or 255, never in between, and edges have no anti-aliasing.
- Outline: 1 pixel in Ink (#1B1230) around every character, prop and UI element. Pure black (#000000) is not used anywhere.
- Shading: three tones per material (shadow, base, light), light from the top left, hard edges. No gradients, no soft shadows, no glow made of semi-transparent pixels.
- Dithering: allowed only in backgrounds and in small amounts. Never on characters or UI.
- Colors: every pixel of every shipped asset must be one of the 32 palette colors. A single sprite should use 16 colors or fewer.
- Movement: positions are whole virtual pixels. Screen shake is 1 to 3 pixels, in whole pixels.
- Shapes: chunky and exaggerated. Big heads, big hands and feet, thick limbs, readable silhouette at 32 x 32.
- Quality gate: a small script in the repo checks that all asset images use only palette colors, have only alpha 0 or 255, and have the sizes listed in this guide. Assets that fail do not get imported.

## Master palette

Thirty-two colors, warm and saturated (arena lights, marigold, papel picado), with deep purple instead of black for darks. Seven neutrals, five reds and pinks, five skin and brown tones, three oranges and yellows, four greens, five blues and teals, three purples.

| # | Name | Hex | Use |
| --- | --- | --- | --- |
| 1 | Ink | #1B1230 | Outlines, deepest shadows, text on light colors |
| 2 | Night Purple | #2E1F4A | Main UI panel background, dark backgrounds |
| 3 | Slate | #4A3B6B | Secondary panels, disabled elements |
| 4 | Dust | #7C7396 | Locked decorations and borders (not for text) |
| 5 | Fog | #B8B2CC | Secondary text, borders |
| 6 | Bone | #F6F0E4 | Main text, highlights |
| 7 | White | #FFFFFF | Hit flash, sparkles, tiny highlights only |
| 8 | Wine | #5E1230 | Dark red shadows, blood-red cloth shadow |
| 9 | Lucha Red | #C8283A | Primary action color, player cloth, danger |
| 10 | Coral | #F2545B | Highlights on red, health bar |
| 11 | Pink | #FF8FB1 | Playful accents, cheeks, special effects |
| 12 | Blush | #FFD0DC | Light pink highlights |
| 13 | Chocolate | #4B2A1E | Dark hair, wood, deep brown shadows |
| 14 | Skin Deep | #8F5A3C | Skin shadow and darker skin base |
| 15 | Skin Mid | #D9915E | Skin base |
| 16 | Skin Light | #F7C9A0 | Skin highlight and lighter skin base |
| 17 | Sand | #E8D3A2 | Ring floor, paper, cream details |
| 18 | Burnt Orange | #E2661B | Fire, tacos, warm accents |
| 19 | Marigold | #FFB627 | Coins, buttons, gold trim (cempasúchil) |
| 20 | Sun Yellow | #FFE066 | Coin highlights, lights, star effects |
| 21 | Forest | #1F5A3A | Dark foliage, deep green shadows |
| 22 | Nopal | #2E9E5B | Nopal, avocado, positive states |
| 23 | Lime | #8FD14F | Bright green highlights |
| 24 | Mint | #C5F0A4 | Light green highlights |
| 25 | Navy | #1D2F6F | Night sky, dark blue cloth |
| 26 | Royal | #2F5BEA | Secondary action color, blue cloth |
| 27 | Sky | #5BB8FF | Sky, ice effects, blue highlights |
| 28 | Teal | #1FA6A0 | Water, teal cloth |
| 29 | Aqua | #8FF0E0 | Teal highlights, magic effects |
| 30 | Violet | #7A3FD1 | Masks, magic, special items |
| 31 | Lilac | #B993F5 | Violet highlights |
| 32 | Magenta | #D12FA0 | Rare items, boss accents |

Color use rules:

- Each ramp (reds, skin tones, yellows, greens, blues, purples) provides dark, base and light for shading.
- Main text is Bone on Night Purple or Ink. Numbers that matter (coins, damage) use Sun Yellow or Marigold on Night Purple or Ink.
- Buttons: Lucha Red is the main action, Royal is secondary, Nopal means confirm or positive, Slate or Dust means disabled.

Contrast, measured with the WCAG formula (4.5 or higher is comfortable for small text):

| Text on background | Ratio | Verdict |
| --- | --- | --- |
| Bone on Ink | 15.7 | Fine |
| Bone on Night Purple | 13.1 | Fine |
| Sun Yellow on Night Purple | 11.4 | Fine |
| Marigold on Ink | 10.2 | Fine |
| Ink on Sun Yellow | 13.7 | Fine |
| White on Lucha Red | 5.5 | Fine for button text |
| Bone on Lucha Red | 4.8 | Fine for button text |
| Ink on Nopal | 5.2 | Use this for text on green |
| White on Nopal | 3.4 | Too low for small text; do not use |

The palette is a proposal to refine after the art style test: the real sprites may show that one ramp needs another tone. Also checked: Fog on Slate reaches 4.8 (use it for disabled text), while Lucha Red on Night Purple (2.7) and Dust on Slate (2.2) are too low for text.

## Typography

One pixel font for the whole game, free for commercial use. Candidates to test, all available as open fonts: Press Start 2P, Silkscreen and Pixelify Sans. Before choosing, render this test string in each one and check that every character draws correctly: ÁÉÍÓÚÜÑ áéíóúüñ ¡! ¿? 0123456789 1.2K 3.4M. Also confirm each font's license in writing before shipping.

Rules:

- Draw the font only at its native pixel size and at whole multiples of it (for example 8 and 16 virtual pixels). Never at other sizes.
- Sizes: body and labels 8 pixels, section titles 16 pixels, boss names and big numbers 16 to 24 pixels. No text smaller than 8 pixels.
- Text color comes from the palette only (see contrast table). Titles may have a 1-pixel Ink drop shadow to the bottom right.
- Numbers use compact notation: 999, 1.2K, 3.4M, 5.6B, then scientific. They never change width while counting, so use tabular spacing for digits when the font allows it.
- All text is Spanish, written with correct accents and opening marks. Text inside images is also Spanish.

## UI components

All sizes are in virtual pixels (1 pixel is about 2 dp).

- Touch targets: every tappable element is at least 24 x 24 pixels (about 48 dp), with at least 4 pixels between neighboring targets.
- Panels: 9-slice sprite, Night Purple fill, 1-pixel Ink outline, 1-pixel Slate inner border on top and left, 4-pixel corners made of stepped pixels (no curves). Smallest panel 16 x 16.
- Buttons: 24 pixels tall or more, three colors (Lucha Red main action, Royal secondary, Nopal confirm). Three states: normal; pressed (shifts 1 pixel down and uses the darker tone of its ramp); disabled (Slate fill, Fog text). Label in Bone, 8 pixels.
- Progress bars: 8 pixels tall with a 1-pixel Ink outline. Health: Coral fill on a Wine track. Boss timer: Marigold on Ink. Combo meter: Violet filling up, turning Sun Yellow when full and the finisher is ready.
- Icons: 16 x 16 for navigation and lists, 8 x 8 for inline icons (coin, gem, belt). Same outline and palette rules as sprites.
- List rows (upgrades, trainers): 26 pixels tall (a 24-pixel button with 1 pixel above and below). 16 x 16 icon on the left, name and level in the middle (8-pixel text), buy button 24 pixels tall on the right showing the cost.
- Overlay behind pop-ups: a checkerboard of Ink pixels (every other pixel) instead of a semi-transparent fill, so the screen keeps strict pixel rules.
- Pop-ups (offline earnings, prestige, shop item): centered panel up to 150 pixels wide, title 16 pixels, one main button and one close button.
- Feedback: every press shows the pressed state immediately; successful purchases flash the row Sun Yellow for 2 frames; when a purchase is not affordable the button uses the disabled style (Lucha Red on Night Purple only reaches 2.7:1, so it is not used for text).

## Main fight screen layout

Rows for the 180 x 320 canvas. On taller phones, the extra rows are added to the arena; every other zone keeps its height.

| Rows (y) | Height | Zone | Contents |
| --- | --- | --- | --- |
| 0–12 | 12 | Top safe area | Empty |
| 12–36 | 24 | HUD | Coins (left), fight number (center), gems and settings icon (right) |
| 36–52 | 16 | Opponent bar | Opponent name (8-pixel text) and health bar; on boss fights two stacked 8-pixel bars (health above, timer below) replace the name line, and the boss name moves to the top of the arena |
| 52–154 | 102 | Arena | Background, opponent (right), player (left), damage numbers, lucky-event pickups. The whole zone is the tap area |
| 154–178 | 24 | Combo row | Combo meter (left, about 100 pixels wide) and the finisher button (right, 48 x 24) |
| 178–208 | 30 | Skills row | Up to five skill buttons, 30 x 30 each, 4 pixels apart, with a cooldown fill |
| 208–288 | 80 | Panel | Buy multiplier selector (x1, x10, x100, max) 24 pixels tall, then two 26-pixel list rows; scrolls |
| 288–312 | 24 | Bottom navigation | Five tabs, 36 pixels wide each: Upgrades, Skills, Masks, Talents, Shop |
| 312–320 | 8 | Bottom safe area | Empty |

Other screens reuse the same frame: Masks, Talents and Shop replace the arena and panel (rows 34 to 288) and keep the HUD and navigation. Prestige, boss intro and the offline earnings pop-up are overlays on top of the frame.

Arena composition: the player stands on the left (feet on the floor line), the opponent on the right. Regular opponents are 48 pixels tall, bosses 64. The tap area is the whole arena, so no part of it holds a small button.

## Characters and effects

Sprite sizes (each in a square cell, feet at the bottom center):

| Asset | Size | Notes |
| --- | --- | --- |
| Player | 48 x 48 | Faces right |
| Regular opponent | 48 x 48 | Drawn facing right and flipped in the engine; the lighting flips with it, which is accepted |
| Boss and mask-versus-hair opponent | 64 x 64 | Bigger and more detailed |
| Trainer portrait | 24 x 24 | Static, optional two-frame idle |
| Mask icon | 16 x 16 | Collection grid; a 32 x 32 preview on the mask screen |
| Item and skill icons | 16 x 16 | Same rules as sprites |

Animations per fight character (a sheet has one row per animation, frames left to right, cells of the sprite size):

| Animation | Frames | Speed | Plays |
| --- | --- | --- | --- |
| Idle | 4 | 6 fps | Loops |
| Attack | 3 | 12 fps | Once |
| Hit | 2 | 12 fps | Once |
| Defeated | 3 | 10 fps | Once |
| Victory | 2 | 4 fps | Loops |

Mask palette swap: character sprites are drawn with three reserved colors that appear only on the mask: Night Purple (shadow), Violet (base) and Lilac (light). The engine replaces those three with the color triplet stored in each mask's data file. No other part of a character may use those three colors. A second set of reserved colors for trunks or cape can be added later if the art test shows it is needed.

Effects (all built from palette colors and whole pixels):

- Hit flash: the opponent's silhouette turns White for 2 frames on every tap.
- Damage numbers: 8-pixel Bone text rises 12 pixels in 0.6 seconds and disappears. Critical hits and finishers use 16-pixel Sun Yellow.
- Screen shake: none on a normal tap; 3 pixels for 0.2 seconds on a finisher; 3 pixels for 0.5 seconds when a boss falls.
- Particles: at most 4 x 4 pixels each and at most 24 on screen. Coins are 8 x 8 and fly to the coin counter.
- Boss intro: Ink bars of 24 pixels slide in at the top and bottom, the opponent shows at exactly 2x, the name appears in 16-pixel text, about 1.5 seconds, then the timer starts.
- Mask-versus-hair intro: same as the boss intro, plus a stronger shake and the music change.

## Brief for Claude Design and open decisions

Plain text, ready to copy and paste into Claude Design. The mockups are layout and hierarchy references; they will not be true pixel art, so the brief asks for hard pixel edges to get as close as possible.

```text
Design mobile game UI mockups for "Lucha Tap, Tap!", an Android idle/clicker game with a comedic Mexican lucha libre theme. All on-screen text is in Spanish.

CANVAS
- Portrait, 180 x 320 px base canvas. Also provide a 180 x 390 variant (extra height goes to the arena only).
- Render at 3x or 6x with hard pixel edges and no smoothing. One canvas pixel is about 2 dp.

STYLE
- Chunky pixel art look. 1 px outline in #1B1230 around everything.
- No gradients, no blur, no soft shadows, no anti-aliasing, no rounded vector corners (use stepped pixel corners). Light from the top left, three tones per material.
- Use ONLY these 32 colors: Ink #1B1230, Night Purple #2E1F4A, Slate #4A3B6B, Dust #7C7396, Fog #B8B2CC, Bone #F6F0E4, White #FFFFFF, Wine #5E1230, Lucha Red #C8283A, Coral #F2545B, Pink #FF8FB1, Blush #FFD0DC, Chocolate #4B2A1E, Skin Deep #8F5A3C, Skin Mid #D9915E, Skin Light #F7C9A0, Sand #E8D3A2, Burnt Orange #E2661B, Marigold #FFB627, Sun Yellow #FFE066, Forest #1F5A3A, Nopal #2E9E5B, Lime #8FD14F, Mint #C5F0A4, Navy #1D2F6F, Royal #2F5BEA, Sky #5BB8FF, Teal #1FA6A0, Aqua #8FF0E0, Violet #7A3FD1, Lilac #B993F5, Magenta #D12FA0.
- Pixel font only: 8 px for body and labels, 16 px for titles. Spanish accents must render. Main text Bone on Night Purple or Ink; important numbers in Sun Yellow or Marigold.
- Buttons: Lucha Red main action, Royal secondary, Nopal confirm, Slate disabled. Minimum tappable size 24 x 24 px, 4 px between targets.

MAIN FIGHT SCREEN LAYOUT (y rows on the 320 px canvas)
- 0-12 empty safe area
- 12-36 HUD: coins left, fight number center, gems and settings right
- 36-52 opponent name and health bar (on boss fights: two stacked bars, health above and timer below, and the boss name at the top of the arena)
- 52-154 arena: player left, opponent right (48 px tall, bosses 64 px), whole zone is the tap area
- 154-178 combo meter (left) and finisher button (right, 48 x 24)
- 178-208 up to five skill buttons, 30 x 30 each
- 208-288 panel: buy multiplier selector (x1, x10, x100, max) (24 px tall) and two 26 px list rows
- 288-312 bottom navigation, five tabs: Mejoras, Habilidades, Máscaras, Talentos, Tienda
- 312-320 empty safe area

SCREENS TO DESIGN (one frame each)
1. Main fight, regular opponent
2. Main fight, boss with countdown timer
3. Boss intro (dark bars top and bottom, opponent at 2x, name in 16 px)
4. Mejoras panel with tap upgrades and trainers
5. Habilidades panel with cooldowns
6. Máscaras collection grid (owned and locked silhouettes)
7. Cambiar de máscara (prestige) confirmation with Belts to earn
8. Talentos tree
9. Ganancias sin conexión pop-up with a button to double them by watching an ad
10. Tienda
11. Ajustes, including Créditos

SAMPLE COPY (Spanish, comedic tone): "Pelea 47", "¡Golpe final!", "Cambiar de máscara", "Ganancias sin conexión", "Duplicar (ver anuncio)", "Máscara contra cabellera".

CHARACTERS: use simple placeholder pixel figures with exaggerated proportions (big head, big hands). Do not depict real wrestlers or real brands.
```

Open decisions:

- Font: pick one after the Spanish glyph test and a license check.
- Palette: confirm after the art style test; add a tone if a color ramp lacks a shade.
- Mask slot colors (Night Purple, Violet, Lilac): confirm on the first real character.
- Sprite sizes (48 and 64 pixels): confirm that the AI pipeline holds the pixel grid at these sizes.
- Second slot set for trunks or cape: decide after the art test.
- Horizontal flipping of opponents: accepted for now; revisit if the flipped lighting looks wrong.
