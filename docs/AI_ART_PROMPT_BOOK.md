# Lucha Tap, Tap! — AI Art Prompt Book v0

Nov 11, 2026 · @Alfredo

## 1. How to use this book

Every prompt below is complete: copy one block, paste it into the image tool, and nothing else is needed. The style rules and the palette are repeated inside each prompt on purpose, so you never have to remember a prefix.

**Workflow for each asset**

1. Generate at large size (about 1024 x 1024) with the prompt. AI tools cannot draw true 48 x 48 pixel art, so the prompt asks for a design that survives downscaling.
2. Generate 4 variations and pick the best silhouette. Do not pick by details; they disappear at 48 px.
3. If something is wrong, use a fix-up prompt from section 6 with the picked image attached.
4. Remove the magenta background, trim to the character, downscale to the target size with nearest-neighbor, and remap every pixel to the 32-color palette (section 7; Claude Code can write the script).
5. Hand-clean in a pixel editor (Aseprite, LibreSprite or Pixelorama): outline, stray pixels, eyes, mask colors.
6. For animation, feed the cleaned 48 x 48 sprite (or the large version) to AutoSprite with the prompts in section 3.

**Target sizes.** Player and regular opponents 48 x 48; bosses 64 x 64; trainer portraits 24 x 24; icons 16 x 16; masks 24 x 24. Characters face right.

**Reserved colors.** Night Purple #2E1F4A, Violet #7A3FD1 and Lilac #B993F5 are used only on masks, because the game recolors masks at runtime by swapping exactly those three. Opponent prompts therefore exclude them.

**Names in brackets** such as the second opponent are proposals. Change the character concept inside the prompt if you prefer another idea, and keep the rest as is.

**What changes between tools.** Gemini, ChatGPT and similar tools follow these long prompts well but may ignore hex codes and exact pixel counts. If that happens, attach an earlier good result and add the fix-up prompt; reference images work better than longer text.

## 2. Art style test: characters

The art style test is 1 player, 2 opponents and 1 boss, then 5 animations. If these four look right together and still read at 48 px and 64 px, the pipeline is validated and the rest of the cast follows.

### 2.1 Player: the luchador (48 x 48)

```
Pixel art, 16-bit era game sprite of a young lucha libre wrestler. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: friendly and determined, bare chest, athletic but cartoonish. Full-head lucha mask in violet #7A3FD1 with lilac #B993F5 highlights and dark purple #2E1F4A shadows, white eye openings with small dark pupils. Red trunks #C8283A with coral #F2545B highlights. Gold boots and wrist tape #FFB627 with yellow #FFE066 highlights. Skin #D9915E with light #F7C9A0 highlights. Both fists raised in a ready fighting stance. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 48 x 48 pixels, so use few details, big shapes and 1-pixel features (eyes, mask edge, belt line). Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #2E1F4A, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #7A3FD1, #B993F5, #D12FA0. The colors #2E1F4A, #7A3FD1 and #B993F5 are reserved for the mask only.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### 2.2 Opponent 1: Mr. Aguacate (48 x 48)

```
Pixel art, 16-bit era game sprite of a comedic lucha libre opponent. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: "Mr. Aguacate", a stocky, confident wrestler. His full-head mask is shaped and colored like an avocado: green #2E9E5B with darker green #1F5A3A edges and a lighter pale-green #C5F0A4 oval on the forehead, white eye openings with smug raised eyebrows. Orange trunks #E2661B with gold #FFB627 trim, green boots #1F5A3A, bare chest and arms with skin #8F5A3C and light #D9915E highlights. Arms flexed, a cocky pose. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 48 x 48 pixels, so use few details, big shapes and 1-pixel features. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5 anywhere; they are reserved for the player's mask.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### 2.3 Opponent 2: El Tamal Mortal (48 x 48, proposed concept)

```
Pixel art, 16-bit era game sprite of a comedic lucha libre opponent. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: "El Tamal Mortal", a heavy, round wrestler dressed like a tamal. His body suit is wrapped like a corn husk in sand #E8D3A2 with cream #F6F0E4 highlights and darker #8F5A3C fold lines, tied at the waist with a red chile-colored rope #C8283A. His full-head mask is a husk-colored hood with a small knot on top, white eye openings with angry brows. Brown boots #4B2A1E, skin #D9915E on the hands. Fists forward in an aggressive stance. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 48 x 48 pixels, so use few details, big shapes and 1-pixel features. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5 anywhere; they are reserved for the player's mask.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### 2.4 Boss: El Mariachi Furioso (64 x 64)

```
Pixel art, 16-bit era game sprite of a comedic boss opponent for a lucha libre game. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: "El Mariachi Furioso", a taller, wider and more imposing wrestler than the regular opponents. Charro-style outfit: navy jacket #1D2F6F with gold #FFB627 trim and buttons, a red #C8283A sash at the waist, dark trousers #4A3B6B. A huge sombrero in chocolate #4B2A1E with a gold #FFB627 band, a thick dark mustache, furious scowling eyebrows, and clenched fists. Skin #D9915E with light #F7C9A0 highlights. No guitar and no other props, to keep a clean silhouette. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 64 x 64 pixels, so use few details, big shapes and 1-pixel features. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5 anywhere; they are reserved for the player's mask.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```

## 3. Art style test: animations

Use these in AutoSprite (or any sprite-animation tool) with the finished character image attached as the reference. Run each prompt once per character: the player, both opponents and the boss. Frame counts and speeds are fixed by the game: idle 4 frames at 6 fps (loop), attack 3 frames at 12 fps, hit 2 frames at 12 fps, defeated 3 frames at 10 fps, victory 2 frames at 4 fps (loop). Opponents are drawn facing right; the game flips them at runtime.

### 3.1 Idle (4 frames, loop)

```
Create a pixel art sprite animation sheet from the attached character image. Keep the character exactly as in the reference: same colors, same proportions, same 1-pixel dark outline #1B1230, same pixel style, no new colors. Crisp square pixels, no anti-aliasing, no blur, no gradients, no motion blur, no dithering. Three-tone cel shading with light from the top-left.

Animation: idle, 4 frames, looping seamlessly. The wrestler bounces gently in a fighting stance: the body drops 1 to 2 pixels on frames 2 and 3, fists bob slightly, then returns on frame 4 to match frame 1. Feet stay planted. Character faces right in every frame. Same canvas size and same character position in every frame, so frames line up. Arrange the 4 frames in one horizontal row, evenly spaced, no gaps.

Background: plain flat magenta #FF00FF. No ground, no shadow, no text, no watermark, no border.
```

### 3.2 Attack (3 frames)

```
Create a pixel art sprite animation sheet from the attached character image. Keep the character exactly as in the reference: same colors, same proportions, same 1-pixel dark outline #1B1230, same pixel style, no new colors. Crisp square pixels, no anti-aliasing, no blur, no gradients, no motion blur, no dithering. Three-tone cel shading with light from the top-left.

Animation: punch attack, 3 frames. Frame 1: wind-up, the body leans back and the punching fist is pulled behind. Frame 2: impact, the body lunges forward to the right and the fist is fully extended, with a small 2 to 3 pixel white #FFFFFF impact spark at the fist. Frame 3: recovery, the body returns toward the stance. Character faces right in every frame. Same canvas size in every frame, with the feet near the same position so frames line up. Arrange the 3 frames in one horizontal row, evenly spaced, no gaps.

Background: plain flat magenta #FF00FF. No ground, no shadow, no text, no watermark, no border.
```

### 3.3 Hit (2 frames)

```
Create a pixel art sprite animation sheet from the attached character image. Keep the character exactly as in the reference: same colors, same proportions, same 1-pixel dark outline #1B1230, same pixel style, no new colors. Crisp square pixels, no anti-aliasing, no blur, no gradients, no motion blur, no dithering. Three-tone cel shading with light from the top-left.

Animation: getting hit, 2 frames. Frame 1: the head snaps back and the body recoils to the left by 2 to 3 pixels, eyes squeezed shut, mouth or mask opening in a wince. Frame 2: the body starts returning to the stance, still leaning slightly back. Character faces right in every frame. Same canvas size in every frame so frames line up. Arrange the 2 frames in one horizontal row, evenly spaced, no gaps.

Background: plain flat magenta #FF00FF. No ground, no shadow, no text, no watermark, no border.
```

### 3.4 Defeated (3 frames)

```
Create a pixel art sprite animation sheet from the attached character image. Keep the character exactly as in the reference: same colors, same proportions, same 1-pixel dark outline #1B1230, same pixel style, no new colors. Crisp square pixels, no anti-aliasing, no blur, no gradients, no motion blur, no dithering. Three-tone cel shading with light from the top-left.

Animation: knocked out, 3 frames, comedic and not violent. Frame 1: the wrestler staggers backward, arms flailing, eyes as spirals. Frame 2: tips over backward in mid-air. Frame 3: lies flat on his back, arms and legs spread, with 2 or 3 small yellow #FFE066 stars above the head. Character faces right when standing. Same canvas size in every frame; the final frame keeps the body on the same ground line as the standing frames. Arrange the 3 frames in one horizontal row, evenly spaced, no gaps.

Background: plain flat magenta #FF00FF. No ground, no shadow, no text, no watermark, no border.
```

### 3.5 Victory (2 frames, loop)

```
Create a pixel art sprite animation sheet from the attached character image. Keep the character exactly as in the reference: same colors, same proportions, same 1-pixel dark outline #1B1230, same pixel style, no new colors. Crisp square pixels, no anti-aliasing, no blur, no gradients, no motion blur, no dithering. Three-tone cel shading with light from the top-left.

Animation: victory pose, 2 frames, looping. Frame 1: both arms raised high in a flex, chest out. Frame 2: the same pose with the body 2 pixels higher and a small jump, a tiny yellow #FFE066 sparkle near each fist. Character faces right in every frame. Same canvas size in every frame so frames line up. Arrange the 2 frames in one horizontal row, evenly spaced, no gaps.

Background: plain flat magenta #FF00FF. No ground, no shadow, no text, no watermark, no border.
```

## 4. Masks

Twelve masks, one prompt each. All masks use only three colors plus outline and eye whites, because the game recolors them by swapping Night Purple, Violet and Lilac. Each mask is designed alone, front view, then downscaled to 24 x 24. The names are the ones in the mockups; the motifs are proposals you can change.

### 4.1 Jaguar

```
Pixel art, 16-bit era game icon of a lucha libre mask shown alone (no head, no body), front view, centered. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone shading with the light from the top-left. Chunky, bold shapes with comedic exaggeration. Original design, not based on any real wrestler, brand or existing character.

Mask design: a jaguar. Rounded ears on top, a pattern of dark spots on the forehead and cheeks, two small fangs at the mouth opening, fierce angled eye openings.

Color rule (important): use ONLY these colors: #7A3FD1 (base), #B993F5 (highlights), #2E1F4A (shadows and spots), #1B1230 (outline) and #FFFFFF (eye whites, fangs). Nothing else.

Design for tiny size: the image will be downscaled to 24 x 24 pixels, so use few details and big shapes. Generate large, about 1024 x 1024. Background: plain flat magenta #FF00FF, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### 4.2 Águila

```
Pixel art, 16-bit era game icon of a lucha libre mask shown alone (no head, no body), front view, centered. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone shading with the light from the top-left. Chunky, bold shapes with comedic exaggeration. Original design, not based on any real wrestler, brand or existing character.

Mask design: an eagle. A crest of three pointed feathers on top of the head, a beak-like pointed shape running down the nose bridge, sharp eyebrows that slope down toward the nose, small feather lines on the cheeks.

Color rule (important): use ONLY these colors: #7A3FD1 (base), #B993F5 (highlights), #2E1F4A (shadows and feather lines), #1B1230 (outline) and #FFFFFF (eye whites). Nothing else.

Design for tiny size: the image will be downscaled to 24 x 24 pixels, so use few details and big shapes. Generate large, about 1024 x 1024. Background: plain flat magenta #FF00FF, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### 4.3 Toro

```
Pixel art, 16-bit era game icon of a lucha libre mask shown alone (no head, no body), front view, centered. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone shading with the light from the top-left. Chunky, bold shapes with comedic exaggeration. Original design, not based on any real wrestler, brand or existing character.

Mask design: a bull. Two thick curved horns rising from the sides of the head, a wide muzzle area at the bottom with two nostril marks, heavy angry eyebrows, a small ring shape at the nose.

Color rule (important): use ONLY these colors: #7A3FD1 (base), #B993F5 (highlights), #2E1F4A (shadows and nostrils), #1B1230 (outline) and #FFFFFF (eye whites, horn tips). Nothing else.

Design for tiny size: the image will be downscaled to 24 x 24 pixels, so use few details and big shapes. Generate large, about 1024 x 1024. Background: plain flat magenta #FF00FF, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### 4.4 Rayo

```
Pixel art, 16-bit era game icon of a lucha libre mask shown alone (no head, no body), front view, centered. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone shading with the light from the top-left. Chunky, bold shapes with comedic exaggeration. Original design, not based on any real wrestler, brand or existing character.

Mask design: lightning. A large bold zigzag lightning bolt running from the forehead down across one side of the face, sharp pointed eye openings, small spiky points along the top of the head.

Color rule (important): use ONLY these colors: #7A3FD1 (base), #B993F5 (highlights and the bolt), #2E1F4A (shadows), #1B1230 (outline) and #FFFFFF (eye whites). Nothing else.

Design for tiny size: the image will be downscaled to 24 x 24 pixels, so use few details and big shapes. Generate large, about 1024 x 1024. Background: plain flat magenta #FF00FF, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### 4.5 Lobo

```
Pixel art, 16-bit era game icon of a lucha libre mask shown alone (no head, no body), front view, centered. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone shading with the light from the top-left. Chunky, bold shapes with comedic exaggeration. Original design, not based on any real wrestler, brand or existing character.

Mask design: a wolf. Two tall pointed ears on top, jagged fur lines on the cheeks and forehead, a long narrow snout shape down the middle, narrow slanted eye openings.

Color rule (important): use ONLY these colors: #7A3FD1 (base), #B993F5 (highlights and fur), #2E1F4A (shadows), #1B1230 (outline) and #FFFFFF (eye whites). Nothing else.

Design for tiny size: the image will be downscaled to 24 x 24 pixels, so use few details and big shapes. Generate large, about 1024 x 1024. Background: plain flat magenta #FF00FF, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### 4.6 Cobra

```
Pixel art, 16-bit era game icon of a lucha libre mask shown alone (no head, no body), front view, centered. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone shading with the light from the top-left. Chunky, bold shapes with comedic exaggeration. Original design, not based on any real wrestler, brand or existing character.

Mask design: a cobra. A wide flared hood shape around the head, a diamond scale pattern on the forehead, two small fangs at the mouth opening, narrow vertical-slit eyes.

Color rule (important): use ONLY these colors: #7A3FD1 (base), #B993F5 (highlights and scales), #2E1F4A (shadows), #1B1230 (outline) and #FFFFFF (eye whites, fangs). Nothing else.

Design for tiny size: the image will be downscaled to 24 x 24 pixels, so use few details and big shapes. Generate large, about 1024 x 1024. Background: plain flat magenta #FF00FF, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### 4.7 Fénix

```
Pixel art, 16-bit era game icon of a lucha libre mask shown alone (no head, no body), front view, centered. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone shading with the light from the top-left. Chunky, bold shapes with comedic exaggeration. Original design, not based on any real wrestler, brand or existing character.

Mask design: a phoenix. A tall crest of three flame-shaped feathers rising from the forehead, flame-like swirls along both cheeks, sharp upswept eye openings.

Color rule (important): use ONLY these colors: #7A3FD1 (base), #B993F5 (highlights and flames), #2E1F4A (shadows), #1B1230 (outline) and #FFFFFF (eye whites). Nothing else.

Design for tiny size: the image will be downscaled to 24 x 24 pixels, so use few details and big shapes. Generate large, about 1024 x 1024. Background: plain flat magenta #FF00FF, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### 4.8 Tigre

```
Pixel art, 16-bit era game icon of a lucha libre mask shown alone (no head, no body), front view, centered. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone shading with the light from the top-left. Chunky, bold shapes with comedic exaggeration. Original design, not based on any real wrestler, brand or existing character.

Mask design: a tiger. Small rounded ears, bold curved stripes on the forehead and both cheeks, a wide muzzle with a small nose, angry slanted eye openings.

Color rule (important): use ONLY these colors: #7A3FD1 (base), #B993F5 (highlights), #2E1F4A (shadows and stripes), #1B1230 (outline) and #FFFFFF (eye whites, muzzle). Nothing else.

Design for tiny size: the image will be downscaled to 24 x 24 pixels, so use few details and big shapes. Generate large, about 1024 x 1024. Background: plain flat magenta #FF00FF, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### 4.9 Oso

```
Pixel art, 16-bit era game icon of a lucha libre mask shown alone (no head, no body), front view, centered. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone shading with the light from the top-left. Chunky, bold shapes with comedic exaggeration. Original design, not based on any real wrestler, brand or existing character.

Mask design: a bear. Two big round ears on top, a large round muzzle area with a big nose, thick friendly-but-tough eyebrows, small round eye openings.

Color rule (important): use ONLY these colors: #7A3FD1 (base), #B993F5 (highlights and muzzle), #2E1F4A (shadows and nose), #1B1230 (outline) and #FFFFFF (eye whites). Nothing else.

Design for tiny size: the image will be downscaled to 24 x 24 pixels, so use few details and big shapes. Generate large, about 1024 x 1024. Background: plain flat magenta #FF00FF, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### 4.10 Diablo

```
Pixel art, 16-bit era game icon of a lucha libre mask shown alone (no head, no body), front view, centered. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone shading with the light from the top-left. Chunky, bold shapes with comedic exaggeration. Original design, not based on any real wrestler, brand or existing character.

Mask design: a mischievous devil. Two small pointed horns on top, sharply angled evil eyebrows, a wide cheeky grin shown as a curved line with two small fangs, a pointed goatee shape at the chin. Funny, not scary.

Color rule (important): use ONLY these colors: #7A3FD1 (base), #B993F5 (highlights), #2E1F4A (shadows and grin line), #1B1230 (outline) and #FFFFFF (eye whites, fangs). Nothing else.

Design for tiny size: the image will be downscaled to 24 x 24 pixels, so use few details and big shapes. Generate large, about 1024 x 1024. Background: plain flat magenta #FF00FF, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### 4.11 Sol

```
Pixel art, 16-bit era game icon of a lucha libre mask shown alone (no head, no body), front view, centered. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone shading with the light from the top-left. Chunky, bold shapes with comedic exaggeration. Original design, not based on any real wrestler, brand or existing character.

Mask design: the sun. Eight short triangular rays radiating around the head outline like a sunburst, a round sun disc shape on the forehead, wide round eye openings, a calm confident look.

Color rule (important): use ONLY these colors: #7A3FD1 (base), #B993F5 (highlights and rays), #2E1F4A (shadows), #1B1230 (outline) and #FFFFFF (eye whites). Nothing else.

Design for tiny size: the image will be downscaled to 24 x 24 pixels, so use few details and big shapes. Generate large, about 1024 x 1024. Background: plain flat magenta #FF00FF, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### 4.12 Hielo

```
Pixel art, 16-bit era game icon of a lucha libre mask shown alone (no head, no body), front view, centered. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone shading with the light from the top-left. Chunky, bold shapes with comedic exaggeration. Original design, not based on any real wrestler, brand or existing character.

Mask design: ice. Three jagged ice-crystal spikes rising from the top of the head, angular faceted lines across the forehead and cheeks like cracked ice, cold narrow eye openings.

Color rule (important): use ONLY these colors: #7A3FD1 (base), #B993F5 (highlights and crystal facets), #2E1F4A (shadows), #1B1230 (outline) and #FFFFFF (eye whites). Nothing else.

Design for tiny size: the image will be downscaled to 24 x 24 pixels, so use few details and big shapes. Generate large, about 1024 x 1024. Background: plain flat magenta #FF00FF, no shadow, no scenery. No text, no logo, no watermark, no border.
```

## 5. Arena, logo emblem and app icon

AI tools draw text badly. The words "LUCHA TAP, TAP!" are added later in code with the pixel font, so these prompts ask for the emblem only, with no lettering.

### 5.1 Arena background, league 1 (180 x 102)

```
Pixel art, 16-bit era game background for a lucha libre arena, side-on flat view like a classic 2D fighting game. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230 on the main shapes. Three-tone shading with the light from the top-left. Original design, not based on any real arena, promotion or brand.

Scene, from back to front: a dark navy #1D2F6F wall; two rows of cheering crowd silhouettes made of simple colorful blocks (shirts in #FFB627, #C8283A, #2F5BEA, #2E9E5B, skin tones #D9915E, #8F5A3C, #F7C9A0), some with raised arms, some with tiny flags; the bottom edge of the crowd hidden behind three horizontal red ropes #C8283A with coral #F2545B highlights; two steel corner posts #B8B2CC with red pads at the far left and far right; in front, a sand-colored #E8D3A2 canvas floor with a slightly darker #D9915E line near the bottom edge. No wrestlers, no characters, no text, no signs with words.

Composition: very wide and short, aspect ratio 180 to 102. The center area must stay calm and empty because two fighters are placed there later. Design for tiny size: the image will be downscaled to 180 x 102 pixels, so use big shapes. Generate large, about 1800 x 1020.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5; they are reserved for masks.
```

### 5.2 Logo emblem (about 96 x 96)

```
Pixel art, 16-bit era game logo emblem, shown alone and centered. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone shading with the light from the top-left. Chunky, bold shapes with comedic exaggeration. Original design, not based on any real brand, wrestler or game logo.

Emblem: a golden lucha libre mask in marigold #FFB627 with yellow #FFE066 highlights and orange #E2661B shadows, front view, with white eye openings and angry brows, and a small red #C8283A star on the forehead. Behind it, a sunburst of eight short triangular rays alternating red #C8283A and coral #F2545B. Below the mask, two crossed clenched fists in skin tone #D9915E with light #F7C9A0 highlights. Strong, simple silhouette that still reads at small size. No letters, no words, no numbers anywhere.

Design for tiny size: the image will be downscaled to about 96 x 96 pixels, so use few details and big shapes. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5.

Background: plain flat magenta #FF00FF. No text, no watermark, no border.
```

### 5.3 App icon (drawn at 64 x 64, exported at 512 x 512)

```
Pixel art, 16-bit era mobile game app icon, square, filling the whole canvas edge to edge with no rounded corners and no border (the store applies its own mask). Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230 around the main figure. Three-tone shading with the light from the top-left. Chunky, bold shapes. Original design, not based on any real brand or game icon.

Icon: a large golden lucha libre mask in marigold #FFB627 with yellow #FFE066 highlights and orange #E2661B shadows, front view, centered and filling about 70 percent of the canvas, with white eye openings and angry brows. Behind it, a sunburst background of alternating wine #5E1230 and red #C8283A rays covering the whole square. A small clenched fist in skin tone #D9915E at the bottom right corner overlapping the mask edge. Strong, simple silhouette that is readable at 48 x 48 pixels. No letters, no words, no numbers.

Design for tiny size: the image will be downscaled to 64 x 64 pixels, so use few details and big shapes. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5.
```

## 6. Fix-up prompts

Use these with the picked image attached. Each one is complete on its own and keeps everything else unchanged.

### 6.1 Too smooth, gradients or blur

```
Redraw the attached image as true pixel art. Keep the exact same character, pose, composition and colors. Remove all gradients, blur, soft shading, glow and anti-aliasing. Use crisp square pixels, flat color areas, and exactly three tones per material (base, light, shadow) with the light coming from the top-left. Add a clean 1-pixel dark outline in deep indigo #1B1230 around the whole figure. Do not add or remove any details. Keep the plain flat magenta #FF00FF background. No text, no watermark, no border.
```

### 6.2 Too many details for tiny size

```
Simplify the attached pixel art character so it still reads clearly when downscaled to 48 x 48 pixels. Keep the exact same character, pose, outfit colors and style. Remove small details such as thin lines, tiny patterns, tiny teeth and fine texture. Merge them into bigger, bolder shapes. Make the eyes, the mask edge and the belt line 1 pixel features. Keep crisp square pixels, no anti-aliasing, no gradients, a clean 1-pixel dark outline in deep indigo #1B1230, three-tone shading with the light from the top-left. Keep the plain flat magenta #FF00FF background. No text, no watermark, no border.
```

### 6.3 Wrong colors, off the palette

```
Recolor the attached pixel art so that it uses only colors from this palette: #1B1230, #2E1F4A, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #7A3FD1, #B993F5, #D12FA0. Replace every other color with the nearest palette color. Keep the exact same character, pose, shapes and composition. Keep crisp square pixels, no anti-aliasing, no gradients, a clean 1-pixel dark outline in deep indigo #1B1230. Keep the plain flat magenta #FF00FF background. No text, no watermark, no border.
```

### 6.4 Background is not flat magenta

```
Replace the entire background of the attached image with a plain, flat, solid magenta #FF00FF with no gradient, no floor, no shadow, no glow and no scenery. Keep the character exactly as it is, unchanged, with crisp square pixels and its 1-pixel dark outline in deep indigo #1B1230. Do not recolor, resize or move the character. No text, no watermark, no border.
```

### 6.5 Mask uses colors outside the three mask tones

```
Recolor the attached pixel art lucha libre mask so that it uses ONLY these colors: #7A3FD1 (base), #B993F5 (highlights), #2E1F4A (shadows and deep lines), #1B1230 (outline) and #FFFFFF (eye whites and teeth). Keep the exact same mask design, shapes and composition. Keep crisp square pixels, no anti-aliasing, no gradients, a clean 1-pixel dark outline in deep indigo #1B1230. Keep the plain flat magenta #FF00FF background. No text, no watermark, no border.
```

### 6.6 Character faces the wrong way or the stance is wrong

```
Redraw the attached pixel art character in a side view facing right (toward the right edge of the image) in a ready fighting stance with the fists raised, slightly three-quarter view. Keep the exact same character design, outfit, colors and proportions. Keep crisp square pixels, no anti-aliasing, no gradients, a clean 1-pixel dark outline in deep indigo #1B1230, three-tone shading with the light from the top-left. Full body, centered, with a small margin. Keep the plain flat magenta #FF00FF background. No text, no watermark, no border.
```

## 7. Cleanup, checklist and next steps

**Cleanup script (Claude Code can write it).** A small tool, for example `tools/pixelize.py`, that takes a generated image and: removes the magenta #FF00FF background, trims to the character, downscales to a given size with nearest-neighbor (or a pixel-art-aware method), remaps every pixel to the nearest of the 32 palette colors, forces alpha to 0 or 255, and writes a PNG. A second tool, `tools/validate_sprite.py`, should fail on any sprite whose size, palette or alpha is wrong, and on any non-mask sprite that contains #2E1F4A, #7A3FD1 or #B993F5.

**Art style test checklist.** Pass all items before drawing any more characters.

- [ ] Player, both opponents and the boss look like they belong to the same game when placed side by side at 48 px and 64 px.
- [ ] Each character is recognizable by silhouette alone.
- [ ] Outline, shading direction and level of detail match across all four.
- [ ] Every sprite passes the validator (size, 32-color palette, alpha 0 or 255).
- [ ] The 5 animations loop cleanly, with the feet and body at the same position across frames.
- [ ] Masks recolor correctly when the three mask colors are swapped in the game.
- [ ] Everything looks right on a real phone at integer scale, not only on the computer.

**Tips for consistency.** Always attach the first approved image of a character when generating any further view or pose of it. Keep one folder per character with the prompt, the picked image and the final sprite. If a tool drifts from the style after several images, start a new chat and paste the prompt again.

**Not in this book yet.** These need decisions first, then get the same full-prompt treatment: the remaining 15 regular opponents and 2 bosses (names and concepts), the 6 trainer portraits at 24 x 24 (Don Chuy is the first), the 16 x 16 icon set (coin, belt, upgrades, skills, tabs), the arena variants for leagues 2 and 3, and the lucky-event pickups. Next step: agree on the concept list, then add them here.

**Licensing note.** Check the terms of each image and animation tool you use for commercial use of generated assets before release, and keep a record of the tool and date for every asset.
