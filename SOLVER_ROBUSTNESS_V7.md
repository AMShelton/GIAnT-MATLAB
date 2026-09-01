# SILo trust-region solver robustness (v7)

This revision addresses the rare MATLAB Optimization Toolbox error:

```text
Error using trdog>quad1d
Square root error in trdog/quad1d.
```

The normal successful GIAnT solver path is unchanged. `fmincon` is first
called with the same trust-region-reflective objective, bounds, gradient,
and cached Hessian multiply function.

Only when MATLAB raises the specific `trdog/quad1d` numerical error does
GIAnT retry the same objective. Retries add a small positive diagonal to
the Hessian approximation and reduce the number of PCG iterations. The
objective function, source data, bounds, lambda, kinetics, and NMF
iteration count are not changed.

Defaults:

```matlab
solverRobustFallback = true;
solverRetryDamping = [1e-8 1e-6 1e-4];
solverRetryPCGIter = 3;
```

The source solver also now checks for non-finite Y/Finv and invalid analytic
curvature before entering Optimization Toolbox, and parallel errors print
the extended nested exception report and subproblem/stage context.
