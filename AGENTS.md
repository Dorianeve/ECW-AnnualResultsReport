# AGENTS.md: guide for AI assistants working on this repository

Read this first. It tells you what the project is, how to run it, how to debug it, and which rules you must not break.

## What this project is

The ARR (Annual Results Report) flow of Education Cannot Wait. It reads two files made by the sister repository **Combiner** (`cr_clean.xlsx`, `pr_clean.xlsx`) and the grants list (`grants_db.csv`), then **cleans** them, **checks** them (Excel workbooks with issues) and **analyses** them (Excel tables for the report). Language: R (4.3+), tidyverse style, `openxlsx` for Excel.

The two repositories are downloaded side by side and talk to each other: the Combiner copies the three input files into `AnnualResultsReport/data/input/`. Do not make this project depend on a fixed path outside the repository.

## Layout

```
config.example.yml      settings template; config.yml is the user's copy (git-ignored, never commit)
cr_main.R, pr_main.R    full CR / PR flow (cleaning, checks, patch, analysis), no report
scripts/run_cleaning.R  cleaning with a run report;  scripts/run_checks.R  checks with a run report
scripts/check_setup.R   "doctor": checks settings, inputs, columns and years BEFORE a run
scripts/compare_outputs.R  compares two output folders (csv + every xlsx sheet)
scripts/{cr,pr,mne}/    the flow scripts (cleaning/, checks/, analysis/)
scripts/prep_env.R      loads packages, R/, functions/ and turns config.yml into variables
R/                      diagnostics (reports), trace helpers, setup check, compare, debug mode
functions/              helper functions used by the scripts (analysis tables, Google Drive sync)
templates/              empty examples of the input files the user prepares
docs/                   diagnostics.md (run reports), debugging.md (read it), development.md (how to change the code safely, recipes), glossary.md
.githooks/pre-commit    blocks commits with data, settings, passwords, e-mails, personal paths or real GRNs (enable: git config core.hooksPath .githooks)
data/                   input, cleaned, output: confidential, git-ignored
```

## Commands

```bash
Rscript scripts/check_setup.R                  # first: what is wrong before a run
Rscript scripts/run_cleaning.R [cr|pr|mne]     # cleaning + report
Rscript scripts/run_checks.R [cr|pr]           # checks + report
Rscript scripts/compare_outputs.R <A> <B>      # did the results change?
```

R is at `C:/Program Files/R/R-4.3.2/bin/Rscript.exe` on the main Windows machine. Run everything from the project root. A full cleaning takes several minutes (reading big Excel files).

## Rules (do not break these)

1.  **Never change the format of the Excel outputs** (sheet names, column names, order). Other people depend on it. The checks and the analysis must give identical results after your change.
2.  **Prove it.** After a change, run the flow on the same inputs and use `scripts/compare_outputs.R` against a backup made before. Say what you ran and what the result was. Never say "it should work".
3.  **Smallest change.** The scripts are long and top-level (not functions). Do not reformat, rename or restructure them while fixing a bug.
4.  **No data in the repository or in your messages.** `data/`, `config.yml`, `log_decisions.xlsx`, `priority_grn_codes.xlsx`, `patch_units.csv` hold confidential data and real grant numbers (GRNs). Never commit them, never paste rows from them. Use the files in `templates/` (fake rows) for examples and tests.
5.  **No secrets.** There are no passwords or tokens in this project. Do not add any. Secrets would go in `.Renviron`, never in `config.yml` or the code.
6.  **Follow `docs/development.md`** for how to change code, with step-by-step recipes (new setting, check, analysis table, year). The commit hook blocks real GRNs: put exclusions in `config.yml` (`cr_exclude_leadgrn`, `pr_exclude_leadgrn`), never in a script.
7.  **Do not delete** outputs, inputs or the user's backups. Do not run `git push` or change the git history unless asked.
8.  **Say when something is not tested.** The Google Drive API sync (`functions/gdrive_sync.R`) has not been tested.

## Things that surprise newcomers

-   **Every script ends with `rm(list = ls())`** (and `prep_env.R` starts with it). Objects do not survive from one script to the next; scripts communicate through `data/cleaned/*.csv`. To inspect objects use `arr_debug()` (it skips the wipe), then run one script. Dot-objects (`.diag_env`) survive the wipe on purpose.
-   **Lazy arguments:** if you pass a global variable into a function that then runs a legacy script, `force()` it first, otherwise the script's `rm(list = ls())` deletes it before it is used (this bit us once in `R/diagnostics/`).
-   **Settings are plain variables.** `config.yml` is read with `yaml::read_yaml` and every key becomes a global variable (`report_year`, `annual`, ...). A new setting is available by its name as soon as it is in `config.yml`.
-   **The year comes from `config.yml`, not from the code.** Exercise codes (`encode_exercise()`), source labels (`recode_source()`), the `ActiveinYYYY` window (`active_year_cols()`), the strategic-plan dates and `achieved_as_rw` are settings or helpers in `R/utils/years.R`. Never write a year into a script. What is still fixed in the code is listed in `docs/debugging.md` section 5 (for example `pr_patch.R` numbers only RW1-RW6 and `Achieved`). Always run `check_setup.R` when the year or a setting changes.
-   **The MnE tracker is read from two header rows** (`startRow = 4` in `mne_cleaning.R`, `skip = 6` in the checks). Both must work.
-   **Column names lose their spaces** in the cleaning (`gsub("\\s+", "", ...)`): `Type of investment` becomes `Typeofinvestment`.
-   **Check scripts apply `log_decisions.xlsx`** inside the script (9 places). `diag_decisions()` is called just before, to count what is hidden.
-   **CR number checks** write two workbooks, `Number checks - Reached.xlsx` and `Number checks - Targeted.xlsx`. (Older versions also saved a half-way `Number checks.xlsx` in the CR folder; it was removed because everything in it is in the two real files. The PR flow still writes its own `Number checks.xlsx`: that one is real.)
-   **Backslashes:** when writing R code through a shell here-document, backslashes may be halved. Use `[.]` and `[[:space:]]` instead of `\\.` and `\\s` in new regular expressions, and check the file afterwards.

## Diagnostics: how the run reports work

`R/diagnostics/` writes `data/output/diagnostics/{cleaning,checks}/<run>/report.md` (+ csv files, `run.log`, `profile.rds`). A run is compared with the last run that worked, per flow. The scripts feed it with `trace_step(df, "label")` (row count after a step; the text before the first `:` groups the steps of one script, and the whole text is the comparison key, so do not rename it without a reason), `diag_input(df, name)` (columns of an input) and `diag_decisions(x, log, "script")`. These calls only record: they return their input unchanged. See `docs/diagnostics.md`.

## Debugging in five lines

1.  `Rscript scripts/check_setup.R`: fix every FAIL.
2.  Open `data/output/diagnostics/cleaning/latest/report.md` (or `checks`): look at "Attention", "Failed flows" and the row trace.
3.  `source("scripts/prep_env.R"); arr_debug(); source("<one script>")`, then inspect `df`.
4.  Fix with the smallest change.
5.  Run again; `scripts/compare_outputs.R` against the backup; report the result.

More: `docs/debugging.md`.

## How to add things

-   **New setting:** add to `config.example.yml` and `config.yml`; add to `CONFIG_REQUIRED` in `R/utils/setup_check.R` if a run needs it; add a row to the README table.
-   **New input column used by a script:** add it to `COLUMNS_REQUIRED` in `R/utils/setup_check.R`.
-   **New cleaning step that changes the number of rows:** add a `trace_step()` after it.
-   **New check workbook:** add its file name to `checks_workbooks` (and its script to `checks_scripts`) in `R/diagnostics/diag_checks.R`.
-   **New year:** follow the yearly checklist in the README (section 9), then `check_setup.R`.

## Style

Match the surrounding code: tidyverse pipes (`%>%` and the magrittr `%<>%` are used in the scripts, `|>` in `R/`), `snake_case` for new objects, short comments in English, section headers as `## Title ----`. Documentation is written in plain English for non-programmers: short sentences, no jargon without explanation.
