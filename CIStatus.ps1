# CI Status - desktop widget that shows the state of GitHub Actions runs (read through the GitHub CLI, gh)
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, Microsoft.VisualBasic

$dir     = Split-Path -Parent $MyInvocation.MyCommand.Path
$cfgPath = Join-Path $dir 'config.json'
$inv     = [Globalization.CultureInfo]::InvariantCulture

$cfg = [ordered]@{ topmost = $true; left = 100; top = 100; language = 'en'; repos = @('saysphilippe/Nerdehagen'); perRepo = 5; maxRows = 8; minimized = $false; miniLeft = $null; miniTop = $null; tab = 'runs'; actionsIncluded = 2000; quotaMinutes = $null; budgetUsd = $null }
if (Test-Path $cfgPath) {
    try { (Get-Content $cfgPath -Raw | ConvertFrom-Json).psobject.Properties | ForEach-Object { $cfg[$_.Name] = $_.Value } } catch {}
}
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
        tabRuns = 'Runs'; tabUsage = 'Usage'; linkUsage = 'Open GitHub usage ↗'
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
        tabRuns = 'Kjøringer'; tabUsage = 'Forbruk'; linkUsage = 'Åpne GitHub-forbruk ↗'
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
        tabRuns = 'Körningar'; tabUsage = 'Förbrukning'; linkUsage = 'Öppna GitHub-förbrukning ↗'
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
        tabRuns = 'Kørsler'; tabUsage = 'Forbrug'; linkUsage = 'Åbn GitHub-forbrug ↗'
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
        <TextBlock Name="uHead" Foreground="#EEE" FontSize="14"/>
        <!-- The white marker shows how far through the month we are: the bar should stay left of it -->
        <Grid Name="uTrack" Width="368" Height="9" Margin="0,4,0,3" Background="#333" HorizontalAlignment="Left">
          <Rectangle Name="uUsedBar" HorizontalAlignment="Left" RadiusX="2" RadiusY="2" Width="0"/>
          <Rectangle Name="uPace" HorizontalAlignment="Left" Width="2" Fill="#FFFFFF" Opacity="0.85" Margin="0,-2,0,-2"/>
        </Grid>
        <TextBlock Name="uSub" Foreground="#EEE" FontSize="13" TextWrapping="Wrap"/>
        <TextBlock Name="uPaceTxt" FontSize="13" TextWrapping="Wrap"/>
        <TextBlock Name="uCost" FontSize="13" Margin="0,4,0,0" TextWrapping="Wrap"/>
        <Grid Name="uTrack2" Width="368" Height="9" Margin="0,8,0,3" Background="#333" HorizontalAlignment="Left" Visibility="Collapsed">
          <Rectangle Name="uUsedBar2" HorizontalAlignment="Left" RadiusX="2" RadiusY="2" Width="0"/>
          <Rectangle Name="uPace2" HorizontalAlignment="Left" Width="2" Fill="#FFFFFF" Opacity="0.85" Margin="0,-2,0,-2"/>
        </Grid>
        <TextBlock Name="uMoney" FontSize="13" TextWrapping="Wrap"/>
        <TextBlock Name="uFore" Foreground="#999" FontSize="13" Margin="0,4,0,0" TextWrapping="Wrap"/>
        <TextBlock Name="uDailyHead" Foreground="#EEE" FontSize="14" Margin="0,12,0,0"/>
        <Canvas Name="uDaily" Width="368" Height="52" Margin="0,4,0,0" HorizontalAlignment="Left"/>
        <TextBlock Name="uReposHead" Foreground="#EEE" FontSize="14" Margin="0,10,0,2"/>
        <StackPanel Name="uRepos"/>
        <TextBlock Name="uOtherHead" Foreground="#EEE" FontSize="14" Margin="0,10,0,2"/>
        <StackPanel Name="uOther"/>
        <TextBlock Name="uNote" FontSize="12" Margin="0,8,0,0" TextWrapping="Wrap" Visibility="Collapsed"/>
      </StackPanel>
      <TextBlock Name="upd" Foreground="#666" FontSize="12" Margin="0,8,0,0" TextWrapping="Wrap"/>
      <TextBlock Name="usageLink" Foreground="#6A9BCC" FontSize="12" Margin="0,4,0,0" Cursor="Hand" HorizontalAlignment="Left" Background="Transparent" TextDecorations="Underline" Tag="https://github.com/settings/billing/summary"/>
    </StackPanel>
  </Border>
  </Grid>
</Window>
'@
$win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$el = @{}
'root', 'mini', 'miniRows', 'minBtn', 'summary', 'title', 'flash', 'rows', 'note', 'upd', 'tabRuns', 'tabUsage', 'usageLink', 'runsPanel', 'usagePanel', 'uHead', 'uTrack', 'uUsedBar', 'uPace', 'uSub', 'uPaceTxt', 'uCost', 'uTrack2', 'uUsedBar2', 'uPace2', 'uMoney', 'uFore', 'uDailyHead', 'uDaily', 'uReposHead', 'uRepos', 'uOtherHead', 'uOther', 'uNote' | ForEach-Object { $el[$_] = $win.FindName($_) }
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
$script:usage = @{ summary = $null; items = $null; at = $null; err = $null; pending = 0; user = $null }
$cultures = @{ en = 'en-US'; no = 'nb-NO'; sv = 'sv-SE'; da = 'da-DK' }
function Get-Culture2 { try { [Globalization.CultureInfo]::GetCultureInfo($cultures[[string]$cfg.language]) } catch { $inv } }
function Format-Money($v) { '$' + ([double]$v).ToString('N2', $inv) }
function Format-Num($v) { ([double]$v).ToString('N0', (Get-Culture2)) }

function Receive-Usage($out, $err, $code, $ctx) {
    if ($code -ne 0) {
        $m = ([string]$err).Trim()
        $script:usage.err = $(if ($m -match '403|404|scope|Resource not accessible') { T 'uScope' } else { (T 'uErr') -f $(if ($m.Length -gt 100) { $m.Substring(0, 100) } else { $m }) })
    } else {
        try {
            $parsed = $out | ConvertFrom-Json
            if ($ctx.kind -eq 'summary') { $script:usage.summary = $parsed } else { $script:usage.items = @($parsed.usageItems) }
            $script:usage.err = $null
        } catch { $script:usage.err = (T 'uErr') -f 'JSON' }
    }
    $script:usage.pending--
    if ($script:usage.pending -le 0) { $script:usage.at = Get-Date; $script:usage.pending = 0; Render; if ($win.IsLoaded) { Keep-OnScreen } }
}
function Start-UsageFetch {
    $now = (Get-Date).ToUniversalTime()
    $u = $script:usage.user
    $script:usage.pending = 2
    Start-Gh "api users/$u/settings/billing/usage/summary" ${function:Receive-Usage} @{ kind = 'summary' }
    Start-Gh "api `"users/$u/settings/billing/usage?year=$($now.Year)&month=$($now.Month)`"" ${function:Receive-Usage} @{ kind = 'items' }
}
function Refresh-Usage {
    if ($script:usage.pending -gt 0) { return }
    $fx = $env:CISTATUS_USAGE_FIXTURE
    if ($fx -and (Test-Path $fx)) {
        $f = Get-Content $fx -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:usage.summary = $f.summary; $script:usage.items = @($f.items); $script:usage.at = Get-Date; $script:usage.err = $null; Render; return
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

function Set-Track($bar, $pace, $pct, $monthPct, $color) {
    $w = 368.0
    $bar.Width = [math]::Max(0, [math]::Min(100, $pct)) / 100 * $w
    $bar.Fill = Br $color
    $pace.Margin = New-Object Windows.Thickness(([math]::Max(0, [math]::Min(100, $monthPct)) / 100 * $w - 1), -2, 0, -2)
}

function Render-Usage {
    $u = $script:usage
    $ci = Get-Culture2
    $el.uRepos.Children.Clear(); $el.uOther.Children.Clear(); $el.uDaily.Children.Clear()
    $el.uNote.Visibility = 'Collapsed'; $el.uTrack2.Visibility = 'Collapsed'; $el.uMoney.Text = ''; $el.uPaceTxt.Text = ''
    $month = (Get-Date).ToUniversalTime()
    $el.uHead.Text = (T 'uHead') -f $month.ToString('MMMM yyyy', $ci)
    if ($u.err) { $el.uNote.Text = $u.err; $el.uNote.Foreground = Br $colors.fail; $el.uNote.Visibility = 'Visible' }
    $has = $u.summary -and $u.summary.usageItems
    if (-not $has) {
        $el.uUsedBar.Width = 0; $el.uPace.Margin = '0,-2,0,-2'; $el.uSub.Text = $(if ($u.pending -gt 0) { T 'uLoading' } elseif (-not $u.err) { T 'uNone' } else { '' })
        $el.uCost.Text = ''; $el.uFore.Text = ''; $el.uDailyHead.Text = ''; $el.uReposHead.Text = ''; $el.uOtherHead.Text = ''
        return
    }
    $items = @($u.summary.usageItems)
    $mins = @($items | Where-Object { $_.product -eq 'Actions' -and $_.unitType -eq 'minutes' })
    $gross = [double](($mins | Measure-Object grossQuantity -Sum).Sum)
    $disc = [double](($mins | Measure-Object discountQuantity -Sum).Sum)
    $net = [double](($mins | Measure-Object netQuantity -Sum).Sum)
    $netAmt = [double](($mins | Measure-Object netAmount -Sum).Sum)
    $price = if ($mins.Count -and $mins[0].pricePerUnit) { [double]$mins[0].pricePerUnit } else { 0.006 }
    # The plan's included minutes: known exactly once they are used up (the discount), otherwise the configured value
    $incl = if ($net -gt 0) { $disc } else { [math]::Max([double]$cfg.actionsIncluded, $gross) }
    if ($incl -le 0) { $incl = 1 }
    # The user's own quota in minutes (menu), otherwise what the plan includes
    $quota = if ([double]$cfg.quotaMinutes -gt 0) { [double]$cfg.quotaMinutes } else { $incl }
    $startM = Get-Date -Year $month.Year -Month $month.Month -Day 1 -Hour 0 -Minute 0 -Second 0
    $daysIn = [datetime]::DaysInMonth($month.Year, $month.Month)
    $elapsed = [math]::Max(1.0, ($month - $startM.ToUniversalTime()).TotalDays)
    $monthPct = [math]::Min(100, $elapsed / $daysIn * 100)
    $fg = $gross / $elapsed * $daysIn
    $pct = $gross / $quota * 100
    $state = if ($gross -ge $quota) { 'fail' } elseif ($fg -gt $quota) { 'running' } else { 'ok' }
    Set-Track $el.uUsedBar $el.uPace $pct $monthPct $colors[$state]
    $el.uSub.Text = (T 'uQuota') -f (Format-Num $gross), (Format-Num $quota), ([math]::Round($pct))
    if ($gross -ge $quota) { $paceTxt = (T 'uPaceOver') -f (Format-Num ($gross - $quota)) }
    elseif ($fg -gt $quota) {
        $rate = [math]::Max($gross / $elapsed, 0.0001)
        $paceTxt = (T 'uPaceHit') -f $month.AddDays(($quota - $gross) / $rate).ToString('d. MMMM', $ci)
    } else { $paceTxt = (T 'uPaceOk') -f ([math]::Round($fg / $quota * 100)) }
    $el.uPaceTxt.Text = ((T 'uMonthGone') -f ([math]::Round($monthPct))) + ' · ' + $paceTxt
    $el.uPaceTxt.Foreground = Br $colors[$state]
    if ($net -gt 0) { $el.uCost.Text = (T 'uOver') -f (Format-Num $net), (Format-Money $netAmt); $el.uCost.Foreground = Br $colors.fail }
    else { $el.uCost.Text = T 'uOk'; $el.uCost.Foreground = Br $colors.ok }
    # Forecast of the month's minutes and what is billable at the plan's price beyond what it includes
    $foreTxt = (T 'uFore') -f (Format-Num (([math]::Round($fg / 10) * 10)))
    $fc = [math]::Max(0, $fg - $incl) * $price
    if ($fc -gt 0.005) { $foreTxt += (T 'uForeCost') -f (Format-Money $fc) }
    $el.uFore.Text = $foreTxt + "`n" + ((T 'uResets') -f $startM.AddMonths(1).ToString('d. MMMM', $ci))

    # Minutes per day (bars) and per repository, from the detailed report
    $detail = @($u.items | Where-Object { $_ -and $_.unitType -eq 'Minutes' })
    if ($detail.Count) {
        $el.uDailyHead.Text = T 'uDaily'
        $byDay = @{}
        foreach ($d in $detail) { $k = (ToUtc $d.date).Day; $byDay[$k] = [double]$byDay[$k] + [double]$d.quantity }
        $max = [double](($byDay.Values | Measure-Object -Maximum).Maximum); if ($max -le 0) { $max = 1 }
        $bw = 368.0 / $daysIn
        for ($day = 1; $day -le $daysIn; $day++) {
            $v = [double]$byDay[$day]
            $h = if ($v -gt 0) { [math]::Max(2, $v / $max * 46) } else { 1 }
            $r = New-Object Windows.Shapes.Rectangle
            $r.Width = [math]::Max(1, $bw - 2); $r.Height = $h
            $r.Fill = Br $(if ($day -eq $month.Day) { $colors.running } elseif ($v -gt 0) { '#6A9BCC' } else { '#333333' })
            $r.ToolTip = "$day. : " + (Format-Num $v) + ' min'
            [Windows.Controls.Canvas]::SetLeft($r, ($day - 1) * $bw); [Windows.Controls.Canvas]::SetTop($r, 50 - $h)
            [void]$el.uDaily.Children.Add($r)
        }
        $el.uReposHead.Text = T 'uRepos'
        $byRepo = $detail | Group-Object repositoryName | ForEach-Object { [pscustomobject]@{ name = $_.Name; v = [double](($_.Group | Measure-Object quantity -Sum).Sum) } } | Sort-Object v -Descending | Select-Object -First 5
        foreach ($r in $byRepo) {
            $tb = New-Object Windows.Controls.TextBlock; $tb.FontSize = 13; $tb.Foreground = Br '#BBBBBB'
            $tb.Text = ('{0}  ·  {1} min' -f $r.name, (Format-Num $r.v)); [void]$el.uRepos.Children.Add($tb)
        }
    } else { $el.uDailyHead.Text = ''; $el.uReposHead.Text = '' }

    # Everything else in the summary (storage, Copilot, Packages, Codespaces ...) with what is billable
    $others = @($items | Where-Object { -not ($_.product -eq 'Actions' -and $_.unitType -eq 'minutes') })
    if ($others.Count) {
        $el.uOtherHead.Text = T 'uOther'
        foreach ($o in $others) {
            $tb = New-Object Windows.Controls.TextBlock; $tb.FontSize = 13; $tb.Foreground = Br '#BBBBBB'
            $line = '{0}  ·  {1} {2}' -f (([string]$o.sku) -replace '_', ' '), (Format-Num ([math]::Round([double]$o.grossQuantity, 1))), $o.unitType
            if ([double]$o.netAmount -gt 0.004) { $line += '  ·  ' + ((T 'uBillable') -f (Format-Money $o.netAmount)) }
            $tb.Text = $line; [void]$el.uOther.Children.Add($tb)
        }
    } else { $el.uOtherHead.Text = '' }
    $total = [double](($items | Measure-Object netAmount -Sum).Sum)
    if ($total -gt 0.004) { $el.uCost.Text += "`n" + ((T 'uTotal') -f (Format-Money $total)) }
    # Monthly budget in dollars (menu): spending so far against the budget, with the same month marker
    $bud = [double]$cfg.budgetUsd
    if ($bud -gt 0) {
        $otherNet = [double](($others | Measure-Object netAmount -Sum).Sum)
        $fcTotal = [math]::Max($total, $fc + $otherNet)
        $bstate = if ($total -ge $bud) { 'fail' } elseif ($fcTotal -gt $bud) { 'running' } else { 'ok' }
        $el.uTrack2.Visibility = 'Visible'
        Set-Track $el.uUsedBar2 $el.uPace2 ($total / $bud * 100) $monthPct $colors[$bstate]
        $el.uMoney.Text = ((T 'uBudget') -f (Format-Money $total), (Format-Money $bud), ([math]::Round($total / $bud * 100))) + ((T 'uBudgetFore') -f (Format-Money $fcTotal))
        $el.uMoney.Foreground = Br $colors[$bstate]
    }
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
AddItem 'mQuota' {
    $v = ([Microsoft.VisualBasic.Interaction]::InputBox((T 'askQuota'), (T 'title'), [string]$cfg.quotaMinutes)).Trim() -replace ',', '.'
    if (-not $v) { return }
    $n = 0.0
    if (-not [double]::TryParse($v, [Globalization.NumberStyles]::Float, $inv, [ref]$n) -or $n -lt 0) { [void][Windows.MessageBox]::Show((T 'badNum'), (T 'title')); return }
    $cfg.quotaMinutes = $(if ($n -gt 0) { $n } else { $null }); Save-Config; Render
} | Out-Null
AddItem 'mBudget' {
    $v = ([Microsoft.VisualBasic.Interaction]::InputBox((T 'askBudget'), (T 'title'), [string]$cfg.budgetUsd)).Trim() -replace ',', '.'
    if (-not $v) { return }
    $n = 0.0
    if (-not [double]::TryParse($v, [Globalization.NumberStyles]::Float, $inv, [ref]$n) -or $n -lt 0) { [void][Windows.MessageBox]::Show((T 'badNum'), (T 'title')); return }
    $cfg.budgetUsd = $(if ($n -gt 0) { $n } else { $null }); Save-Config; Render
} | Out-Null
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
AddItem 'mUpdate' {
    $l = if ($cfg.language -in @('en', 'no', 'sv', 'da')) { $cfg.language } else { 'en' }
    $c = "`$env:CISTATUS_LANG = '$l'; gh api repos/saysphilippe/CIStatus/contents/install.ps1 -H 'Accept: application/vnd.github.raw' | iex"
    Start-Process powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $c
} | Out-Null
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
        elseif ($act -like 'cmd:tab:*') { Show-Tab ($act -replace '^cmd:tab:', '') }
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
