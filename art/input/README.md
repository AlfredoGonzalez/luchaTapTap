# Arte de entrada

Deja aquí tus imágenes (PNG, WebP o JPG, cuadradas o no, fondo liso blanco o magenta o ya transparente).
Una imagen por personaje, con la pose de reposo mirando a la derecha.

Nombres (la herramienta entiende estos formatos):

- `player.webp` -> el luchador del jugador (48x48)
- `MrAguacate.webp`, `mr_aguacate.png` o `opp_mr_aguacate.png` -> el oponente `mr_aguacate`
  (el nombre debe corresponder a un oponente de `assets/data/opponents.json`; los jefes salen a 64x64 solos)

Después se ejecuta:

    python3 tools/build_sprites.py            # procesa todo art/input
    python3 tools/build_sprites.py player     # solo uno

Genera `assets/sprites/<clave>.png` (hoja con las 5 animaciones) y corre el validador.
Con una sola pose las animaciones se derivan moviendo la imagen (rebote, empuje, caída, salto);
si más adelante dibujas fotogramas reales, usa `tools/pixelize.py` (ver su ayuda).

## Hojas de animación (5 x 5)

Si exportas una hoja de 5 x 5 cuadros por animación, nómbrala con la clave y la animación
(por ejemplo `player ... idle ...png`, `... punch ...`, `... hurt ...`, `... defeated ...`, `... victory ...`).
Con las cinco, `build_sprites.py` elige los cuadros (ver `PICK` en el script) y arma la hoja del juego;
tiene prioridad sobre la imagen de una sola pose.
