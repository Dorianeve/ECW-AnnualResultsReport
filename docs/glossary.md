# Glossary

Short explanations of the words used in this project, in alphabetical order.

| Word | What it means |
|----|----|
| **AF** | Aligned funding. It is a Combiner table. It is not used by this project, and AF programmes are removed from the data. |
| **Analysis** | The last step of a flow. It makes the tables for the report from the cleaned and checked data. |
| **Analysis code** | A short code for an indicator in the PR data, for example `e46_drr`. The file `priority_grn_codes.xlsx` says which codes are used. |
| **Annual** | One of the two "exercises". The numbers of one year only. See **Exercise**. |
| **ARR** | Annual Results Report. In a name like `ARR25` the number is the last two digits of the year. |
| **Attention point** | A line in a run report that you should look at. |
| **Cache / cleaned file** | The csv files in `data/cleaned/`. The cleaning writes them, and the checks and the analysis read them. They are overwritten at every run. |
| **Checks** | The step that looks for problems in the cleaned data. It writes Excel files with the problems. There are **data checks** (gaps and mistakes) and **number checks** (do the numbers add up). |
| **Cleaning** | The first step of a flow. It makes the Combiner file tidy: names, dates, labels, codes. |
| **Combiner** | The partner project. It builds the CR and PR files that this project reads. Download both projects side by side. |
| **`config.yml`** | Your settings file. It is a plain text file with lines like `report_year: "2025"`. It is never committed. |
| **CR** | Children reached. A flow, and the Combiner file with the numbers of children targeted and reached. |
| **Cube** | A sheet in a check file. For each programme or grant it shows `TRUE` (problem) or `FALSE` for every check. |
| **Cumulative** | One of the two "exercises". The numbers from the start of the grant up to that year. See **Exercise**. |
| **Debug mode** | `arr_debug()`. The scripts keep their objects, so you can look inside after a run. |
| **Exercise** | A label that says if a row belongs to the **Annual** or the **Cumulative** report of a year, for example `ARR25 Annual`. |
| **`exercice`** | The number made from the Exercise label, for example 10 for `ARR25 Annual` and 11 for `ARR25 Cumulative`. The settings `annual` and `cumulative` hold the numbers of the current year. |
| **ExCom** | The Executive Committee that approves the grants. |
| **Flow** | The set of steps for one Combiner file: the CR flow and the PR flow. |
| **GMGRN** | The grant reference number of one grantee. |
| **GMS** | The grants management system. It holds the list of grants, their dates and their partners. The list is called `grants_db.csv` here. |
| **GRN** | Grant reference number, with parts for the year, the fund, a number, the country and the organisation (written like `NN-ECW-XXX-NN-XXX-AAA`). Real GRNs never go in the code or the docs. |
| **Hand-over** | The copy of `cr_clean.xlsx`, `pr_clean.xlsx` and `grants_db.csv` from the Combiner into `data/input/` of this project. The Combiner does it after every run. |
| **Individual / Joint reporting** | In CR, grantees of a programme can report together (Joint) or each one alone (Individual). |
| **Issue** | A problem found by a check. In the log of decisions, the column `Issue` holds the name of the check. |
| **Lead grantee** | The main organisation of a programme. Its grant number is the **LeadGRN**. |
| **Level** | In the priority file: what an analysis code counts (Child, Teacher, School, Caregiver, Policy). |
| **Log of decisions** | The file `log_decisions.xlsx`. Issues written in it are accepted and are hidden from the check files. |
| **M&E / MnE** | Monitoring and evaluation. |
| **MnE tracker** | The Excel file of Grants Management that says which reports are approved. Only approved (or waived) programmes are checked. |
| **Patch** | A small script (`cr_patch.R`, `pr_patch.R`) that prepares the data for the analysis, for example by leaving out some LeadGRNs. |
| **PR** | Programme results. A flow, and the Combiner file with the results of each programme, by indicator. |
| **Pre-commit hook** | A small program (`.githooks/pre-commit`) that runs before every Git commit and stops it if it finds data, a password, an e-mail address, a personal path or a real GRN. |
| **Priority** | The column in `priority_grn_codes.xlsx` that decides which analysis codes are used: only `1` counts. |
| **Programme** | A group of grants that work together. It has a `ProgrammeID`. |
| **Reached / Targeted** | The two kinds of numbers in CR. Children reached so far, and children planned to be reached. |
| **Reporting window (RW)** | A period for which a report is due, for example `RW1`. |
| **Row trace** | A list of how many rows there are after each step. It shows where rows are lost. |
| **Run report** | The `report.md` that the cleaning and the checks write. It shows what changed since the last run and what went wrong. |
| **Setup check** | `Rscript scripts/check_setup.R`. It tests your settings, your input files and your years before you run anything. |
| **Source of data (`Sourceofdata`)** | A label in the data that says which year's report a row comes from, for example `CR25` or `PR25`. |
| **Strategic plan** | The multi-year plan of ECW. A programme is "active in the plan" if its dates overlap the plan (settings `strategic_plan_start` and `strategic_plan_end`). |
| **Summary** | A sheet in a check file with the list of problems, one row for each problem. |
| **Template** | Two meanings. (1) The Excel file that grantees fill in. (2) The empty example files in the folder `templates/` of this project. |
| **Trace step** | A line `trace_step(df, "text")` in a script. It records the number of rows at that point for the row trace. |
| **YAML** | The simple format of `config.yml`: one `name: value` on each line. |
