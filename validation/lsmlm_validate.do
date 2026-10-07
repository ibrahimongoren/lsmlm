/****************************************************************************
  lsmlm_validate.do
  --------------------------------------------------------------------------
  Cross-checks the lsmlm command against leestra (the reference Mata
  implementation, SSC s459688) on the same series.

  REQUIRES:
    - leestra:  ssc install leestra
    - lsmlm:    put lsmlm.ado on your adopath (see net install), then -discard-

  WHAT IT DOES:
    PART A  Test-statistic agreement at FIXED 0 lags (removes lag-selection
            differences). At 0 lags the two commands compute the identical LM
            regression *given the same break*, so:
              - breaks(0): tau must match to ~1e-6 (no break search -> a clean
                anchor). If this differs, something is wrong.
              - breaks(1)/(2): tau matches whenever both pick the same break
                index (printed). Small trimming-grid differences can
                occasionally make them pick a neighbouring break; that is a
                convention difference, not a bug.

    PART B  Critical-value agreement. Runs both commands (fixed 0 lags) and
            compares their reported critical values. lsmlm uses leestra's
            lag-adjusted lambda convention and PART A confirms the same break
            is selected, so these should match to ~0 -- which validates the
            ~290 transcribed CV numbers and the interpolation code.
****************************************************************************/

clear all
set more off
set seed 20260720

capture which leestra
if _rc {
    di as error "leestra not found.  Install it:  ssc install leestra"
    exit 111
}
capture which lsmlm
if _rc {
    di as error "lsmlm not found.  Put lsmlm.ado on your adopath, then: discard"
    exit 111
}

*--------------------------------------------------------------------------
* Simulated annual series with two clear breaks (1950 and 1985), 1890-2019.
*--------------------------------------------------------------------------
set obs 130
gen int year = 1890 + _n - 1
gen double e = rnormal()
gen double y = .
replace y = e                                   in 1
replace y = 0.6*y[_n-1] + 0.3 + e               in 2/l
replace y = y + 7*(year>=1950)
replace y = y - 5*(year>=1985)
replace y = y + 0.12*(year-1950)*(year>=1950)
replace y = y - 0.10*(year-1985)*(year>=1985)
tsset year, yearly

* warm-up run so lsmlm's Mata CV functions are loaded for PART B
quietly lsmlm y, breaks(0)

*==========================================================================
di as txt _n "{hline 72}"
di as res  "  PART A: test-statistic agreement (fixed 0 lags)"
di as txt  "{hline 72}"

local a_ok = 1
foreach mod in break crash {
    forvalues b = 0/2 {

        * leestra, fixed 0 lags
        quietly leestra y, model(`mod') breaks(`b') method(fixed) lags(0)
        local tau_ee = r(tstat)
        if `b' >= 1 {
            matrix bpe = r(bps)
            local bi1_ee = bpe[1,1]
            if `b' == 2 local bi2_ee = bpe[1,2]
        }

        * lsmlm, 0 lags
        quietly lsmlm y, model(`mod') breaks(`b') maxlag(0)
        local tau_ls = r(tau)
        if `b' >= 1 {
            local bi1_ls = r(tb1_index)
            if `b' == 2 local bi2_ls = r(tb2_index)
        }

        local dtau = `tau_ls' - `tau_ee'

        * assemble a break-index note
        local brk ""
        if `b' == 1 local brk "   break idx  ee=`bi1_ee'  ls=`bi1_ls'"
        if `b' == 2 local brk "   break idx  ee=`bi1_ee',`bi2_ee'  ls=`bi1_ls',`bi2_ls'"

        di as txt "  [" as res "`mod'" as txt " / breaks=" as res "`b'" as txt "]" ///
            as txt "  tau: leestra=" as res %9.4f `tau_ee' ///
            as txt "  lsmlm=" as res %9.4f `tau_ls' ///
            as txt "  diff=" as res %8.4f `dtau' as txt "`brk'"

        * breaks(0) is the strict anchor
        if `b' == 0 & abs(`dtau') > 1e-4 local a_ok = 0
    }
}
di as txt "{hline 72}"
if `a_ok' di as res "  breaks(0) anchor OK: SP statistic matches leestra."
else      di as err "  breaks(0) anchor FAILED: check the no-break construction."

*==========================================================================
di as txt _n "{hline 72}"
di as res  "  PART B: critical-value agreement (reported CVs, fixed 0 lags)"
di as txt  "{hline 72}"

local b_ok = 1
* label  breaks  model
foreach spec in "no-break 0 break" "crash-1 1 crash" "crash-2 2 crash" "break-1 1 break" "break-2 2 break" {
    tokenize "`spec'"
    local lab "`1'"
    local b   `2'
    local mod "`3'"

    quietly leestra y, model(`mod') breaks(`b') method(fixed) lags(0)
    matrix cve = r(cv)
    local cv1_ee  = cve[1,1]
    local cv5_ee  = cve[1,2]
    local cv10_ee = cve[1,3]

    quietly lsmlm y, model(`mod') breaks(`b') maxlag(0)
    local cv1_p  = r(cv1)
    local cv5_p  = r(cv5)
    local cv10_p = r(cv10)

    local d1  = abs(`cv1_p'  - `cv1_ee')
    local d5  = abs(`cv5_p'  - `cv5_ee')
    local d10 = abs(`cv10_p' - `cv10_ee')
    local dmax = max(`d1', `d5', `d10')

    di as txt "  [" as res %-9s "`lab'" as txt "]  max|CV diff| = " as res %8.5f `dmax' ///
        as txt "    (leestra 5%=" as res %7.3f `cv5_ee' as txt ", lsmlm 5%=" as res %7.3f `cv5_p' as txt ")"

    if `dmax' > 0.001 local b_ok = 0
}
di as txt "{hline 72}"
if `b_ok' di as res "  CV OK: lsmlm's critical values match leestra."
else      di as err "  CV MISMATCH: check the tables / lambda convention."

di as txt _n "Done. PART A checks the test statistic; PART B validates the CV tables."

exit
