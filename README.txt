GIAnT SILo lsqcurvefit precision fix

Cause
-----
The RAM-optimized localizeSources_vIM keeps the 2-D source-localization
summary image in single precision. getActImPeaks passes values derived from
that image to lsqcurvefit. MATLAB R2024b requires lsqcurvefit X0 and YDATA to
be double, causing:

  LSQCURVEFIT requires the following inputs to be of data type double:
  'X0','YDATA'.

Fix
---
getActImPeaks now converts its compact 2-D actIM input to double once at the
function boundary. The large H x W x T SILo movie remains single precision,
so the RAM optimization is preserved. This also makes getActImPeaks robust
to future single-precision callers.

Install
-------
Replace:
  dependencies/extraction/activityImage/getActImPeaks.m

Then in MATLAB:
  clear getActImPeaks localizeSources_vIM loadAndProcessTrialAsync SILo
  rehash
  which getActImPeaks -all

Rerun SILo. Motion correction does not need to be rerun.
