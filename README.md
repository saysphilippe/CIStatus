# CI Status

A small always-on-top Windows desktop widget that shows the state of your GitHub Actions runs and your Cloudflare builds and deployments (several Cloudflare accounts at once), so you can see whether a push is still building, finished green or failed without opening GitHub or Cloudflare.

- Latest runs across the repositories you watch, newest first, with a coloured dot: yellow = running (with elapsed time and `jobs done/total`), green = success, red = failed, grey = cancelled/skipped/queued.
- Header summary: `N running`, `Failing` (the latest run of some workflow failed) or `All green`.
- When a run that was running finishes, a line at the top announces it for a minute.
- **Several accounts side by side, so work and private can be kept apart:** several GitHub logins (gh accounts) and several Cloudflare accounts at the same time. Every row carries a small coloured label with the source and the name you gave the account (`GH · Work`, `CF · Private`), the Runs tab has a filter row (All, then one chip per account, with a red or yellow dot where something is failing or running), the room in the list is shared between the accounts so a busy one cannot push the others out, and the header says where it is going on (`1 running · Work`, `Failing · Private`). See [Accounts](#accounts-github-and-cloudflare).
- **Several Cloudflare accounts** (for example work and private) next to GitHub: builds from Workers Builds and the latest deployment of each Worker show up as rows on the Runs tab, marked with the account's name. The Usage tab gets a switch (GitHub, then one entry per account) with today's Workers requests, D1 rows read and written and Workers AI neurons against the Workers Free daily allowance. See [Cloudflare accounts](#cloudflare-accounts).
- **Usage tab** (next to Runs): this month's GitHub Actions usage from the billing API (`gh api users/<you>/settings/billing/usage/summary`, needs the `user` scope on your `gh` login). It opens with a bar chart of usage per day and an **All services** list (with what is billable this month in the heading) with one row per service, also when nothing was used: Actions, Packages, Git LFS, Codespaces and AI credits (all Copilot / premium request SKUs, read from the premium request report). Each row shows the quantities and what is billable against that service's monthly budget, with a small bar and the same month marker. **Click a row and the bar chart (usage per day, in the service's own unit) and the per-repository list switch to that service.** Anything else GitHub reports ends up under Other. 
- **E2E tab** (next to Usage): starts the manual `E2E (manuelt)` workflow in the first watched repo (`e2eRepo` in `config.json` overrides it) with `gh workflow run e2e.yml -f tests=...`. Three buttons: **Relevant tests** (the tests that belong to the files changed in the last commit), **All tests** (split into 4 parts) and **Choose tests...** (a window with a check box and a short description per test, read from `tests/e2e/oversikt.json` in the repo; ticking everything runs all of them). Below the buttons the tab lists the latest runs of the workflow (see *Which tests are running* below). The run also shows up on the Runs tab like any other run. Needs `gh` logged in with permission to run workflows.
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
| Sub-tabs | Hide the chip you right-clicked (and its content), show one again, or show all hidden ones (see *Hide sub-tabs*) |
| Budget per service | Monthly budget in dollars for Actions, Packages, Git LFS, Codespaces and AI credits |
| Add repository… | Watch another repository (`owner/name`) |
| Remove repository | Stop watching one |
| Update the widget | Installs the latest version from GitHub |
| Always on top | Toggle |
| Language | English / Norsk / Svenska / Dansk |

The **Cloudflare accounts** submenu adds and removes accounts (see below).

By default it watches `saysphilippe/Nerdehagen`. The list, the number of runs per repository (`perRepo`, 5), the maximum number of rows (`maxRows`, 8), the budgets (`budgets`) and the selected service (`usageSel`) are stored in `%LOCALAPPDATA%\CIStatus\config.json`.

## Accounts (GitHub and Cloudflare)

With more than one account the widget shows which one every row belongs to. With only one account nothing changes: no labels and no filter row.

- **Label on every row:** a small coloured box in front of the grey text, `GH · <name>` for GitHub and `CF · <name>` for Cloudflare. Each account keeps its own colour (in the order the accounts are listed). The same colours are used on the filter row and on the source switch of the Usage tab.
- **Filter row (Runs tab):** *All*, then one chip per account. A red dot on a chip means the latest run of some workflow there failed, a yellow dot that something is running. Click a chip to see only that account; the choice is remembered.
- **Room in the list:** the list holds `maxRows` rows (8). What is running comes first, then what is failing now, then the accounts get an equal share (8 rows and 4 accounts is 2 each), and the rest is filled with the newest.
- **Header and minimized pill:** the summary counts all accounts, also the ones the filter hides (but not an account you have hidden, see *Hide sub-tabs*), and names where: `1 running · Work`, `Failing · Private` (the first account, then `+N`). The minimized pill puts the account in front of each running line.
- **When a run finishes** the line at the top starts with the account.

### GitHub: several logins

`gh` can be signed in to several GitHub accounts at once (for example a work and a private one). The widget reads each repository with the login it belongs to, without ever switching the active account: for that one call it takes the account's token from `gh auth token --user <login>` and hands it to that one `gh` process. The token is not stored by the widget.

1. Right-click, **GitHub accounts**, **Sign in another account…**. A window opens where `gh auth login` runs in your browser (scopes `repo`, `workflow`, `read:org` and `user`). When it is done, close the window and choose **Refresh accounts**. The widget also asks `gh` who is logged in every five minutes.
2. **Rename account** gives each login a name such as `Work` or `Private`; that is what the labels show (the login is the name until you change it).
3. **Add repository…** asks which account reads the repository. Repositories that were already watched belong to the account that was active when you updated.
4. The **Usage** tab has one entry per GitHub account (the billing of that user), next to the Cloudflare accounts. If GitHub refuses the billing call, the message names the command for that login: `gh auth refresh -h github.com -u <login> -s user`.
5. If a repository belongs to a login that `gh` no longer knows, the widget says so instead of reading with another account.

Billing is read per **user**. An organisation's billing is not read; a work account that is a member of an organisation shows the work user's own billing.

## Cloudflare accounts

The widget can read any number of Cloudflare accounts at the same time, each with its own API token. Nothing is changed on Cloudflare: it only makes `GET` calls and one read-only GraphQL analytics query.

1. In each Cloudflare account, create a token at <https://dash.cloudflare.com/profile/api-tokens> (Create Token, Custom token) with **Read** access to **Workers Scripts**, **Workers Builds Configuration**, **Account Analytics** and **Account Settings**, limited to that account.
2. Right-click the widget, **Cloudflare accounts**, **Add account…**. Type a name (for example `Work` or `Private`) and paste the token. The widget checks it by listing the accounts the token can see; a token that sees several accounts adds all of them.
3. **Rename account** in the same submenu changes the name later (labels, filter chips and the Usage tab follow). **Remove account** removes one again.

What it shows:

- **Runs tab:** the newest build per Worker from Workers Builds (yellow = running or queued, green = success, red = failed) and the latest deployment of each Worker (`deployed via wrangler`, `dash` or `api`). A deployment that is the result of a successful build gets no row of its own. Anything that is running always shows; of the rest only the newest `cfPerAccount` rows per account (3) are kept, and the list is cut to `maxRows` together with the GitHub runs. Click a row to open the Worker in the Cloudflare dashboard. A missing permission shows up as a red line saying which permissions to check.
- **Usage tab:** a switch at the top (GitHub, then each account). For a Cloudflare account it shows today's use (the Cloudflare day starts 00:00 UTC, shown in your local time, e.g. "01:00 CET") of Workers requests (100,000 a day), D1 rows read (5 million) and written (100,000) and Workers AI neurons (10,000), with a bar against the **Workers Free daily allowance**. Yellow from 80 %, red at 100 %. On a paid plan the bars are only a reference, since the paid plan has other limits. The numbers come from Cloudflare's analytics and run a few minutes behind.

Where the token lives: encrypted with Windows DPAPI (the same Windows user on the same machine can decrypt it, nobody else) in `%LOCALAPPDATA%\CIStatus\config.json`. It is not in this repository and is never shown again. Copying `config.json` to another computer or user does not carry the accounts over; add them again there. Deleting an account's entry (or the whole config) removes the token from the machine; to revoke it for good, delete the token in the Cloudflare dashboard.

## Uninstall

`Uninstall.cmd`, or `%LOCALAPPDATA%\CIStatus\uninstall.ps1`. Settings are kept in `%LOCALAPPDATA%\CIStatus\config.json`; delete the folder to remove them too.

## Notes for development

- `CIStatus.ps1` must be saved as UTF-8 **with** BOM (Nordic letters); `install.ps1` must stay ASCII without BOM (it runs through `iex`).
- Several accounts can be tested without real logins: `CISTATUS_FIXTURE` rows are placed on accounts by `repo` through `repoAcct` in `config.json`, and `CISTATUS_CF_FIXTURE` rows carry `acctKey` (`cf:<id>`). In fixture mode `gh` is not asked who is logged in.
- Test without real tokens: `CISTATUS_CF_FIXTURE=<json>` (accounts, runs, usage per account id) shows Cloudflare rows and usage without any network call, like `CISTATUS_FIXTURE` does for GitHub. `CISTATUS_CF_API=http://127.0.0.1:<port>` points the Cloudflare calls at a local stub (only a local address is accepted).
- `gh` runs as a .NET process whose output is read by `ReadToEndAsync` tasks; a `DispatcherTimer` collects the results. No PowerShell runs on background threads.
- `CISTATUS_USAGE_FIXTURE` can point to a JSON file `{ "summary": ..., "items": [...] }` (the two billing responses) for the Usage tab.
- `CISTATUS_FIXTURE` can point to a JSON file with runs to show instead of calling `gh`, which is handy for checking the layout.

## Tabs

Drag a tab sideways to move it; the order is kept. A click without moving still opens the tab.

The account chips (the filter row on Runs and the source row on Usage) can be dragged into another order the same way. The order is shared by both rows; the colour stays with the account.

## E2E per repository and account

With more than one watched repository, the E2E tab has a chip per repository, marked with the GitHub account it is read with. The tests start in the chosen repository with that account's login, and the list behind **Choose tests…** is read per repository.

## Which tests are running

The E2E tab does not only start the tests, it shows them. For each of the latest runs of `e2e.yml` (and, under the run, on the Runs tab) it shows:

- **What was chosen:** the run is named `E2E · <choice>` (`run-name`), and the *plan* job leaves a notice annotation titled `e2e-valg` with the files (or `alle`). The line reads `Tests: kunde, a11y`.
- **How far it has come:** `47/121 tests · 1 failed` with a thin bar (green when everything passed, red with failures), summed over all parts.
- **The parts:** one dot per part (`Part 1 47/121`), yellow while it runs, green or red when done, `waiting` before it starts.
- **What runs right now:** up to four lines `▶ kunde · title (1280)`, the tests the workers are on at this moment.

GitHub does not hand out the log of a job that is still running, so the numbers come from a check run, `e2e-live <run id> <part>`, that the test reporter in the repo (`tests/helpers/ci-progress-reporter.mjs`) keeps up to date on the commit while the tests run (every five seconds at most). Its `output.text` is JSON: `{ total, done, failed, running: ["<project> | <file> | <title>"] }`. The check ends as *neutral*, so it never turns the commit red. The workflow needs `checks: write`, and the repo must have the reporter; without it the tab still shows the choice and the parts. The widget reads the runs every ten seconds while something runs; a finished run is read once and kept. The minimized pill adds the count (`jobs 2/5 · 228/362 tests`).

## Hide sub-tabs

The chip rows are the sub-tabs: the accounts on the Runs tab, the source on the Usage tab and the repository on the E2E tab. Right-click a chip, **Sub-tabs**, **Hide “name”**; or right-click anywhere, **Sub-tabs**, **Choose sub-tabs to hide…**, which opens a list with a check box for every sub-tab (grouped as Runs: accounts, Usage: sources and E2E: repositories). Tick what you want to hide and press OK. The chip **and its content** go: the runs of a hidden account are not listed, not counted in the header and not in the minimized pill, and a hidden source or repository is skipped. If the hidden one was selected, the view moves to the next one (Runs: *All*). The last sub-tab in a row cannot be hidden.

It stays hidden, also after a restart, until you show it again: a small amber **+N** appears at the right of the tabs (click it to show everything), and right-click, **Sub-tabs** lists each hidden one (**Show “name”**) and **Show all hidden**. The choice is kept as `hiddenSubs` in `config.json` (`flt:<account>`, `src:<account>`, `e2erepo:<repo>`).
