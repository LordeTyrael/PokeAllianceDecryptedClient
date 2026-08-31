# PokeAlliance - Decrypted Client

Full decrypted asset tree of **PokeAlliance** (PokeTibia, OTClientv8 fork), build **31/08/2026**.

**8,008 files** - **311.8 MB** - 408 directories

Every file here is the decrypted original.

> **`data/things/things.spr` is not in this repo.** At 1.1 GB (653,783
> sprites) it exceeds GitHub's 100 MB per-file cap. `things.dat` *is* here
> and references those sprite IDs, so the spr is required to render
> anything. `things.dat` + `things.spr` + `things.otfi` form a complete set.

## By type

| Ext | Files | Size | What it is |
|---|---:|---:|---|
| `.png` | 7,069 | 191.8 MB | UI skins, icons, item/creature images, bitmap font atlases |
| `.otui` | 287 | 1.0 MB | OTML widget trees - every window and widget in the UI |
| `.lua` | 242 | 2.6 MB | client core and module scripts (Lua 5.1) |
| `.otmod` | 134 | 32.7 KB | module manifests (name, sandboxed, scripts, load-later) |
| `.ogg` | 114 | 93.5 MB | sound effects and music |
| `.frag` | 107 | 102.9 KB | GLSL fragment-shader sources |
| `.otfont` | 30 | 4.3 KB | font descriptors (bitmap and TTF) |
| `.ttf` | 16 | 7.0 MB | TrueType files loaded via .otfont |
| `.mp4` | 3 | 9.2 MB | squirtle video, gacha opening, a 3d ball vid |
| `.otml` | 2 | 194.8 KB | OTML config trees (cursors, per-thing overrides) |
| `.rc` | 1 | 47 B | Windows resource script (build leftover) |
| `.dat` | 1 | 6.4 MB | object definitions - what every item/creature is |
| `.otfi` | 1 | 188 B | loader manifest for the dat/spr pair |
| `.txt` | 1 | 218 B | outfit displacement save artifact |
| **Total** | **8,008** | **311.8 MB** | |

## By top level

| Path | Files | Size |
|---|---:|---:|
| `modules/` | 4,302 | 86.6 MB |
| `data/` | 3,705 | 225.2 MB |
| `init.lua` | 1 | 2.8 KB |
