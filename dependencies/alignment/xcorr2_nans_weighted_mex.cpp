#include "mex.h"
#include "xcorr2_nans_weighted_core.hpp"

#include <cmath>
#include <cstddef>
#include <exception>

namespace {

void requireRealFloating2D(const mxArray* a, const char* name) {
    const bool floating = mxIsDouble(a) || mxIsSingle(a);
    if (!floating || mxIsComplex(a) || mxIsSparse(a) || mxGetNumberOfDimensions(a) > 2) {
        mexErrMsgIdAndTxt("xcorr2_nans_weighted_mex:UnsupportedType",
                         "%s must be a real, full, 2-D single or double array.", name);
    }
}

long readIntegerScalar(const mxArray* a, const char* name, bool nonnegative) {
    if (!mxIsDouble(a) || mxIsComplex(a) || mxGetNumberOfElements(a) != 1) {
        mexErrMsgIdAndTxt("xcorr2_nans_weighted_mex:InvalidScalar",
                         "%s must be a real double scalar.", name);
    }
    const double v = mxGetScalar(a);
    if (!std::isfinite(v) || v != std::round(v) || (nonnegative && v < 0)) {
        mexErrMsgIdAndTxt("xcorr2_nans_weighted_mex:InvalidScalar",
                         "%s must be a finite %sinteger scalar.", name,
                         nonnegative ? "nonnegative " : "");
    }
    return static_cast<long>(v);
}

template <typename F, typename W, typename T>
giant_xcorr::WeightedXcorrResult runTyped(const mxArray* frame,
                                          const mxArray* freshness,
                                          const mxArray* templ,
                                          std::size_t nRows,
                                          std::size_t nCols,
                                          long centerR,
                                          long centerC,
                                          long dShift) {
    return giant_xcorr::weightedXcorr<F,W,T>(
        static_cast<const F*>(mxGetData(frame)),
        static_cast<const W*>(mxGetData(freshness)),
        static_cast<const T*>(mxGetData(templ)),
        nRows,nCols,centerR,centerC,dShift);
}

giant_xcorr::WeightedXcorrResult dispatchByClass(const mxArray* frame,
                                                  const mxArray* freshness,
                                                  const mxArray* templ,
                                                  std::size_t nRows,
                                                  std::size_t nCols,
                                                  long centerR,
                                                  long centerC,
                                                  long dShift) {
    const bool fs = mxIsSingle(frame);
    const bool ws = mxIsSingle(freshness);
    const bool ts = mxIsSingle(templ);

    if (fs && ws && ts) return runTyped<float,float,float>(frame,freshness,templ,nRows,nCols,centerR,centerC,dShift);
    if (fs && ws && !ts) return runTyped<float,float,double>(frame,freshness,templ,nRows,nCols,centerR,centerC,dShift);
    if (fs && !ws && ts) return runTyped<float,double,float>(frame,freshness,templ,nRows,nCols,centerR,centerC,dShift);
    if (fs && !ws && !ts) return runTyped<float,double,double>(frame,freshness,templ,nRows,nCols,centerR,centerC,dShift);
    if (!fs && ws && ts) return runTyped<double,float,float>(frame,freshness,templ,nRows,nCols,centerR,centerC,dShift);
    if (!fs && ws && !ts) return runTyped<double,float,double>(frame,freshness,templ,nRows,nCols,centerR,centerC,dShift);
    if (!fs && !ws && ts) return runTyped<double,double,float>(frame,freshness,templ,nRows,nCols,centerR,centerC,dShift);
    return runTyped<double,double,double>(frame,freshness,templ,nRows,nCols,centerR,centerC,dShift);
}

} // namespace

void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[]) {
    if (nrhs != 5) {
        mexErrMsgIdAndTxt("xcorr2_nans_weighted_mex:InputCount",
                         "Expected frame, freshness, template, shiftsCenter, dShift.");
    }
    if (nlhs > 3) {
        mexErrMsgIdAndTxt("xcorr2_nans_weighted_mex:OutputCount",
                         "At most three outputs are supported: motion, R, C.");
    }

    requireRealFloating2D(prhs[0],"frame");
    requireRealFloating2D(prhs[1],"freshness");
    requireRealFloating2D(prhs[2],"template");

    const mwSize nRows = mxGetM(prhs[2]);
    const mwSize nCols = mxGetN(prhs[2]);
    if (mxGetM(prhs[0]) != nRows || mxGetN(prhs[0]) != nCols ||
        mxGetM(prhs[1]) != nRows || mxGetN(prhs[1]) != nCols) {
        mexErrMsgIdAndTxt("xcorr2_nans_weighted_mex:SizeMismatch",
                         "frame, freshness, and template must have identical 2-D size.");
    }

    if (!mxIsDouble(prhs[3]) || mxIsComplex(prhs[3]) || mxGetNumberOfElements(prhs[3]) != 2) {
        mexErrMsgIdAndTxt("xcorr2_nans_weighted_mex:InvalidShiftCenter",
                         "shiftsCenter must contain two real double integer offsets.");
    }
    const double* center = mxGetPr(prhs[3]);
    if (!std::isfinite(center[0]) || !std::isfinite(center[1]) ||
        center[0] != std::round(center[0]) || center[1] != std::round(center[1])) {
        mexErrMsgIdAndTxt("xcorr2_nans_weighted_mex:InvalidShiftCenter",
                         "shiftsCenter must contain two finite integer offsets.");
    }
    const long centerR = static_cast<long>(center[0]);
    const long centerC = static_cast<long>(center[1]);
    const long dShift = readIntegerScalar(prhs[4],"dShift",true);

    try {
        giant_xcorr::WeightedXcorrResult result = dispatchByClass(
            prhs[0],prhs[1],prhs[2],
            static_cast<std::size_t>(nRows),static_cast<std::size_t>(nCols),
            centerR,centerC,dShift);

        if (nlhs >= 1) {
            plhs[0] = mxCreateDoubleMatrix(1,2,mxREAL);
            double* m = mxGetPr(plhs[0]);
            m[0] = result.motion[0];
            m[1] = result.motion[1];
        }
        if (nlhs >= 2) {
            plhs[1] = mxCreateDoubleScalar(result.R);
        }
        if (nlhs >= 3) {
            plhs[2] = mxCreateDoubleMatrix(
                static_cast<mwSize>(result.nShifts),
                static_cast<mwSize>(result.nShifts),mxREAL);
            double* c = mxGetPr(plhs[2]);
            std::copy(result.C.begin(),result.C.end(),c);
        }
    } catch (const std::exception& e) {
        mexErrMsgIdAndTxt("xcorr2_nans_weighted_mex:RuntimeError","%s",e.what());
    }
}
