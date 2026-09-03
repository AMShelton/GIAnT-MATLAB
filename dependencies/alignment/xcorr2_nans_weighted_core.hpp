#ifndef GIANT_XCORR2_NANS_WEIGHTED_CORE_HPP
#define GIANT_XCORR2_NANS_WEIGHTED_CORE_HPP

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <limits>
#include <stdexcept>
#include <type_traits>
#include <vector>

namespace giant_xcorr {

struct WeightedXcorrResult {
    std::vector<double> motion;  // [row, col]
    double R = std::numeric_limits<double>::quiet_NaN();
    std::vector<double> C;       // MATLAB column-major nShifts x nShifts
    std::size_t nShifts = 0;
};

inline std::size_t matlabIndex(std::size_t row, std::size_t col, std::size_t nRows) {
    return row + col * nRows;
}

inline long positiveModulo(long value, long modulus) {
    long out = value % modulus;
    if (out < 0) out += modulus;
    return out;
}

template <typename T>
inline std::vector<T> circshift2d(const T* src,
                                  std::size_t nRows,
                                  std::size_t nCols,
                                  long shiftRow,
                                  long shiftCol) {
    std::vector<T> dst(nRows * nCols);
    const long nr = static_cast<long>(nRows);
    const long nc = static_cast<long>(nCols);
    for (std::size_t c = 0; c < nCols; ++c) {
        for (std::size_t r = 0; r < nRows; ++r) {
            const long srcR = positiveModulo(static_cast<long>(r) - shiftRow, nr);
            const long srcC = positiveModulo(static_cast<long>(c) - shiftCol, nc);
            dst[matlabIndex(r,c,nRows)] = src[matlabIndex(
                static_cast<std::size_t>(srcR), static_cast<std::size_t>(srcC), nRows)];
        }
    }
    return dst;
}

template <typename FrameT, typename FreshT>
struct FiniteFramePixelT {
    long row;
    long col;
    FrameT value;
    FreshT freshness;
};

// Native-precision implementation matching MATLAB's default arithmetic rules:
// mean/sum of SINGLE inputs remain SINGLE; mixed SINGLE/DOUBLE expressions
// promote to DOUBLE.  The final C surface is returned as DOUBLE because the
// MATLAB reference preallocates C with NAN (double) before assignment.
template <typename FrameT, typename FreshT, typename TemplateT>
inline WeightedXcorrResult weightedXcorr(const FrameT* frame,
                                         const FreshT* freshness,
                                         const TemplateT* templateIn,
                                         std::size_t nRows,
                                         std::size_t nCols,
                                         long shiftCenterRow,
                                         long shiftCenterCol,
                                         long dShift) {
    static_assert(std::is_floating_point<FrameT>::value, "Frame type must be floating point.");
    static_assert(std::is_floating_point<FreshT>::value, "Freshness type must be floating point.");
    static_assert(std::is_floating_point<TemplateT>::value, "Template type must be floating point.");

    if (!frame || !freshness || !templateIn) {
        throw std::invalid_argument("Null input pointer.");
    }
    if (nRows == 0 || nCols == 0) {
        throw std::invalid_argument("Input images must be non-empty.");
    }
    if (dShift < 0) {
        throw std::invalid_argument("dShift must be nonnegative.");
    }

    const TemplateT* templ = templateIn;
    std::vector<TemplateT> shiftedTemplate;
    if (shiftCenterRow != 0 || shiftCenterCol != 0) {
        shiftedTemplate = circshift2d(templateIn,nRows,nCols,shiftCenterRow,shiftCenterCol);
        templ = shiftedTemplate.data();
    }

    // Mirror FIND(~isnan(frame)) once per call in MATLAB column-major order.
    std::vector<FiniteFramePixelT<FrameT,FreshT>> finiteFrame;
    finiteFrame.reserve(nRows*nCols);
    for (std::size_t c = 0; c < nCols; ++c) {
        for (std::size_t r = 0; r < nRows; ++r) {
            const std::size_t idx = matlabIndex(r,c,nRows);
            const FrameT F = frame[idx];
            if (std::isnan(F)) continue;
            finiteFrame.push_back(FiniteFramePixelT<FrameT,FreshT>{
                static_cast<long>(r),static_cast<long>(c),F,freshness[idx]});
        }
    }

    const long nShiftsLong = 2 * dShift + 1;
    const std::size_t nShifts = static_cast<std::size_t>(nShiftsLong);
    const double nan = std::numeric_limits<double>::quiet_NaN();

    WeightedXcorrResult out;
    out.nShifts = nShifts;
    out.C.assign(nShifts*nShifts,nan);
    out.motion.assign(2,nan);

    const long nr = static_cast<long>(nRows);
    const long nc = static_cast<long>(nCols);

    using FTProduct = typename std::common_type<FrameT,FreshT>::type;
    using CovType = typename std::common_type<FTProduct,TemplateT>::type;

    for (long dcix = 0; dcix < nShiftsLong; ++dcix) {
        const long dc = dcix - dShift;
        for (long drix = 0; drix < nShiftsLong; ++drix) {
            const long dr = drix - dShift;

            // MATLAB mean(F) / mean(T) use native precision for SINGLE.
            FrameT sumF = static_cast<FrameT>(0);
            TemplateT sumT = static_cast<TemplateT>(0);
            std::size_t count = 0;
            for (const auto& px : finiteFrame) {
                const long tr = px.row + dr;
                const long tc = px.col + dc;
                if (tr < 0 || tr >= nr || tc < 0 || tc >= nc) continue;
                const TemplateT T = templ[matlabIndex(
                    static_cast<std::size_t>(tr),static_cast<std::size_t>(tc),nRows)];
                if (std::isnan(T)) continue;
                sumF = static_cast<FrameT>(sumF + px.value);
                sumT = static_cast<TemplateT>(sumT + T);
                ++count;
            }
            if (count == 0) continue;

            const FrameT mF = static_cast<FrameT>(sumF / static_cast<FrameT>(count));
            const TemplateT mT = static_cast<TemplateT>(sumT / static_cast<TemplateT>(count));

            CovType sFT = static_cast<CovType>(0);
            TemplateT sumT2 = static_cast<TemplateT>(0);
            FTProduct sF = static_cast<FTProduct>(0);
            FreshT sumW = static_cast<FreshT>(0);

            for (const auto& px : finiteFrame) {
                const long tr = px.row + dr;
                const long tc = px.col + dc;
                if (tr < 0 || tr >= nr || tc < 0 || tc >= nc) continue;
                const TemplateT T = templ[matlabIndex(
                    static_cast<std::size_t>(tr),static_cast<std::size_t>(tc),nRows)];
                if (std::isnan(T)) continue;

                const FrameT dF = static_cast<FrameT>(px.value - mF);
                const TemplateT dT = static_cast<TemplateT>(T - mT);
                const FreshT w = px.freshness;

                const FTProduct wDF = static_cast<FTProduct>(w * dF);
                sFT = static_cast<CovType>(sFT + static_cast<CovType>(wDF) * static_cast<CovType>(dT));
                sumT2 = static_cast<TemplateT>(sumT2 + static_cast<TemplateT>(dT * dT));
                sF = static_cast<FTProduct>(sF + static_cast<FTProduct>(wDF * static_cast<FTProduct>(dF)));
                sumW = static_cast<FreshT>(sumW + w);
            }

            const TemplateT sT = static_cast<TemplateT>(
                sumT2 / static_cast<TemplateT>(count));

            // Preserve native/mixed arithmetic before converting the result to
            // the double C surface used by MATLAB.
            using DenType = typename std::common_type<TemplateT,FTProduct,FreshT>::type;
            const DenType denomArg = static_cast<DenType>(sT) *
                static_cast<DenType>(sF) * static_cast<DenType>(sumW);
            const DenType denom = static_cast<DenType>(std::sqrt(denomArg));
            const CovType corr = static_cast<CovType>(sFT / static_cast<CovType>(denom));

            out.C[static_cast<std::size_t>(drix) + static_cast<std::size_t>(dcix)*nShifts] =
                static_cast<double>(corr);
        }
    }

    bool found = false;
    double maxval = nan;
    std::size_t maxLinear = 0;
    for (std::size_t i = 0; i < out.C.size(); ++i) {
        const double v = out.C[i];
        if (std::isnan(v)) continue;
        if (!found || v > maxval) {
            found = true;
            maxval = v;
            maxLinear = i;
        }
    }
    out.R = found ? maxval : nan;

    const std::size_t rr = maxLinear % nShifts;
    const std::size_t cc = maxLinear / nShifts;
    const double shiftR = static_cast<double>(static_cast<long>(rr) - dShift);
    const double shiftC = static_cast<double>(static_cast<long>(cc) - dShift);

    double dR = 0.0;
    double dC = 0.0;
    if (found && rr > 0 && rr + 1 < nShifts && cc > 0 && cc + 1 < nShifts) {
        const double center = out.C[rr + cc*nShifts];
        const double rPrev = out.C[(rr-1) + cc*nShifts];
        const double rNext = out.C[(rr+1) + cc*nShifts];
        const double cPrev = out.C[rr + (cc-1)*nShifts];
        const double cNext = out.C[rr + (cc+1)*nShifts];

        const double ratioR = std::min(1e6, (center-rPrev)/(center-rNext));
        dR = (1.0-ratioR)/(1.0+ratioR)/2.0;
        const double ratioC = std::min(1e6, (center-cPrev)/(center-cNext));
        dC = (1.0-ratioC)/(1.0+ratioC)/2.0;
    }

    out.motion[0] = static_cast<double>(shiftCenterRow) - (shiftR - dR);
    out.motion[1] = static_cast<double>(shiftCenterCol) - (shiftC - dC);
    return out;
}

inline WeightedXcorrResult weightedXcorrDouble(const double* frame,
                                                const double* freshness,
                                                const double* templateIn,
                                                std::size_t nRows,
                                                std::size_t nCols,
                                                long shiftCenterRow,
                                                long shiftCenterCol,
                                                long dShift) {
    return weightedXcorr<double,double,double>(frame,freshness,templateIn,
        nRows,nCols,shiftCenterRow,shiftCenterCol,dShift);
}

} // namespace giant_xcorr

#endif
