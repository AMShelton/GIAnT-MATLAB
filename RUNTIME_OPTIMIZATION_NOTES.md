# SLAP2 runtime optimization pass

This branch keeps the scientific GIAnT pathway intact (80-Hz registration, 200-Hz SLAP2 extraction, source localization/NMF model and kinetics) while reducing avoidable memory, interpolation, solver and I/O work.

## Implemented

- MultiRoiRegistration streams `varFacDS` and writes spatially tiled HDF5 chunks (`varFacChunkXY`, default 128), avoiding the full-file SILo rechunk pass for newly generated alignment data.
- MultiRoiRegistration retains the bounded `clipShift` residual search introduced in the previous optimization pass.
- SILo localization remains tiled/disk-backed and RAM-aware.
- High-resolution SLAP2 extraction now interpolates only the union of source pixels, global-trace pixels and user-ROI pixels instead of the complete FOV at 200 Hz.
- High-resolution raw blocks are traversed in forward time order.
- `highResBlockFrames` exposes the raw reconstruction block size (default 600).
- `extractionWorkers` independently controls the thread pool used by NMF source subproblems.
- NMF `fmincon` objective functions cache the curvature coefficient required by PCG Hessian-vector products rather than rebuilding the complete forward state for each Hessian multiply.
- Dense `diag(1./residVar)` matrices are eliminated from SNR estimation.
- `splitFreq` baseline interpolation is vectorized across pixels.
- Full pixel-by-time baseline matrices are no longer reassembled after each source subproblem; compact source-weighted `F0` is calculated before the local baseline is released.
- `savePerTrialSummary` controls the optional `per_trial_summary.h5` output. Default remains `true`; the Andrew local-processing preset sets it to `false`.
- Stage timing is printed for localization, raw `getImages`, selected interpolation and high-resolution extraction.
- RDP-responsive `optionsGUI` and legacy-preset merging are included.
- `getActImPeaks` accepts single-precision activity images while converting the small solver input to double for MATLAB R2024b `lsqcurvefit` compatibility.

## Deliberately unchanged

- `analyzeHz` / 200-Hz SLAP2 sampling
- `alignHz` / 80-Hz motion traces
- source-detection thresholding and Gaussian peak fitting
- NMF iteration count and regularization
- glutamate/calcium kinetics
- motion interpolation (`pchip`)
- freshness-weighted bilinear interpolation equation
- output traces in `experiment_summary.h5`

## Validation on the first rerun

Run the same session locally and retain the console timing output. Compare with the previous run:

1. source number and coordinates
2. mean/activity images
3. per-source footprint correlations
4. `F0`, `dF_ls`, `dF_denoised`, event traces and SNR
5. motion traces and registered TIFFs
6. total runtime and printed `getImages` vs selected-interpolation timing

If `getImages` remains the dominant high-resolution cost after this pass, the next optimization target is the Slap2DataReader internals so raw acquisition samples/superpixels can be selected before full raster reconstruction.


## v4: reader reuse + batched selected interpolation

This revision keeps the SLAP2 scientific reconstruction unchanged while
reducing MATLAB-side overhead:

1. Reuses one `slap2.Slap2DataFile` and metadata object across analysis
   pseudo-trials from the same continuous DAT file.
2. Vectorizes selected-pixel bilinear interpolation across bounded frame
   batches and includes a regression test against the frame-wise reference.
3. Allows larger `getImages` blocks on local SSDs with a conservative
   RAM-based automatic cap.
4. Reduces the recommended source-extraction thread count when I/O is
   overlapped with NMF, leaving more CPU/cache bandwidth for the reader.
