# MultiROI weighted-xcorr acceleration

This upgrade accelerates the weighted local cross-correlation hot path used by
`MultiRoiRegistration` without making GIAnT dependent on a compiler or MEX
binary.

## Production behavior

The default MultiROI settings are:

```matlab
useFastWeightedXcorr     = true;
useMexWeightedXcorr      = true;
validateMexWeightedXcorr = true;
useAdaptiveWeightedXcorr = false;
```

With these defaults, the scientific search is unchanged: the main registration
still evaluates the full `clipShift` radius (normally +/-5 pixels), and initial
template construction remains exhaustive.

`MultiRoiRegistration` never compiles code. At runtime:

1. if `xcorr2_nans_weighted_mex` is loadable, each MATLAB process/worker
   validates it on the first *actual GIAnT correlation input for each input-class
   signature* against `xcorr2_nans_weighted_fast`; real SLAP2 registration uses
   both `single/single/single` and `single/single/double` inputs;
2. if validation passes, the MEX backend is used directly on native `single`
   and/or `double` arrays without MATLAB-side full-image casts;
3. if the MEX is absent, incompatible, fails validation, or throws later, the
   current MATLAB fast implementation is used immediately;
4. a runtime MEX failure is sticky for that process/worker, so a long run does
   not repeatedly encounter the same failure.

A C++ compiler is therefore needed only to **build** the optional binary, not to
run GIAnT. A machine with no compiler and no MEX binary continues to use the
same MATLAB-fast registration behavior as before this upgrade.

## Build once per processing machine

From MATLAB with the GIAnT repo on path:

```matlab
mex -setup C++       % only if a compiler has not already been selected
[ok, report] = buildWeightedXcorrMex;
```

The build helper catches missing/compiler/build failures by default and returns
`ok=false`; it does not change registration parameters. For setup/CI where a
failure should throw:

```matlab
buildWeightedXcorrMex('Strict',true);
```

## Verify before a long run

```matlab
clear functions
verifyMultiRoiUpgrade('D:\path\to\a\writable\test\directory')
```

When a MEX binary is present, the verifier adds randomized MATLAB-vs-MEX
correlation-surface/motion tests and reports MEX speedup versus the existing
MATLAB-fast implementation. When no MEX is present, its absence is explicitly
reported but is not a test failure.

You can also run:

```matlab
validateWeightedXcorrMex('Strict',true,'RunBenchmark',true)
```

## Adaptive search (experimental, OFF by default)

The observed five-file motion sample had 99.9866% of residual frame-to-frame
motion within +/-2 pixels and 100% within +/-3 pixels. An optional adaptive
main-loop mode is therefore included, but is deliberately disabled by default:

```matlab
useAdaptiveWeightedXcorr = false;
```

If explicitly enabled, it searches `adaptiveXcorrRadius` first (default 2) and
recomputes the full `clipShift` search when the small-search peak touches the
boundary, the correlation is below `adaptiveXcorrMinCorrelation`, or a periodic
full-search audit is due. Initial-template correlation is never adaptive.
Periodic audit disagreement disables adaptive mode on that worker.

This mode should remain off until it has been validated across a broader set of
sessions. The MEX acceleration does not require adaptive search.
