# Code Ocean migration assessment — GIAnT-MATLAB

This document separates observed repository functionality from deployment assumptions. Cloud feasibility has **not** been validated by running Code Ocean or by executing MATLAB tests in this environment.

| Change | Repository evidence / intent | Code Ocean feasibility and action |
|---|---|---|
| `processSLAP2` orchestration | Sequential trial table, MultiRoiRegistration, SILo; parameter dialogs and trial-table reuse | **Needs refactoring** for unattended capsules: replace dialogs and `questdlg` with explicit configuration and noninteractive overwrite/reuse policy. Keep the interactive path intact. |
| Dynamic AIND SLAP2 acquisition layouts | `buildTrialTableSLAP2.m`, including epoch/trial construction | **Likely portable** if input mounts and metadata layout are supplied consistently. Test real datasets and path handling. |
| Multi-ROI registration RAM/I/O optimizations | Streaming variance data, tiled HDF5, bounded registration search, optimized cross-correlation | **Promising**, but benchmark storage throughput, RAM, worker memory and output HDF5 integrity on Code Ocean compute. |
| Optional C++ weighted-xcorr MEX | `buildWeightedXcorrMex.m`, dispatch, compiled-source code and build-time validation | **Conditional** on supported compiler/runtime and MATLAB architecture; compile in the capsule or use tested MATLAB fallback. Windows `.mexw64` is not portable to Linux. |
| SILo localization/extraction improvements | Selected-pixel interpolation, bounded blocks, cached computations, configurable worker pools | **Likely portable** after resource tuning; benchmark accuracy, memory and runtime on representative datasets. |
| Optional summarize_LoCo-style extraction | Solver changes and `docs/SOURCE_DETECTION_BACKENDS.md` | **Conditional**: verify numerical behavior and toolbox availability against the current SILo pathway. Do not silently change scientific defaults. |
| Manual ROI annotation | `annotateROIs`, `drawROIs`, SILo ROI workflow | **Interactive dependency**: prepare annotations locally or implement a separate headless annotation-input path. |
| MATLAB/external dependencies | Optimization, Parallel, Image Processing, Signal Processing, Statistics; SLAP2 reader; Fast_Tiff_Write; optional NoRMCorre | **Conditional** on Code Ocean MATLAB license/toolboxes, access to external packages, and executable/runtime compatibility. |
| Local scratch and parallel I/O | `localizationTempDir`, `nWorkers`, `extractionWorkers`, `highResBlockFrames` | **Configurable**: use writable capsule scratch, bound workers to actual memory/CPU, test concurrent HDF5 access. |

## Suggested deployment gates

1. Agree with coworkers on MATLAB licensing, toolbox checkout, SLAP2 reader distribution, and available compiler/MEX support.
2. Establish a fixed, headless configuration for paths, presets, ROI annotations, overwrite behavior and workers. Do not remove GUI behavior for desktop users.
3. Run one representative SLAP2 dataset locally and in Code Ocean with identical input data and parameters; compare trial tables, registration motion/quality, extracted traces, ROI identities and HDF5 schemas.
4. Check solver and MEX-versus-fallback numerical tolerances, failure handling, logs, runtime, peak RAM and scratch-disk usage.
5. Only then define a reproducible capsule environment and pin external dependency versions.

## Repository cleanup

Standalone test suites, benchmark wrappers, installation-audit scripts, historical optimization notes, and old patch files were removed at the repository owner's request. The optional `validateWeightedXcorrMex.m` helper is retained because `buildWeightedXcorrMex.m` calls it to validate a newly compiled accelerator; it is not part of routine dataset processing. The platform-specific prebuilt `.mexw64` artifact was removed; compile from source on the target platform or use the MATLAB fallback.

The absence of automated repository tests increases the importance of full dataset-level regression/QC before merging or deploying to Code Ocean. Existing motion-correction and extraction implementations and parameter presets are retained.

## Validation status

Static review of the supplied archive only. MATLAB, Code Ocean, data-dependent integration tests, and scientific output equivalence have **not** been executed. No runtime or numerical performance claim in this document is a new measurement.
