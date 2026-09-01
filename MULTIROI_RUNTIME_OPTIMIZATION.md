# MultiRoiRegistration runtime optimization v6

This revision targets the 80-Hz SLAP2 motion-correction stage while preserving
the scientific registration settings and output schema.

## Changes

1. **Batched SLAP2 reconstruction**
   - Main registration reads use `Slap2DataFile.getImages` in bounded blocks.
   - Initial 40 template frames are loaded in one batch.
   - ReVolt laser-on probe frames are loaded in batches.
   - Registration remains sequential after loading because the adaptive
     template depends on the previous registered frame.

2. **Allocation-efficient weighted correlation**
   - `xcorr2_nans_weighted_fast.m` evaluates the same correlation statistic,
     candidate shifts, and subpixel peak calculation as the legacy function.
   - It uses overlapping matrix slices rather than rebuilding `find` and
     `sub2ind` coordinate vectors at every candidate shift.
   - Set `useFastWeightedXcorr=false` to revert to the legacy kernel.

3. **Translation-specialized interpolation**
   - `interpFrameTranslationChannels.m` implements the same four-neighbor
     freshness-weighted bilinear calculation.
   - Two-channel recordings share interpolation coordinates and freshness
     lookup.
   - Set `useFastInterpolation=false` to revert to `interpFrame`.

4. **Worker-local reader cache**
   - Reuses a Slap2DataFile and parsed metadata when a process worker receives
     multiple pseudo-trials from the same continuous DAT.
   - Uses `slap2.util.getCachedDataFile` when available and falls back to a
     GIAnT-local cache.

5. **Bounded registration-QC RAM**
   - The old full-session `A_ds` array is replaced by one legacy-equivalent
     QC chunk at a time.
   - Chunk boundaries and `recNegErr` equations are unchanged.

6. **Reduced template allocation**
   - Only the current template crop is combined with the adaptive template.
   - Template updates touch pixels observed in the current aligned frame.

7. **Timing instrumentation**
   - Console output reports wall time plus reader, correlation, interpolation,
     template, TIFF, HDF5, and QC time.
   - Timing values are also written under `/runtime` in `_ALIGNMENTDATA.h5`.

## Recommended parameters for Andrew's 128-GB workstation

```matlab
nWorkers                  = 8;
registrationBlockFrames    = 128;
registrationBlockMemoryGB  = 4;
reuseSlap2Reader           = true;
useFastWeightedXcorr       = true;
useFastInterpolation       = true;
```

Scientific settings retained in the supplied preset:

```matlab
alignHz   = 80;
maxshift  = 50;
clipShift = 5;
```

## Validation before large-scale processing

Run:

```matlab
runtests('tests')
```

For a real DAT file, also compare batched reader output to repeated `getImage`
calls with:

```matlab
report = validateBatchedSlap2Reads(datPath,[1 2],frames,ceil(dt),1,1);
```

`maxAbsImageDifference` and `maxAbsFreshnessDifference` should be zero or at
floating-point roundoff, with identical NaN masks.

For a direct A/B registration comparison, run one short trial once with:

```matlab
useFastWeightedXcorr = false;
useFastInterpolation = false;
registrationBlockFrames = 1;
```

and once with the optimized settings. Compare `motionDSr`, `motionDSc`,
`aError`, `recNegErr`, and registered mean images.
