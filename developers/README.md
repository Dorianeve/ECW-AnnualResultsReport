# For developers and AI assistants

This folder holds the notes for the people (and AI assistants) who work on the **code**. Nothing here is needed to run the project.

| File | What it is |
|----|----|
| [`AGENTS.md`](AGENTS.md) | The brief for an AI assistant: what the project is, the commands, the rules that must not be broken, and the surprises. **Give it to the assistant first.** (`CLAUDE.md` only points to it, for Claude Code.) |
| [`todo_next_year.R`](todo_next_year.R) | The plan for next year: the MnE tracker. Run it with `Rscript developers/todo_next_year.R` to see the checklist and a self-test of a draft reader. |
| [`make_synthetic_mne_tracker.R`](make_synthetic_mne_tracker.R) | Makes a **made-up** MnE tracker for test runs. Never use it for a real run. |

Where the rest is:

| Page | Read it to... |
|----|----|
| [`docs/development.md`](../docs/development.md) | change the code safely: the rules, how a script is built, how to test a change, recipes |
| [`docs/debugging.md`](../docs/debugging.md) | find out what is wrong when a run fails |
| [`docs/mne-tracker.md`](../docs/mne-tracker.md) | know how the MnE tracker is used |
| [`docs/diagnostics.md`](../docs/diagnostics.md) | read the cleaning and the checks reports |
| [`docs/glossary.md`](../docs/glossary.md) | look up a word |

**If you use Claude Code:** it loads `CLAUDE.md` from the folder where it starts. This file is in `developers/`, so either start it here, or tell it: "Read `developers/AGENTS.md` first".
