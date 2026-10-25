# CI Status

A small always-on-top Windows desktop widget that shows the state of your GitHub Actions runs, so you can see whether a push is still building, finished green or failed without opening GitHub.

- Latest runs across the repositories you watch, newest first, with a coloured dot: yellow = running (with elapsed time and `jobs done/total`), green = success, red = failed, grey = cancelled/skipped/queued.
- Header summary: `N running`, `Failing` (the latest run of some workflow failed) or `All green`.
- When a run that was running finishes, a line at the top announces it for a minute.
- **Usage tab** (next to Runs): this month's GitHub Actions usage from the billing API (`gh api users/<you>/settings/billing/usage/summary`, needs the `user` scope on your `gh` login). A bar compares the minutes used with your quota, and a white marker shows how far through the month you are, so you can see at once whether you are ahead of or behind pace. Below it: what is billable, a forecast for the whole month (minutes and dollars), a bar chart of minutes per day, minutes per repository, and an **All services** list with one row per service, also when nothing was used: Actions, Packages, Git LFS, Codespaces and AI credits (all Copilot / premium request SKUs, read from the premium request report). Each row shows the quantities and what is billable; anything else GitHub reports ends up under Other. If you set a monthly budget, a second bar shows spending against it.
- Quota and budget: GitHub does not give out budgets or spending limits for personal accounts through the API, so you enter them yourself (right-click, *Set minutes quota…* and *Set monthly budget…*, `0` clears). Without a quota the bar uses what the plan includes: exact once the included minutes are used up, otherwise `actionsIncluded` in `config.json` (default 2000). GitHub reports usage with a delay of an hour or more. A link at the bottom of the full widget opens your GitHub billing overview (github.com/settings/billing/summary).
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

This repository is private, so the "Update the widget" menu item fetches the installer through `gh`:

```powershell
gh api repos/saysphilippe/CIStatus/contents/install.ps1 -H "Accept: application/vnd.github.raw" | iex
```

## Use

Right-click the widget:

| Item | What it does |
| --- | --- |
| Refresh now | Reads GitHub right away |
| Minimize | Shrinks to only what is running |
| Set minutes quota… | Your monthly limit in Actions minutes, for the Usage tab |
| Set monthly budget… | Your monthly budget in dollars, for the Usage tab |
| Add repository… | Watch another repository (`owner/name`) |
| Remove repository | Stop watching one |
| Update the widget | Installs the latest version from GitHub |
| Always on top | Toggle |
| Language | English / Norsk / Svenska / Dansk |

By default it watches `saysphilippe/Nerdehagen`. The list, the number of runs per repository (`perRepo`, 5), the maximum number of rows (`maxRows`, 8), the quota (`quotaMinutes`) and the budget (`budgetUsd`) are stored in `%LOCALAPPDATA%\CIStatus\config.json`.

## Uninstall

`Uninstall.cmd`, or `%LOCALAPPDATA%\CIStatus\uninstall.ps1`. Settings are kept in `%LOCALAPPDATA%\CIStatus\config.json`; delete the folder to remove them too.

## Notes for development

- `CIStatus.ps1` must be saved as UTF-8 **with** BOM (Nordic letters); `install.ps1` must stay ASCII without BOM (it runs through `iex`).
- `gh` runs as a .NET process whose output is read by `ReadToEndAsync` tasks; a `DispatcherTimer` collects the results. No PowerShell runs on background threads.
- `CISTATUS_USAGE_FIXTURE` can point to a JSON file `{ "summary": ..., "items": [...] }` (the two billing responses) for the Usage tab.
- `CISTATUS_FIXTURE` can point to a JSON file with runs to show instead of calling `gh`, which is handy for checking the layout.
