#ifndef GIANT_XCORR2_NANS_WEIGHTED_CORE_HPP
#define GIANT_XCORR2_NANS_WEIGHTED_CORE_HPP

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <limits>
#include <stdexcept>
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

inline std::vector<double> circshift2d(const double* src,
                                       std::size_t nRows,
                                       std::size_t nCols,
                                       long shiftRow,
                                       long shiftCol) {
    std::vector<double> dst(nRows * nCols);
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

struct FiniteFramePixel {
    long row;
    long col;
    double value;
    double freshness;
};

inline WeightedXcorrResult weightedXcorrDouble(const double* frame,
                                                const double* freshness,
                                                const double* templateIn,
                                                std::size_t nRows,
                                                std::size_t nCols,
                                                long shiftCenterRow,
                                                long shiftCenterCol,
                                                long dShift) {
    if (!frame || !freshness || !templateIn) {
        throw std::invalid_argument("Null input pointer.");
    }
    if (nRows == 0 || nCols == 0) {
        throw std::invalid_argument("Input images must be non-empty.");
    }
    if (dShift < 0) {
        throw std::invalid_argument("dShift must be nonnegative.");
    }

    const double* templ = templateIn;
    std::vector<double> shiftedTemplate;
    if (shiftCenterRow != 0 || shiftCenterCol != 0) {
        shiftedTemplate = circshift2d(templateIn,nRows,nCols,shiftCenterRow,shiftCenterCol);
        templ = shiftedTemplate.data();
    }

    // Mirror the legacy MATLAB implementation's FIND(~isnan(frame)) once per
    // correlation call. MATLAB FIND returns column-major order; scanning
    // columns then rows preserves that reduction order while avoiding all
    // per-candidate coordinate/sub2ind allocations. This is especially useful
    // for sparse SLAP2 multi-ROI raster images.
    std::vector<FiniteFramePixel> finiteFrame;
    finiteFrame.reserve(nRows*nCols);
    for (std::size_t c = 0; c < nCols; ++c) {
        for (std::size_t r = 0; r < nRows; ++r) {
            const std::size_t idx = matlabIndex(r,c,nRows);
            const double F = frame[idx];
            if (std::isnan(F)) continue;
            finiteFrame.push_back(FiniteFramePixel{
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

    for (long dcix = 0; dcix < nShiftsLong; ++dcix) {
        const long dc = dcix - dShift;
        for (long drix = 0; drix < nShiftsLong; ++drix) {
            const long dr = drix - dShift;

            // First pass: exact legacy inclusion criterion and unweighted means.
            double sumF = 0.0;
            double sumT = 0.0;
            std::size_t count = 0;
            for (const FiniteFramePixel& px : finiteFrame) {
                const long tr = px.row + dr;
                const long tc = px.col + dc;
                if (tr < 0 || tr >= nr || tc < 0 || tc >= nc) continue;
                const double T = templ[matlabIndex(
                    static_cast<std::size_t>(tr),static_cast<std::size_t>(tc),nRows)];
                if (std::isnan(T)) continue;
                sumF += px.value;
                sumT += T;
                ++count;
            }
            if (count == 0) continue;

            const double mF = sumF / static_cast<double>(count);
            const double mT = sumT / static_cast<double>(count);

            // Second pass: same freshness-weighted covariance/frame variance
            // and unweighted template variance as xcorr2_nans_weighted.m.
            double sFT = 0.0;
            double sumT2 = 0.0;
            double sF = 0.0;
            double sumW = 0.0;
            for (const FiniteFramePixel& px : finiteFrame) {
                const long tr = px.row + dr;
                const long tc = px.col + dc;
                if (tr < 0 || tr >= nr || tc < 0 || tc >= nc) continue;
                const double T = templ[matlabIndex(
                    static_cast<std::size_t>(tr),static_cast<std::size_t>(tc),nRows)];
                if (std::isnan(T)) continue;
                const double dF = px.value - mF;
                const double dT = T - mT;
                const double w = px.freshness;
                sFT += w * dF * dT;
                sumT2 += dT * dT;
                sF += w * dF * dF;
                sumW += w;
            }

            const double sT = sumT2 / static_cast<double>(count);
            out.C[static_cast<std::size_t>(drix) + static_cast<std::size_t>(dcix)*nShifts] =
                sFT / std::sqrt(sT * sF * sumW);
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
} // namespace giant_xcorr

#endif
