# Debugging, new parameters and new colleagues

This page is for the day something breaks, a new setting or a new column arrives, or a new person (with or without an AI assistant) starts working on the project.

The short version:

1.  `Rscript scripts/check_setup.R` tells you what is wrong **before** a run.
2.  The run reports tell you what changed **after** a run.
3.  `arr_debug()` lets you look inside a script that stopped.
4.  `Rscript scripts/compare_outputs.R` tells you if a change of code changed the results.

------------------------------------------------------------------------

## 1. The first five minutes

Something does not work. Do these in order:

| Step | Command | What you learn |
|----|----|----|
| 1 | `Rscript scripts/check_setup.R` | Missing files, missing columns, settings that do not agree, and years that the scripts do not know yet. Each line is OK, WARN or FAIL, with what to do. |
| 2 | Open `data/output/diagnostics/cleaning/latest/report.md` | Where rows are lost, which columns and values are new, and which flow failed |
| 3 | Open `data/output/diagnostics/checks/latest/report.md` | More issues than last time, workbooks not written, mistakes in the log of decisions |
| 4 | Open `run.log` in the same folder | The error message and the warnings of the run |

Most problems are found in step 1 or step 2.

------------------------------------------------------------------------

## 2. How the project is built (what a new person must know)

-   **A flow is a list of scripts.** `scripts/cr/`, `scripts/pr/` and `scripts/mne/` hold the scripts. The order is in `cr_main.R` and `pr_main.R`. Every script starts with `source("scripts/prep_env.R")`.
-   **`prep_env.R`** loads the packages, the helper code in `R/` and `functions/`, and turns every line of `config.yml` into an R variable (`report_year`, `annual`, ...). A script uses these variables directly.
-   **Scripts talk through files, not objects.** The cleaning writes `data/cleaned/*.csv`. The checks and the analysis read them. So you can run any script alone, if the files it reads exist.
-   **Every script wipes the R session at the end** (`rm(list = ls())`). This is why you cannot look at `df` after a run. See "Look inside a script" below.
-   **All paths are relative** to the project folder. Always start R from there (open the `.Rproj`).
-   **The Excel outputs have a fixed format** (sheets `Summary`, `Cube`, one sheet per check). Other people depend on it. Do not change it.
-   **Data is confidential.** `data/` and `config.yml` never go to GitHub (see `.gitignore`).

------------------------------------------------------------------------

## 3. Which step went wrong?

```
check_setup.R ──fail──► fix the file, setting or column it names
      │ ok
run_cleaning.R ──flow failed──► cleaning report: "Failed flows" + last step that worked
      │ ok                       "attention" points ──► a new column / value / fewer rows?
run_checks.R   ──flow failed──► checks report: "Failed flows"; "workbook not written"
      │ ok                       "more issues" / "new kind of issue" ──► look at changes.csv
analysis       ──────────────► compare with last year's tables; run compare_outputs.R
```

Use the **row trace** in the cleaning and checks reports to find where rows are lost. A step marked "should not add rows" must show a change of 0. A plus means that a key is duplicated in a lookup table (the units patch, the priority codes).

------------------------------------------------------------------------

## 4. Error messages we have seen, and what to do

| What you see | Probable cause | What to do |
|----|----|----|
| `config.yml not found` | Wrong folder, or the settings file was not made | Open the `.Rproj`; copy `config.example.yml` to `config.yml` |
| `object 'xxx' not found` for a setting name | A new setting is in `config.example.yml` but not in your `config.yml` (or the other way round) | `check_setup.R` lists the missing ones. Add them to both files. |
| `Can't subset columns that don't exist: Activein2026` | `grants_db.csv` does not have the `ActiveinYYYY` column of a recent year | In the Combiner, add the year to `reporting: active_years`, run it again |
| `Names must be unique ... "Grantee" at locations ...` | The input already has the columns that the cleaning creates: it was **cleaned before**. Typically the Combiner used an ARR cleaned file as its "previous combiner" | `check_setup.R` says "not cleaned before - already present". In the Combiner, `inputs: previous_cr_combiner` and `previous_pr_combiner` must be the Combiner's own output of last year, not the ARR cleaned file. |
| `rows with an Exercise that is not encoded` (cleaning report) | An exercise label that the rule does not understand (it must contain the year and the word Annual or Cumulative, for example `ARR26 Annual`) | Fix the label at the source |
| `current source of data not found` | `source_cr` / `source_pr` do not match the data | Check the setting against the labels in the data |
| `undefined columns selected` / `Can't subset columns` in a cleaning script | The Combiner output has a renamed or dropped column | Look at `new column in input` / `column no longer in input` in the cleaning report, then change the script |
| `No data found on worksheet`, or a `NULL` column of the MnE tracker | The layout of the tracker changed (header row, sheet name) | `check_setup.R` reads the header in the two ways the scripts do (row 4 and `skip = 6`). Fix `sheet_mne` or the row numbers. |
| `cannot open file '.../data/cleaned/...csv'` | A check was run before the cleaning | Run the cleaning first |
| `could not find function "trace_step"` (or another helper) | A script was run without `prep_env.R` | Run `source("scripts/prep_env.R")` first |
| `argument is of length zero` / `missing value where TRUE/FALSE needed` | An empty table after a filter: nothing matched | Open the row trace: which step gives 0 rows? Often a year, a label or a missing approval in the MnE tracker |
| Numbers differ from last time without a change of code | New input files | Compare the input row counts in the cleaning report |
| The same issue comes back after being "ignored" | `Issue` in `log_decisions.xlsx` is misspelled, or ProgrammeID / LeadGRN is different | The checks report lists entries that match no check |

------------------------------------------------------------------------

## 5. When a new parameter or a new year comes in

### What a new year needs

Since the year-proofing, **a new year needs no change in the scripts**. The year comes from `config.yml`:

| What | How it follows the year |
|----|----|
| The code of an exercise (`ARR26 Annual` = 12, `ARR26 Cumulative` = 13, ...) | Worked out from the label: 2 x (last two digits) - 40 for annual, - 39 for cumulative. The setting `annual` / `cumulative` must give the same number (`check_setup.R` tells you if not). |
| `Sourceofdata` labels (`CR26`, `PR26`) | Any year from 20 up to the report year is recognised |
| The three `ActiveinYYYY` columns in the check sheets | The last 3 years up to `report_year` (2026: `Activein2024`, `Activein2025`, `Activein2026`) |
| The dates of the strategic plan | Settings `strategic_plan_start` and `strategic_plan_end` (keep them equal to the Combiner's `reporting: strategic_plan`) |
| `Achieved` counted as a reporting window | Setting `achieved_as_rw` (7 for ARR25: decide again each year) |

Things that are **still fixed in the code**, and the first suspects when something looks odd:

| Where | What is fixed | What to do |
|----|----|----|
| `scripts/pr/cleaning/pr_cleaning.R` | Reporting windows `RW1` ... `RW9` (found by the digit in the label) | Add more only if a programme reaches RW10 |
| `scripts/pr/cleaning/pr_patch.R` | `RW1` ... `RW6` and `Achieved` get a number. **`RW7`, `RW8`, ... do not (they become NA)** | If the data has `RW7` or more, change the numbering and check that the results make sense |
| `recode_source()` | A label with two years, such as `CR2024`, becomes `CR20` (the first year found wins; this is how the old scripts worked) | Write the label as `CR24` at the source |
| `scripts/mne/mne_cleaning.R` and the checks | The header rows of the MnE tracker (4 and 6) | Change only if the tracker layout changed |
| `functions/analysis_cr/*.R` | Text labels such as `Non-Covid-19 related data` | Change only if the Combiner changes the label |
| The Combiner settings | `reporting: active_years` | Must contain the last 3 years up to the report year |

### Add a new setting (a parameter)

1.  Add it to `config.example.yml` with a comment, and to your `config.yml`.
2.  Use it in the script by its name (for example `my_setting`). It is already a variable. Do **not** write the value into the script.
3.  If a run cannot work without it, add its name to `CONFIG_REQUIRED` in `R/utils/setup_check.R`. Then `check_setup.R` tells the next person when it is missing.
4.  Add a line to the settings table in the README (section 2).
5.  Run `check_setup.R`, then run the flow and compare the outputs (section 7).

### Add a new input column or a new check

-   A new column from the Combiner: add its name to `COLUMNS_REQUIRED` in `R/utils/setup_check.R` if a script needs it. A column that no script uses needs no change.
-   A new check: copy the pattern of a neighbour script (`Summary` + `Cube` + one sheet per check, and the log of decisions). The checks report picks up the new workbook sheets by itself, but a new **workbook** must be added to `checks_workbooks` in `R/diagnostics/diag_checks.R`.
-   A new step in a cleaning script: add `trace_step(df, "PR: what this step does")` after it, so the row trace shows it.

------------------------------------------------------------------------

## 6. Look inside a script that stopped

Because every script wipes the session at the end, switch the wipe off while you debug:

``` r
source("scripts/prep_env.R")
arr_debug()                                   # the scripts keep their objects now
source("scripts/pr/cleaning/pr_cleaning.R")   # run ONE script
View(df)                                      # the data after the script
last_trace()                                  # rows after each step
arr_debug(FALSE)                              # switch it off again
```

If a script **stops with an error**, the objects up to the error are still in the session (the wipe is at the end). Then:

-   `traceback()` shows which line failed.
-   Run the script line by line in RStudio (Ctrl+Enter) from the line before the error.
-   Put `browser()` on a line to stop there and look around.
-   `diag_reset()` clears the row trace between two runs in the same session.

Do not leave debug mode on for a normal run.

------------------------------------------------------------------------

## 7. Prove that a change did not break anything

Any change of code (yours, a colleague's or an assistant's) must keep the results the same, unless you meant to change them.

1.  **Before the change:** run the flow and copy the results to a safe folder, for example `backup/before/` (copy `data/cleaned` and the dated folder of `data/output/pr` or `cr`).
2.  Make the change.
3.  **Run the flow again** with the same input files.
4.  Compare:

``` bash
Rscript scripts/compare_outputs.R "backup/before/cleaned" "data/cleaned"
Rscript scripts/compare_outputs.R "backup/before/2026-10-12" "data/output/pr/2026-10-12"
```

It compares every csv file and every sheet of every Excel file. The answer is `IDENTICAL`, `DIFFERENT` (with the first difference), `ONLY_IN_A` or `ONLY_IN_B`. If something is different and you did not mean it, the change is wrong.

When you **do** mean to change the results (for example a new year), compare anyway and check that only the expected files and sheets differ.

------------------------------------------------------------------------

## 8. Working with an AI assistant

An assistant is useful for reading error messages, finding the line to change and writing a small fix. Rules that keep it safe:

**Give it:** `developers/AGENTS.md` (it explains the project and the rules), the text of the error, `report.md`, `findings.csv` and `run.log` from the run reports, and the output of `check_setup.R`. These contain names, counts and percentages, but no data rows and no passwords.

**Do not give it:** the data files, `config.yml` (it may hold paths and, in older versions, passwords), the log of decisions, or `changes.csv` (it has grant numbers). If the assistant runs on your computer and reads files itself, tell it the same.

**A good first message:**

> This is the ARR project (see developers/AGENTS.md). I ran `scripts/run_cleaning.R` and got the error below. Here are `check_setup.R`, the cleaning `report.md` and `run.log`. Find the cause, change as little code as possible, and tell me how to check that the results of the other flows did not change (`scripts/compare_outputs.R`).

**Ask it to:**

-   change the smallest possible part of the code,
-   never change the format of the Excel outputs,
-   add a `trace_step()` when it adds a step that changes the number of rows,
-   explain what it changed in plain words, so you can check it.

**Always:** run `check_setup.R` and `compare_outputs.R` yourself after the change. Do not accept "it should work".

------------------------------------------------------------------------

## 9. Checklist for a new colleague (first day)

-   [ ] Download **both** repositories into the same parent folder: `Combiner` and `AnnualResultsReport`.
-   [ ] Read the top of the README of both.
-   [ ] Install R 4.3+ and open `AnnualResultsReport.Rproj`.
-   [ ] Copy `config.example.yml` to `config.yml`; fill it in.
-   [ ] Get the input files (see the README, section 3). Run `Rscript scripts/check_setup.R` until there is no FAIL.
-   [ ] Run `Rscript scripts/run_cleaning.R` and read the report from top to bottom.
-   [ ] Run `Rscript scripts/run_checks.R`; open one check workbook and the checks report.
-   [ ] Read [the run reports](diagnostics.md) and this page.
-   [ ] Make a backup of the results, change something small, run again and use `compare_outputs.R`. Now you know how the safety net works.
-   [ ] Read `developers/AGENTS.md` if you will work with an AI assistant.
