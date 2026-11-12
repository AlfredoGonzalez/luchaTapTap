# Prompts de arte: el resto del elenco

Este archivo completa la sección 2 del `AI_ART_PROMPT_BOOK.md`, que solo trae al jugador, a Mr. Aguacate, a El Tamal Mortal y al jefe El Mariachi Furioso. Aquí están los otros **18 personajes** del lanzamiento (3 ligas: 6 oponentes y 1 jefe cada una; faltaban El Taquero Cósmico y los 17 nuevos). Los conceptos son propuestas mías: cambia la línea "Character" si prefieres otra idea y deja el resto igual.

Cómo usarlos: copia el prompt completo, genera a ~1024 x 1024, guarda la imagen en `art/input/` con el nombre que se indica (por ejemplo `la_abuela_fantasma.png`) y corre `python3 tools/build_sprites.py`.

Reglas que el validador exige: nada de morado ni violeta en los oponentes (están reservados para las máscaras del jugador), fondo liso y personaje mirando a la derecha.


## Liga 1: Arena del Barrio

### El Taquero Cósmico (48 x 48)

Archivo: `art/input/el_taquero_cosmico.png`

```
Pixel art, 16-bit era game sprite of a comedic lucha libre opponent. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: "El Taquero Cósmico", a lanky wrestler dressed as a taquero from space. A taco-shaped full-head mask in marigold #FFB627 with orange #E2661B shading and red #C8283A salsa drips on the forehead, white eye openings with sly half-closed eyelids. A white #FFFFFF apron over a bare chest, with small star dots in yellow #FFE066 and sky #5BB8FF. Navy #1D2F6F trunks, royal-blue #2F5BEA boots, skin #8F5A3C with light #D9915E highlights. Fists up in a showy pose. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 48 x 48 pixels, so use few details, big shapes and 1-pixel features. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5 anywhere (no purple or violet at all); they are reserved for the player's mask.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### La Abuela Fantasma (48 x 48)

Archivo: `art/input/la_abuela_fantasma.png`

```
Pixel art, 16-bit era game sprite of a comedic lucha libre opponent. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: "La Abuela Fantasma", a ghostly grandmother wrestler, round and sweet but spooky. Her full-head mask is a pale ghost-white #F6F0E4 hood with fog-gray #B8B2CC shadows and a small gray bun on top, white eye openings with gentle sleepy eyes and round glasses in #7C7396. A fog-gray #B8B2CC shawl over the shoulders, a long pale-blue #8FF0E0 nightgown-style trunks, slate #4A3B6B slippers, skin pale #F7C9A0. Arms open wide as if offering a big hug, slightly floating pose. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 48 x 48 pixels, so use few details, big shapes and 1-pixel features. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5 anywhere (no purple or violet at all); they are reserved for the player's mask.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### Doña Chela Tornado (48 x 48)

Archivo: `art/input/dona_chela_tornado.png`

```
Pixel art, 16-bit era game sprite of a comedic lucha libre opponent. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: "Doña Chela Tornado", a energetic wrestler who spins constantly. Her full-head mask is hot pink #FF8FB1 with magenta #D12FA0 swirl lines and a blush #FFD0DC highlight, white eye openings with confident winking eyes. Magenta #D12FA0 trunks with wine #5E1230 trim, wine #5E1230 boots, a bold pink #FF8FB1 sash flying sideways as if she is spinning, skin #D9915E with light #F7C9A0 highlights. One leg and one arm extended in a spin pose. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 48 x 48 pixels, so use few details, big shapes and 1-pixel features. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5 anywhere (no purple or violet at all); they are reserved for the player's mask.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### El Churro Veloz (48 x 48)

Archivo: `art/input/el_churro_veloz.png`

```
Pixel art, 16-bit era game sprite of a comedic lucha libre opponent. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: "El Churro Veloz", a skinny, very fast wrestler dressed as a churro. His full-head mask is long and ridged, golden-yellow #FFB627 with orange #E2661B ridge lines and sugar sparkle dots in white #FFFFFF, white eye openings with wide hyper eyes. Chocolate-brown #4B2A1E trunks with a cinnamon #E2661B stripe, orange #E2661B boots, bare chest, skin #F7C9A0 with #D9915E shading. A running, leaning-forward pose with fists back. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 48 x 48 pixels, so use few details, big shapes and 1-pixel features. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5 anywhere (no purple or violet at all); they are reserved for the player's mask.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```


## Liga 2: Mercado Bravo

### Don Piñata (48 x 48)

Archivo: `art/input/don_pinata.png`

```
Pixel art, 16-bit era game sprite of a comedic lucha libre opponent. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: "Don Piñata", a cheerful round wrestler built like a piñata. His full-head mask is a star-pointed piñata head with coral #F2545B, yellow #FFE066 and sky #5BB8FF paper-fringe stripes and a small paper tassel on top, white eye openings with big happy eyes. A body with the same fringe layers like a paper costume, royal-blue #2F5BEA trunks, teal #1FA6A0 boots, skin #D9915E. A proud arms-wide pose with small candy shapes in yellow #FFE066 falling. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 48 x 48 pixels, so use few details, big shapes and 1-pixel features. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5 anywhere (no purple or violet at all); they are reserved for the player's mask.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### La Marchanta Loca (48 x 48)

Archivo: `art/input/la_marchanta_loca.png`

```
Pixel art, 16-bit era game sprite of a comedic lucha libre opponent. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: "La Marchanta Loca", a market vendor wrestler with a loud personality. Her full-head mask is teal #1FA6A0 with aqua #8FF0E0 highlights and forest #1F5A3A shadow, tied with a bandana-style knot on top, white eye openings with raised suspicious eyebrows. A chocolate #4B2A1E apron with a tiny coin pocket in marigold #FFB627, forest-green #1F5A3A boots, skin #8F5A3C with light #D9915E highlights. One hand holds out a flat palm as if demanding payment, the other fist raised. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 48 x 48 pixels, so use few details, big shapes and 1-pixel features. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5 anywhere (no purple or violet at all); they are reserved for the player's mask.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### El Nopal Gigante (48 x 48)

Archivo: `art/input/el_nopal_gigante.png`

```
Pixel art, 16-bit era game sprite of a comedic lucha libre opponent. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: "El Nopal Gigante", a huge, wide wrestler shaped like a nopal cactus. His full-head mask is a flat paddle shape in green #2E9E5B with light-green #8FD14F highlights and darker #1F5A3A edges, with white spine dots and a pink #FF8FB1 flower on top, white eye openings with grumpy eyes. A broad paddle-shaped torso with a few white spines, forest #1F5A3A trunks, chocolate #4B2A1E boots, arms like small paddles. A wide, blocky, defensive stance. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 48 x 48 pixels, so use few details, big shapes and 1-pixel features. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5 anywhere (no purple or violet at all); they are reserved for the player's mask.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### El Chicharrón Crujiente (48 x 48)

Archivo: `art/input/el_chicharron_crujiente.png`

```
Pixel art, 16-bit era game sprite of a comedic lucha libre opponent. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: "El Chicharrón Crujiente", a crispy pork-rind wrestler. His full-head mask is a puffed, bubbly golden-brown shape in sand #E8D3A2 with skin-deep #8F5A3C blisters and cream #F6F0E4 highlights, white eye openings with cocky eyes. A bumpy, puffy body in the same tones, chocolate #4B2A1E trunks and boots, a small red #C8283A hot-sauce stripe on the belt. A strong arms-flexed pose. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 48 x 48 pixels, so use few details, big shapes and 1-pixel features. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5 anywhere (no purple or violet at all); they are reserved for the player's mask.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### La Señora Gelatina (48 x 48)

Archivo: `art/input/la_senora_gelatina.png`

```
Pixel art, 16-bit era game sprite of a comedic lucha libre opponent. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: "La Señora Gelatina", a wobbly wrestler made of gelatin. Her full-head mask is a translucent-looking dome in aqua #8FF0E0 with white #FFFFFF highlight streaks and teal #1FA6A0 shading, with a small cherry in red #C8283A on top, white eye openings with a giggling expression. A soft, squishy rounded body in the same aqua tones with a slight wobble pose (one side bulging), teal #1FA6A0 trunks, sky-blue #5BB8FF boots. Fists up, but bouncy. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 48 x 48 pixels, so use few details, big shapes and 1-pixel features. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5 anywhere (no purple or violet at all); they are reserved for the player's mask.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### El Tianguista Turbo (48 x 48)

Archivo: `art/input/el_tianguista_turbo.png`

```
Pixel art, 16-bit era game sprite of a comedic lucha libre opponent. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: "El Tianguista Turbo", a fast street-market seller wrestler. His full-head mask is royal blue #2F5BEA with sky #5BB8FF highlights and navy #1D2F6F shadow and a small yellow #FFE066 lightning bolt on the forehead, white eye openings with a determined look. A tight white #FFFFFF tank top, navy #1D2F6F trunks, white #FFFFFF sneakers with sky-blue #5BB8FF speed stripes, skin #D9915E. A sprinting pose with one fist forward. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 48 x 48 pixels, so use few details, big shapes and 1-pixel features. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5 anywhere (no purple or violet at all); they are reserved for the player's mask.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### El Rey del Tianguis (64 x 64) — jefe

Archivo: `art/input/el_rey_del_tianguis.png`

```
Pixel art, 16-bit era game sprite of a comedic boss opponent for a lucha libre game. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: "El Rey del Tianguis", a huge, wide, imposing wrestler dressed as the king of the street market. A tall golden crown #FFB627 with yellow #FFE066 highlights and a red #C8283A gem, a skin-deep #8F5A3C face with a big bushy chocolate #4B2A1E mustache and furious eyebrows. A wine #5E1230 cape with an ink-dark #1B1230 inner lining and marigold #FFB627 trim hanging behind, a bare chest with gold #FFB627 chains and coins, ink-dark #1B1230 trunks, chocolate #4B2A1E boots. Clenched fists. No props, to keep a clean silhouette. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 64 x 64 pixels, so use few details, big shapes and 1-pixel features. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5 anywhere (no purple or violet at all); they are reserved for the player's mask.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```


## Liga 3: Estadio Monumental

### El Astronauta Azteca (48 x 48)

Archivo: `art/input/el_astronauta_azteca.png`

```
Pixel art, 16-bit era game sprite of a comedic lucha libre opponent. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: "El Astronauta Azteca", a wrestler in a homemade space suit with ancient-feather style. A round glass-dome helmet drawn as a mask: a white #FFFFFF helmet with fog-gray #B8B2CC shading and a sky-blue #5BB8FF visor reflection, a yellow #FFE066 and teal #1FA6A0 feather crest on top, white eye openings behind the glass. A white #FFFFFF suit with royal-blue #2F5BEA trim and a small gold #FFB627 sun emblem on the chest, dust-gray #7C7396 boots, skin #D9915E. A confident pose with one fist raised. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 48 x 48 pixels, so use few details, big shapes and 1-pixel features. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5 anywhere (no purple or violet at all); they are reserved for the player's mask.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### La Catrina Eléctrica (48 x 48)

Archivo: `art/input/la_catrina_electrica.png`

```
Pixel art, 16-bit era game sprite of a comedic lucha libre opponent. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: "La Catrina Eléctrica", an elegant skeleton-style wrestler with electric sparks. Her full-head mask is a bone-white #F6F0E4 skull face with ink-dark #1B1230 eye rings and a stitched grin, with a wide ink-dark #1B1230 hat decorated with magenta #D12FA0 and pink #FF8FB1 flowers and yellow #FFE066 zigzag sparks. A magenta #D12FA0 dress-like top with pink #FF8FB1 highlights, ink-dark #1B1230 trunks, wine #5E1230 boots. Arms crossed in a smug pose with small yellow sparks around her. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 48 x 48 pixels, so use few details, big shapes and 1-pixel features. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5 anywhere (no purple or violet at all); they are reserved for the player's mask.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### El Robot Luchador (48 x 48)

Archivo: `art/input/el_robot_luchador.png`

```
Pixel art, 16-bit era game sprite of a comedic lucha libre opponent. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: "El Robot Luchador", a boxy retro robot wrestler. A square metal head in dust-gray #7C7396 with fog #B8B2CC highlights and slate #4A3B6B shadow, a mask-like visor with two glowing teal #1FA6A0 eyes, a small antenna with a red #C8283A tip. A blocky torso in the same grays with a yellow #FFE066 chest panel and rivets, slate #4A3B6B trunks, ink-dark #1B1230 boots. Stiff, symmetrical pose with big blocky fists. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 48 x 48 pixels, so use few details, big shapes and 1-pixel features. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5 anywhere (no purple or violet at all); they are reserved for the player's mask.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### El Dragón de Papel (48 x 48)

Archivo: `art/input/el_dragon_de_papel.png`

```
Pixel art, 16-bit era game sprite of a comedic lucha libre opponent. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: "El Dragón de Papel", a wrestler in a paper-cut dragon costume, like festival papel picado. A dragon-head mask in red #C8283A with coral #F2545B highlights and wine #5E1230 shading, small yellow #FFE066 horns, a row of triangular paper-cut spikes along the head in marigold #FFB627, white eye openings with fiery eyes. A bare chest with a paper-cut scale pattern, wine #5E1230 trunks, coral #F2545B boots, a small tail with spikes behind. Aggressive pose with a small puff of orange #E2661B flame by the mouth. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 48 x 48 pixels, so use few details, big shapes and 1-pixel features. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5 anywhere (no purple or violet at all); they are reserved for the player's mask.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### El Gallo de Oro (48 x 48)

Archivo: `art/input/el_gallo_de_oro.png`

```
Pixel art, 16-bit era game sprite of a comedic lucha libre opponent. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: "El Gallo de Oro", a proud rooster-themed wrestler. A full-head mask shaped like a rooster head in golden #FFB627 with yellow #FFE066 highlights and orange #E2661B shading, a red #C8283A comb on top and a red wattle under the chin, a small orange #E2661B beak shape over the nose, white eye openings with proud eyes. A bare chest with golden feather fringe on the shoulders, burnt-orange #E2661B trunks, golden boots with small spurs. Chest-out, crowing pose. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 48 x 48 pixels, so use few details, big shapes and 1-pixel features. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5 anywhere (no purple or violet at all); they are reserved for the player's mask.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### La Sirena del Ring (48 x 48)

Archivo: `art/input/la_sirena_del_ring.png`

```
Pixel art, 16-bit era game sprite of a comedic lucha libre opponent. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: "La Sirena del Ring", a mermaid-themed wrestler. A full-head mask in navy #1D2F6F with teal #1FA6A0 scale pattern and aqua #8FF0E0 highlights, a fin-shaped crest on top, white eye openings with a calm, seductive-cartoon look. A teal #1FA6A0 top with scale pattern, trunks with a mermaid-tail fin flare in navy #1D2F6F and aqua #8FF0E0, aqua #8FF0E0 boots, skin #D9915E. A graceful but strong pose with a small bubble or two in #8FF0E0. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 48 x 48 pixels, so use few details, big shapes and 1-pixel features. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5 anywhere (no purple or violet at all); they are reserved for the player's mask.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```

### El Emperador Obsidiana (64 x 64) — jefe

Archivo: `art/input/el_emperador_obsidiana.png`

```
Pixel art, 16-bit era game sprite of a comedic boss opponent for a lucha libre game. Crisp square pixels, no anti-aliasing, no blur, no gradients, no dithering. Clean 1-pixel dark outline in deep indigo #1B1230. Three-tone cel shading (base, light, shadow) with the light coming from the top-left. Chunky, readable silhouette with comedic, exaggerated proportions: large head, large fists, short legs. Original character, not based on any real wrestler, wrestling promotion, brand or existing game character.

Character: "El Emperador Obsidiana", a towering, wide emperor wrestler carved from black volcanic glass. A tall angular crown-helmet in ink-dark #1B1230 with slate #4A3B6B facets, dust #7C7396 highlights and wine #5E1230 gems, a full mask with glowing coral #F2545B eyes and a stern jaw. A broad chest armor with sharp triangular obsidian plates in slate #4A3B6B and ink-dark #1B1230, a wine #5E1230 sash, sharp-edged gauntlets with dust #7C7396 highlights, wine #5E1230 boots. Clenched fists, an imposing wide stance. No props, to keep a clean silhouette. Side view facing right, slightly three-quarter. Full body, centered, with a small margin.

Design for tiny size: the image will be downscaled to 64 x 64 pixels, so use few details, big shapes and 1-pixel features. Generate large, about 1024 x 1024.

Use only colors from this palette: #1B1230, #4A3B6B, #7C7396, #B8B2CC, #F6F0E4, #FFFFFF, #5E1230, #C8283A, #F2545B, #FF8FB1, #FFD0DC, #4B2A1E, #8F5A3C, #D9915E, #F7C9A0, #E8D3A2, #E2661B, #FFB627, #FFE066, #1F5A3A, #2E9E5B, #8FD14F, #C5F0A4, #1D2F6F, #2F5BEA, #5BB8FF, #1FA6A0, #8FF0E0, #D12FA0. Do not use #2E1F4A, #7A3FD1 or #B993F5 anywhere (no purple or violet at all); they are reserved for the player's mask.

Background: plain flat magenta #FF00FF, no ground, no shadow, no scenery. No text, no logo, no watermark, no border.
```
