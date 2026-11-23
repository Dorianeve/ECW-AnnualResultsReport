# The run reports

After the cleaning and after the checks, the pipeline writes a **report**. The report shows **what changed since the last run**, and **what went wrong** if something failed. It follows the same idea as the report of the Combiner.

The reports do not change the cleaned files, the check workbooks or the analysis. They only describe them. They contain no data rows and no passwords.

## How to run

``` bash
Rscript scripts/run_cleaning.R          # cleaning of CR, PR and the MnE tracker  + cleaning report
Rscript scripts/run_checks.R            # all CR and PR checks                    + checks report
Rscript scripts/run_cleaning.R pr       # only some flows (cr, pr, mne)
Rscript scripts/run_checks.R cr         # only some flows (cr, pr)
```

**CR and PR can be run at different moments.** Give the flow name to run only one of them. Each flow is compared with **its own** last run, so a PR run is compared with the last PR run even if a CR run happened in between. The report of a single flow only describes that flow. Two things to know:

-   The checks read the cleaned files, so run the cleaning of that flow first. The checks of both flows also use the cleaned MnE tracker, so run `Rscript scripts/run_cleaning.R mne` once (or run the cleaning without a flow name).
-   If you change the input of one flow, the cleaning report of that flow is the one to read.

The old way (`cr_main.R`, `pr_main.R`, `integrated_flow.R`) still works and gives the same results. It just does not write a report. From R you can also use `source("scripts/run_cleaning.R")`.

## Where are the reports?

The newest report is always here:

-   `data/output/diagnostics/cleaning/latest/report.md`
-   `data/output/diagnostics/checks/latest/report.md`

Every run also has its own folder, named with the date and time. A run is compared with the **newest earlier run that worked**. To start from zero, delete the folders.

### Cleaning report

```         
data/output/diagnostics/cleaning/
  latest/                 a copy of the newest run
  2026-10-12_154017/
    report.md             the report: read this first
    findings.csv          the points of the report, one row each
    trace.csv             rows after each cleaning step
    inputs.csv            the input files: size, date, rows, columns
    schema.csv            the columns of each input and whether the name is kept after cleaning
    outputs.csv           the columns of each cleaned file: empty share and number of different values
    run.log               every message and warning of the run
    profile.rds           numbers that the next run compares with
```

### Checks report

```         
data/output/diagnostics/checks/
  latest/
  2026-10-12_154928/
    report.md             the report: read this first
    findings.csv          the points of the report, one row each
    issues.csv            the number of issues of each check, and the number in the last run
    changes.csv           the issues that are new or solved since the last run (contains programme and grant numbers)
    sheets.csv            every sheet of every checks workbook and its number of rows
    trace.csv             the rows each check script looked at
    run.log               every message and warning of the run
    profile.rds           numbers that the next run compares with
```

## How to read the cleaning report

The first lines tell you the **status**: *Nothing needs attention*, *N point(s) need attention* (read section 1), or *N flow(s) FAILED*.

| Point | What probably happened | What to do |
|----|----|----|
| `new column in input` / `column no longer in input` | The Combiner output changed | Compare with the Combiner. A renamed column may need a change in the cleaning script. |
| `new output column` / `output column disappeared` | A cleaning step or the input changed | Tell the people who use the results |
| `new value(s) in …` | A new category, spelling, source or unit in the data | Decide if the cleaning rules need the new value, or ask for a correction at the source |
| `share of empty cells changed in …` | A column is no longer filled in, or it was renamed | Compare with the input |
| `row count changed` / `input row count changed` | The input data or a filter changed | Look at the row trace |
| `row counts start to differ from the last run at this step` | This is the step where this run first differs from the last run | Look at this step first |
| `rows with an Exercise that is not encoded` | A new label such as `ARR26 Annual` that the encoding in the cleaning script does not know | Add it to the `exercice` encoding |
| `no rows for the annual / cumulative exercise` | `annual` / `cumulative` in `config.yml` do not match the data | Check the yearly parameters |
| `current source of data not found` | `source_cr` / `source_pr` in `config.yml` do not match the data | Check the yearly parameters |
| `the flow failed` | One flow stopped with an error | Read "Failed flows" and `run.log` |

The **row trace** counts the rows after each main step. A step marked "should not add rows" must show a change of 0. If it shows a plus, a key is duplicated in a lookup table. A big negative change shows the step that removes rows.

A change is reported when the share of empty cells moves by 10 percentage points or more, or a row count changes by 10 % or more (and at least 5 rows). Values are compared only in columns with at most 60 different values.

## How to read the checks report

| Section | What it tells you |
|----|----|
| **Attention** | Things you should look at (see the table below) |
| **Information** | Changes that are usually fine, for example fewer issues |
| **Issues by check** | For every check: the number of issues, the number in the last run, the change, and the number of programmes and lead GRNs |
| **Workbooks written** | Each workbook, its number of sheets and the total number of issues. A workbook with 0 issues is listed too. |
| **Row trace** | The rows each check script looked at, after the MnE tracker filter (Completed or Waived) and the GMS filter |
| **Log of decisions** | What `log_decisions.xlsx` did in this run: entries per flow, how many entries hid an issue, how many hid nothing, and how many issues were hidden for each check |

| Point | What probably happened | What to do |
|----|----|----|
| `more issues than in the last run` | New data problems, or the data was updated | Look at `changes.csv` for the new ones and send them to the programme teams |
| `new kind of issue` | A check now finds something it did not find before | Look at the sheet of this check in the workbook |
| `workbook not written in this run` | A check script stopped before it saved | Read the failed flows and `run.log` |
| `cleaned file is older than the Combiner input` | The Combiner was run again, but the cleaning was not | Run `scripts/run_cleaning.R` first |
| `entries whose issue matches no check` | An entry of `log_decisions.xlsx` has a misspelled `issue`. It filters nothing. | Copy the name from the `Cube` sheet again |
| `log_decisions.xlsx not found` | The file is not in `data/input/log_decisions/` | Add it |
| `the flow failed` | A flow stopped with an error | Read "Failed flows" and `run.log` |

| `entries that hid no issue in this run` (information) | The issue of that entry is solved, or the entry is for another year | The entry can be removed from `log_decisions.xlsx` |

*Fewer issues* is shown as information: it is the expected result of corrections.

`changes.csv` lists the issues that are **new** and the ones that are **solved** since the last run, by programme and grant number. This is the list for the iterative loop with the programme teams. Because it contains grant numbers, do not share it outside the team.

### The log of decisions

`log_decisions.xlsx` is applied **inside the check scripts**: an issue that has a matching entry (same programme, lead GRN and `issue`) is removed from the check workbooks. Because the removed issues are not in the workbooks any more, the report records them while the scripts run (`diag_decisions()` is called just before the log is applied, in the 9 places where the log is used). So:

-   **issues found = issues in the workbooks + issues hidden by the log**
-   an entry that hid nothing is probably obsolete (information)
-   an entry whose `issue` is spelled differently from every check is a mistake (attention), because it can never match

*A note on the CR number checks:* the CR flow writes `Number checks - Reached.xlsx` and `Number checks - Targeted.xlsx`. (Older versions also saved a half-way `Number checks.xlsx` in the CR folder. It is not written any more. If you find it in an old folder, the report does not read it.)

## When something fails

The report is written **even if a flow fails**. Each flow (`cr`, `pr`, `mne` for the cleaning; `cr`, `pr` for the checks) runs on its own. If one fails, the others still run. After the report, the run stops with an error that names the failed flows. The report shows the error and the last step that worked. A failed run is **not** used for the next comparison.

## Sharing the report

You can share `report.md`. If someone asks, also share `findings.csv` and `run.log`.

-   **In them:** names of files, columns and checks, counts and percentages, and the values of columns with few different values (only in lines that report a change).
-   **Not in them:** data rows, free-text comments, passwords. Paths are shortened to the file name.
-   `changes.csv` contains programme and grant numbers.

## For developers

-   A cleaning or check step is recorded with one line: `trace_step(df, "PR: what this step is")`. The text before the first `:` groups the steps of one script, and the whole text is the key for the comparison with the last run, so do not change it without a reason.
-   `diag_decisions(x, log, "script")` is called just before a check script applies the log of decisions.
-   `diag_input(df, name)` records the size and the columns of an input right after it is read.
-   The state is kept in objects whose name starts with a dot, because the legacy scripts call `rm(list = ls())` at the end.
-   The code is in `R/diagnostics/` (`diag_core.R`, `diag_cleaning.R`, `diag_checks.R`) and `R/utils/trace.R`. Everything under `R/` is loaded by `scripts/prep_env.R`.
-   The checks report reads the Excel files that the check scripts write, so a new check appears in the report without any change to the report code.

## Limits

-   The report counts rows and issues. It tells you **where** rows are lost, not **which** rows. To see which rows, run the step on its own in R.
-   The analysis step (`cr_analysis.R`, `pr_analysis_*.R`) has no report yet.
-   A step is in the row trace only if someone placed a `trace_step()` there.
