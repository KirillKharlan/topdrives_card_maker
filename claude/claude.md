# Card Maker (Top Drives fan cards) — project notes for Claude

Offline Flutter app (Android, built as APK by GitHub Actions) for making fan-made cards in the style
of the mobile game Top Drives (Hutch Games). The user writes Russian; answer in Russian. Code,
identifiers and UI strings are English.

## Working rules that proved necessary
- The assistant's sandbox has **no Flutter/Dart**. Nothing can be compiled or run here. After every
  change: check bracket balance, check that named arguments of every call match the declaration
  (a mismatched `file:` vs `photo:` once broke the CI build), and say clearly that the code was not run.
- Algorithms are prototyped in Python/C first (PatchMatch fill, crop maths), then ported to Dart.
- The user replaces the **whole project** from the zip. Partial replacement caused a crash once
  (new Dart code + old `assets/templates/standard.json`). The template parser has defaults for new keys.
- Measure, don't guess: compare the user's screenshots with the game's card in the same scale
  (normalise both to card units 1338x828, then measure text bounding boxes). Reference images the
  user supplied: the game card, and a Photoshop fan card that players consider good.
- UI text and defaults the user explicitly chose: no WISHLIST / "TAP TO FLIP"; stat fields start empty
  except Brand/Model placeholders; 0-60 shows `N/A` when top speed < 60; tags may be several, custom
  tags are saved to a library and sorted alphabetically with the ready-made ones.

## Layout of the repository
```
lib/
  main.dart, bootstrap.dart      start-up screen with step names / error text (diagnostics)
  app.dart
  core/                          constants, theme, layout_tweaks (global tyre-name offset)
  data/models/                   CardProject, CardTag, MediaItem, PhotoTransform, PhotoFill
  data/repositories/             AppStore (entry point), MediaLibrary (photos, logos), ProjectRepository,
                                 SettingsRepository (countries, custom tags, tyre offset), FillStore
  templates/                     TemplateSpec (parsed from assets/templates/standard.json), registry, tag catalog
  editor/                        EditorScreen, EditorController (autosave, gestures)
    canvas/                      CardView, CardComposition, PhotoLayer/PhotoPainter, FieldText, LogoTile,
                                 TagStrip, CustomTagView, PrizeStrip, PreviewPane
    panels/                      media, text, sizes, options, extras (tags + prize), tag picker, tag editor
    export/                      CardExporter (PNG, cropped photo), export sheet
  logo_editor/                   background removal (flood fill), margin trimming, RgbaImage
  photo_fill/                    content-aware fill (PatchMatch), FillService, photo decoder
  update/                        update check against GitHub Releases, about/fine-tune dialog
  ui/                            home grid, library screen, dialogs
assets/ templates/standard.json, frames/, overlays/prize_car.png, tags/ (76 PNG), fonts/ (Roboto Condensed)
tool/patch_android.py            CI: manifest permissions + app name
.github/workflows/build-apk.yml  CI build, sign, release
claude/claude.md                 this file
```

## Rendering model
- A card is drawn at **1338 x 828 "card units"** (template size). Everything is positioned in these units
  and scaled by `FittedBox` on screen. Export captures a `RepaintBoundary` at pixelRatio 1.
- Layers, bottom to top: background colour, photo (`PhotoLayer`), frosted-glass `BackdropFilter`
  regions (`blurRegions`, `blurSigma` in the JSON), class frame PNG, logo, text fields.
  Tag strip is above the card, prize marker below it, both on a black backdrop (`CardComposition`).
- All card text ignores the phone's font scale (`TextScaler.noScaling`) and is multiplied by the template's
  `textScale` (0.9, an empirical calibration). Per-card multipliers: `titleScale`, `yearScale`, `tagScale`.
- Text fields: `FieldRect` (x, y, w, h, size, align). Text is vertically centred and shrinks to fit
  (`FittedBox.scaleDown`). Optional `baseline` anchors text on an exact baseline (used for the tyre name).
- Font: Roboto Condensed Regular/Bold only. "Medium" looks are faked by drawing text twice (fill +
  thin outline via `foreground` paint): prize text and custom tags.
- Frames: rarity frames (`common` ... `ultra_rare`, 2400x1494) mapped to class letters in the JSON
  (S legendary, A epic, B ultra_rare, C super_rare, D rare, E uncommon, F common). Old `S..F.png` are
  kept untouched and unused. The word "Tyres" is part of the frames; the tyre NAME is drawn before it,
  right-aligned, baseline 800.3 and cap height matched to the baked letter T. A user slider in the ⓘ dialog
  (`LayoutTweaks.tyreNameOffset`) nudges it by eye.
- Drive: frames contain only "WD"; the app draws the first character (R / F / 4).

## Photo pipeline
- `PhotoTransform`: scale 0.4..6, dx/dy (fraction of card, +-1), rotation (radians). Original files are never
  modified; originals live in the photo library.
- `paintPhoto()` (photo_painter.dart) is the single drawing routine used by the preview, the card export,
  the cropped-photo export and the fill generator.
- Empty areas (photo smaller than card): `PhotoFill.smart` (content-aware, needs a generated picture),
  `mirror` (mirrored tiles + blur), `blur`, `none`. `smart` falls back to `mirror` until generated or when the
  framing changed (`CardProject.fillSignatureNow` must equal the stored signature).
- Content-aware fill = multi-scale PatchMatch in pure Dart (`photo_fill/patch_match_fill.dart`), run with
  `Isolate.run`, working size 400 px long side, then upsampled with detail transfer through the NNF.
  It continues background texture; it is NOT generative AI and mishandles cars cut by the photo edge.
  Possible upgrade: an ONNX inpainting model (e.g. MI-GAN) bundled by the user; not done.
- Each generation writes a new file name (`fills/<projectId>_<time>.png`) so the image cache never serves a
  stale picture.

## Tags
- `CardTag`: ready-made (asset path) or custom (text + ARGB border colour).
- Custom tag proportions were measured on the bundled tags (relative to height H): border 0.08H, corner radius
  0.38H, text size 0.53H, horizontal padding 0.25H + border, fill = border colour / 4.55 per channel.
  Reference tag height on cards: about 55 units, gap 25.

## Storage (app documents / `card_maker/`)
`photos/`, `logos/` (+ index.json each), `projects/<id>.json`, `fills/`, `settings.json`
(custom countries, custom tags, tyre offset).

## Build, release, updates
- `flutter create` runs in CI (android/ and ios/ are git-ignored); `tool/patch_android.py` adds INTERNET,
  legacy storage permission and the app label.
- Workflow triggers: push to main/master (version `major.minor` from pubspec + run number), tags `vX.Y.Z`,
  manual run. `versionCode = X*1_000_000 + Y*1_000 + Z` (must only grow).
- APK is re-signed with `apksigner` using repository secrets `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`,
  `KEY_ALIAS` (`cardmaker`), `KEY_PASSWORD`. Never change `APP_ORG` (package name) or the key: updates
  over an installed app would stop working.
- Artifacts (30 days) and GitHub Releases (permanent) both get the APK. The app checks the latest Release
  at start-up (public repository required) and offers the download.

## Known limitations / ideas
- Sizes were calibrated against screenshots, partly on one phone; `textScale` is an estimate.
- Content-aware fill takes a few seconds and can look streaky on asphalt.
- Logos from the internet often have margins or backgrounds: "Trim margins" and "Remove background" help;
  background removal works on plain backgrounds only (flood fill, no ML).
- Ideas not done: ONNX inpainting, real "medium" font weight, thumbnails cache for the home grid.
