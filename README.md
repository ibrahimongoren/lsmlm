# lsmlm

**Lee–Strazicich minimum LM unit root test with structural breaks, for Stata.**

`lsmlm` tests the null of a unit root against trend-stationarity while estimating zero, one, or two break dates endogenously. Breaks are allowed under the null, so a rejection is not an artefact of ignored breaks.

| | |
|---|---|
| Version | 1.1.0 |
| Requires | Stata 14.0 or later |
| Author | İbrahim Öngören, Department of Economics, Pamukkale University |
| Contact | ongorenibrahim78@gmail.com |
| Licence | MIT (see [LICENSE](LICENSE)) |
| SSC package | [ideas.repec.org/c/boc/bocode/s459809](https://ideas.repec.org/c/boc/bocode/s459809.html) |
| Author profile | [Google Scholar](https://scholar.google.com/citations?view_op=view_citation&hl=tr&user=wWKAVe4AAAAJ&citation_for_view=wWKAVe4AAAAJ:u-x6o8ySG0sC) |

---

## Contents

1. [What the command does](#1-what-the-command-does)
2. [Installation](#2-installation)
3. [Quick start](#3-quick-start)
4. [Syntax and options](#4-syntax-and-options)
5. [Reading the output](#5-reading-the-output)
6. [Stored results](#6-stored-results)
7. [Common workflows](#7-common-workflows)
8. [Method notes](#8-method-notes)
9. [Validation](#9-validation)
10. [Limitations](#10-limitations)
11. [Troubleshooting](#11-troubleshooting)
12. [Repository layout](#12-repository-layout)
13. [Citation and references](#13-citation-and-references)

---

## 1. What the command does

| `breaks()` | `model()` | Test |
|---|---|---|
| `0` | (ignored) | Schmidt–Phillips LM test, no break |
| `1` or `2` | `crash` | Level shift at each break (Lee–Strazicich Model A) |
| `1` or `2` | `break` | Level **and** trend shift at each break (Model C) |

For every candidate break date (or pair of dates) the command builds the LM-detrended series, runs the augmented test regression, and selects the break location(s) that **minimise** the t-statistic on `S(t-1)`. That minimum is the test statistic, compared with Lee–Strazicich critical values interpolated by sample size and, for the trend-break model, by break fraction.

The command works on **one time series** at a time, on any frequency, and on any sub-sample you select with `if` / `in`.

---

## 2. Installation

### From SSC (recommended)

```stata
ssc install lsmlm, replace
```

The package page is at [RePEc / SSC (S459809)](https://ideas.repec.org/c/boc/bocode/s459809.html).

### From GitHub

```stata
net install lsmlm, from("https://raw.githubusercontent.com/ibrahimongoren/lsmlm/main/") replace
```

Replace `ibrahimongoren` with the account that hosts the repository. To update later, run the same line again.

### Manually

Copy `lsmlm.ado` and `lsmlm.sthlp` into your PERSONAL ado folder (type `personal` in Stata to see where it is), then run:

```stata
discard
which lsmlm
help lsmlm
```

### Check the installation

```stata
which lsmlm
help lsmlm
```

---

## 3. Quick start

The repository ships a small example dataset, `lsmlm_oecd15.dta`: log relative per-capita income for 15 OECD countries, 1870–1994 (see [Example data](#example-data)).

```stata
sysuse lsmlm_oecd15, clear
keep if country == "France"
tsset year, yearly

lsmlm y, breaks(2) maxlag(2) mindist(5)
```

Output from this call:

```
Lee-Strazicich minimum LM unit root test

Series:        y
Model:         trend break (level + trend shift)
Breaks:        2   (endogenously selected)
Max lag:       2    Lags chosen (GTOS): 1
Obs (regr.):   123
Sample:        1870 to 1994
Break 1:       1939   (lambda1 = 0.545)
Break 2:       1947   (lambda2 = 0.610)

Test statistic (t on S(t-1)):    -7.2219
Critical values:   1% -6.108    5% -5.418    10% -5.162
Decision:      Reject unit root at 1%

Break significance (t on dummies >= 1.645):
  Break 1:     significant
  Break 2:     significant
```

`maxlag(2)` keeps this illustration fast. For annual data you would typically allow more lags (the bundled application uses `maxlag(8)`).

### Example data

`lsmlm_oecd15.dta` is derived from the **Maddison Project Database 2023** (Bolt and van Zanden), licensed CC BY 4.0. The variable `y` is log(country GDP per capita / yearly OECD15 mean). Variables: `cid`, `countrycode`, `country`, `year`, `gdppc`, `rel_gdppc`, `y`.

---

## 4. Syntax and options

```stata
lsmlm varname [if] [in] [, breaks(#) model(string) maxlag(#) trim(#) mindist(#) timevar(varname) noprint]
```

`varname` must be numeric. The data must be `tsset`, or you must supply `timevar()`.

| Option | Meaning | Default |
|---|---|---|
| `breaks(#)` | Number of breaks: `0`, `1` or `2` | `2` |
| `model(string)` | `break` (level + trend shift) or `crash` (level shift). Ignored when `breaks(0)` | `break` |
| `maxlag(#)` | Maximum number of augmenting lags for the general-to-specific search | `floor(4*(T/100)^0.25)`, at least 1 |
| `trim(#)` | Fraction of the sample trimmed at each end of the break search, in (0, 0.5) | `0.10` |
| `mindist(#)` | Minimum number of observations between the two breaks (two-break case only) | `2` |
| `timevar(varname)` | Time variable to use if the data are not `tsset` | the `tsset` variable |
| `noprint` | Suppress the results table; results remain in `r()` | off |

**Lag selection.** Starting from `maxlag()`, the command drops the highest lag whenever its |t| is below 1.645, and stops at the first lag that is significant (general-to-specific). The chosen lag count is reported as `Lags chosen (GTOS)`.

**Choosing `mindist()` and `trim()` for your frequency.** The defaults suit short annual samples. For monthly data, a larger `mindist()` (for example 24) avoids two breaks falling a few months apart, and `trim()` controls how close to the sample ends a break may be.

---

## 5. Reading the output

**Decision rule.** Reject the unit-root null when the test statistic is **less than or equal to** the critical value (more negative). Example: `-7.22 <= -5.42` rejects at 5%.

**Break dates.** `Break 1`/`Break 2` are shown in the format of your time variable. `lambda` is the break fraction used to look up the critical values.

**Break significance.** The last block reports whether the break dummies are individually relevant (|t| ≥ 1.645). It is informative, not part of the formal test. If the breaks are not significant, the one-break or no-break variants may be more appropriate.

**A caution about the critical values.** In the trend-break model the critical values depend on where the breaks fall, which is why the table reports `lambda`. In the crash model they depend only on the sample size.

---

## 6. Stored results

`lsmlm` is r-class. Break-specific results exist only for the corresponding number of breaks, and the trend-dummy t-statistics exist only for `model(break)`.

**Scalars**

| Result | Description |
|---|---|
| `r(tau)` | Test statistic (minimum t on `S(t-1)`) |
| `r(k)` | Number of augmenting lags chosen |
| `r(breaks)` | Number of breaks |
| `r(N)` | Observations in the final regression |
| `r(maxlag)`, `r(trim)` | Settings used |
| `r(cv1)`, `r(cv5)`, `r(cv10)` | 1%, 5%, 10% critical values |
| `r(reject1)`, `r(reject5)`, `r(reject10)` | 1/0 rejection indicators |
| `r(tb1)`, `r(tb1_index)`, `r(lambda1)` | First break: date, observation index, fraction |
| `r(break1_sig10)`, `r(tB1)`, `r(tD1)` | First-break relevance and dummy t-statistics |
| `r(mindist)` | Minimum break distance (two-break case) |
| `r(tb2)`, `r(tb2_index)`, `r(lambda2)` | Second break |
| `r(break2_sig10)`, `r(tB2)`, `r(tD2)` | Second-break relevance and dummy t-statistics |

**Macros**

| Result | Description |
|---|---|
| `r(siglevel)` | `1%`, `5%`, `10%` or `Not significant` |
| `r(model)` | Deterministic model |
| `r(timevar)` | Time variable used |
| `r(varname)` | Series tested |

---

## 7. Common workflows

### One series, several specifications

```stata
tsset year, yearly
lsmlm y, breaks(0)                    // no break
lsmlm y, breaks(1) model(crash)       // one level shift
lsmlm y, breaks(1) model(break)       // one level + trend shift
lsmlm y, breaks(2) model(break) mindist(5)
```

### Restrict the sample

```stata
lsmlm y if year >= 1946, breaks(1) maxlag(4)
lsmlm y if inrange(year, 1870, 1945), breaks(2) maxlag(4) mindist(5)
```

### Use the returned values

```stata
quietly lsmlm y, breaks(2) mindist(5)
display "tau = " r(tau)
display "breaks: " r(tb1) " and " r(tb2)
display "5% CV = " r(cv5)
display "decision: " r(siglevel)
```

### Monthly data

Break dates are returned as Stata monthly dates. Format them for display:

```stata
tsset ym, monthly
quietly lsmlm inflation, breaks(2) mindist(24) maxlag(12)
display %tm r(tb1)
display %tm r(tb2)
```

### Panel: one call per unit

`lsmlm` tests a single series, so loop over panel units and collect the results:

```stata
xtset id year
tempname P
postfile `P' int id int tb1 int tb2 double tau double cv5 byte rej10 using results.dta, replace

levelsof id, local(ids)
foreach i of local ids {
    preserve
        keep if id == `i'
        tsset year
        capture quietly lsmlm y, breaks(2) maxlag(8) mindist(5)
        if _rc == 0 post `P' (`i') (r(tb1)) (r(tb2)) (r(tau)) (r(cv5)) (r(reject10))
    restore
}
postclose `P'
```

A complete worked application on the shipped data (descriptives, three tables, piecewise trend models, one figure per country, Excel export) is in [`examples/lsmlm_oecd15_analysis.do`](examples/lsmlm_oecd15_analysis.do).

---

## 8. Method notes

1. **Detrending.** For a candidate break set, `D.y` is regressed on the differenced deterministic terms to estimate their coefficients. The detrended series `S(t)` is then built with `S(1) = 0`.
2. **Test regression.** `D.y` is regressed on the differenced deterministic terms, `S(t-1)` and lagged `D.S` terms. The unit-root test statistic is the t-statistic on `S(t-1)`.
3. **Break selection.** All admissible break dates (or pairs) in the trimmed window are evaluated, and the minimum statistic is kept. For two breaks the second must lie more than `mindist()` observations after the first.
4. **Critical values.** Tables are interpolated linearly over the sample size and, for the one-break trend model, over the break fraction. For the two-break trend model the nearest tabulated break-fraction cell is used, then the sample size is interpolated. The tables and interpolation routines are ported from the `leestra` package (see Acknowledgements).
5. **Break fraction.** The reported `lambda` follows the `leestra` convention, adjusted for the lag-truncated start of the regression sample, so that lookups land in the same table cell.
6. **Observation order.** The command works on observation order after dropping missing values, so calendar gaps in the time variable do not stop it from running.

---

## 9. Validation

`lsmlm` was checked against `leestra` (Eruygur, SSC s459688) using [`validation/lsmlm_validate.do`](validation/lsmlm_validate.do) on a simulated annual series with two breaks:

- **Test statistic and break dates** agreed to about 1e-6 for all six combinations of model (`crash`, `break`) and breaks (0, 1, 2), with lags fixed at 0.
- **Critical values** agreed to five decimals for the no-break, crash (1 and 2 breaks) and trend-break (1 and 2 breaks) cases.

Be clear about what this does and does not show: agreement was established on **one simulated series with lags fixed at 0**. With data-driven lag selection the sample used in each regression depends on the number of lags, and the two commands may handle this differently, so results can differ. You can rerun the validation on your own data:

```stata
ssc install leestra
do validation/lsmlm_validate.do
```

---

## 10. Limitations

- **Speed.** The break search is a native-Stata grid search. Run time grows with the sample size, and for two breaks roughly with its square. Monthly samples of a couple of hundred observations with a large `maxlag()` can take minutes per series. A Mata implementation such as `leestra` is faster.
- **Single series.** Panels require a loop (see above).
- **Missing values inside the series.** Observations with a missing value in the tested variable or the time variable are dropped, and the remaining observations are treated as consecutive. Fill or handle interior gaps before testing if that is not what you want.
- **Maximum two breaks.** Critical values are not tabulated for more.
- **Critical-value grid.** The two-break trend model uses the nearest tabulated break-fraction cell rather than a continuous interpolation.
- **Lag selection.** The general-to-specific rule uses a 1.645 cut-off on the highest lag. Other information criteria are not implemented.

---

## 11. Troubleshooting

| Message or symptom | Likely cause and fix |
|---|---|
| `data must be tsset, or specify timevar()` | Run `tsset` first, or pass `timevar(varname)` |
| `the time variable is not unique in the current sample` | You called it on a panel. Restrict to one unit with `if id==1` or loop over units |
| `not enough observations after if/in and missing` | Fewer than about 20 usable observations. Widen the sample |
| `sample too short for the chosen trim() and maxlag()` | The break window is empty. Reduce `maxlag()` or `trim()` |
| `no estimable configuration was found` | Try a smaller `maxlag()` or `trim()`, or a longer sample |
| `r(111)`: command not found | The `.ado` is not on the adopath. Reinstall or place it in your PERSONAL folder, then `discard` |
| You edited the `.ado` but nothing changed | Run `discard` |
| `sysuse lsmlm_oecd15` fails | Make sure the package was installed with `net install`, or `use` the `.dta` directly from the repository folder |

---

## 12. Repository layout

```
lsmlm/
├── lsmlm.ado                     the command
├── lsmlm.sthlp                   Stata help file (help lsmlm)
├── lsmlm.pkg                     package description (for net install)
├── stata.toc                     table of contents (for net install)
├── lsmlm_oecd15.dta              example dataset
├── README.md                     this guide
├── LICENSE                       MIT licence and third-party notices
├── examples/
│   ├── lsmlm_example.do          short demonstration on simulated data
│   ├── lsmlm_oecd15_analysis.do  full application: 15 OECD countries
│   └── lsmlm_turkey_analysis.do  application to monthly Turkish data
└── validation/
    └── lsmlm_validate.do         comparison against leestra
```

The Turkish application reads an Excel workbook that is **not** distributed here. Edit the `XLSX` path at the top of that file to point to your own copy.

---

## 13. Citation and references

If you use `lsmlm`, please cite the package and the underlying methods.

**Package:**

> Öngören, İ. (2026). *lsmlm: Lee–Strazicich minimum LM unit root test with structural breaks* [Stata module, version 1.1.0]. Statistical Software Components S459809, Boston College Department of Economics. <https://ideas.repec.org/c/boc/bocode/s459809.html>

See also the [Google Scholar entry](https://scholar.google.com/citations?view_op=view_citation&hl=tr&user=wWKAVe4AAAAJ&citation_for_view=wWKAVe4AAAAJ:u-x6o8ySG0sC).

**Methods**

- Lee, J. and M. C. Strazicich (2003). Minimum Lagrange multiplier unit root test with two structural breaks. *Review of Economics and Statistics* 85(4): 1082–1089.
- Lee, J. and M. C. Strazicich (2013). Minimum LM unit root test with one structural break. *Economics Bulletin* 33(4): 2483–2492.
- Schmidt, P. and P. C. B. Phillips (1992). LM tests for a unit root in the presence of deterministic trends. *Oxford Bulletin of Economics and Statistics* 54(3): 257–287.

**Example data**

- Bolt, J. and J. L. van Zanden (2024). Maddison style estimates of the evolution of the world economy: A new 2023 update. *Journal of Economic Surveys*, 1–41.

### Acknowledgements

The critical-value tables and interpolation routines are ported from the **`leestra`** package by H. Ozan Eruygur (Statistical Software Components S459688), distributed under the MIT License. Its copyright notice is retained in [LICENSE](LICENSE). The test statistic and the break search are my own native-Stata implementation.

### Contributing and issues

Bug reports and suggestions are welcome through GitHub Issues. A reproducible example (a short `.do` file and, if possible, a small dataset) makes problems much easier to diagnose.
