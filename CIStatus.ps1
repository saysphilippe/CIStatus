# CI Status - desktop widget that shows the state of GitHub Actions runs (read through the GitHub CLI, gh)
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, Microsoft.VisualBasic, System.Net.Http

$dir     = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = $MyInvocation.MyCommand.Path
$cfgPath = Join-Path $dir 'config.json'
$inv     = [Globalization.CultureInfo]::InvariantCulture

$cfg = [ordered]@{ topmost = $true; left = 100; top = 100; language = 'en'; repos = @('saysphilippe/Nerdehagen'); perRepo = 5; maxRows = 8; minimized = $false; miniLeft = $null; miniTop = $null; tab = 'runs'; actionsIncluded = 2000; quotaMinutes = $null; budgets = $null; usageSel = 'Actions'; cfAccounts = @(); cfPerAccount = 3; usageSrc = 'github'; ghAccounts = @(); ghActive = ''; repoAcct = $null; runFilter = 'all' }
if (Test-Path $cfgPath) {
    try { (Get-Content $cfgPath -Raw | ConvertFrom-Json).psobject.Properties | ForEach-Object { $cfg[$_.Name] = $_.Value } } catch {}
}
# Monthly budgets in dollars per service; the defaults are the ones set on GitHub (Budgets and alerts)
$b = [ordered]@{ Actions = 10; Packages = 10; 'Git LFS' = 5; Codespaces = 5; AI = 5 }
if ($cfg.budgets -and $cfg.budgets -isnot [System.Collections.IDictionary]) { $cfg.budgets.PSObject.Properties | ForEach-Object { $b[$_.Name] = $_.Value } }
$cfg.budgets = $b
# Which GitHub login (a gh account) each watched repository is read with: repo -> login
$ra = @{}
if ($cfg.repoAcct -and $cfg.repoAcct -isnot [System.Collections.IDictionary]) { $cfg.repoAcct.PSObject.Properties | ForEach-Object { $ra[$_.Name] = [string]$_.Value } }
$cfg.repoAcct = $ra
function Save-Config { $cfg | ConvertTo-Json -Depth 5 | Set-Content $cfgPath -Encoding UTF8 }
function Get-Repos { @($cfg.repos | Where-Object { $_ }) }
# Something to read from: the GitHub CLI or at least one Cloudflare account
function Test-Sources { [bool]$gh -or (@(Get-CfAccounts).Count -gt 0) }

# ---------- accounts: GitHub logins (several gh accounts side by side) and Cloudflare accounts ----------
# Every row belongs to one account. GitHub: the login a repository is read with (cfg.repoAcct, default the gh account that was active when the
# repository was added). Cloudflare: the account whose token was used. The key is 'gh:<login>' or 'cf:<id>'.
function Get-GhAccounts { @($cfg.ghAccounts | Where-Object { $_ -and $_.login }) }
function Get-RepoLogin($repo) {
    $l = [string]$cfg.repoAcct[[string]$repo]
    if ($l) { return $l }
    if ($cfg.ghActive) { return [string]$cfg.ghActive }
    $f = @(Get-GhAccounts)[0]; if ($f) { return [string]$f.login }
    ''
}
function Get-Accounts {
    $l = @()
    $gha = @(Get-GhAccounts)
    if ($gha.Count) { foreach ($a in $gha) { $l += [pscustomobject]@{ key = "gh:$($a.login)"; src = 'GH'; label = $(if ($a.label) { [string]$a.label } else { [string]$a.login }); id = [string]$a.login } } }
    elseif ($gh) { $l += [pscustomobject]@{ key = 'gh:'; src = 'GH'; label = 'GitHub'; id = '' } }   # before gh has told who is logged in
    foreach ($c in (Get-CfAccounts)) { $l += [pscustomobject]@{ key = "cf:$($c.id)"; src = 'CF'; label = [string]$c.label; id = [string]$c.id } }
    $l
}
function Get-RowKey($r) {
    if ($r.acctKey) { return [string]$r.acctKey }
    if ($r.source -eq 'cloudflare') { $a = Get-Accounts | Where-Object { $_.src -eq 'CF' -and $_.label -eq [string]$r.repo } | Select-Object -First 1; if ($a) { return $a.key }; return "cf:$($r.repo)" }
    'gh:' + (Get-RepoLogin $r.repo)
}
function Get-Acct($key) { Get-Accounts | Where-Object { $_.key -eq $key } | Select-Object -First 1 }
function Get-AcctLabel($key) { $a = Get-Acct $key; if ($a) { $a.label } else { ([string]$key -replace '^(gh|cf):', '') } }
function Test-Multi { @(Get-Accounts).Count -gt 1 }
# One muted colour pair per account (background, text), in the order the accounts are listed, so a colour stays with its account
$acctPalette = @( @('#2F4B6B', '#A8CBF2'), @('#4B3A6B', '#CDB9F2'), @('#2F5E5A', '#A5E3D8'), @('#6B3A4B', '#F2B9CD'), @('#5E5A2F', '#E3DDA5'), @('#3A4B5E', '#B9CCDF') )
function Get-AcctColor($key) {
    $i = 0; $n = 0
    foreach ($a in (Get-Accounts)) { if ($a.key -eq $key) { $i = $n; break }; $n++ }
    $acctPalette[$i % $acctPalette.Count]
}
function Short($s, $n) { $s = [string]$s; if ($s.Length -gt $n) { $s.Substring(0, $n - 1) + '…' } else { $s } }
function New-AcctBadge($key) {
    $a = Get-Acct $key; $c = Get-AcctColor $key
    $b = New-Object Windows.Controls.Border
    $b.CornerRadius = 3; $b.Padding = '5,0,5,1'; $b.Margin = '0,0,6,0'; $b.Background = Br $c[0]; $b.VerticalAlignment = 'Center'
    $t = New-Object Windows.Controls.TextBlock; $t.FontSize = 11; $t.Foreground = Br $c[1]
    $t.Text = if ($a) { "$($a.src) · $(Short $a.label 14)" } else { Short (Get-AcctLabel $key) 16 }
    $b.ToolTip = if ($a) { "$($a.src) · $($a.label)" } else { $key }
    $b.Child = $t
    $b
}

# gh can be logged in to several GitHub accounts at once. A call for another account than the active one gets that account's token
# (gh auth token --user <login>) in GH_TOKEN for that one process; the active account is never switched.
$script:ghTokens = @{}
function Get-GhToken($login) {
    if (-not $login -or -not $gh) { return $null }
    if ($script:ghTokens.ContainsKey($login)) { return $script:ghTokens[$login] }
    try {
        $psi = New-Object Diagnostics.ProcessStartInfo
        $psi.FileName = $gh; $psi.Arguments = "auth token --hostname github.com --user $login"
        $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
        $p = [Diagnostics.Process]::Start($psi)
        $o = $p.StandardOutput.ReadToEndAsync(); $e = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit(8000)) { try { $p.Kill() } catch {}; return $null }
        $t = ([string]$o.Result).Trim()
        if ($p.ExitCode -eq 0 -and $t) { $script:ghTokens[$login] = $t; return $t }
    } catch {}
    $null
}
$script:ghAcctCheckedAt = [datetime]::MinValue
function Refresh-GhAccounts {
    $script:ghAcctCheckedAt = Get-Date
    if (-not $gh -or $env:CISTATUS_FIXTURE -or $script:cfFixture) { return }
    Start-Gh 'auth status --json hosts' {
        param($out, $err, $code, $ctx)
        try { $found = @(($out | ConvertFrom-Json).hosts.'github.com' | Where-Object { $_ -and $_.login }) } catch { return }
        if (-not $found.Count) { return }
        $old = @{}; foreach ($a in (Get-GhAccounts)) { $old[[string]$a.login] = [string]$a.label }
        $new = @(); $active = ''
        foreach ($f in $found) {
            $l = [string]$f.login
            $new += [pscustomobject]@{ login = $l; label = $(if ($old[$l]) { $old[$l] } else { $l }) }
            if ($f.active) { $active = $l }
        }
        if (-not $active) { $active = [string]$new[0].login }
        $changed = ((@(Get-GhAccounts) | ForEach-Object { $_.login }) -join ',') -ne (($new | ForEach-Object { $_.login }) -join ',') -or $cfg.ghActive -ne $active
        # Repositories added before there were several accounts belong to the account that was active
        foreach ($rp in (Get-Repos)) { if (-not $cfg.repoAcct[$rp]) { $cfg.repoAcct[$rp] = $active; $changed = $true } }
        if ($changed) {
            $cfg.ghAccounts = $new; $cfg.ghActive = $active
            if ($script:usageSrc -like 'gh:*' -and -not (Get-GhAccounts | Where-Object { "gh:$($_.login)" -eq $script:usageSrc })) { Set-UsageSrc "gh:$active" }
            Save-Config; Render; Refresh
        }
    } @{}
}

$strings = @{
    en = @{
        title = 'CI Status'; running = '{0} running'; green = 'All green'; failing = 'Failing'; noRuns = 'No runs found'; loading = 'Reading GitHub…'
        updated = 'Updated {0}'; hint = 'Click a run to open it · right-click for options'; finished = 'Finished: {0} – {1}'
        agoNow = 'just now'; agoM = '{0} min ago'; agoH = '{0} h ago'; agoD = '{0} d ago'
        stRunning = 'running'; stQueued = 'queued'; stOk = 'success'; stFail = 'failed'; stCancel = 'cancelled'; stSkip = 'skipped'; stWarn = 'needs attention'
        uQuota = 'Quota: {0} of {1} min ({2} %)'; uPaceOver = 'over the quota by {0} min'; uPaceHit = 'at this pace the quota is reached {0}'
        uPaceOk = 'on track, forecast {0} % of the quota'; uMonthGone = 'Month {0} % gone'; uBudget = 'Budget: {0} of {1} ({2} %)'; uBudgetFore = ' · forecast {0}'
        mQuota = 'Set minutes quota…'; mBudget = 'Set monthly budget…'; badNum = 'Enter a number, for example 3000.'
        askQuota = 'Monthly quota in Actions minutes (0 = what the plan includes):'; askBudget = 'Monthly budget in USD (0 = no budget):'
        uDailyFor = '{0} · {1} per day'; uNoDaily = '{0} · no daily data'; mBudgets = 'Budget per service'; askBudgetFor = 'Monthly budget in USD for {0} (0 = none):'
        updNew = 'New version available – click to update'
        tabRuns = 'Runs'; tabUsage = 'Usage'; linkUsage = 'Open GitHub usage ↗'; uServices = 'All services'; uNoUse = 'no usage'; catAI = 'AI credits'; catOther = 'Other'
        uHead = 'Actions minutes · {0}'; uUsed = '{0} min used of {1} included'; uOver = 'Included minutes are used up – {0} min billable ({1})'
        uOk = 'Nothing billable this month'; uFore = 'Forecast for the month: about {0} min'; uForeCost = ' · about {0} billable'
        uDaily = 'Minutes per day'; uRepos = 'Per repository'; uOther = 'Other usage'; uTotal = 'Billable this month: {0}'; uResets = 'The month resets {0}'
        uLoading = 'Reading GitHub billing…'; uErr = 'Could not read usage: {0}'; uScope = 'GitHub denied access. Run: gh auth refresh -s user'
        uLag = 'GitHub updates usage with a delay of an hour or more.'; uNone = 'No Actions usage this month'; uBillable = '{0} billable'
        jobs = 'jobs {0}/{1}'; minimize = 'Minimize'; restore = 'Show all runs'; nothing = 'Nothing running'
        mRefresh = 'Refresh now'; mMinimize = 'Minimize'; mUpdate = 'Update the widget'; mAddRepo = 'Add repository…'; mRemoveRepo = 'Remove repository'
        mTopmost = 'Always on top'; mLanguage = 'Language'; mClose = 'Close'
        tabE2E = 'E2E'; e2eHelp = 'Browser tests (Playwright) are not part of the pipeline. Start them here when you need them.'
        e2eRel = 'Relevant tests'; e2eRelSub = 'Only the tests that belong to the files changed in the last commit'; e2eAll = 'All tests'; e2eAllSub = 'Everything, split into 4 parts that run at the same time'
        e2eSome = 'Choose tests…'; e2eSomeSub = 'Tick the tests you want to run'
        e2ePick = 'Tick the tests to run'; e2eSelAll = 'Select all'; e2eSelNone = 'Select none'; e2eRunN = 'Run {0} tests'; e2eCancel = 'Cancel'; e2eLoadingList = 'Reading the test list…'; e2eListFail = 'Could not read the test list: {0}'
        e2eStarting = 'Starting e2e: {0}…'; e2eStarted = 'E2E started: {0}. Follow it under Runs.'; e2eFail = 'Could not start e2e: {0}'
        askRepo = 'Repository to watch (owner/name):'; badRepo = 'Use the form owner/name, for example saysphilippe/Nerdehagen.'
        ghNoLogin = 'gh is not signed in as {0}. Choose GitHub accounts, Sign in another account.'
        mGh = 'GitHub accounts'; mGhAdd = 'Sign in another account…'; mGhRefresh = 'Refresh accounts'; mGhName = 'Rename account'
        ghAskLabel = 'Name for the GitHub account {0} (for example Work or Private):'; ghAcctLbl = 'Read with GitHub account:'; fltAll = 'All'
        ghSignIn = 'Sign in to the other GitHub account in the browser. Close this window when you are done, and choose Refresh accounts in CI Status.'
        mCf = 'Cloudflare accounts'; mCfAdd = 'Add account…'; mCfRemove = 'Remove account'; mCfName = 'Rename account'
        cfAskLabel = 'Name for this Cloudflare account (for example Work or Private):'; cfAskToken = 'API token (read only):'; cfAdd = 'Add'; cfCancel = 'Cancel'
        cfTokenHelp = 'Create the token at dash.cloudflare.com/profile/api-tokens with Read access to: Workers Scripts, Workers Builds Configuration, Account Analytics and Account Settings. It is stored encrypted for your Windows user only.'
        cfAdded = 'Added: {0}'; cfAddFail = 'Could not add the account: {0}'; cfNoAccess = 'The token cannot see any Cloudflare account.'
        cfPerm = 'No access. Check the token permissions (Read: Workers Scripts, Workers Builds Configuration, Account Analytics, Account Settings).'
        cfDeployed = 'deployed'; cfVia = 'via {0}'; cfNoDeploys = 'No Workers found'
        linkUsageCf = 'Open Cloudflare dashboard ↗'; uCfHead = '{0} · today (UTC)'; uCfBars = 'Today against the Workers Free daily allowance'
        uCfLag = 'Cloudflare analytics run a few minutes behind. The allowance resets at 00:00 UTC.'; uCfLoading = 'Reading Cloudflare…'
        cfWReq = 'Workers requests'; cfD1R = 'D1 rows read'; cfD1W = 'D1 rows written'; cfAi = 'Workers AI neurons'
        noGh = 'The GitHub CLI (gh) was not found. Install it and run: gh auth login'; ghErr = 'Could not read {0}: {1}'
    }
    no = @{
        title = 'CI Status'; running = '{0} kjører'; green = 'Alt grønt'; failing = 'Feiler'; noRuns = 'Ingen kjøringer funnet'; loading = 'Leser fra GitHub…'
        updated = 'Oppdatert {0}'; hint = 'Trykk på en kjøring for å åpne den · høyreklikk for valg'; finished = 'Ferdig: {0} – {1}'
        agoNow = 'nå nettopp'; agoM = 'for {0} min siden'; agoH = 'for {0} t siden'; agoD = 'for {0} d siden'
        stRunning = 'kjører'; stQueued = 'i kø'; stOk = 'vellykket'; stFail = 'feilet'; stCancel = 'avbrutt'; stSkip = 'hoppet over'; stWarn = 'krever oppmerksomhet'
        uQuota = 'Kvote: {0} av {1} min ({2} %)'; uPaceOver = 'over kvoten med {0} min'; uPaceHit = 'med dette tempoet nås kvoten {0}'
        uPaceOk = 'ligger godt an, prognose {0} % av kvoten'; uMonthGone = 'Måneden er {0} % gått'; uBudget = 'Budsjett: {0} av {1} ({2} %)'; uBudgetFore = ' · prognose {0}'
        mQuota = 'Sett kvote i minutter…'; mBudget = 'Sett månedlig budsjett…'; badNum = 'Skriv et tall, for eksempel 3000.'
        askQuota = 'Månedlig kvote i Actions-minutter (0 = det planen inkluderer):'; askBudget = 'Månedlig budsjett i USD (0 = ingen budsjett):'
        uDailyFor = '{0} · {1} per dag'; uNoDaily = '{0} · ingen data per dag'; mBudgets = 'Budsjett per tjeneste'; askBudgetFor = 'Månedlig budsjett i USD for {0} (0 = ingen):'
        updNew = 'Ny versjon tilgjengelig – trykk for å oppdatere'
        tabRuns = 'Kjøringer'; tabUsage = 'Forbruk'; linkUsage = 'Åpne GitHub-forbruk ↗'; uServices = 'Alle tjenester'; uNoUse = 'ingen bruk'; catAI = 'AI-kreditter'; catOther = 'Annet'
        uHead = 'Actions-minutter · {0}'; uUsed = '{0} min brukt av {1} inkludert'; uOver = 'Inkluderte minutter er brukt opp – {0} min å betale for ({1})'
        uOk = 'Ingenting å betale denne måneden'; uFore = 'Prognose for måneden: ca. {0} min'; uForeCost = ' · ca. {0} å betale'
        uDaily = 'Minutter per dag'; uRepos = 'Per repo'; uOther = 'Annet forbruk'; uTotal = 'Å betale denne måneden: {0}'; uResets = 'Måneden nullstilles {0}'
        uLoading = 'Leser fakturering fra GitHub…'; uErr = 'Kunne ikke lese forbruk: {0}'; uScope = 'GitHub nektet tilgang. Kjør: gh auth refresh -s user'
        uLag = 'GitHub oppdaterer forbruket med en forsinkelse på en time eller mer.'; uNone = 'Ingen Actions-bruk denne måneden'; uBillable = '{0} å betale'
        jobs = 'jobber {0}/{1}'; minimize = 'Minimer'; restore = 'Vis alle kjøringer'; nothing = 'Ingenting kjører'
        mRefresh = 'Oppdater nå'; mMinimize = 'Minimer'; mUpdate = 'Oppdater widgeten'; mAddRepo = 'Legg til repo…'; mRemoveRepo = 'Fjern repo'
        mTopmost = 'Alltid øverst'; mLanguage = 'Språk'; mClose = 'Lukk'
        tabE2E = 'E2E'; e2eHelp = 'Nettleser-testene (Playwright) er ikke en del av pipelinen. Start dem her ved behov.'
        e2eRel = 'Relevante tester'; e2eRelSub = 'Bare testene som hører til filene som er endret i siste commit'; e2eAll = 'Alle tester'; e2eAllSub = 'Alt, delt i 4 deler som kjører samtidig'
        e2eSome = 'Velg tester…'; e2eSomeSub = 'Kryss av testene du vil kjøre'
        e2ePick = 'Kryss av testene som skal kjøres'; e2eSelAll = 'Velg alle'; e2eSelNone = 'Fjern alle'; e2eRunN = 'Kjør {0} tester'; e2eCancel = 'Avbryt'; e2eLoadingList = 'Leser testlisten…'; e2eListFail = 'Kunne ikke lese testlisten: {0}'
        e2eStarting = 'Starter e2e: {0}…'; e2eStarted = 'E2E startet: {0}. Følg den under Kjøringer.'; e2eFail = 'Kunne ikke starte e2e: {0}'
        askRepo = 'Repo som skal følges (eier/navn):'; badRepo = 'Bruk formen eier/navn, for eksempel saysphilippe/Nerdehagen.'
        ghNoLogin = 'gh er ikke innlogget som {0}. Velg GitHub-kontoer, Logg inn en annen konto.'
        mGh = 'GitHub-kontoer'; mGhAdd = 'Logg inn en annen konto…'; mGhRefresh = 'Oppdater kontoer'; mGhName = 'Gi konto nytt navn'
        ghAskLabel = 'Navn på GitHub-kontoen {0} (for eksempel Jobb eller Privat):'; ghAcctLbl = 'Les med GitHub-konto:'; fltAll = 'Alle'
        ghSignIn = 'Logg inn på den andre GitHub-kontoen i nettleseren. Lukk vinduet når du er ferdig, og velg Oppdater kontoer i CI Status.'
        mCf = 'Cloudflare-kontoer'; mCfAdd = 'Legg til konto…'; mCfRemove = 'Fjern konto'; mCfName = 'Gi konto nytt navn'
        cfAskLabel = 'Navn på denne Cloudflare-kontoen (for eksempel Jobb eller Privat):'; cfAskToken = 'API-token (bare lesing):'; cfAdd = 'Legg til'; cfCancel = 'Avbryt'
        cfTokenHelp = 'Lag tokenet på dash.cloudflare.com/profile/api-tokens med lesetilgang (Read) til: Workers Scripts, Workers Builds Configuration, Account Analytics og Account Settings. Det lagres kryptert, bare for din Windows-bruker.'
        cfAdded = 'Lagt til: {0}'; cfAddFail = 'Kunne ikke legge til kontoen: {0}'; cfNoAccess = 'Tokenet ser ingen Cloudflare-konto.'
        cfPerm = 'Ingen tilgang. Sjekk rettighetene til tokenet (Read: Workers Scripts, Workers Builds Configuration, Account Analytics, Account Settings).'
        cfDeployed = 'publisert'; cfVia = 'via {0}'; cfNoDeploys = 'Ingen Workers funnet'
        linkUsageCf = 'Åpne Cloudflare-dashbordet ↗'; uCfHead = '{0} · i dag (UTC)'; uCfBars = 'I dag mot gratisgrensen per dag for Workers'
        uCfLag = 'Cloudflare-statistikken går noen minutter etter. Grensen nullstilles kl. 00:00 UTC.'; uCfLoading = 'Leser fra Cloudflare…'
        cfWReq = 'Workers-kall'; cfD1R = 'D1 rader lest'; cfD1W = 'D1 rader skrevet'; cfAi = 'Workers AI-neuroner'
        noGh = 'GitHub CLI (gh) ble ikke funnet. Installer den og kjør: gh auth login'; ghErr = 'Kunne ikke lese {0}: {1}'
    }
    sv = @{
        title = 'CI Status'; running = '{0} körs'; green = 'Allt grönt'; failing = 'Misslyckas'; noRuns = 'Inga körningar hittades'; loading = 'Läser från GitHub…'
        updated = 'Uppdaterad {0}'; hint = 'Klicka på en körning för att öppna den · högerklicka för val'; finished = 'Klar: {0} – {1}'
        agoNow = 'nyss'; agoM = 'för {0} min sedan'; agoH = 'för {0} h sedan'; agoD = 'för {0} d sedan'
        stRunning = 'körs'; stQueued = 'i kö'; stOk = 'lyckades'; stFail = 'misslyckades'; stCancel = 'avbruten'; stSkip = 'hoppades över'; stWarn = 'kräver uppmärksamhet'
        uQuota = 'Kvot: {0} av {1} min ({2} %)'; uPaceOver = 'över kvoten med {0} min'; uPaceHit = 'i den här takten nås kvoten {0}'
        uPaceOk = 'ligger bra till, prognos {0} % av kvoten'; uMonthGone = 'Månaden är {0} % förbi'; uBudget = 'Budget: {0} av {1} ({2} %)'; uBudgetFore = ' · prognos {0}'
        mQuota = 'Ange kvot i minuter…'; mBudget = 'Ange månadsbudget…'; badNum = 'Skriv ett tal, till exempel 3000.'
        askQuota = 'Månatlig kvot i Actions-minuter (0 = det planen inkluderar):'; askBudget = 'Månatlig budget i USD (0 = ingen budget):'
        uDailyFor = '{0} · {1} per dag'; uNoDaily = '{0} · inga data per dag'; mBudgets = 'Budget per tjänst'; askBudgetFor = 'Månatlig budget i USD för {0} (0 = ingen):'
        updNew = 'Ny version tillgänglig – klicka för att uppdatera'
        tabRuns = 'Körningar'; tabUsage = 'Förbrukning'; linkUsage = 'Öppna GitHub-förbrukning ↗'; uServices = 'Alla tjänster'; uNoUse = 'ingen användning'; catAI = 'AI-krediter'; catOther = 'Övrigt'
        uHead = 'Actions-minuter · {0}'; uUsed = '{0} min använda av {1} inkluderade'; uOver = 'Inkluderade minuter är slut – {0} min att betala för ({1})'
        uOk = 'Inget att betala den här månaden'; uFore = 'Prognos för månaden: ca {0} min'; uForeCost = ' · ca {0} att betala'
        uDaily = 'Minuter per dag'; uRepos = 'Per repo'; uOther = 'Annan förbrukning'; uTotal = 'Att betala den här månaden: {0}'; uResets = 'Månaden nollställs {0}'
        uLoading = 'Läser fakturering från GitHub…'; uErr = 'Kunde inte läsa förbrukning: {0}'; uScope = 'GitHub nekade åtkomst. Kör: gh auth refresh -s user'
        uLag = 'GitHub uppdaterar förbrukningen med en fördröjning på en timme eller mer.'; uNone = 'Ingen Actions-användning den här månaden'; uBillable = '{0} att betala'
        jobs = 'jobb {0}/{1}'; minimize = 'Minimera'; restore = 'Visa alla körningar'; nothing = 'Inget körs'
        mRefresh = 'Uppdatera nu'; mMinimize = 'Minimera'; mUpdate = 'Uppdatera widgeten'; mAddRepo = 'Lägg till repo…'; mRemoveRepo = 'Ta bort repo'
        mTopmost = 'Alltid överst'; mLanguage = 'Språk'; mClose = 'Stäng'
        tabE2E = 'E2E'; e2eHelp = 'Webbläsartesterna (Playwright) ingår inte i pipelinen. Starta dem här vid behov.'
        e2eRel = 'Relevanta tester'; e2eRelSub = 'Bara testerna som hör till filerna som ändrades i senaste committen'; e2eAll = 'Alla tester'; e2eAllSub = 'Allt, delat i 4 delar som körs samtidigt'
        e2eSome = 'Välj tester…'; e2eSomeSub = 'Kryssa i testerna du vill köra'
        e2ePick = 'Kryssa i testerna som ska köras'; e2eSelAll = 'Markera alla'; e2eSelNone = 'Avmarkera alla'; e2eRunN = 'Kör {0} tester'; e2eCancel = 'Avbryt'; e2eLoadingList = 'Läser testlistan…'; e2eListFail = 'Kunde inte läsa testlistan: {0}'
        e2eStarting = 'Startar e2e: {0}…'; e2eStarted = 'E2E startad: {0}. Följ den under Körningar.'; e2eFail = 'Kunde inte starta e2e: {0}'
        askRepo = 'Repo att följa (ägare/namn):'; badRepo = 'Använd formen ägare/namn, till exempel saysphilippe/Nerdehagen.'
        ghNoLogin = 'gh är inte inloggad som {0}. Välj GitHub-konton, Logga in ett annat konto.'
        mGh = 'GitHub-konton'; mGhAdd = 'Logga in ett annat konto…'; mGhRefresh = 'Uppdatera konton'; mGhName = 'Byt namn på konto'
        ghAskLabel = 'Namn på GitHub-kontot {0} (till exempel Jobb eller Privat):'; ghAcctLbl = 'Läs med GitHub-konto:'; fltAll = 'Alla'
        ghSignIn = 'Logga in på det andra GitHub-kontot i webbläsaren. Stäng fönstret när du är klar och välj Uppdatera konton i CI Status.'
        mCf = 'Cloudflare-konton'; mCfAdd = 'Lägg till konto…'; mCfRemove = 'Ta bort konto'; mCfName = 'Byt namn på konto'
        cfAskLabel = 'Namn på det här Cloudflare-kontot (till exempel Jobb eller Privat):'; cfAskToken = 'API-token (endast läsning):'; cfAdd = 'Lägg till'; cfCancel = 'Avbryt'
        cfTokenHelp = 'Skapa token på dash.cloudflare.com/profile/api-tokens med läsbehörighet (Read) till: Workers Scripts, Workers Builds Configuration, Account Analytics och Account Settings. Den lagras krypterad, bara för din Windows-användare.'
        cfAdded = 'Tillagt: {0}'; cfAddFail = 'Kunde inte lägga till kontot: {0}'; cfNoAccess = 'Token ser inget Cloudflare-konto.'
        cfPerm = 'Ingen åtkomst. Kontrollera behörigheterna för token (Read: Workers Scripts, Workers Builds Configuration, Account Analytics, Account Settings).'
        cfDeployed = 'publicerad'; cfVia = 'via {0}'; cfNoDeploys = 'Inga Workers hittades'
        linkUsageCf = 'Öppna Cloudflare-instrumentpanelen ↗'; uCfHead = '{0} · idag (UTC)'; uCfBars = 'Idag mot gratisgränsen per dag för Workers'
        uCfLag = 'Cloudflares statistik ligger några minuter efter. Gränsen nollställs kl. 00:00 UTC.'; uCfLoading = 'Läser från Cloudflare…'
        cfWReq = 'Workers-anrop'; cfD1R = 'D1 rader lästa'; cfD1W = 'D1 rader skrivna'; cfAi = 'Workers AI-neuroner'
        noGh = 'GitHub CLI (gh) hittades inte. Installera den och kör: gh auth login'; ghErr = 'Kunde inte läsa {0}: {1}'
    }
    da = @{
        title = 'CI Status'; running = '{0} kører'; green = 'Alt grønt'; failing = 'Fejler'; noRuns = 'Ingen kørsler fundet'; loading = 'Læser fra GitHub…'
        updated = 'Opdateret {0}'; hint = 'Klik på en kørsel for at åbne den · højreklik for valg'; finished = 'Færdig: {0} – {1}'
        agoNow = 'lige nu'; agoM = 'for {0} min siden'; agoH = 'for {0} t siden'; agoD = 'for {0} d siden'
        stRunning = 'kører'; stQueued = 'i kø'; stOk = 'lykkedes'; stFail = 'fejlede'; stCancel = 'afbrudt'; stSkip = 'sprunget over'; stWarn = 'kræver opmærksomhed'
        uQuota = 'Kvote: {0} af {1} min ({2} %)'; uPaceOver = 'over kvoten med {0} min'; uPaceHit = 'i dette tempo nås kvoten {0}'
        uPaceOk = 'ligger godt, prognose {0} % af kvoten'; uMonthGone = 'Måneden er {0} % gået'; uBudget = 'Budget: {0} af {1} ({2} %)'; uBudgetFore = ' · prognose {0}'
        mQuota = 'Sæt kvote i minutter…'; mBudget = 'Sæt månedligt budget…'; badNum = 'Skriv et tal, for eksempel 3000.'
        askQuota = 'Månedlig kvote i Actions-minutter (0 = det planen inkluderer):'; askBudget = 'Månedligt budget i USD (0 = intet budget):'
        uDailyFor = '{0} · {1} pr. dag'; uNoDaily = '{0} · ingen data pr. dag'; mBudgets = 'Budget pr. tjeneste'; askBudgetFor = 'Månedligt budget i USD for {0} (0 = ingen):'
        updNew = 'Ny version tilgængelig – klik for at opdatere'
        tabRuns = 'Kørsler'; tabUsage = 'Forbrug'; linkUsage = 'Åbn GitHub-forbrug ↗'; uServices = 'Alle tjenester'; uNoUse = 'intet forbrug'; catAI = 'AI-kreditter'; catOther = 'Andet'
        uHead = 'Actions-minutter · {0}'; uUsed = '{0} min brugt af {1} inkluderet'; uOver = 'Inkluderede minutter er brugt op – {0} min at betale for ({1})'
        uOk = 'Intet at betale denne måned'; uFore = 'Prognose for måneden: ca. {0} min'; uForeCost = ' · ca. {0} at betale'
        uDaily = 'Minutter pr. dag'; uRepos = 'Pr. repo'; uOther = 'Andet forbrug'; uTotal = 'At betale denne måned: {0}'; uResets = 'Måneden nulstilles {0}'
        uLoading = 'Læser fakturering fra GitHub…'; uErr = 'Kunne ikke læse forbrug: {0}'; uScope = 'GitHub nægtede adgang. Kør: gh auth refresh -s user'
        uLag = 'GitHub opdaterer forbruget med en forsinkelse på en time eller mere.'; uNone = 'Ingen Actions-brug denne måned'; uBillable = '{0} at betale'
        jobs = 'jobs {0}/{1}'; minimize = 'Minimer'; restore = 'Vis alle kørsler'; nothing = 'Intet kører'
        mRefresh = 'Opdater nu'; mMinimize = 'Minimer'; mUpdate = 'Opdater widgetten'; mAddRepo = 'Tilføj repo…'; mRemoveRepo = 'Fjern repo'
        mTopmost = 'Altid øverst'; mLanguage = 'Sprog'; mClose = 'Luk'
        tabE2E = 'E2E'; e2eHelp = 'Browsertestene (Playwright) er ikke en del af pipelinen. Start dem her ved behov.'
        e2eRel = 'Relevante tests'; e2eRelSub = 'Kun testene der hører til filerne ændret i seneste commit'; e2eAll = 'Alle tests'; e2eAllSub = 'Alt, delt i 4 dele der kører samtidig'
        e2eSome = 'Vælg tests…'; e2eSomeSub = 'Afkryds de tests du vil køre'
        e2ePick = 'Afkryds de tests der skal køre'; e2eSelAll = 'Vælg alle'; e2eSelNone = 'Fravælg alle'; e2eRunN = 'Kør {0} tests'; e2eCancel = 'Annuller'; e2eLoadingList = 'Læser testlisten…'; e2eListFail = 'Kunne ikke læse testlisten: {0}'
        e2eStarting = 'Starter e2e: {0}…'; e2eStarted = 'E2E startet: {0}. Følg den under Kørsler.'; e2eFail = 'Kunne ikke starte e2e: {0}'
        askRepo = 'Repo der skal følges (ejer/navn):'; badRepo = 'Brug formen ejer/navn, for eksempel saysphilippe/Nerdehagen.'
        ghNoLogin = 'gh er ikke logget ind som {0}. Vælg GitHub-konti, Log ind på en anden konto.'
        mGh = 'GitHub-konti'; mGhAdd = 'Log ind på en anden konto…'; mGhRefresh = 'Opdater konti'; mGhName = 'Omdøb konto'
        ghAskLabel = 'Navn på GitHub-kontoen {0} (for eksempel Job eller Privat):'; ghAcctLbl = 'Læs med GitHub-konto:'; fltAll = 'Alle'
        ghSignIn = 'Log ind på den anden GitHub-konto i browseren. Luk vinduet, når du er færdig, og vælg Opdater konti i CI Status.'
        mCf = 'Cloudflare-konti'; mCfAdd = 'Tilføj konto…'; mCfRemove = 'Fjern konto'; mCfName = 'Omdøb konto'
        cfAskLabel = 'Navn på denne Cloudflare-konto (for eksempel Job eller Privat):'; cfAskToken = 'API-token (kun læsning):'; cfAdd = 'Tilføj'; cfCancel = 'Annuller'
        cfTokenHelp = 'Opret tokenet på dash.cloudflare.com/profile/api-tokens med læseadgang (Read) til: Workers Scripts, Workers Builds Configuration, Account Analytics og Account Settings. Det gemmes krypteret, kun for din Windows-bruger.'
        cfAdded = 'Tilføjet: {0}'; cfAddFail = 'Kunne ikke tilføje kontoen: {0}'; cfNoAccess = 'Tokenet kan ikke se nogen Cloudflare-konto.'
        cfPerm = 'Ingen adgang. Kontroller tokenets rettigheder (Read: Workers Scripts, Workers Builds Configuration, Account Analytics, Account Settings).'
        cfDeployed = 'udgivet'; cfVia = 'via {0}'; cfNoDeploys = 'Ingen Workers fundet'
        linkUsageCf = 'Åbn Cloudflare-dashboardet ↗'; uCfHead = '{0} · i dag (UTC)'; uCfBars = 'I dag mod gratisgrænsen pr. dag for Workers'
        uCfLag = 'Cloudflares statistik er nogle minutter bagud. Grænsen nulstilles kl. 00:00 UTC.'; uCfLoading = 'Læser fra Cloudflare…'
        cfWReq = 'Workers-kald'; cfD1R = 'D1 rækker læst'; cfD1W = 'D1 rækker skrevet'; cfAi = 'Workers AI-neuroner'
        noGh = 'GitHub CLI (gh) blev ikke fundet. Installer den og kør: gh auth login'; ghErr = 'Kunne ikke læse {0}: {1}'
    }
}
$langNames = [ordered]@{ en = 'English'; no = 'Norsk'; sv = 'Svenska'; da = 'Dansk' }
function T($k) {
    $s = $strings[[string]$cfg.language]
    if (-not $s -or -not $s.ContainsKey($k)) { $s = $strings.en }
    $s[$k]
}

# ---------- GitHub CLI ----------
$gh = 'C:\Program Files\GitHub CLI\gh.exe'
if (-not (Test-Path $gh)) { $c = Get-Command gh.exe -ErrorAction SilentlyContinue; if ($c) { $gh = $c.Source } else { $gh = $null } }

# Processes run as .NET tasks (no PowerShell on background threads); a DispatcherTimer picks up the results.
$script:jobs = New-Object System.Collections.ArrayList
function Start-Gh($arguments, $onDone, $ctx, $login = $null) {
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $gh; $psi.Arguments = $arguments
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    if ($login) {
        $tok = Get-GhToken $login
        if ($tok) { $psi.EnvironmentVariables['GH_TOKEN'] = $tok }
        else {
            # gh does not know this login (signed out?): fail, rather than read with whatever account happens to be active
            $o = New-Object 'Threading.Tasks.TaskCompletionSource[string]'; $o.SetResult('')
            $e = New-Object 'Threading.Tasks.TaskCompletionSource[string]'; $e.SetResult([string]((T 'ghNoLogin') -f $login))
            [void]$script:jobs.Add(@{ proc = $null; fake = $true; out = $o.Task; err = $e.Task; done = $onDone; ctx = $ctx; started = Get-Date })
            return
        }
    }
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8; $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
    $p = [Diagnostics.Process]::Start($psi)
    [void]$script:jobs.Add(@{ proc = $p; out = $p.StandardOutput.ReadToEndAsync(); err = $p.StandardError.ReadToEndAsync(); done = $onDone; ctx = $ctx; started = Get-Date })
}
function Receive-Jobs {
    for ($i = $script:jobs.Count - 1; $i -ge 0; $i--) {
        $j = $script:jobs[$i]
        $finished = $j.out.IsCompleted -and $j.err.IsCompleted -and ($j.fake -or $j.proc.HasExited)
        $timedOut = ((Get-Date) - $j.started).TotalSeconds -gt 40
        if (-not ($finished -or $timedOut)) { continue }
        $script:jobs.RemoveAt($i)
        if ($timedOut -and -not $finished) {
            try { if ($j.proc) { $j.proc.Kill() } } catch {}
            & $j.done '' 'timeout' 1 $j.ctx
        } else {
            & $j.done $j.out.Result $j.err.Result $(if ($j.fake) { 1 } else { $j.proc.ExitCode }) $j.ctx
        }
    }
}

function ToUtc($v) {
    if ($v -is [datetime]) { return $v.ToUniversalTime() }
    [datetime]::Parse([string]$v, $inv, [Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal)
}
function Get-State($r) {
    switch ([string]$r.status) {
        'completed' {
            switch ([string]$r.conclusion) {
                'success' { 'ok' }
                { $_ -in 'failure', 'timed_out', 'startup_failure' } { 'fail' }
                'cancelled' { 'cancel' }
                { $_ -in 'skipped', 'neutral' } { 'skip' }
                default { 'warn' }
            }
        }
        'in_progress' { 'running' }
        default { 'queued' }
    }
}
$colors = @{ ok = '#4CAF50'; fail = '#E5534B'; running = '#E0B050'; queued = '#8A8A8A'; cancel = '#777777'; skip = '#777777'; warn = '#E0B050' }
$stateKey = @{ ok = 'stOk'; fail = 'stFail'; running = 'stRunning'; queued = 'stQueued'; cancel = 'stCancel'; skip = 'stSkip'; warn = 'stWarn' }
$conv = New-Object Windows.Media.BrushConverter
function Br($hex) { $conv.ConvertFromString($hex) }

function Format-Ago($dt) {
    $m = [int]((Get-Date).ToUniversalTime() - $dt).TotalMinutes
    if ($m -lt 1) { return (T 'agoNow') }
    if ($m -lt 60) { return ((T 'agoM') -f $m) }
    if ($m -lt 2880) { return ((T 'agoH') -f [int][math]::Floor($m / 60)) }
    ((T 'agoD') -f [int][math]::Floor($m / 1440))
}
function Format-Dur($ts) {
    $s = [int][math]::Max(0, $ts.TotalSeconds)
    if ($s -ge 3600) { return ('{0}h {1:00}m' -f [int][math]::Floor($s / 3600), [int][math]::Floor(($s % 3600) / 60)) }
    if ($s -ge 60) { return ('{0}m {1:00}s' -f [int][math]::Floor($s / 60), ($s % 60)) }
    "${s}s"
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ShowInTaskbar="False" SizeToContent="WidthAndHeight" ResizeMode="NoResize">
  <Grid>
  <!-- Minimized: only what is running (or one dot with the latest result) -->
  <Border Name="mini" CornerRadius="8" Background="#1E1E1E" BorderBrush="#3A3A3A" BorderThickness="1" Padding="10,6" Cursor="Hand" Visibility="Collapsed" Tag="cmd:restore">
    <StackPanel Name="miniRows"/>
  </Border>
  <Border Name="root" CornerRadius="10" Background="#1E1E1E" BorderBrush="#3A3A3A" BorderThickness="1" Padding="16,12" Width="400">
    <StackPanel>
      <DockPanel Margin="0,0,0,6">
        <TextBlock Name="minBtn" DockPanel.Dock="Right" Text="–" Foreground="#777" FontSize="15" Cursor="Hand" Margin="12,-2,0,0" Background="Transparent" Tag="cmd:min"/>
        <TextBlock Name="summary" DockPanel.Dock="Right" FontSize="13" FontWeight="SemiBold" VerticalAlignment="Center"/>
        <TextBlock Name="title" Foreground="#D97757" FontWeight="SemiBold" FontSize="16"/>
      </DockPanel>
      <StackPanel Orientation="Horizontal" Margin="0,0,0,8">
        <TextBlock Name="tabRuns" FontSize="13" Cursor="Hand" Background="Transparent" Tag="cmd:tab:runs"/>
        <TextBlock Name="tabUsage" FontSize="13" Cursor="Hand" Background="Transparent" Margin="14,0,0,0" Tag="cmd:tab:usage"/>
        <TextBlock Name="tabE2E" FontSize="13" Cursor="Hand" Background="Transparent" Margin="14,0,0,0" Tag="cmd:tab:e2e"/>
      </StackPanel>
      <StackPanel Name="runsPanel">
      <WrapPanel Name="runFilter" Margin="0,0,0,8" Visibility="Collapsed"/>
      <TextBlock Name="flash" Foreground="#EEE" FontSize="12" Margin="0,0,0,6" TextWrapping="Wrap" Visibility="Collapsed"/>
      <StackPanel Name="rows"/>
      <TextBlock Name="note" FontSize="12" Margin="0,6,0,0" TextWrapping="Wrap" Visibility="Collapsed"/>
      </StackPanel>
      <StackPanel Name="e2ePanel" Visibility="Collapsed">
        <TextBlock Name="e2eHelp" Foreground="#999999" FontSize="12" TextWrapping="Wrap" Margin="0,0,0,8"/>
        <Border CornerRadius="6" Background="#2A2A2A" Padding="10,7" Margin="0,0,0,6" Cursor="Hand" Tag="cmd:e2e:relevante">
          <StackPanel><TextBlock Name="e2eRel" Foreground="#EEEEEE" FontSize="13" FontWeight="SemiBold"/><TextBlock Name="e2eRelSub" Foreground="#999999" FontSize="12" TextWrapping="Wrap"/></StackPanel>
        </Border>
        <Border CornerRadius="6" Background="#2A2A2A" Padding="10,7" Margin="0,0,0,6" Cursor="Hand" Tag="cmd:e2e:alle">
          <StackPanel><TextBlock Name="e2eAll" Foreground="#EEEEEE" FontSize="13" FontWeight="SemiBold"/><TextBlock Name="e2eAllSub" Foreground="#999999" FontSize="12" TextWrapping="Wrap"/></StackPanel>
        </Border>
        <Border CornerRadius="6" Background="#2A2A2A" Padding="10,7" Margin="0,0,0,6" Cursor="Hand" Tag="cmd:e2e:ask">
          <StackPanel><TextBlock Name="e2eSome" Foreground="#EEEEEE" FontSize="13" FontWeight="SemiBold"/><TextBlock Name="e2eSomeSub" Foreground="#999999" FontSize="12" TextWrapping="Wrap"/></StackPanel>
        </Border>
        <TextBlock Name="e2eNote" FontSize="12" Margin="0,4,0,0" TextWrapping="Wrap" Visibility="Collapsed"/>
      </StackPanel>
      <StackPanel Name="usagePanel" Visibility="Collapsed">
        <WrapPanel Name="uSrc" Margin="0,0,0,8" Visibility="Collapsed"/>
        <TextBlock Name="uDailyHead" Foreground="#EEE" FontSize="14"/>
        <Canvas Name="uDaily" Width="368" Height="52" Margin="0,4,0,0" HorizontalAlignment="Left"/>
        <TextBlock Name="uReposHead" Foreground="#EEE" FontSize="14" Margin="0,10,0,2"/>
        <StackPanel Name="uRepos"/>
        <TextBlock Name="uOtherHead" Foreground="#EEE" FontSize="14" Margin="0,10,0,2"/>
        <StackPanel Name="uOther"/>
        <TextBlock Name="uNote" FontSize="12" Margin="0,8,0,0" TextWrapping="Wrap" Visibility="Collapsed"/>
      </StackPanel>
      <TextBlock Name="upd" Foreground="#666" FontSize="12" Margin="0,8,0,0" TextWrapping="Wrap"/>
      <TextBlock Name="usageLink" Foreground="#6A9BCC" FontSize="12" Margin="0,4,0,0" Cursor="Hand" HorizontalAlignment="Left" Background="Transparent" TextDecorations="Underline" Tag="https://github.com/settings/billing/summary"/>
      <TextBlock Name="updNew" Foreground="#E0B050" FontSize="12" Margin="0,6,0,0" Cursor="Hand" HorizontalAlignment="Left" Background="Transparent" TextDecorations="Underline" Visibility="Collapsed" Tag="cmd:update"/>
    </StackPanel>
  </Border>
  </Grid>
</Window>
'@
$win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$el = @{}
'root', 'mini', 'miniRows', 'minBtn', 'summary', 'title', 'flash', 'rows', 'note', 'upd', 'tabRuns', 'tabUsage', 'tabE2E', 'e2ePanel', 'e2eHelp', 'e2eRel', 'e2eRelSub', 'e2eAll', 'e2eAllSub', 'e2eSome', 'e2eSomeSub', 'e2eNote', 'usageLink', 'updNew', 'runsPanel', 'usagePanel', 'uDailyHead', 'uDaily', 'uReposHead', 'uRepos', 'uOtherHead', 'uOther', 'uNote', 'uSrc', 'runFilter' | ForEach-Object { $el[$_] = $win.FindName($_) }
$win.Left = $cfg.left; $win.Top = $cfg.top; $win.Topmost = [bool]$cfg.topmost

# ---------- data and rendering ----------
$script:runs = @()
$script:errors = @{}          # repo -> message
$script:jobInfo = @{}         # run id -> 'done/total'
$script:prevState = @{}       # run id -> state at the last refresh
$script:flashUntil = [datetime]::MinValue
$script:flashColor = '#EEEEEE'
$script:updatedAt = $null
$script:cycle = $null
$script:since = 999

$script:ghRuns = @()          # GitHub runs from the last refresh (before the list is cut to maxRows)
$script:cfRuns = @()          # builds and deployments from the Cloudflare accounts
$script:cfCycle = $null

# ---------- Cloudflare accounts ----------
# One API token per account (read only). The token is encrypted with Windows DPAPI for this Windows user and kept in config.json; it is
# never shown again, and nothing on Cloudflare is changed (GET calls and one read-only GraphQL analytics query).
$cfApi = 'https://api.cloudflare.com/client/v4'
if ($env:CISTATUS_CF_API -match '^http://(127\.0\.0\.1|localhost)(:\d+)?(/|$)') { $cfApi = $env:CISTATUS_CF_API.TrimEnd('/') }   # local test server only
$script:cfFixture = $null
if ($env:CISTATUS_CF_FIXTURE -and (Test-Path $env:CISTATUS_CF_FIXTURE)) { $script:cfFixture = Get-Content $env:CISTATUS_CF_FIXTURE -Raw -Encoding UTF8 | ConvertFrom-Json }
function Get-CfAccounts {
    if ($script:cfFixture) { return @($script:cfFixture.accounts) }
    @($cfg.cfAccounts | Where-Object { $_ -and $_.id -and $_.token })
}
function Protect-Token($plain) { ConvertTo-SecureString $plain -AsPlainText -Force | ConvertFrom-SecureString }
function Unprotect-Token($enc) {
    $ss = ConvertTo-SecureString $enc
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}
$script:cfClients = @{}
function Get-CfClient($acct) {
    $key = [string]$acct.id
    if ($key -and $script:cfClients.ContainsKey($key)) { return $script:cfClients[$key] }
    $c = New-Object Net.Http.HttpClient; $c.Timeout = [TimeSpan]::FromSeconds(30)
    [void]$c.DefaultRequestHeaders.UserAgent.ParseAdd('CIStatus')
    $c.DefaultRequestHeaders.Authorization = New-Object Net.Http.Headers.AuthenticationHeaderValue('Bearer', (Unprotect-Token $acct.token))
    if ($key) { $script:cfClients[$key] = $c }
    $c
}
# Requests are .NET tasks, like the gh processes: nothing runs on a background thread, the timer picks the results up.
$script:cfJobs = New-Object System.Collections.ArrayList
function Start-Cf($acct, $method, $path, $body, $onDone, $ctx) {
    try {
        $client = Get-CfClient $acct
        $req = New-Object Net.Http.HttpRequestMessage((New-Object Net.Http.HttpMethod($method)), ($cfApi + $path))
        if ($body) { $req.Content = New-Object Net.Http.StringContent($body, [Text.Encoding]::UTF8, 'application/json') }
        [void]$script:cfJobs.Add(@{ task = $client.SendAsync($req); stage = 1; resp = $null; status = 0; done = $onDone; ctx = $ctx; started = Get-Date })
    } catch {
        & $onDone '' 0 'token' $ctx   # e.g. the token was encrypted by another Windows user
    }
}
function Receive-CfJobs {
    for ($i = $script:cfJobs.Count - 1; $i -ge 0; $i--) {
        $j = $script:cfJobs[$i]
        if (((Get-Date) - $j.started).TotalSeconds -gt 40) { $script:cfJobs.RemoveAt($i); & $j.done '' 0 'timeout' $j.ctx; continue }
        if (-not $j.task.IsCompleted) { continue }
        if ($j.task.IsFaulted -or $j.task.IsCanceled) {
            $script:cfJobs.RemoveAt($i)
            $m = if ($j.task.Exception) { $j.task.Exception.GetBaseException().Message } else { 'cancelled' }
            & $j.done '' 0 $m $j.ctx; continue
        }
        if ($j.stage -eq 1) {
            $j.resp = $j.task.Result; $j.status = [int]$j.resp.StatusCode
            $j.task = $j.resp.Content.ReadAsStringAsync(); $j.stage = 2
            if (-not $j.task.IsCompleted) { continue }
            if ($j.task.IsFaulted -or $j.task.IsCanceled) { $script:cfJobs.RemoveAt($i); & $j.done '' $j.status 'read' $j.ctx; continue }
        }
        $script:cfJobs.RemoveAt($i)
        & $j.done $j.task.Result $j.status '' $j.ctx
    }
}
function Get-CfErr($body, $status, $err) {
    if ($status -eq 401 -or $status -eq 403) { return (T 'cfPerm') }
    if ($err) { $m = [string]$err }
    else {
        $m = "HTTP $status"
        try { $e = @(($body | ConvertFrom-Json).errors); if ($e.Count -and $e[0].message) { $m = [string]$e[0].message } } catch {}
    }
    if ($m.Length -gt 120) { $m = $m.Substring(0, 120) }
    $m
}

# Builds (Workers Builds) and the latest deployment of every Worker, as rows in the same shape as the GitHub runs.
function Finish-CfAcct($acct, $items, $errMsg) {
    $key = "Cloudflare/$($acct.label)"
    if ($errMsg) { $script:errors[$key] = $errMsg } else { $script:errors.Remove($key) }
    if (-not $script:cfCycle) { return }
    $script:cfCycle.byAcct[[string]$acct.id] = @($items)
    $script:cfCycle.pending--
    if ($script:cfCycle.pending -le 0) {
        $all = @(); foreach ($v in $script:cfCycle.byAcct.Values) { $all += @($v) }
        $script:cfRuns = $all; $script:cfCycle = $null
        Merge-Runs
    }
}
function Receive-CfScripts($body, $status, $err, $ctx) {
    $a = $ctx.acct
    if ($err -or $status -ne 200) { Finish-CfAcct $a @() (Get-CfErr $body $status $err); return }
    try { $parsed = $body | ConvertFrom-Json; $scripts = @($parsed.result | Where-Object { $_ -and $_.id }) } catch { Finish-CfAcct $a @() 'JSON'; return }
    if (-not $scripts.Count) { Finish-CfAcct $a @() $null; return }
    $st = @{ acct = $a; scripts = @{}; builds = @(); left = 0; err = $null }
    foreach ($s in $scripts) { $st.scripts[[string]$s.tag] = $s }
    $tags = @($st.scripts.Keys)
    for ($i = 0; $i -lt $tags.Count; $i += 20) {
        $chunk = @($tags[$i..([math]::Min($i + 19, $tags.Count - 1))])
        $st.left++
        Start-Cf $a 'GET' "/accounts/$($a.id)/builds/builds/latest?external_script_ids=$($chunk -join ',')" $null ${function:Receive-CfBuilds} @{ st = $st }
    }
}
function Receive-CfBuilds($body, $status, $err, $ctx) {
    $st = $ctx.st; $a = $st.acct
    if ($err -or $status -ne 200) { $st.err = Get-CfErr $body $status $err }
    else {
        try {
            $map = ($body | ConvertFrom-Json).result.builds
            foreach ($p in @($map.PSObject.Properties)) {
                $b = $p.Value; $s = $st.scripts[[string]$p.Name]
                if (-not $b -or -not $s) { continue }
                $bs = [string]$b.status; $oc = [string]$b.build_outcome
                $status2 = switch ($bs) { 'queued' { 'queued' } 'stopped' { 'completed' } default { 'in_progress' } }
                $concl = switch ($oc) { 'success' { 'success' } { $_ -in 'fail', 'terminated' } { 'failure' } 'cancelled' { 'cancelled' } 'skipped' { 'skipped' } default { 'neutral' } }
                $msg = ([string]$b.build_trigger_metadata.commit_message -split "`n")[0]
                $st.builds += [pscustomobject]@{
                    databaseId = "cf-$($b.build_uuid)"; status = $status2; conclusion = $concl; displayTitle = $(if ($msg) { $msg } else { [string]$s.id })
                    workflowName = [string]$s.id; createdAt = [string]$b.created_on; updatedAt = $(if ($b.stopped_on) { [string]$b.stopped_on } else { [string]$b.modified_on })
                    url = "https://dash.cloudflare.com/$($a.id)/workers/services/view/$($s.id)/production/builds"; repo = [string]$a.label; acctKey = "cf:$($a.id)"; source = 'cloudflare'; kind = 'build'; via = ''
                }
            }
        } catch { $st.err = 'JSON' }
    }
    $st.left--
    if ($st.left -gt 0) { return }
    # A deployment right after a successful build is the build's own, so it gets no row of its own
    $rows = @($st.builds)
    $deploys = @()
    foreach ($s in $st.scripts.Values) {
        $mod = ToUtc $s.modified_on
        $own = @($st.builds | Where-Object { $_.workflowName -eq [string]$s.id -and $_.conclusion -eq 'success' -and [math]::Abs(((ToUtc $_.updatedAt) - $mod).TotalMinutes) -lt 3 })
        if ($own.Count) { continue }
        $deploys += [pscustomobject]@{
            databaseId = "cf-dep-$($a.id)-$($s.id)"; status = 'completed'; conclusion = 'success'; displayTitle = [string]$s.id; workflowName = ''
            createdAt = [string]$s.modified_on; updatedAt = [string]$s.modified_on; url = "https://dash.cloudflare.com/$($a.id)/workers/services/view/$($s.id)/production"
            repo = [string]$a.label; acctKey = "cf:$($a.id)"; source = 'cloudflare'; kind = 'deploy'; via = [string]$s.last_deployed_from
        }
    }
    $rows += $deploys
    # Everything that is running always shows; of the rest only the newest few per account
    $live = @($rows | Where-Object { (Get-State $_) -in 'running', 'queued' })
    $rest = @($rows | Where-Object { (Get-State $_) -notin 'running', 'queued' } | Sort-Object { ToUtc $_.updatedAt } -Descending | Select-Object -First ([int]$cfg.cfPerAccount))
    Finish-CfAcct $a (@($live) + @($rest)) $st.err
}
function Refresh-Cf {
    if ($script:cfFixture) { $script:cfRuns = @($script:cfFixture.runs); Merge-Runs; return }
    $accts = @(Get-CfAccounts)
    if (-not $accts.Count) { if ($script:cfRuns.Count) { $script:cfRuns = @(); Merge-Runs }; return }
    if ($script:cfCycle) { return }
    $script:cfCycle = @{ pending = $accts.Count; byAcct = @{} }
    foreach ($a in $accts) { Start-Cf $a 'GET' "/accounts/$($a.id)/workers/scripts" $null ${function:Receive-CfScripts} @{ acct = $a } }
}

# All the runs that were read (GitHub and Cloudflare) are kept in $script:cand. What the list shows is chosen from them by Select-Visible:
# the chosen account (filter), then the room is shared between the accounts so a busy one cannot push the others out.
$script:cand = @()
$script:runFilter = [string]$cfg.runFilter; if (-not $script:runFilter) { $script:runFilter = 'all' }
$script:sum = @{ running = 0; runKeys = @(); failKeys = @(); any = $false }
$script:failIds = @{}
function Merge-Runs {
    $script:cand = @(@($script:ghRuns) + @($script:cfRuns) | Where-Object { $_ })
    $multi = Test-Multi
    # A run that was running and has now finished is announced at the top for a minute
    foreach ($r in $script:cand) {
        $id = [string]$r.databaseId; $st = Get-State $r
        if ($script:prevState.ContainsKey($id) -and $script:prevState[$id] -in 'running', 'queued' -and $st -notin 'running', 'queued') {
            $who = $(if ($multi) { (Short (Get-AcctLabel (Get-RowKey $r)) 14) + ' · ' } else { '' })
            $el.flash.Text = (T 'finished') -f ($who + $r.displayTitle), (T $stateKey[$st])
            $el.flash.Foreground = Br $colors[$st]; $script:flashColor = $colors[$st]
            $script:flashUntil = (Get-Date).AddSeconds(60)
        }
        $script:prevState[$id] = $st
    }
    # The header says what is going on in all accounts, also the ones the filter hides: something running, or a workflow whose latest run failed
    $live = @($script:cand | Where-Object { (Get-State $_) -in 'running', 'queued' })
    $script:failIds = @{}
    $seen = @{}
    foreach ($r in ($script:cand | Where-Object { $_.status -eq 'completed' } | Sort-Object { ToUtc $_.createdAt } -Descending)) {
        $k = (Get-RowKey $r) + '|' + $r.repo + '|' + $r.workflowName
        if (-not $seen.ContainsKey($k)) { $seen[$k] = $true; if ((Get-State $r) -eq 'fail') { $script:failIds[[string]$r.databaseId] = $true } }
    }
    $failRows = @($script:cand | Where-Object { $script:failIds.ContainsKey([string]$_.databaseId) })
    $script:sum = @{ running = $live.Count; runKeys = @($live | ForEach-Object { Get-RowKey $_ } | Select-Object -Unique); failKeys = @($failRows | ForEach-Object { Get-RowKey $_ } | Select-Object -Unique); any = ($script:cand.Count -gt 0) }
    $script:updatedAt = Get-Date
    Select-Visible
    Render
    if ($win.IsLoaded) { Keep-OnScreen }
}
function Select-Visible {
    $max = [int]$cfg.maxRows
    $all = @($script:cand)
    $flt = $script:runFilter
    if ($flt -ne 'all' -and -not (Get-Acct $flt)) { $flt = 'all' }
    if ($flt -ne 'all') { $all = @($all | Where-Object { (Get-RowKey $_) -eq $flt }) }
    $sorted = @($all | Sort-Object { ToUtc $_.createdAt } -Descending)
    $script:pickList = New-Object System.Collections.ArrayList; $script:pickSeen = @{}
    # 1. what is running, 2. what is failing now, 3. an equal share per account, 4. the newest of the rest
    foreach ($r in $sorted) { if ((Get-State $r) -in 'running', 'queued') { [void](Add-Pick $r $max) } }
    foreach ($r in $sorted) { if ($script:failIds.ContainsKey([string]$r.databaseId)) { [void](Add-Pick $r $max) } }
    $keys = @($sorted | ForEach-Object { Get-RowKey $_ } | Select-Object -Unique)
    if ($keys.Count -gt 1) {
        $quota = [math]::Max(1, [int][math]::Floor($max / $keys.Count))
        foreach ($k in $keys) {
            $n = @($script:pickList | Where-Object { (Get-RowKey $_) -eq $k }).Count
            foreach ($r in ($sorted | Where-Object { (Get-RowKey $_) -eq $k })) { if ($n -ge $quota) { break }; if (Add-Pick $r $max) { $n++ } }
        }
    }
    foreach ($r in $sorted) { [void](Add-Pick $r $max) }
    $script:runs = @($script:pickList | Sort-Object { ToUtc $_.createdAt } -Descending)
}
function Add-Pick($r, $max) {
    $id = [string]$r.databaseId
    if ($script:pickSeen.ContainsKey($id) -or $script:pickList.Count -ge $max) { return $false }
    $script:pickSeen[$id] = $true; [void]$script:pickList.Add($r); $true
}

# Daily usage per account from the GraphQL analytics API. The reference is the Workers Free daily allowance (resets 00:00 UTC);
# limits from the Cloudflare docs (workers/platform/limits, workers/platform/pricing, workers-ai/platform/pricing), read 2026-11-06.
$cfLimits = @(
    @{ k = 'req'; label = 'cfWReq'; limit = 100000.0 }, @{ k = 'd1r'; label = 'cfD1R'; limit = 5000000.0 },
    @{ k = 'd1w'; label = 'cfD1W'; limit = 100000.0 }, @{ k = 'ai'; label = 'cfAi'; limit = 10000.0 }
)
$script:cfUsage = @{}        # account id -> @{ data; at; err; pending }
function New-Usage($login) { @{ summary = $null; items = $null; premium = @(); at = $null; err = $null; pending = 0; user = $login; login = $login } }
$script:usageBy = @{}
function Select-GhUsage($login) {
    if (-not $script:usageBy.ContainsKey([string]$login)) { $script:usageBy[[string]$login] = New-Usage ([string]$login) }
    $script:usage = $script:usageBy[[string]$login]
}
$script:usage = New-Usage ''
$script:usageBy[''] = $script:usage
# The source of the Usage tab: 'gh:<login>' or 'cf:<account id>'. Older config files have 'github' or a bare Cloudflare account id.
$script:usageSrc = [string]$cfg.usageSrc
function Get-CfUsageAcct {
    if ($script:usageSrc -notlike 'cf:*') { return $null }
    $id = $script:usageSrc.Substring(3)
    Get-CfAccounts | Where-Object { [string]$_.id -eq $id } | Select-Object -First 1
}
function Set-UsageSrc($key) {
    $script:usageSrc = $key; $cfg.usageSrc = $key
    if ($key -like 'gh:*') { Select-GhUsage $key.Substring(3) }
}
if ($script:usageSrc -notlike 'gh:*' -and $script:usageSrc -notlike 'cf:*') { $script:usageSrc = $(if ($script:usageSrc -and $script:usageSrc -ne 'github') { "cf:$($script:usageSrc)" } else { 'gh:' }) }
if ($script:usageSrc -eq 'gh:') { $script:usageSrc = 'gh:' + (Get-RepoLogin '') }
if ($script:usageSrc -like 'cf:*' -and -not (Get-CfUsageAcct)) { $script:usageSrc = 'gh:' + (Get-RepoLogin '') }
if ($script:usageSrc -like 'gh:*') { Select-GhUsage $script:usageSrc.Substring(3) }
function Get-UsageAt {
    $a = Get-CfUsageAcct
    if ($a) { $u = $script:cfUsage[[string]$a.id]; if ($u) { return $u.at } else { return $null } }
    $script:usage.at
}
function Receive-CfUsage($body, $status, $err, $ctx) {
    $u = $script:cfUsage[$ctx.id]; $u.pending = 0
    if ($err -or $status -ne 200) { $u.err = Get-CfErr $body $status $err }
    else {
        try {
            $p = $body | ConvertFrom-Json
            $acc = @($p.data.viewer.accounts)[0]
            if ($acc) {
                $sum = { param($list, $f) $t = 0.0; foreach ($x in @($list)) { if ($x -and $x.sum) { $t += [double]$x.sum.$f } }; $t }
                $u.data = @{ req = (& $sum $acc.w 'requests'); d1r = (& $sum $acc.d 'rowsRead'); d1w = (& $sum $acc.d 'rowsWritten'); ai = (& $sum $acc.ai 'totalNeurons') }
                $u.at = Get-Date; $u.err = $null
            } elseif ($p.errors) {
                $m = [string]@($p.errors)[0].message
                $u.err = $(if ($m -match 'access|authori|permission') { T 'cfPerm' } else { $m })
            } else { $u.err = T 'cfNoAccess' }
        } catch { $u.err = 'JSON' }
    }
    Render
}
function Refresh-CfUsage {
    $a = Get-CfUsageAcct
    if (-not $a) { return }
    $id = [string]$a.id
    if ($script:cfFixture) {
        $f = $script:cfFixture.usage.$id
        $script:cfUsage[$id] = @{ data = @{ req = [double]$f.req; d1r = [double]$f.d1r; d1w = [double]$f.d1w; ai = [double]$f.ai }; at = Get-Date; err = $null; pending = 0 }
        Render; return
    }
    $old = $script:cfUsage[$id]
    if ($old -and $old.pending) { return }
    $script:cfUsage[$id] = @{ data = $(if ($old) { $old.data }); at = $(if ($old) { $old.at }); err = $null; pending = 1 }
    $now = (Get-Date).ToUniversalTime()
    $fmt = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    $q = 'query($a:String!,$s:Time!,$u:Time!){viewer{accounts(filter:{accountTag:$a}){ w:workersInvocationsAdaptive(limit:1000,filter:{datetime_geq:$s,datetime_leq:$u}){sum{requests}} d:d1AnalyticsAdaptiveGroups(limit:1000,filter:{datetime_geq:$s,datetime_leq:$u}){sum{rowsRead rowsWritten}} ai:aiInferenceAdaptiveGroups(limit:1000,filter:{datetime_geq:$s,datetime_leq:$u}){sum{totalNeurons}} }}}'
    $body = @{ query = $q; variables = @{ a = $id; s = $now.Date.ToString($fmt, $inv); u = $now.ToString($fmt, $inv) } } | ConvertTo-Json -Depth 5 -Compress
    Start-Cf $a 'POST' '/graphql' $body ${function:Receive-CfUsage} @{ id = $id }
    Render
}

# ---------- usage (GitHub billing) ----------
$cultures = @{ en = 'en-US'; no = 'nb-NO'; sv = 'sv-SE'; da = 'da-DK' }
function Get-Culture2 { try { [Globalization.CultureInfo]::GetCultureInfo($cultures[[string]$cfg.language]) } catch { $inv } }
function Format-Money($v) { '$' + ([double]$v).ToString('N2', $inv) }
function Format-Num($v) { ([double]$v).ToString('N0', (Get-Culture2)) }

function Receive-Usage($out, $err, $code, $ctx) {
    $u = $ctx.u
    if ($code -ne 0 -and $ctx.kind -eq 'premium') {
        # The AI credits report is optional (not every account has it); a failure there is not an error for the tab
        $u.premium = @()
    } elseif ($code -ne 0) {
        $m = ([string]$err).Trim()
        $u.err = $(if ($m -match '403|404|scope|Resource not accessible') { (T 'uScope') -replace 'gh auth refresh -s user', $(if ($u.login) { "gh auth refresh -h github.com -u $($u.login) -s user" } else { 'gh auth refresh -s user' }) } else { (T 'uErr') -f $(if ($m.Length -gt 100) { $m.Substring(0, 100) } else { $m }) })
    } else {
        try {
            $parsed = $out | ConvertFrom-Json
            if ($ctx.kind -eq 'summary') { $u.summary = $parsed } elseif ($ctx.kind -eq 'premium') { $u.premium = @($parsed.usageItems) } else { $u.items = @($parsed.usageItems) }
            $u.err = $null
        } catch { $u.err = (T 'uErr') -f 'JSON' }
    }
    $u.pending--
    if ($u.pending -le 0) { $u.at = Get-Date; $u.pending = 0; Render; if ($win.IsLoaded) { Keep-OnScreen } }
}
function Start-UsageFetch {
    $now = (Get-Date).ToUniversalTime()
    $uo = $script:usage; $u = $uo.user; $lg = $uo.login
    $uo.pending = 3
    Start-Gh "api users/$u/settings/billing/premium_request/usage" ${function:Receive-Usage} @{ kind = 'premium'; u = $uo } $lg
    Start-Gh "api users/$u/settings/billing/usage/summary" ${function:Receive-Usage} @{ kind = 'summary'; u = $uo } $lg
    Start-Gh "api `"users/$u/settings/billing/usage?year=$($now.Year)&month=$($now.Month)`"" ${function:Receive-Usage} @{ kind = 'items'; u = $uo } $lg
}
function Refresh-Usage {
    if (Get-CfUsageAcct) { Refresh-CfUsage; return }
    if ($script:usage.pending -gt 0) { return }
    $fx = $env:CISTATUS_USAGE_FIXTURE
    if ($fx -and (Test-Path $fx)) {
        $f = Get-Content $fx -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:usage.summary = $f.summary; $script:usage.items = @($f.items); $script:usage.premium = @($f.premium); $script:usage.at = Get-Date; $script:usage.err = $null; Render; return
    }
    if (-not $gh) { Render; return }
    $uo = $script:usage
    $uo.pending = 1; Render
    if ($uo.user) { $uo.pending = 0; Start-UsageFetch; Render; return }
    # The login comes first (only when gh has not said who is logged in), then the billing calls
    Start-Gh 'api user --jq .login' {
        param($out, $err, $code, $ctx)
        $uo = $ctx.u; $uo.pending = 0
        $login = ([string]$out).Trim()
        if ($code -ne 0 -or -not $login) { $uo.err = (T 'uErr') -f ([string]$err).Trim(); Render; return }
        $uo.user = $login
        if ($script:usage -eq $uo) { Start-UsageFetch }
        Render
    } @{ u = $uo }
}

$script:usageSel = [string]$cfg.usageSel
$catDefs = @(
    @{ key = 'Actions'; rx = '^actions' }, @{ key = 'Packages'; rx = 'packages' }, @{ key = 'Git LFS'; rx = 'lfs' },
    @{ key = 'Codespaces'; rx = 'codespaces' }, @{ key = 'AI'; rx = 'copilot|model|spark|premium|credit|inference' }
)
$catKeys = @('Actions', 'Packages', 'Git LFS', 'Codespaces', 'AI', 'Other')
function Get-Cat($it) {
    $hay = (([string]$it.product) + ' ' + ([string]$it.sku)).ToLowerInvariant()
    foreach ($cd in $catDefs) { if ($hay -match $cd.rx) { return $cd.key } }
    'Other'
}
function Get-CatLabel($key) { switch ($key) { 'AI' { T 'catAI' } 'Other' { T 'catOther' } default { $key } } }
function Norm-Unit($x) { ([string]$x).ToLowerInvariant() -replace '[-_ ]', '' }
$unitLabel = @{ minutes = 'min'; gigabytehours = 'GB-h'; gigabytes = 'GB'; corehours = 'core-h'; requests = 'requests'; hours = 'h' }
$unitPrio = @('minutes', 'requests', 'corehours', 'gigabytes', 'gigabytehours', 'hours')
function Get-Budget($key) {
    $bb = $cfg.budgets
    if ($bb -is [System.Collections.IDictionary] -and $bb.Contains($key)) { return [double]$bb[$key] }
    0.0
}

# The source switch at the top of the Usage tab: GitHub, then one entry per Cloudflare account (only when there is an account)
function Render-UsageSrc {
    $accts = @(Get-Accounts)
    $el.uSrc.Children.Clear()
    if ($accts.Count -lt 2) { $el.uSrc.Visibility = 'Collapsed'; return }
    $el.uSrc.Visibility = 'Visible'
    foreach ($a in $accts) {
        $c = Get-AcctColor $a.key
        $on = ($a.key -eq $script:usageSrc)
        $bd = New-Object Windows.Controls.Border; $bd.CornerRadius = 4; $bd.Padding = '7,2,7,2'; $bd.Margin = '0,0,6,4'; $bd.Cursor = 'Hand'; $bd.Tag = "cmd:src:$($a.key)"
        $bd.Background = Br $(if ($on) { $c[0] } else { '#2A2A2A' })
        $tb = New-Object Windows.Controls.TextBlock; $tb.FontSize = 12; $tb.Text = "$($a.src) · $(Short $a.label 14)"; $tb.Foreground = Br $(if ($on) { $c[1] } else { '#999999' })
        if ($on) { $tb.FontWeight = 'SemiBold' }
        $bd.Child = $tb
        [void]$el.uSrc.Children.Add($bd)
    }
}
function Render-CfUsage($a) {
    $u = $script:cfUsage[[string]$a.id]
    $el.uRepos.Children.Clear(); $el.uOther.Children.Clear(); $el.uDaily.Children.Clear(); $el.uDaily.Visibility = 'Collapsed'
    $el.uNote.Visibility = 'Collapsed'; $el.uReposHead.Text = ''; $el.uReposHead.Visibility = 'Collapsed'
    if ($u -and $u.err) { $el.uNote.Text = $u.err; $el.uNote.Foreground = Br $colors.fail; $el.uNote.Visibility = 'Visible' }
    $d = if ($u) { $u.data } else { $null }
    if (-not $d) { $el.uDailyHead.Text = $(if ($u -and $u.pending) { T 'uCfLoading' } else { '' }); $el.uOtherHead.Text = ''; return }
    $el.uDailyHead.Text = (T 'uCfHead') -f $a.label
    $el.uOtherHead.Text = T 'uCfBars'
    foreach ($m in $cfLimits) {
        $v = [double]$d[$m.k]; $pct = $v / $m.limit * 100
        $state = if ($pct -ge 100) { 'fail' } elseif ($pct -ge 80) { 'running' } elseif ($v -gt 0) { 'ok' } else { 'queued' }
        $sp = New-Object Windows.Controls.StackPanel; $sp.Margin = '0,3,0,3'
        $g = New-Object Windows.Controls.Grid
        $cA = New-Object Windows.Controls.ColumnDefinition; $cA.Width = '*'
        $cB = New-Object Windows.Controls.ColumnDefinition; $cB.Width = 'Auto'
        [void]$g.ColumnDefinitions.Add($cA); [void]$g.ColumnDefinitions.Add($cB)
        $nm = New-Object Windows.Controls.StackPanel; $nm.Orientation = 'Horizontal'
        $dt = New-Object Windows.Shapes.Ellipse; $dt.Width = 8; $dt.Height = 8; $dt.Margin = '0,1,8,0'; $dt.Fill = Br $colors[$state]
        $nt = New-Object Windows.Controls.TextBlock; $nt.Text = T $m.label; $nt.FontSize = 13; $nt.Foreground = Br '#DDDDDD'
        [void]$nm.Children.Add($dt); [void]$nm.Children.Add($nt)
        $vt = New-Object Windows.Controls.TextBlock; $vt.FontSize = 13; $vt.Margin = '10,0,0,0'
        $vt.Text = '{0} / {1}' -f (Format-Num $v), (Format-Num $m.limit); $vt.Foreground = Br $(if ($v -gt 0) { $colors[$state] } else { '#777777' })
        [Windows.Controls.Grid]::SetColumn($nm, 0); [Windows.Controls.Grid]::SetColumn($vt, 1)
        [void]$g.Children.Add($nm); [void]$g.Children.Add($vt); [void]$sp.Children.Add($g)
        $trk = New-Object Windows.Controls.Grid; $trk.Height = 4; $trk.Margin = '0,3,0,0'; $trk.Background = Br '#333333'; $trk.HorizontalAlignment = 'Stretch'
        $ub = New-Object Windows.Shapes.Rectangle; $ub.HorizontalAlignment = 'Left'; $ub.RadiusX = 2; $ub.RadiusY = 2; $ub.Fill = Br $colors[$state]
        $ub.Width = [math]::Max(0, [math]::Min(100, $pct)) / 100 * 368
        [void]$trk.Children.Add($ub); [void]$sp.Children.Add($trk)
        [void]$el.uOther.Children.Add($sp)
    }
}

function Render-Usage {
    $u = $script:usage
    $ci = Get-Culture2
    Render-UsageSrc
    $cfA = Get-CfUsageAcct
    if ($cfA) { Render-CfUsage $cfA; return }
    $el.uDaily.Visibility = 'Visible'; $el.uReposHead.Visibility = 'Visible'
    $el.uRepos.Children.Clear(); $el.uOther.Children.Clear(); $el.uDaily.Children.Clear()
    $el.uNote.Visibility = 'Collapsed'
    $month = (Get-Date).ToUniversalTime()
    if ($u.err) { $el.uNote.Text = $u.err; $el.uNote.Foreground = Br $colors.fail; $el.uNote.Visibility = 'Visible' }
    $has = [bool]$u.summary
    if (-not $has) {
        $el.uDailyHead.Text = $(if ($u.pending -gt 0) { T 'uLoading' } elseif (-not $u.err) { T 'uNone' } else { '' })
        $el.uReposHead.Text = ''; $el.uOtherHead.Text = ''
        return
    }
    $items = @($u.summary.usageItems | Where-Object { $_ })
    $startM = Get-Date -Year $month.Year -Month $month.Month -Day 1 -Hour 0 -Minute 0 -Second 0
    $daysIn = [datetime]::DaysInMonth($month.Year, $month.Month)
    $elapsed = [math]::Max(1.0, ($month - $startM.ToUniversalTime()).TotalDays)
    $monthPct = [math]::Min(100, $elapsed / $daysIn * 100)

    # ---- the services: every one has its own row, also when nothing was used ----
    $aiSkus = @{}
    $all = @()
    foreach ($pi in @($u.premium)) { if ($pi) { $all += $pi; $aiSkus[[string]$pi.sku] = $true } }
    foreach ($si in $items) { if (-not $aiSkus.ContainsKey([string]$si.sku) -or [string]$si.product -notmatch 'copilot|model|spark|premium|credit') { $all += $si } }
    $groups = @{}
    foreach ($k in $catKeys) { $groups[$k] = New-Object System.Collections.ArrayList }
    foreach ($it in $all) { [void]$groups[(Get-Cat $it)].Add($it) }
    $total = [double](($all | Measure-Object netAmount -Sum).Sum)

    # ---- the chart and the repository list follow the service that was clicked ----
    $sel = [string]$script:usageSel
    if ($catKeys -notcontains $sel -or ($sel -eq 'Other' -and $groups['Other'].Count -eq 0)) { $sel = 'Actions' }
    $detail = @($u.items | Where-Object { $_ -and $_.date -and (Get-Cat $_) -eq $sel })
    $unit = $null
    foreach ($pu in $unitPrio) { if (@($detail | Where-Object { (Norm-Unit $_.unitType) -eq $pu }).Count) { $unit = $pu; break } }
    if (-not $unit -and $detail.Count) { $unit = Norm-Unit $detail[0].unitType }
    $detailU = @($detail | Where-Object { (Norm-Unit $_.unitType) -eq $unit })
    $ul = if ($unit -and $unitLabel.ContainsKey($unit)) { $unitLabel[$unit] } elseif ($unit) { $unit } else { '' }
    $label = Get-CatLabel $sel
    $byDay = @{}
    foreach ($d in $detailU) { $k = (ToUtc $d.date).Day; $byDay[$k] = [double]$byDay[$k] + [double]$d.quantity }
    $max = [double](($byDay.Values | Measure-Object -Maximum).Maximum); if ($max -le 0) { $max = 1 }
    $el.uDailyHead.Text = $(if ($detailU.Count) { (T 'uDailyFor') -f $label, $ul } else { (T 'uNoDaily') -f $label })
    $bw = 368.0 / $daysIn
    for ($day = 1; $day -le $daysIn; $day++) {
        $v = [double]$byDay[$day]
        $h = if ($v -gt 0) { [math]::Max(2, $v / $max * 46) } else { 1 }
        $r = New-Object Windows.Shapes.Rectangle
        $r.Width = [math]::Max(1, $bw - 2); $r.Height = $h
        $r.Fill = Br $(if ($day -eq $month.Day) { $colors.running } elseif ($v -gt 0) { '#6A9BCC' } else { '#333333' })
        $r.ToolTip = "$day. : " + (Format-Num $v) + " $ul"
        [Windows.Controls.Canvas]::SetLeft($r, ($day - 1) * $bw); [Windows.Controls.Canvas]::SetTop($r, 50 - $h)
        [void]$el.uDaily.Children.Add($r)
    }
    if ($detailU.Count) {
        $el.uReposHead.Text = (T 'uRepos') + ' · ' + $label
        $byRepo = $detailU | Group-Object repositoryName | ForEach-Object { [pscustomobject]@{ name = $_.Name; v = [double](($_.Group | Measure-Object quantity -Sum).Sum) } } | Sort-Object v -Descending | Select-Object -First 5
        foreach ($r in $byRepo) {
            $tb = New-Object Windows.Controls.TextBlock; $tb.FontSize = 13; $tb.Foreground = Br '#BBBBBB'
            $tb.Text = ('{0}  ·  {1} {2}' -f $r.name, (Format-Num $r.v), $ul); [void]$el.uRepos.Children.Add($tb)
        }
    } else { $el.uReposHead.Text = '' }

    # ---- one row per service: quantities, spending against its budget, month marker. A click selects it. ----
    $unitNames = @{ minutes = 'min'; gigabytehours = 'GB-h'; gigabytes = 'GB'; corehours = 'core-h'; requests = 'requests'; hours = 'h' }
    $el.uOtherHead.Text = (T 'uServices') + $(if ($total -gt 0.004) { ' · ' + ((T 'uBillable') -f (Format-Money $total)) } else { '' })
    foreach ($key in $catKeys) {
        $list = @($groups[$key])
        if ($key -eq 'Other' -and $list.Count -eq 0) { continue }
        $qty = @()
        foreach ($it in $list) {
            $g = [double]$it.grossQuantity
            if ($g -gt 0) {
                $nu = Norm-Unit $it.unitType; $un = if ($unitNames.ContainsKey($nu)) { $unitNames[$nu] } else { [string]$it.unitType }
                $gt = if ($g -ge 100) { Format-Num $g } else { $g.ToString('0.##', (Get-Culture2)) }
                $qty += ('{0} {1}' -f $gt, $un)
            }
        }
        $netA = [double](($list | Measure-Object netAmount -Sum).Sum)
        $bud = Get-Budget $key
        $dotColor = if ($netA -gt 0.004) { $colors.fail } elseif ($qty.Count) { $colors.running } else { $colors.queued }
        $rowB = New-Object Windows.Controls.Border
        $rowB.Padding = '4,3,4,3'; $rowB.Margin = '-4,0,-4,0'; $rowB.CornerRadius = 4; $rowB.Cursor = 'Hand'; $rowB.Tag = "cmd:svc:$key"
        $rowB.Background = Br $(if ($key -eq $sel) { '#2C2C2C' } else { '#00000000' })
        $sp2 = New-Object Windows.Controls.StackPanel
        $g2 = New-Object Windows.Controls.Grid
        $cA = New-Object Windows.Controls.ColumnDefinition; $cA.Width = 112
        $cB = New-Object Windows.Controls.ColumnDefinition; $cB.Width = '*'
        $cC = New-Object Windows.Controls.ColumnDefinition; $cC.Width = 'Auto'
        foreach ($cc in $cA, $cB, $cC) { [void]$g2.ColumnDefinitions.Add($cc) }
        $nm = New-Object Windows.Controls.StackPanel; $nm.Orientation = 'Horizontal'
        $dt = New-Object Windows.Shapes.Ellipse; $dt.Width = 8; $dt.Height = 8; $dt.Margin = '0,1,8,0'; $dt.Fill = Br $dotColor
        $nt = New-Object Windows.Controls.TextBlock; $nt.Text = Get-CatLabel $key; $nt.FontSize = 13; $nt.Foreground = Br $(if ($key -eq $sel) { '#FFFFFF' } else { '#DDDDDD' })
        if ($key -eq $sel) { $nt.FontWeight = 'SemiBold' }
        [void]$nm.Children.Add($dt); [void]$nm.Children.Add($nt)
        $qt = New-Object Windows.Controls.TextBlock; $qt.FontSize = 13; $qt.TextTrimming = 'CharacterEllipsis'
        $qt.Text = $(if ($qty.Count) { $qty -join ' · ' } else { T 'uNoUse' }); $qt.Foreground = Br $(if ($qty.Count) { '#BBBBBB' } else { '#777777' })
        $bt = New-Object Windows.Controls.TextBlock; $bt.FontSize = 13; $bt.Margin = '10,0,0,0'
        $bstate = 'ok'
        if ($bud -gt 0) {
            $bt.Text = '{0} / ${1}' -f (Format-Money $netA), ([double]$bud).ToString('0.##', $inv)
            if ($netA -ge $bud) { $bstate = 'fail' } elseif ($netA / $bud * 100 -gt $monthPct + 10) { $bstate = 'running' }
            $bt.Foreground = Br $(if ($netA -gt 0.004) { $colors[$bstate] } else { '#777777' })
        } else {
            $bt.Text = Format-Money $netA; $bt.Foreground = Br $(if ($netA -gt 0.004) { $colors.fail } else { '#777777' })
        }
        [Windows.Controls.Grid]::SetColumn($nm, 0); [Windows.Controls.Grid]::SetColumn($qt, 1); [Windows.Controls.Grid]::SetColumn($bt, 2)
        [void]$g2.Children.Add($nm); [void]$g2.Children.Add($qt); [void]$g2.Children.Add($bt)
        [void]$sp2.Children.Add($g2)
        if ($bud -gt 0) {
            # budget bar: the white marker is how far the month has come, the bar should stay left of it
            $trk = New-Object Windows.Controls.Grid; $trk.Height = 4; $trk.Margin = '0,3,0,0'; $trk.Background = Br '#333333'; $trk.HorizontalAlignment = 'Stretch'
            $ub = New-Object Windows.Shapes.Rectangle; $ub.HorizontalAlignment = 'Left'; $ub.RadiusX = 2; $ub.RadiusY = 2; $ub.Fill = Br $colors[$bstate]
            $ub.Width = [math]::Max(0, [math]::Min(100, $netA / $bud * 100)) / 100 * 352
            $pm = New-Object Windows.Shapes.Rectangle; $pm.HorizontalAlignment = 'Left'; $pm.Width = 1.5; $pm.Fill = Br '#FFFFFF'; $pm.Opacity = 0.8; $pm.Margin = New-Object Windows.Thickness(([math]::Min(100, $monthPct) / 100 * 352 - 1), -1, 0, -1)
            [void]$trk.Children.Add($ub); [void]$trk.Children.Add($pm); [void]$sp2.Children.Add($trk)
        }
        $rowB.Child = $sp2
        [void]$el.uOther.Children.Add($rowB)
    }
}

# ---------- updates ----------
function Start-Update {
    $l = if ($cfg.language -in @('en', 'no', 'sv', 'da')) { $cfg.language } else { 'en' }
    $c = "`$env:CISTATUS_LANG = '$l'; `$h = @{ Accept = 'application/vnd.github.raw'; 'User-Agent' = 'CIStatus' }; `$s = try { irm -Headers `$h 'https://api.github.com/repos/saysphilippe/CIStatus/contents/install.ps1?ref=main' } catch { irm 'https://raw.githubusercontent.com/saysphilippe/CIStatus/main/install.ps1' }; iex `$s"
    Start-Process powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $c
}
# The widget compares itself with the file on GitHub (ignoring line endings and BOM). A .NET task fetches it; the one-second timer picks it up.
$script:updateAvailable = ($env:CISTATUS_FAKEUPDATE -eq '1')
$script:updTask = $null
$script:updHttp = $null
$script:updCheckedAt = [datetime]::MinValue
$script:http = $null
function Get-NormHash($text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($text -replace "`r", '').TrimStart([char]0xFEFF))))
}
function Start-UpdateCheck {
    if ($script:updTask -or -not $scriptPath -or $env:CISTATUS_FAKEUPDATE) { return }
    if (-not $script:updHttp) {
        $script:updHttp = New-Object Net.Http.HttpClient; $script:updHttp.Timeout = [TimeSpan]::FromSeconds(20)
        [void]$script:updHttp.DefaultRequestHeaders.UserAgent.ParseAdd('CIStatus'); [void]$script:updHttp.DefaultRequestHeaders.Accept.ParseAdd('application/vnd.github.raw')
    }
    $script:updCheckedAt = Get-Date
    # The API is not cached like raw.githubusercontent.com, which can be a few minutes behind a push
    $script:updTask = $script:updHttp.GetStringAsync('https://api.github.com/repos/saysphilippe/CIStatus/contents/CIStatus.ps1?ref=main')
}
function Receive-UpdateCheck {
    if (-not $script:updTask -or -not $script:updTask.IsCompleted) { return }
    $t = $script:updTask; $script:updTask = $null
    if ($t.IsFaulted -or $t.IsCanceled) { return }
    try {
        $remote = Get-NormHash $t.Result
        $local = Get-NormHash ([IO.File]::ReadAllText($scriptPath, [Text.Encoding]::UTF8))
        $was = $script:updateAvailable
        $script:updateAvailable = ($remote -ne $local)
        if ($was -ne $script:updateAvailable) { Render }
    } catch {}
}

function Show-Tab($t) {
    $cfg.tab = $t; Save-Config
    $el.runsPanel.Visibility = $(if ($t -eq 'runs') { 'Visible' } else { 'Collapsed' })
    $el.usagePanel.Visibility = $(if ($t -eq 'usage') { 'Visible' } else { 'Collapsed' })
    $el.e2ePanel.Visibility = $(if ($t -eq 'e2e') { 'Visible' } else { 'Collapsed' })
    $el.tabRuns.Foreground = Br $(if ($t -eq 'runs') { '#D97757' } else { '#999999' }); $el.tabRuns.FontWeight = $(if ($t -eq 'runs') { 'SemiBold' } else { 'Normal' })
    $el.tabUsage.Foreground = Br $(if ($t -eq 'usage') { '#D97757' } else { '#999999' }); $el.tabUsage.FontWeight = $(if ($t -eq 'usage') { 'SemiBold' } else { 'Normal' })
    $el.tabE2E.Foreground = Br $(if ($t -eq 'e2e') { '#D97757' } else { '#999999' }); $el.tabE2E.FontWeight = $(if ($t -eq 'e2e') { 'SemiBold' } else { 'Normal' })
    $uat = Get-UsageAt
    if ($t -eq 'usage' -and (-not $uat -or ((Get-Date) - $uat).TotalSeconds -gt 60)) { Refresh-Usage }
    Render
    if ($win.IsLoaded) { Keep-OnScreen }
}

# The filter row on the Runs tab: All, then one chip per account with a dot for what is happening there (red = failing, yellow = running)
function Render-RunFilter {
    $accts = @(Get-Accounts)
    $el.runFilter.Children.Clear()
    if ($accts.Count -lt 2) { $el.runFilter.Visibility = 'Collapsed'; return }
    $el.runFilter.Visibility = 'Visible'
    $cur = $script:runFilter; if ($cur -ne 'all' -and -not (Get-Acct $cur)) { $cur = 'all' }
    $items = @([pscustomobject]@{ key = 'all'; text = T 'fltAll'; c = @('#3A3A3A', '#EEEEEE') })
    foreach ($a in $accts) { $items += [pscustomobject]@{ key = $a.key; text = "$($a.src) · $(Short $a.label 14)"; c = (Get-AcctColor $a.key) } }
    foreach ($it in $items) {
        $on = ($it.key -eq $cur)
        $bd = New-Object Windows.Controls.Border; $bd.CornerRadius = 4; $bd.Padding = '7,2,7,2'; $bd.Margin = '0,0,6,4'; $bd.Cursor = 'Hand'; $bd.Tag = "cmd:flt:$($it.key)"
        $bd.Background = Br $(if ($on) { $it.c[0] } else { '#2A2A2A' })
        $sp = New-Object Windows.Controls.StackPanel; $sp.Orientation = 'Horizontal'
        if ($it.key -ne 'all') {
            $dotColor = if (@($script:sum.failKeys) -contains $it.key) { $colors.fail } elseif (@($script:sum.runKeys) -contains $it.key) { $colors.running } else { $null }
            if ($dotColor) { $d = New-Object Windows.Shapes.Ellipse; $d.Width = 7; $d.Height = 7; $d.Margin = '0,1,5,0'; $d.Fill = Br $dotColor; [void]$sp.Children.Add($d) }
        }
        $tb = New-Object Windows.Controls.TextBlock; $tb.FontSize = 12; $tb.Text = $it.text; $tb.Foreground = Br $(if ($on) { $it.c[1] } else { '#999999' })
        if ($on) { $tb.FontWeight = 'SemiBold' }
        [void]$sp.Children.Add($tb); $bd.Child = $sp
        [void]$el.runFilter.Children.Add($bd)
    }
}

function Render {
    $el.title.Text = T 'title'
    $el.tabRuns.Text = T 'tabRuns'; $el.tabUsage.Text = T 'tabUsage'; $el.tabE2E.Text = T 'tabE2E'
    $cfLink = if ($cfg.tab -eq 'usage') { Get-CfUsageAcct } else { $null }
    if ($cfLink) { $el.usageLink.Text = T 'linkUsageCf'; $el.usageLink.Tag = "https://dash.cloudflare.com/$($cfLink.id)/workers-and-pages" }
    else { $el.usageLink.Text = T 'linkUsage'; $el.usageLink.Tag = 'https://github.com/settings/billing/summary' }
    foreach ($k in 'e2eHelp', 'e2eRel', 'e2eRelSub', 'e2eAll', 'e2eAllSub', 'e2eSome', 'e2eSomeSub') { $el[$k].Text = T $k }
    # The last e2e message stays on the E2E tab for a while
    if ($script:e2eNoteText -and (Get-Date) -lt $script:e2eNoteUntil) { $el.e2eNote.Text = $script:e2eNoteText; $el.e2eNote.Foreground = Br $script:e2eNoteColor; $el.e2eNote.Visibility = 'Visible' } else { $el.e2eNote.Visibility = 'Collapsed' }
    $el.updNew.Text = T 'updNew'; $el.updNew.Visibility = $(if ($script:updateAvailable) { 'Visible' } else { 'Collapsed' })
    if ($cfg.tab -eq 'usage') { Render-Usage }
    $el.rows.Children.Clear()
    Render-RunFilter
    $running = @($script:runs | Where-Object { (Get-State $_) -in 'running', 'queued' })
    # Summary (over all accounts, also the ones the filter hides): something running > a workflow whose latest run failed > all green.
    # With more than one account it also says where.
    $multi = Test-Multi
    $where = { param($keys) if (-not $multi -or -not @($keys).Count) { return '' }; ' · ' + (Short (Get-AcctLabel @($keys)[0]) 12) + $(if (@($keys).Count -gt 1) { " +$(@($keys).Count - 1)" } else { '' }) }
    if (-not (Test-Sources)) { $el.summary.Text = ''; }
    elseif ($script:sum.running -gt 0) { $el.summary.Text = ((T 'running') -f $script:sum.running) + (& $where $script:sum.runKeys); $el.summary.Foreground = Br $colors.running }
    elseif (@($script:sum.failKeys).Count) { $el.summary.Text = (T 'failing') + (& $where $script:sum.failKeys); $el.summary.Foreground = Br $colors.fail }
    elseif ($script:sum.any) { $el.summary.Text = T 'green'; $el.summary.Foreground = Br $colors.ok }
    else { $el.summary.Text = '' }
    $failing = @($script:sum.failKeys).Count -gt 0

    foreach ($r in $script:runs) {
        $st = Get-State $r
        $row = New-Object Windows.Controls.Border
        $row.Padding = '0,5,0,5'; $row.Background = Br '#00000000'; $row.Cursor = 'Hand'; $row.Tag = [string]$r.url
        $g = New-Object Windows.Controls.Grid
        $c0 = New-Object Windows.Controls.ColumnDefinition; $c0.Width = 'Auto'
        $c1 = New-Object Windows.Controls.ColumnDefinition; $c1.Width = '*'
        [void]$g.ColumnDefinitions.Add($c0); [void]$g.ColumnDefinitions.Add($c1)
        $dot = New-Object Windows.Shapes.Ellipse
        $dot.Width = 10; $dot.Height = 10; $dot.Margin = '0,5,10,0'; $dot.VerticalAlignment = 'Top'; $dot.Fill = Br $colors[$st]
        [Windows.Controls.Grid]::SetColumn($dot, 0)
        $sp = New-Object Windows.Controls.StackPanel
        [Windows.Controls.Grid]::SetColumn($sp, 1)
        $t1 = New-Object Windows.Controls.TextBlock
        $t1.Text = [string]$r.displayTitle; $t1.Foreground = Br '#EEEEEE'; $t1.FontSize = 13; $t1.TextTrimming = 'CharacterEllipsis'; $t1.ToolTip = [string]$r.displayTitle
        $created = ToUtc $r.createdAt
        $parts = @(if ($r.source -eq 'cloudflare') { [string]$r.workflowName } else { ([string]$r.repo -split '/')[-1]; [string]$r.workflowName })
        if ($r.kind -eq 'deploy') {
            # A Cloudflare deployment: the Worker's name is the title, no workflow and no duration
            $parts = @(((T 'cfDeployed') + $(if ($r.via) { ' ' + ((T 'cfVia') -f $r.via) } else { '' })), (Format-Ago $created))
        } elseif ($st -in 'running', 'queued') {
            $parts += (T $stateKey[$st]) + ' ' + (Format-Dur ((Get-Date).ToUniversalTime() - $created))
            if ($script:jobInfo.ContainsKey([string]$r.databaseId)) { $parts += ((T 'jobs') -f ($script:jobInfo[[string]$r.databaseId] -split '/')) }
        } else {
            $parts += (T $stateKey[$st]) + ' · ' + (Format-Dur ((ToUtc $r.updatedAt) - $created))
            $parts += Format-Ago (ToUtc $r.updatedAt)
        }
        $t2 = New-Object Windows.Controls.TextBlock
        $t2.Text = (@($parts | Where-Object { $_ }) -join ' · '); $t2.Foreground = Br '#999999'; $t2.FontSize = 12; $t2.TextTrimming = 'CharacterEllipsis'
        if ($multi) {
            # Which account the run belongs to: a small coloured label (source and name) in front of the grey text
            $dp = New-Object Windows.Controls.DockPanel
            $bdg = New-AcctBadge (Get-RowKey $r)
            [Windows.Controls.DockPanel]::SetDock($bdg, 'Left')
            [void]$dp.Children.Add($bdg); [void]$dp.Children.Add($t2)
            [void]$sp.Children.Add($t1); [void]$sp.Children.Add($dp)
        } else { [void]$sp.Children.Add($t1); [void]$sp.Children.Add($t2) }
        [void]$g.Children.Add($dot); [void]$g.Children.Add($sp)
        $row.Child = $g
        [void]$el.rows.Children.Add($row)
    }

    $msgs = @()
    if (-not (Test-Sources)) { $msgs += T 'noGh' }
    elseif (($script:cycle -or $script:cfCycle) -and $script:runs.Count -eq 0 -and $script:errors.Count -eq 0) { $msgs += T 'loading' }
    elseif ($script:runs.Count -eq 0 -and $script:errors.Count -eq 0) { $msgs += T 'noRuns' }
    foreach ($k in $script:errors.Keys) { $msgs += ((T 'ghErr') -f $k, $script:errors[$k]) }
    if ($msgs.Count) { $el.note.Text = ($msgs -join "`n"); $el.note.Foreground = Br $(if ($script:errors.Count -or -not (Test-Sources)) { '#E5534B' } else { '#999999' }); $el.note.Visibility = 'Visible' }
    else { $el.note.Visibility = 'Collapsed' }

    if ((Get-Date) -lt $script:flashUntil) { $el.flash.Visibility = 'Visible' } else { $el.flash.Visibility = 'Collapsed' }
    # Minimized view: one line per run that is running; with nothing running, a dot in the colour of the latest result
    $el.miniRows.Children.Clear()
    $addMini = {
        param($color, $text)
        $mr = New-Object Windows.Controls.StackPanel; $mr.Orientation = 'Horizontal'; $mr.Margin = '0,2,0,2'
        $d = New-Object Windows.Shapes.Ellipse; $d.Width = 9; $d.Height = 9; $d.Margin = '0,1,8,0'; $d.Fill = Br $color
        $tb = New-Object Windows.Controls.TextBlock; $tb.Text = $text; $tb.Foreground = Br '#EEEEEE'; $tb.FontSize = 12
        [void]$mr.Children.Add($d); [void]$mr.Children.Add($tb); [void]$el.miniRows.Children.Add($mr)
    }
    foreach ($r in ($running | Select-Object -First 4)) {
        $name = [string]$r.displayTitle; if ($name.Length -gt 34) { $name = $name.Substring(0, 33) + '…' }
        if ($multi) { $name = (Short (Get-AcctLabel (Get-RowKey $r)) 10) + ' · ' + $name }
        $info = Format-Dur ((Get-Date).ToUniversalTime() - (ToUtc $r.createdAt))
        if ($script:jobInfo.ContainsKey([string]$r.databaseId)) { $info += ' · ' + ((T 'jobs') -f ($script:jobInfo[[string]$r.databaseId] -split '/')) }
        & $addMini $colors[(Get-State $r)] "$name  $info"
    }
    if ((Get-Date) -lt $script:flashUntil) { & $addMini $script:flashColor ([string]$el.flash.Text) }
    if ($el.miniRows.Children.Count -eq 0) {
        if (-not (Test-Sources)) { & $addMini $colors.fail (T 'noGh') }
        elseif ($script:errors.Count) { & $addMini $colors.fail ((T 'ghErr') -f @($script:errors.Keys)[0], '') }
        elseif ($failing) { & $addMini $colors.fail ((T 'failing') + (& $where $script:sum.failKeys)) }
        elseif ($script:sum.any) { & $addMini $colors.ok (T 'green') }
        else { & $addMini $colors.queued (T 'nothing') }
    }
    $el.mini.ToolTip = T 'restore'; $el.minBtn.ToolTip = T 'minimize'
    if ($cfg.tab -eq 'usage') { $uat = Get-UsageAt; $el.upd.Text = $(if ($uat) { ((T 'updated') -f $uat.ToString('HH:mm:ss')) + ' · ' } else { '' }) + (T $(if (Get-CfUsageAcct) { 'uCfLag' } else { 'uLag' })) }
    else { $el.upd.Text = $(if ($script:updatedAt) { ((T 'updated') -f $script:updatedAt.ToString('HH:mm:ss')) + ' · ' } else { '' }) + (T 'hint') }
    if ($win.IsLoaded) { Keep-OnScreen }   # the content may have grown or shrunk: back to the anchor
}

function Complete-Cycle {
    $gAll = @()
    foreach ($repo in (Get-Repos)) { $gAll += @($script:cycle.byRepo[$repo]) }
    $script:ghRuns = @($gAll | Where-Object { $_ })
    $script:cycle = $null
    Merge-Runs
    # For GitHub runs in progress, read the jobs so the row can show how far it has come
    foreach ($r in ($script:runs | Where-Object { (Get-State $_) -eq 'running' -and $_.source -ne 'cloudflare' } | Select-Object -First 3)) {
        Start-Gh "run view $($r.databaseId) --repo $($r.repo) --json jobs" {
            param($out, $err, $code, $ctx)
            if ($code -ne 0) { return }
            try {
                $jobsList = @(($out | ConvertFrom-Json).jobs)
                $script:jobInfo[$ctx.id] = '{0}/{1}' -f @($jobsList | Where-Object { $_.status -eq 'completed' }).Count, $jobsList.Count
                Render
            } catch {}
        } @{ id = [string]$r.databaseId } (Get-RepoLogin $r.repo)
    }
}

function Receive-RunList($out, $err, $code, $ctx) {
    $repo = $ctx.repo
    if ($code -ne 0) {
        $m = ([string]$err).Trim(); if ($m.Length -gt 120) { $m = $m.Substring(0, 120) }
        $script:errors[$repo] = $m
    } else {
        $script:errors.Remove($repo)
        try {
            $parsed = $out | ConvertFrom-Json   # Windows PowerShell 5.1 hands a JSON array on as one object, so assign before wrapping
            $list = @($parsed)
            foreach ($r in $list) { $r | Add-Member -NotePropertyName repo -NotePropertyValue $repo -Force }
            $script:cycle.byRepo[$repo] = $list
        } catch { $script:errors[$repo] = 'JSON' }
    }
    $script:cycle.pending--
    if ($script:cycle.pending -le 0) { Complete-Cycle }
}

function Refresh {
    $script:since = 0
    Refresh-Cf
    if ($script:cycle) { return }
    $repos = @(Get-Repos)
    $fixture = $env:CISTATUS_FIXTURE
    if ($fixture -and (Test-Path $fixture)) {
        $parsed = Get-Content $fixture -Raw -Encoding UTF8 | ConvertFrom-Json; $script:ghRuns = @($parsed); Merge-Runs; return
    }
    if (-not $gh -or $repos.Count -eq 0) { Render; return }
    $script:cycle = @{ pending = $repos.Count; byRepo = @{} }
    foreach ($repo in $repos) {
        Start-Gh "run list --repo $repo --limit $([int]$cfg.perRepo) --json databaseId,status,conclusion,displayTitle,workflowName,createdAt,updatedAt,event,headBranch,url" ${function:Receive-RunList} @{ repo = $repo } (Get-RepoLogin $repo)
    }
    Render
}

# The window is not drawn yet at start-up (ActualWidth is 0), so its size is measured instead
function Get-WinSize {
    # The window sizes itself to its content, so the content's own desired size is the window size
    $c = $win.Content
    $c.Measure((New-Object Windows.Size ([double]::PositiveInfinity), ([double]::PositiveInfinity)))
    @($c.DesiredSize.Width, $c.DesiredSize.Height)
}
# The position the user chose (the anchor) is kept apart from where the window is drawn. The window sizes itself to its content, so a run with a long
# title makes it wider or taller than the screen edge allows and it is shifted to stay on screen. When the content shrinks again the window goes back to the
# anchor, instead of staying where it was pushed. Minimized and not moved by the user: the bottom right corner, growing left and up.
$script:dragging = $false
function Get-Anchor {
    if ($cfg.minimized) {
        if ($null -ne $cfg.miniLeft -and $null -ne $cfg.miniTop) { return @([double]$cfg.miniLeft, [double]$cfg.miniTop) }
        $sz = Get-WinSize; $wa = [Windows.SystemParameters]::WorkArea
        return @(($wa.Right - $sz[0] - 12), ($wa.Bottom - $sz[1] - 12))
    }
    @([double]$cfg.left, [double]$cfg.top)
}
# Put the window at its anchor, then keep the whole window inside the work area (taskbar excluded), e.g. after the Usage tab made it taller
function Keep-OnScreen {
    if ($script:dragging) { return }
    $sz = Get-WinSize
    $wa = [Windows.SystemParameters]::WorkArea
    $a = Get-Anchor
    $win.Left = [math]::Max($wa.Left, [math]::Min($a[0], $wa.Right - $sz[0]))
    $win.Top = [math]::Max($wa.Top, [math]::Min($a[1], $wa.Bottom - $sz[1]))
}

function Set-Minimized($m) {
    $cfg.minimized = [bool]$m; Save-Config
    $el.root.Visibility = $(if ($m) { 'Collapsed' } else { 'Visible' })
    $el.mini.Visibility = $(if ($m) { 'Visible' } else { 'Collapsed' })
    Render
    Keep-OnScreen
}

# ---------- e2e tests (the "E2E (manuelt)" workflow in the first watched repo) ----------
$script:e2eNoteText = $null; $script:e2eNoteColor = '#EEEEEE'; $script:e2eNoteUntil = [datetime]::MinValue
function Set-E2ENote($text, $color) {
    $script:e2eNoteText = $text; $script:e2eNoteColor = $color; $script:e2eNoteUntil = (Get-Date).AddSeconds(90)
    Render
}
# $tests: 'relevante', 'alle' or parts of test names (scripts/e2e-relevant.mjs in the repo decides what runs)
function Start-E2E($tests) {
    $tests = ([string]$tests -replace '[^A-Za-z0-9 ._-]', '').Trim()
    if (-not $tests) { $tests = 'relevante' }
    $repo = if ($cfg.e2eRepo) { [string]$cfg.e2eRepo } else { [string]@(Get-Repos)[0] }
    if (-not $gh -or -not $repo) { Set-E2ENote (T 'noGh') $colors.fail; return }
    Set-E2ENote ((T 'e2eStarting') -f $tests) $colors.running
    Start-Gh "workflow run e2e.yml --repo $repo -f `"tests=$tests`"" {
        param($out, $err, $code, $ctx)
        if ($code -eq 0) { Set-E2ENote ((T 'e2eStarted') -f $ctx.tests) $colors.ok; $script:since = 24 }
        else { $m = ([string]$err).Trim(); if ($m.Length -gt 120) { $m = $m.Substring(0, 120) }; Set-E2ENote ((T 'e2eFail') -f $m) $colors.fail }
    } @{ tests = $tests } (Get-RepoLogin $repo)
}
# "Choose tests": a list with a check box per test. The names and descriptions come from tests/e2e/oversikt.json in the repo.
$script:e2eList = $null; $script:e2eListAt = [datetime]::MinValue
function Show-E2EPicker($list) {
    [xml]$px = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Width="560" Height="620" Background="#1E1E1E" WindowStartupLocation="CenterScreen" ShowInTaskbar="False" Topmost="True">
  <DockPanel Margin="16">
    <TextBlock Name="pTitle" DockPanel.Dock="Top" Foreground="#D97757" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,6"/>
    <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="0,0,0,8">
      <TextBlock Name="pAll" Foreground="#6A9BCC" FontSize="12" Cursor="Hand" TextDecorations="Underline" Background="Transparent"/>
      <TextBlock Name="pNone" Foreground="#6A9BCC" FontSize="12" Cursor="Hand" TextDecorations="Underline" Background="Transparent" Margin="14,0,0,0"/>
    </StackPanel>
    <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,12,0,0">
      <Button Name="pCancel" Padding="16,6" Margin="0,0,8,0" IsCancel="True"/>
      <Button Name="pRun" Padding="16,6" IsDefault="True"/>
    </StackPanel>
    <ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel Name="pList"/></ScrollViewer>
  </DockPanel>
</Window>
'@
    $dlg = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $px))
    $f = @{}
    'pTitle', 'pAll', 'pNone', 'pList', 'pCancel', 'pRun' | ForEach-Object { $f[$_] = $dlg.FindName($_) }
    $dlg.Title = T 'e2eSome'; $f.pTitle.Text = T 'e2ePick'; $f.pAll.Text = T 'e2eSelAll'; $f.pNone.Text = T 'e2eSelNone'; $f.pCancel.Content = T 'e2eCancel'
    $boxes = New-Object System.Collections.ArrayList
    $upd = {
        $n = @($boxes | Where-Object { $_.IsChecked }).Count
        $f.pRun.Content = (T 'e2eRunN') -f $n; $f.pRun.IsEnabled = ($n -gt 0)
    }.GetNewClosure()
    foreach ($it in $list) {
        $cb = New-Object Windows.Controls.CheckBox
        $cb.Tag = [string]$it.name; $cb.Margin = '0,4,0,4'
        $sp = New-Object Windows.Controls.StackPanel
        $t1 = New-Object Windows.Controls.TextBlock; $t1.Text = [string]$it.title; $t1.TextWrapping = 'Wrap'; $t1.FontSize = 13; $t1.Foreground = Br '#EEEEEE'
        $t2 = New-Object Windows.Controls.TextBlock; $t2.Text = [string]$it.name; $t2.FontSize = 11; $t2.Foreground = Br '#888888'
        [void]$sp.Children.Add($t1); [void]$sp.Children.Add($t2)
        $cb.Content = $sp
        $cb.Add_Checked($upd); $cb.Add_Unchecked($upd)
        [void]$boxes.Add($cb); [void]$f.pList.Children.Add($cb)
    }
    $f.pAll.Add_MouseLeftButtonDown({ foreach ($b in $boxes) { $b.IsChecked = $true } }.GetNewClosure())
    $f.pNone.Add_MouseLeftButtonDown({ foreach ($b in $boxes) { $b.IsChecked = $false } }.GetNewClosure())
    $f.pRun.Add_Click({ $dlg.DialogResult = $true }.GetNewClosure())
    & $upd
    if ($dlg.ShowDialog()) {
        $picked = @($boxes | Where-Object { $_.IsChecked } | ForEach-Object { [string]$_.Tag })
        if ($picked.Count -eq $boxes.Count) { Start-E2E 'alle' } elseif ($picked.Count -gt 0) { Start-E2E ($picked -join ' ') }
    }
}
function Open-E2EPicker {
    if ($script:e2eList -and ((Get-Date) - $script:e2eListAt).TotalMinutes -lt 10) { Show-E2EPicker $script:e2eList; return }
    $repo = if ($cfg.e2eRepo) { [string]$cfg.e2eRepo } else { [string]@(Get-Repos)[0] }
    if (-not $gh -or -not $repo) { Set-E2ENote (T 'noGh') $colors.fail; return }
    Set-E2ENote (T 'e2eLoadingList') $colors.running
    Start-Gh "api repos/$repo/contents/tests/e2e/oversikt.json -H `"Accept: application/vnd.github.raw`"" {
        param($out, $err, $code, $ctx)
        $list = $null
        if ($code -eq 0) { try { $parsed = $out | ConvertFrom-Json; $list = @($parsed) } catch {} }
        if ($list -and $list.Count) {
            $script:e2eList = $list; $script:e2eListAt = Get-Date; $script:e2eNoteText = $null; Render
            Show-E2EPicker $list
        } else {
            $m = ([string]$err).Trim(); if ($m.Length -gt 120) { $m = $m.Substring(0, 120) }
            Set-E2ENote ((T 'e2eListFail') -f $m) $colors.fail
        }
    } @{} (Get-RepoLogin $repo)
}

# ---------- menu ----------
$menu = New-Object Windows.Controls.ContextMenu
$menuItems = @{}
function AddItem($key, $action, $parent = $menu) { $mi = New-Object Windows.Controls.MenuItem; $mi.Add_Click($action); [void]$parent.Items.Add($mi); if ($key) { $menuItems[$key] = $mi }; $mi }
AddItem 'mRefresh' { Refresh; if ($cfg.tab -eq 'usage') { Refresh-Usage } } | Out-Null
AddItem 'mMinimize' { Set-Minimized (-not $cfg.minimized) } | Out-Null
$budgetMenu = AddItem 'mBudgets' {}
$budgetItems = @{}
foreach ($bk in 'Actions', 'Packages', 'Git LFS', 'Codespaces', 'AI') {
    $bi = AddItem $null {
        $key = $this.Tag
        $v = ([Microsoft.VisualBasic.Interaction]::InputBox(((T 'askBudgetFor') -f (Get-CatLabel $key)), (T 'title'), [string](Get-Budget $key))).Trim() -replace ',', '.'
        if (-not $v) { return }
        $n = 0.0
        if (-not [double]::TryParse($v, [Globalization.NumberStyles]::Float, $inv, [ref]$n) -or $n -lt 0) { [void][Windows.MessageBox]::Show((T 'badNum'), (T 'title')); return }
        $cfg.budgets[$key] = $n; Save-Config; Render
    } $budgetMenu
    $bi.Tag = $bk; $budgetItems[$bk] = $bi
}
function Show-AddRepoDialog {
    [xml]$dx = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
        SizeToContent="Height" Width="400" Background="#1E1E1E" ShowInTaskbar="False" Topmost="True">
  <StackPanel Margin="16">
    <TextBlock Name="lbl" Foreground="#EEEEEE" FontSize="13" TextWrapping="Wrap" Margin="0,0,0,4"/>
    <TextBox Name="repo" FontSize="13" Margin="0,0,0,10"/>
    <StackPanel Name="acctBox">
      <TextBlock Name="alb" Foreground="#EEEEEE" FontSize="13" Margin="0,0,0,4"/>
      <ComboBox Name="acct" FontSize="13" Margin="0,0,0,10"/>
    </StackPanel>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,6,0,0">
      <Button Name="ok" IsDefault="True" Padding="16,4" Margin="0,0,8,0"/>
      <Button Name="cancel" IsCancel="True" Padding="16,4"/>
    </StackPanel>
  </StackPanel>
</Window>
'@
    $dlg = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $dx))
    $dlg.Title = T 'mAddRepo'
    $dlg.FindName('lbl').Text = T 'askRepo'; $dlg.FindName('alb').Text = T 'ghAcctLbl'
    $dlg.FindName('ok').Content = T 'cfAdd'; $dlg.FindName('cancel').Content = T 'cfCancel'
    $cb = $dlg.FindName('acct'); $gha = @(Get-GhAccounts)
    foreach ($a in $gha) {
        $it = New-Object Windows.Controls.ComboBoxItem; $it.Content = "$(if ($a.label) { $a.label } else { $a.login })  ($($a.login))"; $it.Tag = [string]$a.login
        [void]$cb.Items.Add($it)
        if ([string]$a.login -eq [string]$cfg.ghActive) { $cb.SelectedItem = $it }
    }
    if ($cb.SelectedIndex -lt 0 -and $cb.Items.Count) { $cb.SelectedIndex = 0 }
    if ($gha.Count -lt 2) { $dlg.FindName('acctBox').Visibility = 'Collapsed' }
    $dlg.FindName('ok').Add_Click({ $dlg.DialogResult = $true })
    $dlg.Add_ContentRendered({ $dlg.FindName('repo').Focus() | Out-Null })
    if ($dlg.ShowDialog() -ne $true) { return $null }
    $sel = $cb.SelectedItem
    @{ repo = $dlg.FindName('repo').Text; login = $(if ($sel) { [string]$sel.Tag } else { '' }) }
}
AddItem 'mAddRepo' {
    $r = Show-AddRepoDialog
    if (-not $r) { return }
    $v = ([string]$r.repo).Trim()
    if (-not $v) { return }
    if ($v -notmatch '^[\w.-]+/[\w.-]+$') { [void][Windows.MessageBox]::Show((T 'badRepo'), (T 'title')); return }
    if ((Get-Repos) -notcontains $v) { $cfg.repos = @((Get-Repos) + $v) }
    $lg = if ($r.login) { [string]$r.login } else { Get-RepoLogin '' }
    if ($lg) { $cfg.repoAcct[$v] = $lg }
    Save-Config
    Refresh
} | Out-Null
$removeMenu = AddItem 'mRemoveRepo' {}
$removeMenu.Add_SubmenuOpened({
    $removeMenu.Items.Clear()
    foreach ($repo in (Get-Repos)) {
        $mi = New-Object Windows.Controls.MenuItem; $mi.Header = $(if (Test-Multi) { "$repo  ($(Get-AcctLabel ('gh:' + (Get-RepoLogin $repo))))" } else { $repo }); $mi.Tag = $repo
        $mi.Add_Click({ $r = $this.Tag; $cfg.repos = @((Get-Repos) | Where-Object { $_ -ne $r }); $cfg.repoAcct.Remove($r); Save-Config; $script:ghRuns = @($script:ghRuns | Where-Object { $_.repo -ne $r }); $script:runs = @($script:runs | Where-Object { $_.repo -ne $r }); $script:errors.Remove($r); Render; Refresh })
        [void]$removeMenu.Items.Add($mi)
    }
})
[void]$removeMenu.Items.Add((New-Object Windows.Controls.MenuItem))
# Cloudflare accounts: add one (name + read-only API token, typed into a password box) or remove one
function Show-CfAddDialog {
    [xml]$dx = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
        SizeToContent="Height" Width="400" Background="#1E1E1E" ShowInTaskbar="False" Topmost="True">
  <StackPanel Margin="16">
    <TextBlock Name="lbl" Foreground="#EEEEEE" FontSize="13" TextWrapping="Wrap" Margin="0,0,0,4"/>
    <TextBox Name="name" FontSize="13" Margin="0,0,0,10" MaxLength="40"/>
    <TextBlock Name="tlbl" Foreground="#EEEEEE" FontSize="13" Margin="0,0,0,4"/>
    <PasswordBox Name="tok" FontSize="13" Margin="0,0,0,8"/>
    <TextBlock Name="help" Foreground="#999999" FontSize="12" TextWrapping="Wrap" Margin="0,0,0,14"/>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
      <Button Name="ok" IsDefault="True" Padding="16,4" Margin="0,0,8,0"/>
      <Button Name="cancel" IsCancel="True" Padding="16,4"/>
    </StackPanel>
  </StackPanel>
</Window>
'@
    $dlg = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $dx))
    $dlg.Title = T 'mCfAdd'
    $dlg.FindName('lbl').Text = T 'cfAskLabel'; $dlg.FindName('tlbl').Text = T 'cfAskToken'; $dlg.FindName('help').Text = T 'cfTokenHelp'
    $dlg.FindName('ok').Content = T 'cfAdd'; $dlg.FindName('cancel').Content = T 'cfCancel'
    $dlg.FindName('ok').Add_Click({ $dlg.DialogResult = $true })
    $dlg.Add_ContentRendered({ $dlg.FindName('name').Focus() | Out-Null })
    if ($dlg.ShowDialog() -ne $true) { return $null }
    @{ label = $dlg.FindName('name').Text; token = $dlg.FindName('tok').Password }
}
function Add-CfAccount {
    $r = Show-CfAddDialog
    if (-not $r) { return }
    $label = ([string]$r.label).Trim(); $plain = ([string]$r.token).Trim()
    if (-not $label -or -not $plain) { return }
    try { $enc = Protect-Token $plain } catch { [void][Windows.MessageBox]::Show(((T 'cfAddFail') -f $_.Exception.Message), (T 'title')); return }
    $plain = $null; $r.token = $null
    # The token is tested by listing the accounts it can see; a token can see more than one
    Start-Cf @{ id = ''; label = $label; token = $enc } 'GET' '/accounts' $null {
        param($body, $status, $err, $ctx)
        if ($err -or $status -ne 200) { [void][Windows.MessageBox]::Show(((T 'cfAddFail') -f (Get-CfErr $body $status $err)), (T 'title')); return }
        try { $found = @(($body | ConvertFrom-Json).result | Where-Object { $_ -and $_.id }) } catch { $found = @() }
        if (-not $found.Count) { [void][Windows.MessageBox]::Show(((T 'cfAddFail') -f (T 'cfNoAccess')), (T 'title')); return }
        $keep = @(Get-CfAccounts | Where-Object { $id = [string]$_.id; -not ($found | Where-Object { [string]$_.id -eq $id }) })
        $new = foreach ($f in $found) { [pscustomobject]@{ id = [string]$f.id; label = $(if ($found.Count -gt 1) { "$($ctx.label) ($($f.name))" } else { $ctx.label }); token = $ctx.enc } }
        foreach ($f in $found) { $script:cfClients.Remove([string]$f.id) }
        $cfg.cfAccounts = @($keep) + @($new); Save-Config
        [void][Windows.MessageBox]::Show(((T 'cfAdded') -f ((@($new) | ForEach-Object { $_.label }) -join ', ')), (T 'title'))
        Refresh
    } @{ label = $label; enc = $enc }
}
# GitHub accounts: the logins gh knows. A second account is signed in with gh itself (a window opens), the widget never sees a password.
$ghMenu = AddItem 'mGh' {}
AddItem 'mGhAdd' {
    if (-not $gh) { [void][Windows.MessageBox]::Show((T 'noGh'), (T 'title')); return }
    $hint = (T 'ghSignIn') -replace "'", ''
    $c = "Write-Host '$hint'; & '$gh' auth login --hostname github.com --web --git-protocol https --scopes repo,workflow,read:org,user"
    Start-Process powershell.exe -ArgumentList '-NoProfile', '-NoExit', '-Command', $c
} $ghMenu | Out-Null
AddItem 'mGhRefresh' { Refresh-GhAccounts } $ghMenu | Out-Null
$ghNameMenu = AddItem 'mGhName' {} $ghMenu
$ghNameMenu.Add_SubmenuOpened({
    $ghNameMenu.Items.Clear()
    foreach ($a in (Get-GhAccounts)) {
        $mi = New-Object Windows.Controls.MenuItem; $mi.Header = "$(if ($a.label) { $a.label } else { $a.login })  ($($a.login))"; $mi.Tag = [string]$a.login
        $mi.Add_Click({
            $lg = $this.Tag
            $acct = Get-GhAccounts | Where-Object { [string]$_.login -eq $lg } | Select-Object -First 1
            $v = ([Microsoft.VisualBasic.Interaction]::InputBox(((T 'ghAskLabel') -f $lg), (T 'title'), [string]$acct.label)).Trim()
            if (-not $v) { return }
            $acct.label = $v; Save-Config; Render
        })
        [void]$ghNameMenu.Items.Add($mi)
    }
})
[void]$ghNameMenu.Items.Add((New-Object Windows.Controls.MenuItem))
$cfMenu = AddItem 'mCf' {}
AddItem 'mCfAdd' { Add-CfAccount } $cfMenu | Out-Null
$cfNameMenu = AddItem 'mCfName' {} $cfMenu
$cfNameMenu.Add_SubmenuOpened({
    $cfNameMenu.Items.Clear()
    foreach ($a in (Get-CfAccounts)) {
        $mi = New-Object Windows.Controls.MenuItem; $mi.Header = [string]$a.label; $mi.Tag = [string]$a.id
        $mi.Add_Click({
            $id = $this.Tag
            $acct = Get-CfAccounts | Where-Object { [string]$_.id -eq $id } | Select-Object -First 1
            $v = ([Microsoft.VisualBasic.Interaction]::InputBox((T 'cfAskLabel'), (T 'title'), [string]$acct.label)).Trim()
            if (-not $v) { return }
            $acct.label = $v; Save-Config; Render
        })
        [void]$cfNameMenu.Items.Add($mi)
    }
})
[void]$cfNameMenu.Items.Add((New-Object Windows.Controls.MenuItem))
$cfRemoveMenu = AddItem 'mCfRemove' {} $cfMenu
$cfRemoveMenu.Add_SubmenuOpened({
    $cfRemoveMenu.Items.Clear()
    foreach ($a in (Get-CfAccounts)) {
        $mi = New-Object Windows.Controls.MenuItem; $mi.Header = [string]$a.label; $mi.Tag = [string]$a.id
        $mi.Add_Click({
            $id = $this.Tag
            $cfg.cfAccounts = @(Get-CfAccounts | Where-Object { [string]$_.id -ne $id }); Save-Config
            $script:cfClients.Remove($id); $script:cfUsage.Remove($id)
            if ($script:usageSrc -eq $id) { $script:usageSrc = 'github'; $cfg.usageSrc = 'github'; Save-Config }
            foreach ($k in @($script:errors.Keys | Where-Object { $_ -like 'Cloudflare/*' })) { $script:errors.Remove($k) }
            $script:cfRuns = @($script:cfRuns | Where-Object { $_.url -notlike "*dash.cloudflare.com/$id/*" })
            Merge-Runs; Refresh
        })
        [void]$cfRemoveMenu.Items.Add($mi)
    }
})
[void]$cfRemoveMenu.Items.Add((New-Object Windows.Controls.MenuItem))
AddItem 'mUpdate' { Start-Update } | Out-Null
$top = AddItem 'mTopmost' { $win.Topmost = -not $win.Topmost; $this.IsChecked = $win.Topmost; $cfg.topmost = $win.Topmost; Save-Config }
$top.IsChecked = $win.Topmost
$langMenu = AddItem 'mLanguage' {}
$langItems = @{}
foreach ($code in $langNames.Keys) {
    $li = AddItem $null { $cfg.language = $this.Tag; Save-Config; Set-MenuText; Render } $langMenu
    $li.Tag = $code; $li.Header = $langNames[$code]; $langItems[$code] = $li
}
AddItem 'mClose' { $win.Close() } | Out-Null
function Set-MenuText {
    foreach ($k in $menuItems.Keys) { $menuItems[$k].Header = T $k }
    foreach ($k in $budgetItems.Keys) { $budgetItems[$k].Header = (Get-CatLabel $k) + '…' }
    foreach ($c in $langItems.Keys) { $langItems[$c].IsChecked = ($c -eq $cfg.language) }
}
Set-MenuText
$win.ContextMenu = $menu

# Whenever the window changes size (it follows its content), go back to the anchor
$win.Add_SizeChanged({ if ($win.IsLoaded) { Keep-OnScreen } })

# Drag the window; a click without moving opens the run under the mouse, or minimizes / restores
$win.Add_MouseLeftButtonDown({
    param($s, $e)
    $src = $e.OriginalSource; $act = $null
    while ($src -and -not $act) {
        if ($src -is [Windows.FrameworkElement] -and $src.Tag -is [string] -and ($src.Tag -like 'http*' -or $src.Tag -like 'cmd:*')) { $act = $src.Tag }
        $src = if ($src -is [Windows.Media.Visual] -or $src -is [Windows.Media.Media3D.Visual3D]) { [Windows.Media.VisualTreeHelper]::GetParent($src) } else { $null }
    }
    $l0 = $win.Left; $t0 = $win.Top
    $script:dragging = $true
    try { $win.DragMove() } finally { $script:dragging = $false }
    if ([math]::Abs($win.Left - $l0) -lt 4 -and [math]::Abs($win.Top - $t0) -lt 4) {
        if ($act -eq 'cmd:min') { Set-Minimized $true }
        elseif ($act -eq 'cmd:restore') { Set-Minimized $false }
        elseif ($act -eq 'cmd:update') { Start-Update }
        elseif ($act -like 'cmd:tab:*') { Show-Tab ($act -replace '^cmd:tab:', '') }
        elseif ($act -eq 'cmd:e2e:ask') { Open-E2EPicker }
        elseif ($act -like 'cmd:e2e:*') { Start-E2E ($act -replace '^cmd:e2e:', '') }
        elseif ($act -like 'cmd:src:*') { Set-UsageSrc ($act -replace '^cmd:src:', ''); Save-Config; if (-not (Get-UsageAt)) { Refresh-Usage }; Render }
        elseif ($act -like 'cmd:flt:*') { $script:runFilter = $act -replace '^cmd:flt:', ''; $cfg.runFilter = $script:runFilter; Save-Config; Select-Visible; Render }
        elseif ($act -like 'cmd:svc:*') { $script:usageSel = $act -replace '^cmd:svc:', ''; $cfg.usageSel = $script:usageSel; Save-Config; Render }
        elseif ($act) { Start-Process $act }
    } elseif ($cfg.minimized) { $cfg.miniLeft = $win.Left; $cfg.miniTop = $win.Top; Save-Config }
    else { $cfg.left = $win.Left; $cfg.top = $win.Top; Save-Config }
})

# One-second tick: collect finished gh calls, redraw elapsed times, refresh every 30 s (10 s while something runs)
$script:tick = 0
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({
    Receive-Jobs
    Receive-CfJobs
    if (((Get-Date) - $script:ghAcctCheckedAt).TotalMinutes -ge 5 -and -not $script:cycle) { Refresh-GhAccounts }
    Receive-UpdateCheck
    # Every six hours; every ten minutes while the notice is showing, because GitHub's raw files are cached for a few minutes
    # and a freshly pushed version can look "new" to a widget that already has it
    $wait = if ($script:updateAvailable) { 10 } else { 360 }
    if (-not $script:updTask -and ((Get-Date) - $script:updCheckedAt).TotalMinutes -ge $wait) { Start-UpdateCheck }
    $script:tick++; $script:since++
    $busy = @($script:runs | Where-Object { (Get-State $_) -in 'running', 'queued' }).Count -gt 0
    $every = if ($busy) { 10 } else { 30 }
    $uat = Get-UsageAt
    if ($cfg.tab -eq 'usage' -and -not $cfg.minimized -and $uat -and ((Get-Date) - $uat).TotalSeconds -gt 300) { Refresh-Usage }
    if ($script:since -ge $every -and -not $script:cycle) { Refresh }
    elseif ($script:runs.Count -gt 0 -and ($script:tick % 5 -eq 0 -or ($cfg.minimized -and $busy))) { Render }
})
$timer.Start()
Show-Tab $(if ($cfg.tab -in 'usage', 'e2e') { $cfg.tab } else { 'runs' })
Refresh
if ($cfg.minimized) { Set-Minimized $true } else { Keep-OnScreen }   # a saved position can be on a monitor that is gone
[void]$win.ShowDialog()
