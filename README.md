# Annual Results Report (ARR) workflow

This project takes the two files made by the **Combiner** (the CR file with children reached and the PR file with programme results). It then:

1.  **cleans** them,
2.  **checks** them and lists the problems in Excel files,
3.  **analyses** them and writes the tables for the report.

```         
Combiner  ──►  cr_clean.xlsx, pr_clean.xlsx  ──►  [ cleaning ] ──► [ checks ] ──► [ analysis ]  ──►  Excel tables
                                                       │               │
                                                       └───────────────┴──►  a short report of what changed since the last run
```

You do not need to know R to use it. You need to open the project, change a few settings, and run one line.

## The short version

1.  Download **this project and the Combiner side by side** (see below). Run the Combiner. It copies three files into `data/input/`.
2.  Copy `config.example.yml` to `config.yml` and fill it in (section 2).
3.  Put your own two files in `data/input/`: the log of decisions and the priority codes (section 6). The MnE tracker comes later (section 3).
4.  Check everything before you start:

    ``` bash
    Rscript scripts/check_setup.R
    ```

5.  Run the flow, one step after the other:

    ``` bash
    Rscript scripts/run_cleaning.R
    Rscript scripts/run_checks.R
    ```

6.  Read the two reports (section 5), then the check files (section 7). When the checks are clean, run the analysis (section 4).

## Download this project together with the Combiner

This project and the **Combiner** are two parts of one workflow. They talk to each other, so **download both, into the same parent folder, side by side**:

```         
my-folder/
├─ Combiner/               makes the CR and PR files (run this first)
└─ AnnualResultsReport/    this project (reads what the Combiner wrote)
```

After every run, the Combiner copies three files into `AnnualResultsReport/data/input/`:

| File            | What it is                      |
|-----------------|---------------------------------|
| `cr_clean.xlsx` | The CR file (children)          |
| `pr_clean.xlsx` | The PR file (programme results) |
| `grants_db.csv` | The list of grants from the GMS |

You do not copy them by hand. The order of work is always: **1. run the Combiner, 2. run this project.**

*If the two folders are not side by side,* tell the Combiner where this project is: in the Combiner's settings file (`config/config.yml`), change `outputs: arr_input_dir` to the full path of this project's `data/input` folder. Or copy the three files by hand.

------------------------------------------------------------------------

## 1. Set up (only once)

1.  **Install R** (version 4.3 or newer). RStudio is useful but not required.
2.  **Get the project** and open `AnnualResultsReport.Rproj`. (Or open a terminal in the project folder.) Always work from the project folder: all paths are relative to it.
3.  **Make your settings file.** Copy `config.example.yml` and name the copy `config.yml`. Then fill it in (see section 2). `config.yml` never goes to GitHub.
4.  **Put your input files** in the folder `data/input/` (see section 3).
5.  Run the code. The first run installs the R packages it needs. This can take a few minutes.

------------------------------------------------------------------------

## 2. The settings file (`config.yml`)

It is a plain text file. Each line is `name: value`. There are no passwords in it.

| Setting | What it is | Example |
|----|----|----|
| `combiner_cr`, `combiner_pr` | Names of the Combiner files in `data/input/` | `cr_clean.xlsx` |
| `grants_db` | Name of the GMS export in `data/input/` | `grants_db.csv` |
| `mne_approval` | The MnE reports tracker. A file name in `data/input/`, **or** the full path to the file (for example on Google Drive) | `G:/My Drive/ARR/mne_tracker.xlsx` |
| `sheet_mne` | The sheet of the tracker to read | `Results_Reports_Auto` |
| `codes` | Name of the analysis codes file in `data/input/analysis_codes/` | `analysis_codes.xlsx` |
| `report_year`, `previous_report_year` | The reporting year and the one before | `"2025"`, `"2024"` |
| `report_year_number` | The reporting year as a number | `2025` |
| `source_cr`, `source_pr` | The "source of data" label of this year | `CR25`, `PR25` |
| `annual`, `cumulative` | The numbers that mean "this year's annual" and "this year's cumulative" (2024 = 8 and 9, 2025 = 10 and 11, 2026 = 12 and 13 ...) | `10`, `11` |
| `past_annual`, `past_cumulative` | The same numbers for last year | `8`, `9` |
| `ex_com_approval_date_cutoff` | Only grants approved by the ExCom **before** this date are expected to report individually. Used in the CR "New checks". | `"2025-01-01"` |
| `strategic_plan_start`, `strategic_plan_end` | The dates of the strategic plan. A programme is "active in the plan" if it ends after the start and starts on or before the end. Keep them equal to the Combiner settings. | `"2023-01-01"`, `"2025-12-31"` |
| `achieved_as_rw` | Reports marked "Achieved" count as this reporting window number (used in `pr_patch.R`) | `7` |
| `cr_exclude_leadgrn`, `pr_exclude_leadgrn` | LeadGRNs to leave out of the CR / PR analysis this year (a list, can be empty) | `[]` |
| `gdrive` | Only for the Google Drive download (see section 8) | `enabled: false` |

**Every new reporting year you must change the "yearly" settings.** See the checklist in section 9.

------------------------------------------------------------------------

## 3. The input files (`data/input/`)

The folder `data/input/` is not on GitHub because the files are confidential. Empty examples of the Excel and csv files you must prepare are in the folder `templates/`.

| File | Where it goes | Where it comes from | Template |
|----|----|----|----|
| `cr_clean.xlsx` | `data/input/` | Combiner (copied here automatically) | none |
| `pr_clean.xlsx` | `data/input/` | Combiner (copied here automatically) | none |
| `grants_db.csv` | `data/input/` | Combiner (copied here automatically; it is the processed GMS list) | none |
| MnE reports tracker | anywhere (set `mne_approval`) | Grants Management | none |
| `log_decisions.xlsx` | `data/input/log_decisions/` | You (see section 6) | `templates/log_decisions.xlsx` |
| `priority_grn_codes.xlsx` | `data/input/patch/` | You (see section 6) | `templates/priority_grn_codes.xlsx` |
| `patch_units.csv` | `data/input/patch/` | You | `templates/patch_units.csv` |
| `analysis_codes.xlsx` | `data/input/analysis_codes/` | Already in the project | already there |

The example rows in the templates are fake. Delete them and add your own.

*Note about the MnE tracker:* the scripts expect the same layout every year (the table starts at a fixed row). If the layout changes, tell whoever maintains the code.

------------------------------------------------------------------------

## 4. How to run it

You can run **CR** and **PR** together or **one at a time**. They do not depend on each other, so you can run them on different days.

### Before you run: check the setup

``` bash
Rscript scripts/check_setup.R
```

It looks at your settings, your input files, the columns inside them and the years the scripts know. It prints one line for each check: `OK`, `WARN` (probably wrong) or `FAIL` (the run will stop), and says what to do. Run it the first time, at the start of every new year, and whenever something is added or does not work.

### Option A (recommended): run with a report

Open a terminal in the project folder and run:

``` bash
Rscript scripts/run_cleaning.R      # step 1: clean CR, PR and the MnE tracker
Rscript scripts/run_checks.R        # step 2: run the checks of CR and PR
```

Run only one flow by adding its name:

``` bash
Rscript scripts/run_cleaning.R cr       # only CR   (you can also write pr, or mne)
Rscript scripts/run_cleaning.R pr       # only PR
Rscript scripts/run_checks.R cr         # only the CR checks
Rscript scripts/run_checks.R pr         # only the PR checks
```

Rules to remember:

- **Clean first, then check.** The checks read the cleaned files.
- **Run `mne` at least once.** Both CR and PR checks use the cleaned MnE tracker. `run_cleaning.R` without a name does it for you.
- Each run writes a **report** (section 5). Each flow is compared with its own last run, so CR and PR never get mixed up.

(In RStudio you can do the same with `source("scripts/run_cleaning.R")`.)

### Option B: run the whole flow in one go, without the report

The older way still works and gives the same results. It does cleaning, checks **and analysis**:

``` r
source("cr_main.R")     # CR: cleaning, checks, patch, analysis
source("pr_main.R")     # PR: cleaning, checks, patch, analysis
```

`integrated_flow.R` does the cleaning and the checks of CR and PR together, without the analysis.

### Option C: run it step by step

Good for the **first time of the year**, when you want to look at each step. Run the first line, then the scripts you need, in this order:

``` r
source("scripts/prep_env.R")                         # always first

# CR
source("scripts/cr/cleaning/cr_cleaning.R")
source("scripts/mne/mne_cleaning.R")
source("scripts/cr/checks/cr_data_checks.R")
source("scripts/cr/checks/cr_data_checks_new.R")
source("scripts/cr/checks/cr_numbers_checks_reached.R")
source("scripts/cr/checks/cr_numbers_checks_targeted.R")
source("scripts/cr/cleaning/cr_patch.R")             # prepares the analysis
source("scripts/cr/analysis/cr_analysis.R")

# PR
source("scripts/pr/cleaning/pr_cleaning.R")
source("scripts/mne/mne_cleaning.R")
source("scripts/pr/checks/pr_data_checks.R")
source("scripts/pr/checks/pr_number_checks.R")
source("scripts/pr/cleaning/pr_patch.R")             # prepares the analysis
source("scripts/pr/analysis/pr_analysis_annual.R")
source("scripts/pr/analysis/pr_analysis_annual_active_in_year.R")
source("scripts/pr/analysis/pr_analysis_cumulative.R")
source("scripts/pr/analysis/pr_analysis_cumulative_strategic_plan.R")
```

### The analysis

The analysis is not part of Option A. Run it when the checks are clean and the data is final: use Option B, or the last lines of Option C (the "patch" script first, then the analysis scripts).

------------------------------------------------------------------------

## 5. The run reports (what changed since last time)

Each run of Option A writes a short report. Read it before you read anything else.

| Report   | Where                                               |
|----------|-----------------------------------------------------|
| Cleaning | `data/output/diagnostics/cleaning/latest/report.md` |
| Checks   | `data/output/diagnostics/checks/latest/report.md`   |

The first lines say one of three things:

- **Nothing needs attention.** All is as before.
- **N point(s) need attention.** Read the section "Attention". Each point says what changed (for example a new column, a new value, fewer rows, more issues).
- **N flow(s) FAILED.** One flow stopped with an error. The report says where, and the other flows are still done.

What you find in them:

- **Cleaning report:** how many rows are left after each cleaning step (so you see where rows are lost), the input files, empty cells, new values, and sanity checks (for example "no rows for this year").
- **Checks report:** for every check, how many issues were found, how many last time, which issues are **new** and which are **solved**, how many rows each check looked at, and what the log of decisions did.

The list of new and solved issues is in `changes.csv` next to the report. It has grant numbers, so keep it inside the team.

The full guide, with a table "what does this point mean and what do I do", is in [docs/diagnostics.md](docs/diagnostics.md).

------------------------------------------------------------------------

## 6. The files you maintain by hand

### The log of decisions (`log_decisions.xlsx`)

Sometimes a check finds something that is **correct as it is** and the programme team cannot or will not change it. You write it in the log, and the checks stop reporting it.

- The file has two sheets: `cr` and `pr`.
- One row for each decision. Fill in at least `ProgrammeID`, `LeadGRN` and `Issue` (and `AnalysisCode` for PR), plus a `Justification`.
- **`Issue` must be copied exactly** from the check (the name in the `Cube` sheet of the check file). If it is misspelled, nothing is hidden. The checks report warns you about this.
- The report also tells you which entries hid **nothing** in the last run. Those entries are probably old and can be removed.

### The priority codes (`priority_grn_codes.xlsx`)

It says which analysis codes (indicators) are used in the **PR** checks and in the **PR** analysis. The CR flow does not use it.

**The rule: only the column `Priority` decides, and only the value `1` counts.**

| `Priority` in the `Codes` sheet | What happens to the code |
|----|----|
| `1` | **Used.** It is checked and analysed. |
| `0` | Left out. |
| empty cell | Left out. |
| anything else (text, `Yes`, `2`) | Left out. |

How the scripts apply it:

1.  They read the sheet `Codes` and take three columns: `Analysis code`, `Priority` and `Level`.
2.  The code is trimmed and written in lower case, so capital letters and extra spaces do not matter.
3.  Every PR row gets the `Priority` and `Level` of its code.
4.  Only the rows whose code has `Priority` = `1` stay in the PR data checks, the PR number checks and the PR analysis.

The columns in the file:

-   **`Analysis code`**: the code, as written in the PR data. One row for each code, no duplicates.
-   **`Priority`**: the column that decides (see the rule above). It must be called exactly `Priority`.
-   **`Level`**: what the code counts (Child, Teacher, School, Caregiver, Policy). It is carried into the analysis.
-   **Any other column** (for example `Priority23`, `Priority24`, `Indicator`) is **not read**. You can keep old years' choices in extra columns as a record.
-   **Sheet `LeadGRN`** (column `Lead Grantee GRN`): the scripts read it, but **they do not filter by it at the moment**, because the filter is switched off in the code. Keep the sheet in the file.

**Two things to watch**

-   A code that is in the PR data but **not** in the `Codes` sheet is left out too, without a message. When a new code appears, add a row for it.
-   A wrong value in `Priority` (for example `Yes`) does not give an error: the code is simply left out. Use only `1` and `0`.

**Every new reporting year:** keep last year's choice in an extra column (for example copy `Priority` to `Priority25`), then set the column `Priority` to `1` or `0` for the new year. Check the number of codes with `1`: the checks report shows how many rows each check looked at.

### The units patch (`patch_units.csv`)

A table of the correct unit (for example `Number #`) for old reports where the unit was missing. One row for each LeadGRN, code and Exercise.

------------------------------------------------------------------------

## 7. What you get (outputs)

| What | Where | Notes |
|----|----|----|
| Cleaned data | `data/cleaned/*.csv` | Overwritten at every run, so you always have the latest |
| Cleaning log | `data/output/cr/` or `pr/` `<date>/cleaning log.txt` | Counts of every category |
| Check files | `data/output/cr/<date>/` and `data/output/pr/<date>/` | See below |
| Analysis tables | `data/output/cr/<date>/analysis/` and `.../pr/<date>/analysis/` | CR: `Children Reached.xlsx`. PR: four `Program Results - ...xlsx` files. |
| Run reports | `data/output/diagnostics/` | Section 5 |

`<date>` is the day of the run, written `YYYY-MM-DD`. A new day makes a new folder.

**The check files**

| Flow | Files |
|----|----|
| CR | `Data checks.xlsx`, `New checks.xlsx`, `Number checks - Reached.xlsx`, `Number checks - Targeted.xlsx` |
| PR | `Data checks.xlsx`, `Number checks.xlsx` |

How to read a check file:

- Sheet **Summary** (or *OverallSummary*): the list of problems. One row for each problem.
- Sheet **Cube**: for every programme or grant, which checks are `TRUE` (a problem) or `FALSE`.
- The other sheets: the details of one check each. A sheet exists only if that check found something.

> Old CR folders may contain a file `Number checks.xlsx`. It was a half-way copy of the CR number checks (Annual part only) that older versions saved by mistake. It is not written any more: use the *Reached* and *Targeted* files.

------------------------------------------------------------------------

## 8. Working with Google Drive

There are two ways. Use the first if you can.

**1. Google Drive for Desktop (simplest).** Your Drive appears as a normal folder (for example `G:/My Drive/...`). Either copy the input files into `data/input/`, or put the full path in `config.yml`, as for `mne_approval`.

**2. Download with the Google API.** For people without Drive for Desktop. In `config.yml` set:

``` yaml
gdrive:
  enabled: true
  input_folder_id: "the id of the Drive folder with the input files"
  output_folder_id: ""
```

The folder id is the last part of the folder's web address. The first time, a browser window asks you to sign in to Google. The input files are then downloaded into `data/input/` once, at the start of every R session. (This part has not been tested yet.)

------------------------------------------------------------------------

## 9. The yearly checklist

When a new reporting year starts:

1.  Run the **Combiner** first (it must be in the folder next to this project, see the top of this page).
2.  Check that `cr_clean.xlsx`, `pr_clean.xlsx` and `grants_db.csv` in `data/input/` have today's date. If not, the Combiner did not find this project: see its troubleshooting page.
3.  Put the new MnE tracker in place and check `mne_approval` and `sheet_mne`.
4.  Change the yearly settings in `config.yml`: `report_year`, `previous_report_year`, `report_year_number`, `source_cr`, `source_pr`, `annual`, `cumulative`, `past_annual`, `past_cumulative`, `ex_com_approval_date_cutoff`, and, if they changed, `strategic_plan_start`, `strategic_plan_end` and `achieved_as_rw`. **No script has to be edited for a new year.** `Rscript scripts/check_setup.R` tells you if the numbers do not agree with each other.
5.  Update `cr_exclude_leadgrn` and `pr_exclude_leadgrn` (empty them if last year's exclusions do not apply).
6.  Update `priority_grn_codes.xlsx` (copy last year's `Priority` column to an extra column, then set `Priority` to `1` / `0` for the new year; see section 6) and `log_decisions.xlsx` (remove old entries).
7.  Run `Rscript scripts/run_cleaning.R` and read the cleaning report. Look especially for "Exercise that is not encoded", "no rows for the annual exercise" and new values.
8.  Decide again how "Achieved" counts as a reporting window (`achieved_as_rw`) and check the places marked `CHECK` in the code, such as the reporting windows in `scripts/pr/cleaning/pr_cleaning.R` and `scripts/pr/cleaning/pr_patch.R`. Note that `pr_patch.R` gives a number only to `RW1` ... `RW6` and `Achieved`: see [docs/debugging.md](docs/debugging.md), section 5.

------------------------------------------------------------------------

## 10. The normal working loop

During the checking period you repeat this:

1.  Run the cleaning and the checks.
2.  Read the checks report and open `changes.csv`: it shows what is **new** and what is **solved**.
3.  Send the new issues to the ECW staff, who correct them in the original reports.
4.  When the Combiner has been run again, it copies the new files to `data/input/` by itself. Go back to step 1.
5.  Issues that are correct as they are go into the **log of decisions**.
6.  When the checks are clean, run the analysis (section 4).

------------------------------------------------------------------------

## 11. When something goes wrong

| What you see | What it means | What to do |
|----|----|----|
| `config.yml not found` | You are not in the project folder, or you did not make the settings file | Open the `.Rproj`, and copy `config.example.yml` to `config.yml` |
| `cannot open file ... data/input/...` | An input file is missing or has another name | Check section 3 and the file names in `config.yml` |
| `cleaned file is older than the Combiner input` (checks report) | You have a new Combiner file but did not clean it | Run `scripts/run_cleaning.R` again |
| `entries whose issue matches no check` | An `Issue` in the log of decisions is misspelled | Copy it again from the check file |
| `workbook not written in this run` | A check script stopped before it saved | Read the "Failed flows" part of the report and `run.log` |
| The run stops with an error in the middle | Probably a new value or a changed column in the data | Open the report: it names the last step that worked |
| You do not know what is wrong | Many things can break after a change of year, settings or input | Run `Rscript scripts/check_setup.R` first. It names the file, setting or column. |
| It is slow | Reading big Excel files takes a few minutes | This is normal for now |
| A package cannot be installed | No internet, or an old R | Update R, or ask IT |

More detail on the reports: [docs/diagnostics.md](docs/diagnostics.md).

**For debugging, new settings, a new year, or a new colleague** (also one who works with an AI assistant): read [docs/debugging.md](docs/debugging.md). It has the list of error messages we know, the places where a year is written into the code, how to look inside a script (`arr_debug()`), and how to prove that a change did not alter the results (`scripts/compare_outputs.R`). AI assistants should start with [AGENTS.md](AGENTS.md).

------------------------------------------------------------------------

## 12. What is in the folders

```         
AnnualResultsReport/
├─ config.example.yml        settings template (copy to config.yml)
├─ cr_main.R, pr_main.R      run the whole CR or PR flow
├─ integrated_flow.R         cleaning + checks of CR and PR
├─ scripts/
│   ├─ run_cleaning.R        cleaning + report        (Option A)
│   ├─ run_checks.R          checks + report          (Option A)
│   ├─ check_setup.R         checks settings, inputs and years before a run
│   ├─ compare_outputs.R     did a change alter the results?
│   ├─ prep_env.R            loads settings, packages and functions
│   ├─ cr/  pr/  mne/        the scripts of each flow: cleaning, checks, analysis
├─ R/                        run reports, setup check, debug mode, output comparison
├─ functions/                helper functions (analysis tables, Google Drive download)
├─ templates/                empty examples of the files you prepare
├─ docs/                     the documentation (see "Read more" below)
├─ AGENTS.md                 guide for AI assistants (CLAUDE.md points to it)
├─ .githooks/pre-commit      stops a commit that holds data, passwords, e-mails or real GRNs
├─ .sensitive-patterns.example  words that must never be committed (copy to .sensitive-patterns)
├─ data/
│   ├─ input/                your input files (not on GitHub)
│   ├─ cleaned/              cleaned data (not on GitHub)
│   └─ output/               checks, analysis and reports (not on GitHub)
└─ requirements/             list of the R packages
```

------------------------------------------------------------------------

## 13. What this project does not do (yet)

- It does not run the Combiner. Run the Combiner first: it puts the files in `data/input/`.
- The analysis step does not write a run report.
- Everything runs one step after the other, so a full run takes several minutes.
- The checks are not sent to Airtable any more. The Excel files and the checks report are the result.

------------------------------------------------------------------------

## 14. For developers: changing the code

You can change the code, but follow a few rules, because the Excel files are used by other people and the data is confidential. The short version:

-   **Never change the format of the Excel outputs** (sheets, columns, order).
-   **No year, grant number (GRN), name or path in the code.** Use `config.yml`.
-   **No data and no passwords in the repository.** Turn on the commit check once: `git config core.hooksPath .githooks`.
-   **Make the smallest change that works,** and add a `trace_step()` after any step that can change the number of rows.
-   **Prove that nothing else changed:** run before and after, then `Rscript scripts/compare_outputs.R <before> <after>`. The results must be `IDENTICAL`.

[docs/development.md](docs/development.md) has the details: how a script is built, how to test a change, and step-by-step recipes (add a setting, a check, an analysis table, a new year, more reporting windows, a change of the MnE tracker). If you work with an AI assistant, give it [AGENTS.md](AGENTS.md) first.

------------------------------------------------------------------------

## Read more

| Document | Read it to... |
|----|----|
| [The run reports](docs/diagnostics.md) | understand the cleaning report and the checks report |
| [Debugging](docs/debugging.md) | find out what is wrong when a run fails, handle a new setting or a new year, and work with an AI assistant |
| [For developers](docs/development.md) | change the code safely and test the change |
| [Glossary](docs/glossary.md) | look up a word used in this project |
| [AGENTS.md](AGENTS.md) | brief an AI assistant before it works on the code |
| `templates/` | start the files you prepare by hand |
