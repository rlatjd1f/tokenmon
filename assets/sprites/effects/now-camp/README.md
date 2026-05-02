# Now Camp Effect Assets

P1 Now Camp / Leader Training visual assets.

The field folders contain review sheets for field-specific camp overlays. They
are source/review material, not runtime assets.

Folders:

- `grassland/` — Grassland props, care, resonance, and training effects.
- `coast/` — Coast props, care, resonance, and training effects.
- `ice/` — Ice props, care, resonance, and training effects.
- `sky/` — Sky props, care, resonance, and training effects.
- `common/` — Field-neutral resonance and state effects.
- `candidates/` — Earlier broad concept sheets and layout references.
- `runtime/` — transparent PNGs loaded by the app. Runtime camp props are
  sliced from the field review sheets and alpha-cleaned so they can sit on top
  of the existing field backgrounds without a checkerboard or mockup plate.

Runtime field keys are:

- `camp_mat_64.png`
- `camp_prop_primary_32.png`
- `camp_prop_secondary_32.png`
- `camp_prop_32.png` legacy fallback
- `care_fx_16.png`
- `train_fx_16.png`

Common runtime keys remain under `runtime/common/`.
