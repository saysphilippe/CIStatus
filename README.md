# CI Status

A small always-on-top Windows desktop widget that shows the state of your GitHub Actions runs, so you can see whether a push is still building, finished green or failed without opening GitHub.

- Latest runs across the repositories you watch, newest first, with a coloured dot: yellow = running (with elapsed time and `jobs done/total`), green = success, red = failed, grey = cancelled/skipped/queued.
- Header summary: `N running`, `Failing` (the latest run of some workflow failed) or `All green`.
- When a run that was running finishes, a line at the top announces it for a minute.
- **Usage tab** (next to Runs): this month's GitHub Actions usage from the billing API (`gh api users/<you>/settings/billing/usage/summary`, needs the `user` scope on your `gh` login). It opens with a bar chart of usage per day and an **All services** list (with what is billable this month in the heading) with one row per service, also when nothing was used: Actions, Packages, Git LFS, Codespaces and AI credits (all Copilot / premium request SKUs, read from the premium request report). Each row shows the quantities and what is billable against that service's monthly budget, with a small bar and the same month marker. **Click a row and the bar chart (usage per day, in the service's own unit) and the per-repository list switch to that service.** Anything else GitHub reports ends up under Other. 
- **E2E tab** (next to Usage): starts the manual `E2E (manuelt)` workflow in the first watched repo (`e2eRepo` in `config.json` overrides it) with `gh workflow run e2e.yml -f tests=...`. Three buttons: **Relevant tests** (the tests that belong to the files changed in the last commit), **All tests** (split into 4 parts) and **Choose tests...** (a window with a check box and a short description per test, read from `tests/e2e/oversikt.json` in the repo; ticking everything runs all of them). The run then shows up on the Runs tab like any other run. Needs `gh` logged in with permission to run workflows.
- Budgets: GitHub does not give out budgets or spending limits for personal accounts through the API, so they are stored in the widget, one monthly budget per service (right-click, *Budget per service*, `0` clears). The budgets start out as the ones on github.com/settings/billing/budgets when they were read on 2026-10-25: Actions $10, Packages $10, Git LFS $5, Codespaces $5, AI credits $5. GitHub reports usage with a delay of an hour or more. A link at the bottom of the full widget opens your GitHub billing overview (github.com/settings/billing/summary).
- Minimize with the dash in the corner (or right-click, Minimize): a small pill that shows only the runs that are running, with elapsed time and jobs done. With nothing running it is a single dot, green (all green) or red (failing). Click the pill to bring the full list back; the pill remembers its own position.
- Click a run to open it on GitHub. Drag the widget anywhere; the position is remembered.
- Refreshes every 30 seconds, every 10 seconds while something is running.
- Languages: English, Norwegian, Swedish, Danish (right-click, Language).

It is PowerShell 5.1 + WPF, no dependencies besides the [GitHub CLI](https://cli.github.com/) (`gh`), which must be signed in (`gh auth login`). The widget only reads (`gh run list`, `gh run view`).

## Install

From a downloaded copy:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

or double-click `Install.cmd`. The installer asks for a language (set `CISTATUS_LANG` to `en`, `no`, `sv` or `da` to skip the question), installs to `%LOCALAPPDATA%\CIStatus`, adds a **CI Status** shortcut on the Desktop and in Startup, and starts the widget. Settings are kept when you install again.

You do not need `install.ps1` on disk: install or update straight from GitHub with

```powershell
irm https://raw.githubusercontent.com/saysphilippe/CIStatus/main/install.ps1 | iex
```

The widget also checks GitHub for a newer version at start-up and every six hours (it compares itself with `CIStatus.ps1` on the `main` branch). When there is one, an amber line **New version available – click to update** appears at the bottom; clicking it, or *Update the widget* in the right-click menu, runs the installer above and restarts the widget with your settings kept.

## Use

Right-click the widget:

| Item | What it does |
| --- | --- |
| Refresh now | Reads GitHub right away |
| Minimize | Shrinks to only what is running |
| Budget per service | Monthly budget in dollars for Actions, Packages, Git LFS, Codespaces and AI credits |
| Add repository… | Watch another repository (`owner/name`) |
| Remove repository | Stop watching one |
| Update the widget | Installs the latest version from GitHub |
| Always on top | Toggle |
| Language | English / Norsk / Svenska / Dansk |

By default it watches `saysphilippe/Nerdehagen`. The list, the number of runs per repository (`perRepo`, 5), the maximum number of rows (`maxRows`, 8), the budgets (`budgets`) and the selected service (`usageSel`) are stored in `%LOCALAPPDATA%\CIStatus\config.json`.

## Uninstall

`Uninstall.cmd`, or `%LOCALAPPDATA%\CIStatus\uninstall.ps1`. Settings are kept in `%LOCALAPPDATA%\CIStatus\config.json`; delete the folder to remove them too.

## Notes for development

- `CIStatus.ps1` must be saved as UTF-8 **with** BOM (Nordic letters); `install.ps1` must stay ASCII without BOM (it runs through `iex`).
- `gh` runs as a .NET process whose output is read by `ReadToEndAsync` tasks; a `DispatcherTimer` collects the results. No PowerShell runs on background threads.
- `CISTATUS_USAGE_FIXTURE` can point to a JSON file `{ "summary": ..., "items": [...] }` (the two billing responses) for the Usage tab.
- `CISTATUS_FIXTURE` can point to a JSON file with runs to show instead of calling `gh`, which is handy for checking the layout.
