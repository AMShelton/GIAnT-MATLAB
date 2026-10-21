# Selectable SILo source-detection backends

## Purpose

GIAnT source extraction can use either:

- `silo` — native/current GIAnT source detection (**default**)
- `summarize_loco` — compatibility source detection based on the supplied historical `summarize_LoCo.m`

The integration is intentionally narrow: both pathways share the user's current GIAnT loading, motion-corrected inputs, trial localization, cross-trial alignment, valid-trial filtering, source neighborhoods, high-resolution refinement, signal extraction, and HDF5 writers. The experimental variable is the source-seed detector.

## Call syntax

```matlab
% Existing/default SILo behavior
p.sourceDetectionMethod = 'silo';
SILo(pathToTrialTable, p);

% summarize_LoCo-compatible source detection
p.sourceDetectionMethod = 'summarize_loco';
p.maxSynapseDensity = YOUR_ORIGINAL_SUMMARIZE_LOCO_VALUE;
SILo(pathToTrialTable, p);
```

Aliases `loco` and `summarizeloco` normalize to `summarize_loco`.

## Critical legacy parameter

The supplied `summarize_LoCo.m` gets `maxSynapseDensity` from `setParams('summarize_LoCo')`; it does not define the numeric value internally. For a faithful historical comparison, use the value from the parameter set used for your prior LoCo processing.

## Native SILo detector

The `silo` branch preserves the current source-selection calculation:

1. mean aligned activity across valid trials (`'includenan'`)
2. existing SILo order-of-magnitude activity scaling
3. invalid-pixel masking using `nanThresh`
4. fixed 5x5 local median subtraction
5. `getActImPeaks(..., peakth, somaMask, minPeakDistance)`
6. duplicate coordinate pruning

## summarize_LoCo-compatible detector

The compatibility branch preserves the supplied LoCo source-selection rule:

1. mean aligned activity image across valid trials (`'includenan'`)
2. local median subtraction, side length `2*ceil(1.5*dXY)+1`
3. positive 3x3 local maxima
4. iterative 5x5 exclusion/suppression
5. soma masking
6. determine source-density rank from `ceil(totalValidPixels*maxSynapseDensity)`
7. threshold at twice the activity of the peak at that rank
8. retain source seeds meeting the threshold

The helper uses `maxk` to recover the required kth-largest value when this avoids sorting the complete candidate vector. This preserves the threshold value while reducing unnecessary sorting work. The iterative LoCo suppression itself is intentionally retained because substituting a different NMS implementation can change which candidate sources survive.

## Important v2 installer behavior

Installer v2 **does not modify shared SILo runtime code** such as:

- `meanAligned` allocation
- registration interpolation grids
- worker/memory policy
- `selPix` validity-mask implementation

Those parts have evolved across GIAnT versions and forks, including optimized versions. The integration now patches only the backend-control and detector boundary. This is why v2 works when the local SILo has already been runtime-optimized.

## Comparing source-detection methods

The standalone `runSourceDetectionBenchmark.m` wrapper was removed during repository cleanup. To compare backends, run `SILo` separately with the two `sourceDetectionMethod` values shown above, using the same input and other parameters. Save each run's outputs under a distinct output path or archive them before the next run, since conventional output names may be overwritten. Preserve the original `maxSynapseDensity` for comparisons to historical LoCo results.

## Diagnostic MAT contents

Each detector diagnostic stores:

- `rawActIM` — common mean-aligned activity entering backend-specific detection
- `detectionIM` — actual activity image used for that backend's peak selection
- `sources` — source seed row/column/value
- `sourceDetectionInfo` — method, median-filter size, source-density threshold, candidate count
- `params` — parameters for that run

These are intended for subsequent spatial matching and source-quality QC: matched sources, SILo-only sources, LoCo-only sources, density, SNR, trial stability, source footprint, and downstream refinement quality.
