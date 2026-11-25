# The MnE reports tracker

This page explains, in plain English, **what the MnE tracker is, where this project uses it, and what to do when it changes.** Read it before you touch anything that reads the tracker. Next year the tracker will be tackled again: the plan is in [`developers/todo_next_year.R`](../developers/todo_next_year.R).

## What it is

The MnE reports tracker is an Excel file kept by Grants Management. It has **one row for each report** that a grant has to send. For every report it says, among other things, if the report was **approved**.

This project uses it for one purpose: **to check only the programmes whose reports are approved.** A programme that is not in the tracker, or whose report is not yet received, is not checked.

The tracker is **not a Combiner file**. It is not made by this project, and the project never changes it. It is not in the repository: it is confidential data.

## Where the project finds it

Two settings in `config.yml` say where it is:

| Setting | What it is | Example |
|----|----|----|
| `mne_approval` | The tracker file: a name in `data/input/`, or the full path (for example on a shared drive) | `mne_tracker.xlsx` |
| `sheet_mne` | The sheet of the tracker to read | `Results_Reports_Auto` |

## What the sheet must look like

-   **A header row, with some empty rows above it.** In the 2025 tracker there are 6 empty rows, and the column names are in row 7.
-   **These columns must exist** (the spelling counts, also the spaces):

| Column | Used for |
|----|----|
| `Programme ID` | The link to the CR and PR data (`ProgrammeID`) |
| `GM Status` | Is the report approved? `Completed` and `Waived` count as approved. Anything else (for example `Not yet Received`) does not. |
| `GM GRN` | The grant of the report (becomes `GMGRN`) |
| `Type of investment` | `AF` rows are removed |
| `Start date`, `Current end date` | Used to flag the programmes active in the strategic plan |
| `Grantee organization`, `M&E focal person` | Carried through, renamed |

The other columns are carried through and not used.

## Where each script uses it

The tracker is read in **seven places** (the cleaning and six check scripts), in two different ways.

| Script | What it does with the tracker |
|----|----|
| `scripts/mne/mne_cleaning.R` (run by `run_cleaning.R mne`) | Reads the sheet (starting at row 4, empty rows are skipped). Removes the spaces from the column names. **Removes the `AF` rows.** Adds `ActiveStrategicPlan` from the dates and the settings `strategic_plan_start` and `strategic_plan_end`. Saves `data/cleaned/MnE Report Tracker.csv`. It keeps **all** statuses, not only the approved ones. |
| `cr_data_checks.R`, `cr_data_checks_new.R`, `cr_numbers_checks_reached.R`, `cr_numbers_checks_targeted.R`, `pr_data_checks.R`, `pr_number_checks.R` | Read the **original** tracker again (skipping 6 rows). Keep the rows with `GM Status` = `Completed` or `Waived`. Then keep only the CR or PR rows whose `ProgrammeID` is in that list. **This is what limits the checks to approved programmes.** |
| `cr_data_checks_new.R`, `pr_data_checks.R` | Also read the **cleaned** file (`MnE Report Tracker.csv`) to list the programmes and grants that are in the tracker. They compare this list with the GMS and with the CR / PR data (for example "in the tracker but not in the CR"). |

**The analysis does not read the tracker.** The CR and PR analysis tables use all programmes that are active in the strategic plan, approved or not. Only the checks are limited to approved programmes.

**Without the tracker the checks stop.** The cleaning of CR and PR still works.

## Things to know

-   **The tracker changes.** Its layout and its name have changed in earlier years. The code reads it in two different ways (row 4, and skip 6), and the approved statuses are written in the code as text. A new tracker can therefore break the checks.
-   **`Rscript scripts/check_setup.R` tests the tracker.** It reads the header in both ways, and checks that the columns above exist. Run it first when you get a new tracker.
-   **A tracker with all programmes "Completed" hides problems.** The checks would treat every programme as approved. Never use a test tracker for a real run.

## Testing without the real tracker

The real tracker is confidential, and the new one may not exist yet. To test the whole flow, you can make a **synthetic tracker**. It is built from your own `grants_db.csv`, so that the programme numbers match the data, and every other value is made up:

``` bash
Rscript developers/make_synthetic_mne_tracker.R
```

It writes `data/input/mne_tracker_SYNTHETIC.xlsx`. In cell A1 it says that it is synthetic. About 80% of the programmes are `Completed`, some are `Waived`, and a few are `Not yet Received`, so that the filters have something to do. A few `AF` rows are added so that the removal of `AF` is tested too. To use it, set `mne_approval: "mne_tracker_SYNTHETIC.xlsx"` in `config.yml`. The script never overwrites an existing file, and the file stays on your computer (the folder `data/input/` is not committed).

What the synthetic tracker **can** test: that the code runs from start to end, that the layout is read, and that the status filter works. What it **cannot** test: a real change in the layout or the names of the real tracker. That needs the real file.

### A test run with the synthetic tracker (25 November 2026)

The whole flow was run on the real **2026** Combiner files with a synthetic tracker, with the settings of the 2026 cycle (`report_year` 2026, `annual` 12, `cumulative` 13):

-   `check_setup.R`: 30 OK, 0 FAIL. Both ways of reading the tracker found the header.
-   **Cleaning:** CR 491,104 rows; PR 92,303 rows, 88,609 after removing the rows without a number; tracker 57 rows, 54 after removing the 3 `AF` rows. The report said "nothing needs attention": the labels `ARR26`, `CR26` and `PR26` were understood without any change in the code.
-   **Checks:** all CR and PR workbooks were written. The status filter kept the approved programmes only (the PR rows went from 88,609 to 56,381). One real weakness was found and fixed: `pr_data_checks.R` stopped when no row had the unit "Percentage %".
-   **Analysis:** all CR and PR tables were written. The file name follows the year by itself (`Program Results - Annual Active in 2026.xlsx`).
-   **Time:** the CR cleaning took about 7 minutes, almost all of it reading the Excel file; the PR cleaning about 1.5 minutes.

The numbers of the checks come from a **made-up** approval list, so they say nothing about the real 2026 results. The test only shows that the code runs.

## What to do when the new tracker arrives

The full plan is in [`developers/todo_next_year.R`](../developers/todo_next_year.R). In short:

1.  Put the new file in place and run `Rscript scripts/check_setup.R`. Read what it says about the header and the columns.
2.  Find the row of the header and the names of the columns `Programme ID` and `GM Status` (they may have changed).
3.  Decide which statuses mean "approved" this year.
4.  Change the code in **all seven places** (or, better, replace them by one reading function: this is the main to-do of the plan).
5.  Run the cleaning and the checks. Compare the results with a run on the synthetic tracker (`scripts/compare_outputs.R`): only the expected differences should appear.
