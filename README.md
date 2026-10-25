# CI Status

A small always-on-top Windows desktop widget that shows the state of your GitHub Actions runs, so you can see whether a push is still building, finished green or failed without opening GitHub.

- Latest runs across the repositories you watch, newest first, with a coloured dot: yellow = running (with elapsed time and `jobs done/total`), green = success, red = failed, grey = cancelled/skipped/queued.
- Header summary: `N running`, `Failing` (the latest run of some workflow failed) or `All green`.
- When a run that was running finishes, a line at the top announces it for a minute.
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
| Add repository… | Watch another repository (`owner/name`) |
| Remove repository | Stop watching one |
| Update the widget | Installs the latest version from GitHub |
| Always on top | Toggle |
| Language | English / Norsk / Svenska / Dansk |

By default it watches `saysphilippe/Nerdehagen`. The list, the number of runs per repository (`perRepo`, 5) and the maximum number of rows (`maxRows`, 8) are stored in `%LOCALAPPDATA%\CIStatus\config.json`.

## Uninstall

`Uninstall.cmd`, or `%LOCALAPPDATA%\CIStatus\uninstall.ps1`. Settings are kept in `%LOCALAPPDATA%\CIStatus\config.json`; delete the folder to remove them too.

## Notes for development

- `CIStatus.ps1` must be saved as UTF-8 **with** BOM (Nordic letters); `install.ps1` must stay ASCII without BOM (it runs through `iex`).
- `gh` runs as a .NET process whose output is read by `ReadToEndAsync` tasks; a `DispatcherTimer` collects the results. No PowerShell runs on background threads.
- `CISTATUS_FIXTURE` can point to a JSON file with runs to show instead of calling `gh`, which is handy for checking the layout.
