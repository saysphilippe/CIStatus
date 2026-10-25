# CI Status - desktop widget that shows the state of GitHub Actions runs (read through the GitHub CLI, gh)
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, Microsoft.VisualBasic

$dir     = Split-Path -Parent $MyInvocation.MyCommand.Path
$cfgPath = Join-Path $dir 'config.json'
$inv     = [Globalization.CultureInfo]::InvariantCulture

$cfg = [ordered]@{ topmost = $true; left = 100; top = 100; language = 'en'; repos = @('saysphilippe/Nerdehagen'); perRepo = 5; maxRows = 8 }
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
        jobs = 'jobs {0}/{1}'
        mRefresh = 'Refresh now'; mUpdate = 'Update the widget'; mAddRepo = 'Add repository…'; mRemoveRepo = 'Remove repository'
        mTopmost = 'Always on top'; mLanguage = 'Language'; mClose = 'Close'
        askRepo = 'Repository to watch (owner/name):'; badRepo = 'Use the form owner/name, for example saysphilippe/Nerdehagen.'
        noGh = 'The GitHub CLI (gh) was not found. Install it and run: gh auth login'; ghErr = 'Could not read {0}: {1}'
    }
    no = @{
        title = 'CI Status'; running = '{0} kjører'; green = 'Alt grønt'; failing = 'Feiler'; noRuns = 'Ingen kjøringer funnet'; loading = 'Leser fra GitHub…'
        updated = 'Oppdatert {0}'; hint = 'Trykk på en kjøring for å åpne den · høyreklikk for valg'; finished = 'Ferdig: {0} – {1}'
        agoNow = 'nå nettopp'; agoM = 'for {0} min siden'; agoH = 'for {0} t siden'; agoD = 'for {0} d siden'
        stRunning = 'kjører'; stQueued = 'i kø'; stOk = 'vellykket'; stFail = 'feilet'; stCancel = 'avbrutt'; stSkip = 'hoppet over'; stWarn = 'krever oppmerksomhet'
        jobs = 'jobber {0}/{1}'
        mRefresh = 'Oppdater nå'; mUpdate = 'Oppdater widgeten'; mAddRepo = 'Legg til repo…'; mRemoveRepo = 'Fjern repo'
        mTopmost = 'Alltid øverst'; mLanguage = 'Språk'; mClose = 'Lukk'
        askRepo = 'Repo som skal følges (eier/navn):'; badRepo = 'Bruk formen eier/navn, for eksempel saysphilippe/Nerdehagen.'
        noGh = 'GitHub CLI (gh) ble ikke funnet. Installer den og kjør: gh auth login'; ghErr = 'Kunne ikke lese {0}: {1}'
    }
    sv = @{
        title = 'CI Status'; running = '{0} körs'; green = 'Allt grönt'; failing = 'Misslyckas'; noRuns = 'Inga körningar hittades'; loading = 'Läser från GitHub…'
        updated = 'Uppdaterad {0}'; hint = 'Klicka på en körning för att öppna den · högerklicka för val'; finished = 'Klar: {0} – {1}'
        agoNow = 'nyss'; agoM = 'för {0} min sedan'; agoH = 'för {0} h sedan'; agoD = 'för {0} d sedan'
        stRunning = 'körs'; stQueued = 'i kö'; stOk = 'lyckades'; stFail = 'misslyckades'; stCancel = 'avbruten'; stSkip = 'hoppades över'; stWarn = 'kräver uppmärksamhet'
        jobs = 'jobb {0}/{1}'
        mRefresh = 'Uppdatera nu'; mUpdate = 'Uppdatera widgeten'; mAddRepo = 'Lägg till repo…'; mRemoveRepo = 'Ta bort repo'
        mTopmost = 'Alltid överst'; mLanguage = 'Språk'; mClose = 'Stäng'
        askRepo = 'Repo att följa (ägare/namn):'; badRepo = 'Använd formen ägare/namn, till exempel saysphilippe/Nerdehagen.'
        noGh = 'GitHub CLI (gh) hittades inte. Installera den och kör: gh auth login'; ghErr = 'Kunde inte läsa {0}: {1}'
    }
    da = @{
        title = 'CI Status'; running = '{0} kører'; green = 'Alt grønt'; failing = 'Fejler'; noRuns = 'Ingen kørsler fundet'; loading = 'Læser fra GitHub…'
        updated = 'Opdateret {0}'; hint = 'Klik på en kørsel for at åbne den · højreklik for valg'; finished = 'Færdig: {0} – {1}'
        agoNow = 'lige nu'; agoM = 'for {0} min siden'; agoH = 'for {0} t siden'; agoD = 'for {0} d siden'
        stRunning = 'kører'; stQueued = 'i kø'; stOk = 'lykkedes'; stFail = 'fejlede'; stCancel = 'afbrudt'; stSkip = 'sprunget over'; stWarn = 'kræver opmærksomhed'
        jobs = 'jobs {0}/{1}'
        mRefresh = 'Opdater nu'; mUpdate = 'Opdater widgetten'; mAddRepo = 'Tilføj repo…'; mRemoveRepo = 'Fjern repo'
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
  <Border Name="root" CornerRadius="10" Background="#1E1E1E" BorderBrush="#3A3A3A" BorderThickness="1" Padding="16,12" Width="400">
    <StackPanel>
      <DockPanel Margin="0,0,0,6">
        <TextBlock Name="summary" DockPanel.Dock="Right" FontSize="13" FontWeight="SemiBold" VerticalAlignment="Center"/>
        <TextBlock Name="title" Foreground="#D97757" FontWeight="SemiBold" FontSize="16"/>
      </DockPanel>
      <TextBlock Name="flash" Foreground="#EEE" FontSize="12" Margin="0,0,0,6" TextWrapping="Wrap" Visibility="Collapsed"/>
      <StackPanel Name="rows"/>
      <TextBlock Name="note" FontSize="12" Margin="0,6,0,0" TextWrapping="Wrap" Visibility="Collapsed"/>
      <TextBlock Name="upd" Foreground="#666" FontSize="12" Margin="0,8,0,0" TextWrapping="Wrap"/>
    </StackPanel>
  </Border>
</Window>
'@
$win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$el = @{}
'root', 'summary', 'title', 'flash', 'rows', 'note', 'upd' | ForEach-Object { $el[$_] = $win.FindName($_) }
$win.Left = $cfg.left; $win.Top = $cfg.top; $win.Topmost = [bool]$cfg.topmost

# ---------- data and rendering ----------
$script:runs = @()
$script:errors = @{}          # repo -> message
$script:jobInfo = @{}         # run id -> 'done/total'
$script:prevState = @{}       # run id -> state at the last refresh
$script:flashUntil = [datetime]::MinValue
$script:updatedAt = $null
$script:cycle = $null
$script:since = 999

function Render {
    $el.title.Text = T 'title'
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
    $el.upd.Text = $(if ($script:updatedAt) { ((T 'updated') -f $script:updatedAt.ToString('HH:mm:ss')) + ' · ' } else { '' }) + (T 'hint')
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
            $el.flash.Foreground = Br $colors[$st]
            $script:flashUntil = (Get-Date).AddSeconds(60)
        }
        $script:prevState[$id] = $st
    }
    $script:runs = $all
    $script:updatedAt = Get-Date
    $script:cycle = $null
    Render
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

# ---------- menu ----------
$menu = New-Object Windows.Controls.ContextMenu
$menuItems = @{}
function AddItem($key, $action, $parent = $menu) { $mi = New-Object Windows.Controls.MenuItem; $mi.Add_Click($action); [void]$parent.Items.Add($mi); if ($key) { $menuItems[$key] = $mi }; $mi }
AddItem 'mRefresh' { Refresh } | Out-Null
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

# Drag the window; a click without moving opens the run under the mouse
$win.Add_MouseLeftButtonDown({
    param($s, $e)
    $src = $e.OriginalSource; $url = $null
    while ($src -and -not $url) {
        if ($src -is [Windows.FrameworkElement] -and $src.Tag -is [string] -and $src.Tag -like 'http*') { $url = $src.Tag }
        $src = if ($src -is [Windows.Media.Visual] -or $src -is [Windows.Media.Media3D.Visual3D]) { [Windows.Media.VisualTreeHelper]::GetParent($src) } else { $null }
    }
    $l0 = $win.Left; $t0 = $win.Top
    $win.DragMove()
    if ([math]::Abs($win.Left - $l0) -lt 4 -and [math]::Abs($win.Top - $t0) -lt 4) {
        if ($url) { Start-Process $url }
    } else { $cfg.left = $win.Left; $cfg.top = $win.Top; Save-Config }
})

# Keep the window on a screen (a saved position can be on a monitor that is gone)
$vl = [Windows.SystemParameters]::VirtualScreenLeft; $vt = [Windows.SystemParameters]::VirtualScreenTop
$vw = [Windows.SystemParameters]::VirtualScreenWidth; $vh = [Windows.SystemParameters]::VirtualScreenHeight
if ($win.Left -lt $vl -or $win.Left -gt $vl + $vw - 60) { $win.Left = $vl + 100 }
if ($win.Top -lt $vt -or $win.Top -gt $vt + $vh - 60) { $win.Top = $vt + 100 }

# One-second tick: collect finished gh calls, redraw elapsed times, refresh every 30 s (10 s while something runs)
$script:tick = 0
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({
    Receive-Jobs
    $script:tick++; $script:since++
    $busy = @($script:runs | Where-Object { (Get-State $_) -in 'running', 'queued' }).Count -gt 0
    $every = if ($busy) { 10 } else { 30 }
    if ($script:since -ge $every -and -not $script:cycle) { Refresh }
    elseif ($script:tick % 5 -eq 0 -and $script:runs.Count -gt 0) { Render }
})
$timer.Start()
Refresh
[void]$win.ShowDialog()
