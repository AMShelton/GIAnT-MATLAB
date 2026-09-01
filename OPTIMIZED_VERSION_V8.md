# GIAnT optimized reconciliation v8

This tree reconciles all performance/robustness work through v7 and fixes
the MATLAB unit-test packaging issues found during validation.

Included optimization generations:
- AIND dynamic_data-aware SLAP2 trial-table resolution.
- SILo RAM optimization and lazy/tiled variance access.
- Sparse selected-pixel 200-Hz interpolation.
- Batched selected-pixel interpolation and Slap2DataReader handle reuse.
- Large per-trial summary output made optional.
- R2024b getActImPeaks single/double compatibility.
- optionsGUI saved-preset schema/type normalization.
- MultiRoiRegistration batched reads, fast weighted correlation,
  translation-specialized interpolation, reader reuse, and reduced QC RAM.
- SILo trust-region solver diagnostics and trdog/quad1d fallback.

v8-specific reconciliation:
- Corrected test_getActImPeaks_single.m so functiontests discovers the test.
- Added test_repositoryCompleteness.m to catch missing optimized helper files.
- Added runGIAnTTests.m; avoids invalid manual TestSuite concatenation.
- Added auditGIAnTInstall.m for path/completeness/revision-marker checks.
- Added canonical file manifest and current parameter presets.

No source-detection or scientific parameter logic was changed in v8.
