/*****************************************************************************
  lsmlm_turkey_analysis.do
  ---------------------------------------------------------------------------
  Applies the -lsmlm- command (Lee-Strazicich minimum LM unit root test with
  structural breaks) to Turkish monthly macro data, 2004m1-2021m9, taken from
  the workbook data_TimeSeries.xlsx, sheet "Analiz_Veri":

      inflation   CPI inflation, y/y % change      (TUIK,  EVDS TP.FG.J0_3)
      rate        Deposit rate, <=3m TL deposits, % (TCMB,  EVDS TP.TRY.MT02)
      exr         USD/TRY exchange rate, selling    (TCMB,  EVDS TP.DK.USD.S.YTL)

  The workbook's other two sheets ("Sayfa1", a scratch quantile sheet, and
  "EVDS", the raw source pull with series metadata) are not used here; only
  "Analiz_Veri" is imported.

  MODELLING CHOICE - READ BEFORE INTERPRETING RESULTS
  ----------------------------------------------------
  The exchange rate is tested in LOGS (log_exr = ln(exr)): this is the
  standard convention for nominal exchange-rate unit-root work (e.g. PPP
  tests), since it treats proportional moves symmetrically. inflation and
  rate are tested as given, since rate/percentage variables are conventionally
  tested in levels, not logs. Edit VARLIST below to test raw exr instead, or
  to add other series (e.g. a Fisher-approximation real rate = rate -
  inflation would be a natural, cheap extension - not included by default
  since it is a derived series, not one of the variables actually in the
  workbook).

  WHAT THIS FILE PRODUCES
  ------------------------
    Section 1  Setup, import, date parsing, data check
    Section 2  Descriptive statistics + a 3-panel overview figure
    Section 3  Single-variable walkthrough (inflation): every model variant
    Section 4  TABLE 1  two-break LM test (main specification), all variables
    Section 5  TABLE 2  one-break LM test (robustness), all variables
    Section 6  Piecewise trend models at the estimated breaks
    Section 7  Figures: one standalone aesthetic PNG per variable + 1 summary
    Section 8  Excel workbook with every table

  REQUIREMENTS
  ------------
    - lsmlm installed:  net install lsmlm, from("<your lsmlm folder>")
    - Your own copy of data_TimeSeries.xlsx - EDIT THE PATH in Section 1

  RUN TIME
  --------
  T=213 monthly observations gives a much larger break-date search grid than
  annual data of similar span. With the FULL settings below (maxlag 12, trim
  0.10), the two-break search has on the order of 10,000 candidate break-date
  pairs PER VARIABLE, so expect several minutes per variable. Start with
  QUICK=1 (fast, coarse settings) to confirm the whole file runs end to end
  before committing to the full search.
*****************************************************************************/

clear all
set more off
set linesize 120

*============================================================================
* SECTION 1  SETUP, IMPORT, AND DATA CHECK
*============================================================================

*--- USER SETTINGS: EDIT THESE -----------------------------------------------
* Path to your own copy of the uploaded workbook:
global XLSX "data_TimeSeries.xlsx"

* Where to write results (created automatically if it does not exist):
global OUT  "turkey_results"

* QUICK = 1 : fast, coarse settings - use this first to smoke-test the file
* QUICK = 0 : full analysis (recommended settings for monthly macro data)
local QUICK = 1

* Variables to test (see the modelling-choice note above).
local VARLIST "inflation rate log_exr"

* Full-run econometric settings
local MAXLAG   12     // ~1 year of monthly augmenting lags
local MINDIST  24     // the two breaks must be >= 24 months apart
local TRIM     0.10   // trim 10% of the sample at each end of the search

* The Section 3 sub-sample demo has fewer observations, so use fewer lags.
local MAXLAG_SUB 6
*----------------------------------------------------------------------------

if `QUICK' {
    local MAXLAG     3
    local TRIM       0.20
    local MINDIST    24
    local MAXLAG_SUB 3
    di as txt _n "*** QUICK MODE: fast, coarse settings for a smoke test. Set QUICK = 0 for the full run. ***"
}

capture mkdir "$OUT"
capture mkdir "$OUT/figs"

capture which lsmlm
if _rc {
    di as error "lsmlm not found. Install it first, e.g.:"
    di as error `"    net install lsmlm, from("D:/lsmlm")"'
    exit 111
}

capture import excel using "$XLSX", sheet("Analiz_Veri") firstrow clear case(preserve)
if _rc {
    di as error "Could not import the workbook. Please check:"
    di as error "  1) Does this path exist:  $XLSX"
    di as error "  2) Is the file currently open in Excel? Close it and retry."
    di as error `"  3) Does it contain a sheet named "Analiz_Veri"?"'
    exit 601
}

quietly drop if missing(Date)

capture confirm variable Date inflation rate exr
if _rc {
    di as error "The imported sheet does not have the expected columns"
    di as error "(Date, inflation, rate, exr). Here is what was found instead:"
    describe
    exit 601
}

* Parse "YYYY-MM" text into a proper Stata monthly date, then verify the
* parse against the original string (robust to any future date range, since
* nothing here is hardcoded to today's specific sample).
gen long ym = monthly(Date, "YM")
format ym %tm
sort ym

di as txt "Verifying date parsing (parsed ym vs the original Date text)..."
gen int _yr_check = real(substr(Date,1,4))
gen int _mo_check = real(substr(Date,6,2))
assert _yr_check == year(dofm(ym))
assert _mo_check == month(dofm(ym))
drop _yr_check _mo_check
di as txt "  OK."

tsset ym, monthly

gen double log_exr = ln(exr)

label var inflation "CPI inflation, y/y % (TUIK)"
label var rate      "Deposit rate, <=3m maturity, % (TCMB)"
label var exr       "USD/TRY exchange rate, selling (TCMB)"
label var log_exr   "Log USD/TRY exchange rate"

di as txt _n "{hline 78}"
di as res  "  DATA: Turkey, monthly, 2004m1-2021m9 (TCMB / TUIK via EVDS)"
di as txt  "{hline 78}"
describe inflation rate exr log_exr

* Log the session
capture log close _all
log using "$OUT/lsmlm_turkey_analysis.log", replace text name(main)

timer clear 1
timer on 1

*============================================================================
* SECTION 2  DESCRIPTIVE STATISTICS
*============================================================================

di as txt _n "{hline 78}"
di as res  "  SECTION 2: Descriptive statistics"
di as txt  "{hline 78}"

tabstat inflation rate exr log_exr, stat(n mean sd min max) columns(statistics) format(%9.3f)

di as txt _n "Correlation matrix:"
correlate inflation rate log_exr

*--- Figure 0: a quick 3-panel overview of the raw series (context only) ----
set graphics off

local xtlo = tm(2004m1)
local xthi = tm(2020m1)

twoway (line inflation ym, lcolor("26 82 118") lwidth(medthick)) ///
    , ytitle("y/y %", size(small)) xtitle("") ///
      xlabel(`xtlo'(24)`xthi', format(%tmCCYY) labsize(small)) ///
      ylabel(, angle(0) labsize(small) grid glcolor(gs15) glwidth(vthin)) ///
      title("CPI inflation", size(medsmall) justification(left)) ///
      graphregion(color(white) lcolor(white)) plotregion(lcolor(none)) ///
      name(gp_inf, replace)

twoway (line rate ym, lcolor("176 58 46") lwidth(medthick)) ///
    , ytitle("%", size(small)) xtitle("") ///
      xlabel(`xtlo'(24)`xthi', format(%tmCCYY) labsize(small)) ///
      ylabel(, angle(0) labsize(small) grid glcolor(gs15) glwidth(vthin)) ///
      title("Deposit rate (<=3m)", size(medsmall) justification(left)) ///
      graphregion(color(white) lcolor(white)) plotregion(lcolor(none)) ///
      name(gp_rate, replace)

twoway (line exr ym, lcolor("52 118 52") lwidth(medthick)) ///
    , ytitle("level", size(small)) xtitle("") ///
      xlabel(`xtlo'(24)`xthi', format(%tmCCYY) labsize(small)) ///
      ylabel(, angle(0) labsize(small) grid glcolor(gs15) glwidth(vthin)) ///
      title("USD/TRY exchange rate", size(medsmall) justification(left)) ///
      graphregion(color(white) lcolor(white)) plotregion(lcolor(none)) ///
      name(gp_exr, replace)

graph combine gp_inf gp_rate gp_exr, cols(1) ///
    graphregion(color(white)) ysize(9) xsize(7) ///
    title("Turkey: macro series overview, 2004-2021", size(medium))
graph export "$OUT/figs/fig0_overview.png", replace width(1800)
graph drop gp_inf gp_rate gp_exr

set graphics on
di as txt "  saved: figs/fig0_overview.png"

*============================================================================
* SECTION 3  SINGLE-VARIABLE WALKTHROUGH (inflation)
*============================================================================

di as txt _n "{hline 78}"
di as res  "  SECTION 3: Single-variable walkthrough (inflation)"
di as txt  "{hline 78}"

di as txt _n ">>> (a) No break: Schmidt-Phillips LM test"
lsmlm inflation, breaks(0) maxlag(`MAXLAG')

di as txt _n ">>> (b) One break, crash model (level shift)"
lsmlm inflation, breaks(1) model(crash) maxlag(`MAXLAG') trim(`TRIM')

di as txt _n ">>> (c) One break, trend-break model (level + trend shift)"
lsmlm inflation, breaks(1) model(break) maxlag(`MAXLAG') trim(`TRIM')

di as txt _n ">>> (d) Two breaks, trend-break model  [the main specification]"
lsmlm inflation, breaks(2) model(break) maxlag(`MAXLAG') mindist(`MINDIST') trim(`TRIM')

di as txt _n ">>> Stored results from the last run:"
di as txt "   tau       = " as res r(tau)
di as txt "   lags (k)  = " as res r(k)
di as txt "   break 1   = " as res %tm r(tb1) as txt "   lambda1 = " as res r(lambda1)
di as txt "   break 2   = " as res %tm r(tb2) as txt "   lambda2 = " as res r(lambda2)
di as txt "   5% CV     = " as res r(cv5)
di as txt "   decision  = " as res "`r(siglevel)'"

di as txt _n ">>> (e) Pre-2018-crisis sub-sample only, via if"
lsmlm inflation if ym < tm(2018m8), breaks(1) model(break) maxlag(`MAXLAG_SUB') trim(`TRIM')

*============================================================================
* SECTION 4  TABLE 1 - TWO-BREAK LM TEST (MAIN SPECIFICATION)
*============================================================================

di as txt _n "{hline 78}"
di as res  "  SECTION 4: TABLE 1 - two-break LM test, all variables"
di as txt  "{hline 78}"

tempname P1
postfile `P1' str12 variable int N byte k int tb1 int tb2 ///
    double lambda1 double lambda2 double tau ///
    double cv1 double cv5 double cv10 ///
    byte rej1 byte rej5 byte rej10 byte b1sig byte b2sig ///
    using "$OUT/table1_two_break.dta", replace

foreach v of local VARLIST {
    di as txt "  running: " as res "`v'" _continue
    capture quietly lsmlm `v', breaks(2) model(break) ///
        maxlag(`MAXLAG') mindist(`MINDIST') trim(`TRIM')
    local rc = _rc
    if `rc' == 0 {
        post `P1' ("`v'") (r(N)) (r(k)) (r(tb1)) (r(tb2)) ///
            (r(lambda1)) (r(lambda2)) (r(tau)) ///
            (r(cv1)) (r(cv5)) (r(cv10)) ///
            (r(reject1)) (r(reject5)) (r(reject10)) (r(break1_sig10)) (r(break2_sig10))
        di as txt "  done"
    }
    else {
        di as err "  FAILED (rc=`rc')"
        post `P1' ("`v'") (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.)
    }
}
postclose `P1'

preserve
    use "$OUT/table1_two_break.dta", clear
    gen str30 decision = cond(rej10==1, "unit root rejected", "unit root NOT rejected")
    gen str8  sig = cond(rej1==1,"1%", cond(rej5==1,"5%", cond(rej10==1,"10%","ns")))
    format tb1 tb2 %tm
    format lambda1 lambda2 tau cv1 cv5 cv10 %8.3f
    save "$OUT/table1_two_break.dta", replace

    di as txt _n "TABLE 1: Two-break minimum LM unit root test, Turkey 2004m1-2021m9"
    list variable N k tb1 tb2 tau cv5 sig decision, noobs abbrev(14) sep(0)
restore

*============================================================================
* SECTION 5  TABLE 2 - ONE-BREAK LM TEST (ROBUSTNESS)
*============================================================================

di as txt _n "{hline 78}"
di as res  "  SECTION 5: TABLE 2 - one-break LM test, all variables"
di as txt  "{hline 78}"

tempname P2
postfile `P2' str12 variable int N byte k int tb1 double lambda1 double tau ///
    double cv1 double cv5 double cv10 byte rej1 byte rej5 byte rej10 byte b1sig ///
    using "$OUT/table2_one_break.dta", replace

foreach v of local VARLIST {
    di as txt "  running: " as res "`v'" _continue
    capture quietly lsmlm `v', breaks(1) model(break) maxlag(`MAXLAG') trim(`TRIM')
    local rc = _rc
    if `rc' == 0 {
        post `P2' ("`v'") (r(N)) (r(k)) (r(tb1)) (r(lambda1)) (r(tau)) ///
            (r(cv1)) (r(cv5)) (r(cv10)) ///
            (r(reject1)) (r(reject5)) (r(reject10)) (r(break1_sig10))
        di as txt "  done"
    }
    else {
        di as err "  FAILED (rc=`rc')"
        post `P2' ("`v'") (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.)
    }
}
postclose `P2'

preserve
    use "$OUT/table2_one_break.dta", clear
    gen str30 decision = cond(rej10==1, "unit root rejected", "unit root NOT rejected")
    gen str8  sig = cond(rej1==1,"1%", cond(rej5==1,"5%", cond(rej10==1,"10%","ns")))
    format tb1 %tm
    format lambda1 tau cv1 cv5 cv10 %8.3f
    save "$OUT/table2_one_break.dta", replace

    di as txt _n "TABLE 2: One-break minimum LM unit root test, Turkey 2004m1-2021m9"
    list variable N k tb1 tau cv5 sig decision, noobs abbrev(14) sep(0)
restore

*============================================================================
* SECTION 6  PIECEWISE TREND MODELS AT THE ESTIMATED BREAKS
*----------------------------------------------------------------------------
* Once the break dates are known (Table 1), fit a deterministic trend model
* with level and slope shifts at those dates to describe HOW the series moved.
*     y_t = a + b*t + d1*D1 + d2*D2 + g1*T1 + g2*T2 + e_t
*============================================================================

di as txt _n "{hline 78}"
di as res  "  SECTION 6: Piecewise trend models at the Table 1 breaks"
di as txt  "{hline 78}"

tempname P3
postfile `P3' str12 variable int tb1 int tb2 ///
    double b_t double b_D1 double b_T1 double b_D2 double b_T2 ///
    double r2 int N ///
    using "$OUT/piecewise_trends.dta", replace

foreach v of local VARLIST {
    local bk1 = .
    local bk2 = .

    preserve
        quietly use "$OUT/table1_two_break.dta", clear
        quietly keep if variable == "`v'"
        if _N > 0 {
            local bk1 = tb1[1]
            local bk2 = tb2[1]
        }
    restore

    if missing(`bk1') | missing(`bk2') {
        di as err "  `v': no break dates in Table 1, skipped"
        continue
    }

    tempvar t D1 T1 D2 T2
    quietly gen double `t'  = _n
    quietly gen double `D1' = (ym >  `bk1')
    quietly gen double `T1' = (ym - `bk1') * (ym > `bk1')
    quietly gen double `D2' = (ym >  `bk2')
    quietly gen double `T2' = (ym - `bk2') * (ym > `bk2')

    capture quietly regress `v' `t' `D1' `T1' `D2' `T2'
    if _rc == 0 {
        post `P3' ("`v'") (`bk1') (`bk2') ///
            (_b[`t']) (_b[`D1']) (_b[`T1']) (_b[`D2']) (_b[`T2']) (e(r2)) (e(N))
        di as txt "  `v': R2 = " as res %5.3f e(r2)
    }
    else di as err "  `v': regression failed"
}
postclose `P3'

preserve
    use "$OUT/piecewise_trends.dta", clear
    format tb1 tb2 %tm
    format b_* %9.5f
    format r2 %6.3f
    di as txt _n "Piecewise trend models (breaks taken from Table 1)"
    list variable tb1 tb2 b_t b_D1 b_T1 b_D2 b_T2 r2, noobs abbrev(10) sep(0)
restore

*============================================================================
* SECTION 7  FIGURES
*----------------------------------------------------------------------------
* One standalone, aesthetic PNG per variable, written to $OUT/figs/, plus one
* summary chart comparing all variables. Each per-variable figure shows:
*     - the observed series
*     - the fitted piecewise trend from Section 6
*     - vertical line(s) at the estimated break date(s)
*     - light shaded bands for well-known reference episodes (context only,
*       NOT statistically estimated): the 2008-09 global financial crisis,
*       the 2018 TRY currency crisis, and the COVID-19 period
*     - the test result (tau, 5% critical value, decision) in the subtitle
*============================================================================

di as txt _n "{hline 78}"
di as res  "  SECTION 7: Figures"
di as txt  "{hline 78}"

set graphics off

local C_DATA "26 82 118"
local C_FIT  "176 58 46"
local C_BRK  "176 58 46"

local xtlo = tm(2004m1)
local xthi = tm(2020m1)

* well-known reference episodes (context only - NOT statistically estimated)
local gfc_lo    = tm(2008m9)
local gfc_hi    = tm(2009m6)
local crisis_lo = tm(2018m6)
local crisis_hi = tm(2018m9)
local covid_lo  = tm(2020m3)
local covid_hi  = tm(2021m9)

foreach v of local VARLIST {
    local bk1  = .
    local bk2  = .
    local tauv = .
    local cv5v = .
    local decv = ""

    preserve
        quietly use "$OUT/table1_two_break.dta", clear
        quietly keep if variable == "`v'"
        if _N > 0 {
            local bk1  = tb1[1]
            local bk2  = tb2[1]
            local tauv = tau[1]
            local cv5v = cv5[1]
            local decv = cond(rej10[1]==1, "unit root rejected", "unit root not rejected")
        }
    restore

    if missing(`bk1') {
        di as err "  `v': no break dates, figure skipped"
        continue
    }

    local vlabel : variable label `v'
    local taufmt = string(`tauv', "%6.3f")
    local cvfmt  = string(`cv5v', "%6.3f")

    local bk1txt = string(`bk1', "%tm")
    local brklab "`bk1txt'"
    if !missing(`bk2') {
        local bk2txt = string(`bk2', "%tm")
        local brklab "`brklab' and `bk2txt'"
    }

    preserve
        tempvar t D1 T1 D2 T2 yhat top bot
        quietly gen double `t'  = _n
        quietly gen double `D1' = (ym >  `bk1')
        quietly gen double `T1' = (ym - `bk1') * (ym > `bk1')
        quietly gen double `D2' = (ym >  `bk2')
        quietly gen double `T2' = (ym - `bk2') * (ym > `bk2')

        local fitline ""
        local leg legend(off)
        capture quietly regress `v' `t' `D1' `T1' `D2' `T2'
        if _rc == 0 {
            quietly predict double `yhat', xb
            local fitline (line `yhat' ym, lcolor("`C_FIT'") lwidth(medthick) lpattern(dash))
            local leg legend(order(2 "Observed" 3 "Piecewise trend at estimated breaks") rows(1) size(vsmall) position(6))
        }

        quietly summarize `v'
        local ymin = r(min)
        local ymax = r(max)
        local pad  = 0.06*(`ymax'-`ymin')
        local ytop = `ymax' + `pad'
        local ybot = `ymin' - `pad'

        quietly gen double `top' = `ytop' if inrange(ym,`gfc_lo',`gfc_hi') ///
            | inrange(ym,`crisis_lo',`crisis_hi') | inrange(ym,`covid_lo',`covid_hi')
        quietly gen double `bot' = `ybot' if !missing(`top')

        local xlines "`bk1'"
        if !missing(`bk2') local xlines "`xlines' `bk2'"

        twoway (rarea `top' `bot' ym, color(gs12%40) lwidth(none)) ///
               (line `v' ym, lcolor("`C_DATA'") lwidth(medthick)) ///
               `fitline' ///
            , xline(`xlines', lpattern(shortdash) lcolor("`C_BRK'") lwidth(thin)) ///
              title("Turkey: `vlabel'", size(medlarge) color(black) justification(left)) ///
              subtitle("Two-break LM test: {&tau} = `taufmt', 5% critical value = `cvfmt'  -  `decv'", ///
                       size(small) color(gs7) justification(left)) ///
              ytitle("`vlabel'", size(small)) xtitle("") ///
              ylabel(, angle(0) labsize(small) grid glcolor(gs15) glwidth(vthin)) ///
              xlabel(`xtlo'(24)`xthi', format(%tmCCYY) labsize(small)) ///
              note("Vertical line(s): estimated break date(s) (`brklab')." ///
                   "Shaded bands (reference only, not estimated): 2008-09 global financial crisis," ///
                   "2018 TRY currency crisis, and the COVID-19 period. Source: TCMB / TUIK via EVDS.", ///
                   size(vsmall) color(gs9)) ///
              graphregion(color(white) lcolor(white)) ///
              plotregion(lcolor(none)) ///
              `leg' ///
              xsize(8) ysize(5)

        graph export "$OUT/figs/fig_`v'.png", replace width(2400)
        di as txt "  saved: figs/fig_`v'.png"
    restore
}

*--- Summary figure: tau vs 5% critical value, all variables ---------------
preserve
    use "$OUT/table1_two_break.dta", clear
    quietly drop if missing(tau)
    if _N >= 2 {
        graph hbar tau cv5, over(variable) ///
            bar(1, color("26 82 118")) bar(2, color("176 58 46")) ///
            legend(order(1 "{&tau} (test statistic)" 2 "5% critical value") rows(1) size(vsmall) position(6)) ///
            title("Two-break LM test results, Turkey", size(medlarge) color(black) justification(left)) ///
            subtitle("Unit root is rejected when {&tau} lies to the left (more negative) of the 5% critical value", ///
                     size(small) color(gs7) justification(left)) ///
            graphregion(color(white) lcolor(white)) ///
            plotregion(lcolor(none)) ///
            xsize(8) ysize(4)
        graph export "$OUT/figs/fig_summary_test_results.png", replace width(2400)
        di as txt "  saved: figs/fig_summary_test_results.png"
    }
restore

set graphics on
di as txt _n "  All figures written to: " as res "$OUT/figs"

*============================================================================
* SECTION 8  EXCEL WORKBOOK
*============================================================================

di as txt _n "{hline 78}"
di as res  "  SECTION 8: Excel export"
di as txt  "{hline 78}"

local XLSOUT "$OUT/lsmlm_turkey_results.xlsx"

preserve
    use "$OUT/table1_two_break.dta", clear
    export excel using "`XLSOUT'", sheet("Table1_TwoBreak") firstrow(variables) replace
restore
preserve
    use "$OUT/table2_one_break.dta", clear
    export excel using "`XLSOUT'", sheet("Table2_OneBreak") firstrow(variables) sheetmodify
restore
preserve
    use "$OUT/piecewise_trends.dta", clear
    export excel using "`XLSOUT'", sheet("PiecewiseTrends") firstrow(variables) sheetmodify
restore

di as txt "  saved: `XLSOUT'"

timer off 1
quietly timer list 1
di as txt _n "{hline 78}"
di as res  "  FINISHED"
di as txt  "{hline 78}"
di as txt "  Elapsed time: " as res %8.1f r(t1) as txt " seconds"
di as txt "  Output folder: " as res "$OUT"
if `QUICK' {
    di as txt _n as err "  NOTE: this was a QUICK run (coarse settings, for a smoke test only)."
    di as err  "        Set  local QUICK = 0  near the top for the full analysis."
}

log close main

exit
