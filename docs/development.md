# For developers

This page is for people who want to **change the code**. You do not need it to run the project.

If you are new, read it from top to bottom once. After that, use the table of contents to find the recipe you need ("How do I add a check?").

-   [The rules in one minute](#the-rules-in-one-minute)
-   [Set up](#set-up)
-   [How the project works](#how-the-project-works)
-   [How a script is built](#how-a-script-is-built)
-   [How to test a change](#how-to-test-a-change)
-   [Recipes: how do I ...?](#recipes-how-do-i)
-   [Odd things to know](#odd-things-to-know)
-   [Before you commit or publish](#before-you-commit-or-publish)
-   [Style](#style)

Related pages: [Debugging](debugging.md) (when something breaks), [The run reports](diagnostics.md), [Glossary](glossary.md), and [`developers/AGENTS.md`](../developers/AGENTS.md) (a short brief for AI assistants).

------------------------------------------------------------------------

## The rules in one minute

1.  **Never change the format of the Excel outputs.** The sheet names, the column names and their order stay as they are. Other people depend on them.
2.  **No year, no grant number (GRN), no name and no path in the code.** They come from `config.yml`.
3.  **No data and no passwords in the repository.** Not in the code, not in the docs, not in tests.
4.  **Make the smallest change that works.** Do not reformat or rename things in a script while you fix something else.
5.  **Prove that nothing else changed.** Before the change, make a backup of the results. After the change, run again and compare (see [How to test a change](#how-to-test-a-change)).
6.  **Leave a trace.** If a step can change the number of rows, add a `trace_step()` line after it.

------------------------------------------------------------------------

## Set up

Do this once on your computer.

1.  **Install R**, version 4.3 or newer. RStudio is nice to have.
2.  **Open the project** by double-clicking `AnnualResultsReport.Rproj`. All paths are relative to this folder.
3.  **Make your settings file.** Copy `config.example.yml` to `config.yml` and fill it in.
4.  **Check the setup:**

    ``` bash
    Rscript scripts/check_setup.R
    ```

    It tells you what is missing. The R packages are installed by themselves the first time you run something.

5.  **Turn on the commit check.** After the project is in a Git repository, run once:

    ``` bash
    git config core.hooksPath .githooks
    ```

    The hook (`.githooks/pre-commit`) runs before every commit and **stops you** if you try to commit:

    -   an e-mail address,
    -   a path into your personal Windows folder (the one that starts with the drive letter and `Users`),
    -   a password, token or key written as `name = "value"`,
    -   a real grant reference number (GRN),
    -   a data file (`.xlsx`, `.csv`, `.rds`) or your `config.yml`. Only the files in `templates/` and `data/input/analysis_codes/` are allowed.

    To add your own words that must never be committed (a name, a domain), copy `.sensitive-patterns.example` to `.sensitive-patterns` and write one pattern per line. That file stays on your computer.

------------------------------------------------------------------------

## How the project works

### The big picture

```
Combiner  -->  data/input/  -->  CLEANING  -->  data/cleaned/*.csv  -->  CHECKS  -->  data/output/<flow>/<date>/*.xlsx
                                                      |
                                                      +------------------------>  ANALYSIS  -->  data/output/<flow>/<date>/analysis/*.xlsx
```

-   **Scripts do not pass objects to each other.** Each script reads files and writes files. The cleaning writes the cleaned CSV files in `data/cleaned/`. The checks and the analysis read them. This is why you can run any script alone, when the file it needs already exists.
-   **Every script starts the same way:** `source("scripts/prep_env.R")`. This loads the packages, the helper code, and every line of `config.yml` as an R variable (`report_year`, `annual`, ...).
-   **CR and PR are two separate flows.** They can run on different days.

### The folders

| Folder or file | What is inside |
|----|----|
| `config.example.yml` | The settings template. Your copy, `config.yml`, is not committed. |
| `cr_main.R`, `pr_main.R`, `integrated_flow.R` | The old way to run a whole flow |
| `scripts/run_cleaning.R`, `scripts/run_checks.R` | Run the flow **with a report** |
| `scripts/check_setup.R`, `scripts/compare_outputs.R` | The checks before a run, and the comparison of two results |
| `scripts/prep_env.R` | Loads everything at the start of every script |
| `scripts/cr/`, `scripts/pr/`, `scripts/mne/` | The scripts of each flow (see below) |
| `R/` | The code for the run reports, the setup check, the debug mode, the year rules, the comparison |
| `functions/` | Helper functions used by the scripts (the CR analysis tables, the Google Drive download) |
| `templates/` | Empty examples of the files you prepare |
| `docs/` | The documentation |
| `data/` | Input, cleaned data and results. **Never committed.** |

### The scripts of each flow

| Step | CR | PR |
|----|----|----|
| Cleaning | `scripts/cr/cleaning/cr_cleaning.R` | `scripts/pr/cleaning/pr_cleaning.R` |
| Cleaning of the MnE tracker | `scripts/mne/mne_cleaning.R` (used by both) | |
| Checks | `cr_data_checks.R`, `cr_data_checks_new.R`, `cr_numbers_checks_reached.R`, `cr_numbers_checks_targeted.R` (in `scripts/cr/checks/`) | `pr_data_checks.R`, `pr_number_checks.R` (in `scripts/pr/checks/`) |
| Patch (prepares the analysis) | `scripts/cr/cleaning/cr_patch.R` | `scripts/pr/cleaning/pr_patch.R` |
| Analysis | `scripts/cr/analysis/cr_analysis.R`, with the table functions in `functions/analysis_cr/` | four scripts in `scripts/pr/analysis/` |

### The code in `R/`

| File | What it does |
|----|----|
| `R/pipeline/project.R` | `source_project()` loads every file in `R/` |
| `R/utils/years.R` | The rules that depend on the year: `encode_exercise()`, `recode_source()`, `active_year_cols()` |
| `R/utils/trace.R` | The row trace: `trace_step()`, `diag_input()`, `diag_decisions()` |
| `R/utils/setup_check.R` | The "doctor" (`check_setup.R`) |
| `R/utils/compare_outputs.R` | The comparison of two folders of results |
| `R/utils/debug.R` | `arr_debug()` |
| `R/diagnostics/` | The cleaning report and the checks report |

------------------------------------------------------------------------

## How a script is built

Almost every script has the same shape. This is a simplified example:

``` r
# PR FLOW - Cleaning ----                                    # 1. a title

# Prep env ----
source("scripts/prep_env.R")                                 # 2. load packages, helpers and settings
folder_path <- paste0("data/output/pr/", Sys.Date(), "/")    # 3. the folder of today's results
dir.create(folder_path, recursive = TRUE, showWarnings = FALSE)

# Load ----
df <- read.xlsx(paste0("data/input/", combiner_pr))          # 4. read: the file name is a setting
diag_input(df, combiner_pr)                                  # 5. record the columns of the input (for the report)
trace_step(df, "PR: input combiner")                         # 6. record the number of rows

# Cleaning ----
df %<>% filter(...)                                          # 7. the real work (tidyverse)
trace_step(df, "PR: after cleaning Total")                   # 8. a trace point after a step that can change the rows

# Save ----
write.csv(df, "data/cleaned/PR Combiner - For Checks.csv", row.names = FALSE)   # 9. write for the next script

if (!isTRUE(getOption("arr.debug"))) rm(list = ls())         # 10. clean the session (skipped in debug mode)
```

What to know:

-   **Settings are plain variables.** After `prep_env.R`, `report_year`, `annual`, `combiner_pr` and the others exist. Do not type their values into a script.
-   **Column names lose their spaces** when the Combiner file is read (`Type of investment` becomes `Typeofinvestment`). Use the names without spaces.
-   **`%<>%`** is the pipe that also saves the result back into the object (`df %<>% filter(...)` is the same as `df <- df %>% filter(...)`).
-   **Write the folder of the day** as `data/output/<flow>/<YYYY-MM-DD>/`. A new day makes a new folder.
-   **Every script wipes the session at the end** (line 10). This is why you cannot look at `df` after a run. Turn on `arr_debug()` to keep it (see [Debugging](debugging.md#6-look-inside-a-script-that-stopped)).

------------------------------------------------------------------------

## How to test a change

There is no automatic test suite yet. The safety net is this routine. **Use it for every change**, also for a small one.

1.  **Work in a copy.** Copy the project folder (with your `data/input/` files) to another place, and change the code there.
2.  **Make a "before" backup** with the old code. Run the flow and copy the results:

    ``` bash
    Rscript scripts/run_cleaning.R
    Rscript scripts/run_checks.R
    ```

    Then copy `data/cleaned` and the dated folders of `data/output/cr` and `data/output/pr` to a folder `backup/before/`. Run the analysis too, if you touched it.

3.  **Make your change.**
4.  **Run the same commands again** with the same input files.
5.  **Compare:**

    ``` bash
    Rscript scripts/compare_outputs.R "backup/before/cleaned" "data/cleaned"
    Rscript scripts/compare_outputs.R "backup/before/2026-11-23" "data/output/cr/2026-11-23"
    ```

    Everything must be `IDENTICAL`, unless you meant to change it. If you did, check that **only** the expected files and sheets differ.

6.  **Run the setup check and read the reports:**

    ``` bash
    Rscript scripts/check_setup.R
    ```

    Open the two reports in `data/output/diagnostics/*/latest/report.md`. No new "Attention" point should appear that you cannot explain.

**A faster test with a sample.** A full run takes several minutes. For a quick test, keep all the rows of a share of the LeadGRNs (for example 75%) in `cr_clean.xlsx` and `pr_clean.xlsx`, and use the **same sample** before and after the change. A sample that is too small can still stop a check, because some column or value does not occur in it. That is a limit of the sample, not of your change: read the message and the "Failed flows" part of the report.

------------------------------------------------------------------------

## Recipes: how do I ...?

### ... add or change a setting

1.  Add it to `config.example.yml` with a short comment, and to your `config.yml`.
2.  Use it in the script by its name (for example `my_setting`). Do not write its value in the script.
3.  If a run cannot work without it, add its name to `CONFIG_REQUIRED` at the top of `R/utils/setup_check.R`. Then `check_setup.R` tells the next person when it is missing.
4.  Add a row to the settings table in the README (section 2).

### ... start a new reporting year

No script has to change. Follow the yearly checklist in the README (section 9), then run `Rscript scripts/check_setup.R`. It checks that the numbers agree with each other. The year rules live in `R/utils/years.R`:

| Function | What it does |
|----|----|
| `encode_exercise(x)` | `ARR26 Annual` becomes 12, `ARR26 Cumulative` becomes 13 (2 x last two digits - 40, or - 39) |
| `recode_source(x, "PR", last_year)` | `...26...` becomes `PR26` |
| `active_year_cols()` | The last 3 `ActiveinYYYY` columns up to the report year |

The things that are **still fixed in the code** are listed in [Debugging](debugging.md#5-when-a-new-parameter-or-a-new-year-comes-in), for example how `pr_patch.R` numbers the reporting windows.

### ... use a new column of the Combiner output

1.  Use it by its name without spaces, in the cleaning or the check script.
2.  If a script cannot work without it, add the name to `COLUMNS_REQUIRED` in `R/utils/setup_check.R`.
3.  A column that no script uses needs no change.

### ... add a cleaning step

1.  Add it in `cr_cleaning.R` or `pr_cleaning.R`, in the place where it belongs.
2.  If it can add or remove rows, add `trace_step(df, "PR: what this step does")` after it. If it must **not** change the rows, write "(should not change rows)" in the text. The report then shows the step and compares it with the last run.
3.  Run [the test routine](#how-to-test-a-change). Only the cleaned file you meant to change should differ.

### ... add a check to an existing workbook

This is the pattern in `cr_data_checks.R` (the PR scripts are similar):

1.  **Make a flag column.** Add a column that is `TRUE` when there is a problem:

    ``` r
    df %<>%
      mutate(MissingProgrammeID = case_when(
        is.na(ProgrammeID) ~ TRUE,
        TRUE ~ FALSE
      ))
    ```

2.  **Name it.** Add a line to `label_map` (just before `# OUTPUT ----`): the left side is the column name, the right side is the text people read in the `Summary` sheet.

    ``` r
    "MissingProgrammeID" = "ProgrammeID missing",
    ```

3.  That is all. The script builds the `Cube` sheet, the `Summary` sheet, the sheet of this check (only when it finds something) and applies the log of decisions by itself, using `label_map`.
4.  **The name is also the `Issue` of the log of decisions.** People copy the column name into `log_decisions.xlsx`. Choose a clear name and do not rename it later.
5.  Test. A new check **adds** a sheet or rows; everything else stays identical.

### ... add a new check workbook (a new script)

1.  Copy a neighbour script. Keep the shape: filter to the programmes in scope, build the checks, apply the log of decisions, write `Summary`, `Cube` and one sheet per check.
2.  Add `trace_step()` lines after the filters, and `diag_decisions(x, log, "script name")` just before the log is applied.
3.  Register it for the reports: add the script to `checks_scripts` and the workbook name to `checks_workbooks` in `R/diagnostics/diag_checks.R`.
4.  Add it to the flow list in `cr_main.R` or `pr_main.R` and in `integrated_flow.R`.

### ... apply the log of decisions in a new check

Write the issue as a text, build a `Concat` of `ProgrammeID`, `LeadGRN` and the issue, and remove (or set to `FALSE`) the rows whose `Concat` is in the log. Copy the lines of `cr_data_checks.R` under `# FILTER Log decisions`. Add `diag_decisions(x, log, "...")` just before, so the report counts what is hidden.

### ... add a table to the CR analysis

1.  Write a function in `functions/analysis_cr/`. Copy `analysis_programme_table.R`: it takes `df` and `status` ("Reached" or "Targeted") and returns a table.
2.  In `scripts/cr/analysis/cr_analysis.R`, call it for Reached and for Targeted, and add the two results to the `sheets` list with a sheet name.
3.  Any file in `functions/` is loaded by itself.

### ... change the PR analysis

The four scripts in `scripts/pr/analysis/` are long and build their sheets one after the other (`addWorksheet`, `writeData`). Change one sheet at a time, and compare the workbook after each change.

### ... add a new analysis code (indicator) or change the priority

Edit `data/input/patch/priority_grn_codes.xlsx`, not the code. The rule is in the README (section 6): only the column `Priority` with the value `1` counts.

### ... support more reporting windows

`pr_cleaning.R` finds `RW1` ... `RW9` by the digit. `pr_patch.R` gives a number only to `RW1` ... `RW6` and to `Achieved` (the setting `achieved_as_rw`). **`RW7` and above become empty.** If a programme reaches `RW7`, change the numbering in `pr_patch.R` and decide how `Achieved` fits in. Test with a comparison.

### ... handle a change in the MnE tracker

The tracker is read in two ways: with the header in row 4 (`mne_cleaning.R`) and after skipping 6 rows (the check scripts). `check_setup.R` tests both. If the layout changes, change the number in every place (search for `startRow = 4` and `skip = 6`), then run `check_setup.R`.

### ... change what the run reports show

The reports are made by `R/diagnostics/`. A step appears in the report only if it has a `trace_step()`. The text of a trace step is also its **key** for the comparison with the last run, so do not rename it without a reason. The limits that decide "change" (10 percentage points of empty cells, 10% of rows) are at the top of `diag_core.R`. See [The run reports](diagnostics.md#for-developers).

------------------------------------------------------------------------

## Odd things to know

| Thing | What happens | What to do |
|----|----|----|
| `rm(list = ls())` | Every script ends with it, and `prep_env.R` starts with it. Objects do not survive from one script to the next. | Use `arr_debug()` to keep them. Do not rely on an object from another script: read the file. |
| Lazy arguments | If you pass a global variable to a function that runs a script, the script's `rm(list = ls())` can delete the variable before it is used. | Write `force(x)` at the start of the function. |
| Dot-objects | Objects whose name starts with a dot (`.diag_env`) survive `rm(list = ls())`. The reports use this on purpose. | Do not use dot-objects for anything else. |
| Reading the CSV again | `read.csv()` turns `Covid-19related` into `Covid.19related`, and dates into text. | Use the names that `read.csv()` gives. |
| `recode_source()` | A label with two years, such as `CR2024`, becomes `CR20` (the first year found wins). It is how the old scripts worked. | Write the label as `CR24` at the source. |
| The `LeadGRN` sheet of the priority file | It is read, but the filter that uses it is switched off. | Keep the sheet. Do not rely on it. |
| A value that does not occur | `pr_data_checks.R` used to stop when no row had the unit "Percentage %" after the filters (this happens early in a reporting year). It is fixed for the units, but other checks may have the same weakness. | If a check stops with "Column ... doesn't exist", look at which value is missing in the filtered data, and make the script add the empty column (see the fix for `unit_overtime` in `pr_data_checks.R`). |
| The PR `Number checks.xlsx` | It is the real output of `pr_number_checks.R`. | Keep it. (The CR flow has no such file.) |
| Line endings | Some files have Windows line endings, some Linux. Both work. | Do not change the line endings of a whole file in a commit: it makes the change hard to read. |
| Backslashes | If you write code through a shell here-document, backslashes can be halved. | In new regular expressions use `[.]` instead of `\\.` and `[[:space:]]` instead of `\\s`. Check the file afterwards. |

------------------------------------------------------------------------

## Before you commit or publish

-   [ ] The commit hook is on (`git config core.hooksPath .githooks`).
-   [ ] `git status` shows **no** file from `data/`, no `config.yml`, no `.xlsx` or `.csv` outside `templates/` and `data/input/analysis_codes/`.
-   [ ] No real grant number (GRN), e-mail address, personal path or password in the code, the docs or the comments. The hook looks for these, but read your own change too.
-   [ ] `Rscript scripts/check_setup.R` has no new FAIL, and the results are `IDENTICAL` to the backup (or differ only as you meant).
-   [ ] The README and the docs say what the change does. A new setting is in `config.example.yml` and in the README table.
-   [ ] You said what you did **not** test.

If a secret was ever committed, changing the file is not enough: it stays in the history. Tell the project owner, who must rotate the secret and clean the history.

------------------------------------------------------------------------

## Style

-   Use the tidyverse. The scripts use the pipes `%>%` and `%<>%`; the files in `R/` use `|>`. Write `package::function()` inside `R/`.
-   Names of new objects are `snake_case`. Section headers look like `## Title ----`.
-   A comment explains **why**, not what.
-   The documentation is written in **plain English**: short sentences, no jargon without an explanation.
-   Make one change at a time. Do not commit data, results or settings files.
