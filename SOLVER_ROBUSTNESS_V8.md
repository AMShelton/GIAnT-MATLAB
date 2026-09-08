# SILo solver robustness (v8)

This revision extends the existing guard for the rare MATLAB Optimization
Toolbox failure:

```text
Error using trdog>quad1d
Square root error in trdog/quad1d.
```

## Normal path is unchanged

Every SILo source-activity/footprint solve still first uses the existing
`fmincon` trust-region-reflective problem with the same objective, analytic
gradient, bounds, kinetics, lambda, and NMF iteration state.

If and only if MATLAB raises the specific `trdog/quad1d` numerical error,
GIAnT first performs the existing trust-region retries with small positive
Hessian damping and reduced PCG iterations.

## New final fallback

If all damped trust-region retries hit the same `trdog/quad1d` error, GIAnT
now solves that same bounded objective with `fmincon` interior-point using an
L-BFGS Hessian approximation. L-BFGS keeps the rare fallback memory-bounded
for the large activity vectors used by SILo.

The fallback does **not** change the source data, objective, gradient, bounds,
regularization parameters, kinetics, or NMF iteration count. It changes only
the numerical optimizer for the subproblem that MATLAB's trust-region
implementation could not solve.

Fallback output is accepted only when the returned objective and parameters
are finite and the solution satisfies the original bounds within a small
numerical tolerance. Otherwise the extraction still fails rather than
silently accepting invalid data.

## Baseline least-squares fit

`fitB` now explicitly requests the `lsqlin` `interior-point` algorithm. This
is MATLAB's current documented default, so normal behavior is unchanged, but
pinning the algorithm ensures this bounded convex baseline fit does not drift
onto the trust-region `trdog` implementation in a future environment.

Existing controls remain:

```matlab
solverRobustFallback = true;
solverRetryDamping = [1e-8 1e-6 1e-4];
solverRetryPCGIter = 3;
```

When the final fallback is used, GIAnT prints the failing subproblem/stage and
the interior-point exit flag for QC/provenance.
