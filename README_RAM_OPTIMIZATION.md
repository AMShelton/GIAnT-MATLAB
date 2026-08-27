# GIAnT SILo RAM optimization patch

This patch is based on the GIAnT-MATLAB repository snapshot supplied on 2026-08-27.

## Files replaced / added

- `source_extraction/SILo.m` — replace
- `dependencies/extraction/activityImage/loadAndProcessTrialAsync.m` — replace
- `dependencies/extraction/activityImage/localizeSources_vIM.m` — replace
- `dependencies/io/loadAlignmentDataLite.m` — **new file**
- `dependencies/gui/setParams.m` — replace (adds two performance-only GUI options)

## Main changes

1. `SILo` no longer calls `loadStructFromH5` on alignment files just to access small metadata. `loadAlignmentDataLite` skips `/slap2/varFacDS`.
2. `loadAndProcessTrialAsync` passes `/slap2/varFacDS` to source localization as an on-disk HDF5 source instead of loading the complete H x W x T array.
3. `localizeSources_vIM` performs variance normalization and matched filtering in spatial tiles. Temporal filters still operate over the entire time axis for every pixel.
4. If an older alignment H5 uses full-frame variance chunks (`H x W x 1`), the localizer automatically makes a temporary spatially chunked cache and deletes it after the trial. Put `localizationTempDir` on a fast local SSD.
5. SILo estimates a safe process-worker count from current available RAM and the registered TIFF size, and respects the MATLAB Processes-profile worker ceiling.
6. If only one worker is selected, SILo uses a normal `for` loop so MATLAB does not auto-create an unexpected pool.
7. Per-trial mean/activity image stacks and alignment work arrays are stored as `single` where scientifically appropriate.
8. The internal trial loader no longer returns the full registered movie to SILo, because SILo discarded that output.

## New optionsGUI performance parameters

- `localizationTileSize` (default `96` pixels): larger tiles generally reduce overhead but use more RAM per worker.
- `localizationTempDir` (default `tempdir`): directory for a temporary rechunked `varFacDS` cache when needed. Prefer a fast local SSD with ample free space.

These are computational parameters only; they do not change indicator kinetics, thresholds, source size, or other scientific settings.

## Recommended validation before batch processing

Run the original and patched source-localization code on the same 1–3 already motion-corrected trials and compare:

- `aIM` / activity images
- detected peak coordinates and values
- source count after cross-trial source selection
- `experiment_summary.h5` output traces
- peak MATLAB/OS RAM
- wall-clock time

The tile implementation is designed to reproduce the original localization calculations in each tile core. The global variance model is calibrated from the same first 500 valid frames with enough temporal look-ahead for centered smoothing.
