# CI Status - desktop widget that shows the state of GitHub Actions runs (read through the GitHub CLI, gh)
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, Microsoft.VisualBasic, System.Net.Http

$dir     = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = $MyInvocation.MyCommand.Path
$cfgPath = Join-Path $dir 'config.json'
$inv     = [Globalization.CultureInfo]::InvariantCulture

$cfg = [ordered]@{ topmost = $true; left = 100; top = 100; language = 'en'; repos = @('saysphilippe/Nerdehagen'); perRepo = 5; maxRows = 8; minimized = $false; miniLeft = $null; miniTop = $null; tab = 'runs'; actionsIncluded = 2000; quotaMinutes = $null; budgets = $null; usageSel = 'Actions' }
if (Test-Path $cfgPath) {
    try { (Get-Content $cfgPath -Raw | ConvertFrom-Json).psobject.Properties | ForEach-Object { $cfg[$_.Name] = $_.Value } } catch {}
}
# Monthly budgets in dollars per service; the defaults are the ones set on GitHub (Budgets and alerts)
$b = [ordered]@{ Actions = 10; Packages = 10; 'Git LFS' = 5; Codespaces = 5; AI = 5 }
if ($cfg.budgets -and $cfg.budgets -isnot [System.Collections.IDictionary]) { $cfg.budgets.PSObject.Properties | ForEach-Object { $b[$_.Name] = $_.Value } }
$cfg.budgets = $b
function Save-Config { $cfg | ConvertTo-Json | Set-Content $cfgPath -Encoding UTF8 }
function Get-Repos { @($cfg.repos | Where-Object { $_ }) }

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
        askRepo = 'Repository to watch (owner/name):'; badRepo = 'Use the form owner/name, for example saysphilippe/Nerdehagen.'
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
        askRepo = 'Repo som skal følges (eier/navn):'; badRepo = 'Bruk formen eier/navn, for eksempel saysphilippe/Nerdehagen.'
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
        askRepo = 'Repo att följa (ägare/namn):'; badRepo = 'Använd formen ägare/namn, till exempel saysphilippe/Nerdehagen.'
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
        askRepo = 'Repo der skal følges (ejer/navn):'; badRepo = 'Brug formen ejer/navn, for eksempel saysphilippe/Nerdehagen.'
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
function Start-Gh($arguments, $onDone, $ctx) {
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $gh; $psi.Arguments = $arguments
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8; $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
    $p = [Diagnostics.Process]::Start($psi)
    [void]$script:jobs.Add(@{ proc = $p; out = $p.StandardOutput.ReadToEndAsync(); err = $p.StandardError.ReadToEndAsync(); done = $onDone; ctx = $ctx; started = Get-Date })
}
function Receive-Jobs {
    for ($i = $script:jobs.Count - 1; $i -ge 0; $i--) {
        $j = $script:jobs[$i]
        $finished = $j.out.IsCompleted -and $j.err.IsCompleted -and $j.proc.HasExited
        $timedOut = ((Get-Date) - $j.started).TotalSeconds -gt 40
        if (-not ($finished -or $timedOut)) { continue }
        $script:jobs.RemoveAt($i)
        if ($timedOut -and -not $finished) {
            try { $j.proc.Kill() } catch {}
            & $j.done '' 'timeout' 1 $j.ctx
        } else {
            & $j.done $j.out.Result $j.err.Result $j.proc.ExitCode $j.ctx
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
      </StackPanel>
      <StackPanel Name="runsPanel">
      <TextBlock Name="flash" Foreground="#EEE" FontSize="12" Margin="0,0,0,6" TextWrapping="Wrap" Visibility="Collapsed"/>
      <StackPanel Name="rows"/>
      <TextBlock Name="note" FontSize="12" Margin="0,6,0,0" TextWrapping="Wrap" Visibility="Collapsed"/>
      </StackPanel>
      <StackPanel Name="usagePanel" Visibility="Collapsed">
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
'root', 'mini', 'miniRows', 'minBtn', 'summary', 'title', 'flash', 'rows', 'note', 'upd', 'tabRuns', 'tabUsage', 'usageLink', 'updNew', 'runsPanel', 'usagePanel', 'uDailyHead', 'uDaily', 'uReposHead', 'uRepos', 'uOtherHead', 'uOther', 'uNote' | ForEach-Object { $el[$_] = $win.FindName($_) }
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

# ---------- usage (GitHub billing) ----------
$script:usage = @{ summary = $null; items = $null; premium = @(); at = $null; err = $null; pending = 0; user = $null }
$cultures = @{ en = 'en-US'; no = 'nb-NO'; sv = 'sv-SE'; da = 'da-DK' }
function Get-Culture2 { try { [Globalization.CultureInfo]::GetCultureInfo($cultures[[string]$cfg.language]) } catch { $inv } }
function Format-Money($v) { '$' + ([double]$v).ToString('N2', $inv) }
function Format-Num($v) { ([double]$v).ToString('N0', (Get-Culture2)) }

function Receive-Usage($out, $err, $code, $ctx) {
    if ($code -ne 0 -and $ctx.kind -eq 'premium') {
        # The AI credits report is optional (not every account has it); a failure there is not an error for the tab
        $script:usage.premium = @()
    } elseif ($code -ne 0) {
        $m = ([string]$err).Trim()
        $script:usage.err = $(if ($m -match '403|404|scope|Resource not accessible') { T 'uScope' } else { (T 'uErr') -f $(if ($m.Length -gt 100) { $m.Substring(0, 100) } else { $m }) })
    } else {
        try {
            $parsed = $out | ConvertFrom-Json
            if ($ctx.kind -eq 'summary') { $script:usage.summary = $parsed } elseif ($ctx.kind -eq 'premium') { $script:usage.premium = @($parsed.usageItems) } else { $script:usage.items = @($parsed.usageItems) }
            $script:usage.err = $null
        } catch { $script:usage.err = (T 'uErr') -f 'JSON' }
    }
    $script:usage.pending--
    if ($script:usage.pending -le 0) { $script:usage.at = Get-Date; $script:usage.pending = 0; Render; if ($win.IsLoaded) { Keep-OnScreen } }
}
function Start-UsageFetch {
    $now = (Get-Date).ToUniversalTime()
    $u = $script:usage.user
    $script:usage.pending = 3
    Start-Gh "api users/$u/settings/billing/premium_request/usage" ${function:Receive-Usage} @{ kind = 'premium' }
    Start-Gh "api users/$u/settings/billing/usage/summary" ${function:Receive-Usage} @{ kind = 'summary' }
    Start-Gh "api `"users/$u/settings/billing/usage?year=$($now.Year)&month=$($now.Month)`"" ${function:Receive-Usage} @{ kind = 'items' }
}
function Refresh-Usage {
    if ($script:usage.pending -gt 0) { return }
    $fx = $env:CISTATUS_USAGE_FIXTURE
    if ($fx -and (Test-Path $fx)) {
        $f = Get-Content $fx -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:usage.summary = $f.summary; $script:usage.items = @($f.items); $script:usage.premium = @($f.premium); $script:usage.at = Get-Date; $script:usage.err = $null; Render; return
    }
    if (-not $gh) { Render; return }
    $script:usage.pending = 1; Render
    if ($script:usage.user) { $script:usage.pending = 0; Start-UsageFetch; Render; return }
    # The login comes first, then the two billing calls
    Start-Gh 'api user --jq .login' {
        param($out, $err, $code, $ctx)
        $script:usage.pending = 0
        $login = ([string]$out).Trim()
        if ($code -ne 0 -or -not $login) { $script:usage.err = (T 'uErr') -f ([string]$err).Trim(); Render; return }
        $script:usage.user = $login
        Start-UsageFetch
        Render
    } @{}
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

function Render-Usage {
    $u = $script:usage
    $ci = Get-Culture2
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
    $c = "`$env:CISTATUS_LANG = '$l'; irm https://raw.githubusercontent.com/saysphilippe/CIStatus/main/install.ps1 | iex"
    Start-Process powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $c
}
# The widget compares itself with the file on GitHub (ignoring line endings and BOM). A .NET task fetches it; the one-second timer picks it up.
$script:updateAvailable = ($env:CISTATUS_FAKEUPDATE -eq '1')
$script:updTask = $null
$script:updCheckedAt = [datetime]::MinValue
$script:http = $null
function Get-NormHash($text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($text -replace "`r", '').TrimStart([char]0xFEFF))))
}
function Start-UpdateCheck {
    if ($script:updTask -or -not $scriptPath -or $env:CISTATUS_FAKEUPDATE) { return }
    if (-not $script:http) { $script:http = New-Object Net.Http.HttpClient; $script:http.Timeout = [TimeSpan]::FromSeconds(20) }
    $script:updCheckedAt = Get-Date
    $script:updTask = $script:http.GetStringAsync('https://raw.githubusercontent.com/saysphilippe/CIStatus/main/CIStatus.ps1?v=' + [guid]::NewGuid().ToString('N'))
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
    $el.tabRuns.Foreground = Br $(if ($t -eq 'runs') { '#D97757' } else { '#999999' }); $el.tabRuns.FontWeight = $(if ($t -eq 'runs') { 'SemiBold' } else { 'Normal' })
    $el.tabUsage.Foreground = Br $(if ($t -eq 'usage') { '#D97757' } else { '#999999' }); $el.tabUsage.FontWeight = $(if ($t -eq 'usage') { 'SemiBold' } else { 'Normal' })
    if ($t -eq 'usage' -and (-not $script:usage.at -or ((Get-Date) - $script:usage.at).TotalSeconds -gt 60)) { Refresh-Usage }
    Render
    if ($win.IsLoaded) { Keep-OnScreen }
}

function Render {
    $el.title.Text = T 'title'
    $el.tabRuns.Text = T 'tabRuns'; $el.tabUsage.Text = T 'tabUsage'; $el.usageLink.Text = T 'linkUsage'
    $el.updNew.Text = T 'updNew'; $el.updNew.Visibility = $(if ($script:updateAvailable) { 'Visible' } else { 'Collapsed' })
    if ($cfg.tab -eq 'usage') { Render-Usage }
    $el.rows.Children.Clear()
    $running = @($script:runs | Where-Object { (Get-State $_) -in 'running', 'queued' })
    # Summary: something running > a failed latest run of any workflow > all green
    $latest = @{}
    foreach ($r in ($script:runs | Where-Object { $_.status -eq 'completed' } | Sort-Object { ToUtc $_.createdAt } -Descending)) {
        $k = "$($r.repo)|$($r.workflowName)"; if (-not $latest.ContainsKey($k)) { $latest[$k] = Get-State $r }
    }
    if (-not $gh) { $el.summary.Text = ''; }
    elseif ($running.Count -gt 0) { $el.summary.Text = (T 'running') -f $running.Count; $el.summary.Foreground = Br $colors.running }
    elseif ($latest.Values -contains 'fail') { $el.summary.Text = T 'failing'; $el.summary.Foreground = Br $colors.fail }
    elseif ($script:runs.Count -gt 0) { $el.summary.Text = T 'green'; $el.summary.Foreground = Br $colors.ok }
    else { $el.summary.Text = '' }

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
        $parts = @(([string]$r.repo -split '/')[-1], [string]$r.workflowName)
        if ($st -in 'running', 'queued') {
            $parts += (T $stateKey[$st]) + ' ' + (Format-Dur ((Get-Date).ToUniversalTime() - $created))
            if ($script:jobInfo.ContainsKey([string]$r.databaseId)) { $parts += ((T 'jobs') -f ($script:jobInfo[[string]$r.databaseId] -split '/')) }
        } else {
            $parts += (T $stateKey[$st]) + ' · ' + (Format-Dur ((ToUtc $r.updatedAt) - $created))
            $parts += Format-Ago (ToUtc $r.updatedAt)
        }
        $t2 = New-Object Windows.Controls.TextBlock
        $t2.Text = ($parts -join ' · '); $t2.Foreground = Br '#999999'; $t2.FontSize = 12; $t2.TextTrimming = 'CharacterEllipsis'
        [void]$sp.Children.Add($t1); [void]$sp.Children.Add($t2)
        [void]$g.Children.Add($dot); [void]$g.Children.Add($sp)
        $row.Child = $g
        [void]$el.rows.Children.Add($row)
    }

    $msgs = @()
    if (-not $gh) { $msgs += T 'noGh' }
    elseif ($script:cycle -and $script:runs.Count -eq 0 -and $script:errors.Count -eq 0) { $msgs += T 'loading' }
    elseif ($script:runs.Count -eq 0 -and $script:errors.Count -eq 0) { $msgs += T 'noRuns' }
    foreach ($k in $script:errors.Keys) { $msgs += ((T 'ghErr') -f $k, $script:errors[$k]) }
    if ($msgs.Count) { $el.note.Text = ($msgs -join "`n"); $el.note.Foreground = Br $(if ($script:errors.Count -or -not $gh) { '#E5534B' } else { '#999999' }); $el.note.Visibility = 'Visible' }
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
        $info = Format-Dur ((Get-Date).ToUniversalTime() - (ToUtc $r.createdAt))
        if ($script:jobInfo.ContainsKey([string]$r.databaseId)) { $info += ' · ' + ((T 'jobs') -f ($script:jobInfo[[string]$r.databaseId] -split '/')) }
        & $addMini $colors[(Get-State $r)] "$name  $info"
    }
    if ((Get-Date) -lt $script:flashUntil) { & $addMini $script:flashColor ([string]$el.flash.Text) }
    if ($el.miniRows.Children.Count -eq 0) {
        if (-not $gh) { & $addMini $colors.fail (T 'noGh') }
        elseif ($script:errors.Count) { & $addMini $colors.fail ((T 'ghErr') -f @($script:errors.Keys)[0], '') }
        elseif ($latest.Values -contains 'fail') { & $addMini $colors.fail (T 'failing') }
        elseif ($script:runs.Count -gt 0) { & $addMini $colors.ok (T 'green') }
        else { & $addMini $colors.queued (T 'nothing') }
    }
    $el.mini.ToolTip = T 'restore'; $el.minBtn.ToolTip = T 'minimize'
    if ($cfg.tab -eq 'usage') { $el.upd.Text = $(if ($script:usage.at) { ((T 'updated') -f $script:usage.at.ToString('HH:mm:ss')) + ' · ' } else { '' }) + (T 'uLag') }
    else { $el.upd.Text = $(if ($script:updatedAt) { ((T 'updated') -f $script:updatedAt.ToString('HH:mm:ss')) + ' · ' } else { '' }) + (T 'hint') }
}

function Complete-Cycle {
    $all = @()
    foreach ($repo in (Get-Repos)) { $all += @($script:cycle.byRepo[$repo]) }
    $all = @($all | Where-Object { $_ } | Sort-Object { ToUtc $_.createdAt } -Descending | Select-Object -First ([int]$cfg.maxRows))
    # A run that was running and has now finished is announced at the top for a minute
    foreach ($r in $all) {
        $id = [string]$r.databaseId; $st = Get-State $r
        if ($script:prevState.ContainsKey($id) -and $script:prevState[$id] -in 'running', 'queued' -and $st -notin 'running', 'queued') {
            $el.flash.Text = (T 'finished') -f $r.displayTitle, (T $stateKey[$st])
            $el.flash.Foreground = Br $colors[$st]; $script:flashColor = $colors[$st]
            $script:flashUntil = (Get-Date).AddSeconds(60)
        }
        $script:prevState[$id] = $st
    }
    $script:runs = $all
    $script:updatedAt = Get-Date
    $script:cycle = $null
    Render
    if ($win.IsLoaded) { Keep-OnScreen }
    # For runs in progress, read the jobs so the row can show how far it has come
    foreach ($r in ($all | Where-Object { (Get-State $_) -eq 'running' } | Select-Object -First 3)) {
        Start-Gh "run view $($r.databaseId) --repo $($r.repo) --json jobs" {
            param($out, $err, $code, $ctx)
            if ($code -ne 0) { return }
            try {
                $jobsList = @(($out | ConvertFrom-Json).jobs)
                $script:jobInfo[$ctx.id] = '{0}/{1}' -f @($jobsList | Where-Object { $_.status -eq 'completed' }).Count, $jobsList.Count
                Render
            } catch {}
        } @{ id = [string]$r.databaseId }
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
    if ($script:cycle) { return }
    $repos = @(Get-Repos)
    $fixture = $env:CISTATUS_FIXTURE
    if ($fixture -and (Test-Path $fixture)) {
        $parsed = Get-Content $fixture -Raw -Encoding UTF8 | ConvertFrom-Json; $script:runs = @($parsed); $script:updatedAt = Get-Date; Render; return
    }
    if (-not $gh -or $repos.Count -eq 0) { Render; return }
    $script:cycle = @{ pending = $repos.Count; byRepo = @{} }
    foreach ($repo in $repos) {
        Start-Gh "run list --repo $repo --limit $([int]$cfg.perRepo) --json databaseId,status,conclusion,displayTitle,workflowName,createdAt,updatedAt,event,headBranch,url" ${function:Receive-RunList} @{ repo = $repo }
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
# Keep the whole window inside the work area (taskbar excluded), e.g. after the Usage tab made it taller
$script:dragging = $false
function Keep-OnScreen {
    if ($script:dragging) { return }
    $sz = Get-WinSize
    $wa = [Windows.SystemParameters]::WorkArea
    $win.Left = [math]::Max($wa.Left, [math]::Min($win.Left, $wa.Right - $sz[0]))
    $win.Top = [math]::Max($wa.Top, [math]::Min($win.Top, $wa.Bottom - $sz[1]))
}

function Set-Minimized($m) {
    $cfg.minimized = [bool]$m; Save-Config
    $el.root.Visibility = $(if ($m) { 'Collapsed' } else { 'Visible' })
    $el.mini.Visibility = $(if ($m) { 'Visible' } else { 'Collapsed' })
    Render
    $sz = Get-WinSize
    $wa = [Windows.SystemParameters]::WorkArea
    if ($m) {
        if ($null -ne $cfg.miniLeft -and $null -ne $cfg.miniTop) { $win.Left = [double]$cfg.miniLeft; $win.Top = [double]$cfg.miniTop }
        else { $win.Left = $wa.Right - $sz[0] - 12; $win.Top = $wa.Bottom - $sz[1] - 12 }
    } else { $win.Left = [double]$cfg.left; $win.Top = [double]$cfg.top }
    Keep-OnScreen
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
AddItem 'mAddRepo' {
    $v = ([Microsoft.VisualBasic.Interaction]::InputBox((T 'askRepo'), (T 'title'), '')).Trim()
    if (-not $v) { return }
    if ($v -notmatch '^[\w.-]+/[\w.-]+$') { [void][Windows.MessageBox]::Show((T 'badRepo'), (T 'title')); return }
    if ((Get-Repos) -notcontains $v) { $cfg.repos = @((Get-Repos) + $v); Save-Config }
    Refresh
} | Out-Null
$removeMenu = AddItem 'mRemoveRepo' {}
$removeMenu.Add_SubmenuOpened({
    $removeMenu.Items.Clear()
    foreach ($repo in (Get-Repos)) {
        $mi = New-Object Windows.Controls.MenuItem; $mi.Header = $repo; $mi.Tag = $repo
        $mi.Add_Click({ $r = $this.Tag; $cfg.repos = @((Get-Repos) | Where-Object { $_ -ne $r }); Save-Config; $script:runs = @($script:runs | Where-Object { $_.repo -ne $r }); $script:errors.Remove($r); Render; Refresh })
        [void]$removeMenu.Items.Add($mi)
    }
})
[void]$removeMenu.Items.Add((New-Object Windows.Controls.MenuItem))
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
    Receive-UpdateCheck
    if (-not $script:updTask -and ((Get-Date) - $script:updCheckedAt).TotalHours -ge 6) { Start-UpdateCheck }
    $script:tick++; $script:since++
    $busy = @($script:runs | Where-Object { (Get-State $_) -in 'running', 'queued' }).Count -gt 0
    $every = if ($busy) { 10 } else { 30 }
    if ($cfg.tab -eq 'usage' -and -not $cfg.minimized -and $script:usage.at -and ((Get-Date) - $script:usage.at).TotalSeconds -gt 300) { Refresh-Usage }
    if ($script:since -ge $every -and -not $script:cycle) { Refresh }
    elseif ($script:runs.Count -gt 0 -and ($script:tick % 5 -eq 0 -or ($cfg.minimized -and $busy))) { Render }
})
$timer.Start()
Show-Tab $(if ($cfg.tab -eq 'usage') { 'usage' } else { 'runs' })
Refresh
if ($cfg.minimized) { Set-Minimized $true } else { Keep-OnScreen }   # a saved position can be on a monitor that is gone
[void]$win.ShowDialog()
