# CI Status installer - installs the widget, adds Desktop + Startup shortcuts, and starts it.
# From a downloaded copy:  powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
# From GitHub (private repo, needs gh):  gh api repos/saysphilippe/CIStatus/contents/install.ps1 -H "Accept: application/vnd.github.raw" | iex
# Keep this file ASCII-only: Invoke-Expression chokes on a UTF-8 BOM, so Nordic letters are built with [char].
$ErrorActionPreference = 'Stop'
$dest = Join-Path $env:LOCALAPPDATA 'CIStatus'
$cfgPath = Join-Path $dest 'config.json'
$ae = [char]0xE6; $oe = [char]0xF8; $aa = [char]0xE5; $auml = [char]0xE4; $ouml = [char]0xF6

$cfg = [ordered]@{}
if (Test-Path $cfgPath) {
    try { (Get-Content $cfgPath -Raw | ConvertFrom-Json).psobject.Properties | ForEach-Object { $cfg[$_.Name] = $_.Value } } catch {}
}

$langs = 'en', 'no', 'sv', 'da'
$lang = $env:CISTATUS_LANG
if ($lang -notin $langs) {
    Write-Host ''
    Write-Host "Choose display language / Velg spr${aa}k / V${auml}lj spr${aa}k / V${ae}lg sprog:" -ForegroundColor Cyan
    Write-Host '  1) English'
    Write-Host '  2) Norsk'
    Write-Host '  3) Svenska'
    Write-Host '  4) Dansk'
    $default = [array]::IndexOf($langs, [string]$cfg.language) + 1
    if ($default -lt 1) { $default = 1 }
    $answer = Read-Host "[1-4] (default $default)"
    if ($answer -notmatch '^[1-4]$') { $answer = $default }
    $lang = $langs[[int]$answer - 1]
}
$cfg.language = $lang

$msg = @{
    en = @{ installing = 'Installing CI Status...'; done = "Done. Installed to $dest - CI Status is now running and will start at login."; tip = 'Tip: right-click the widget to add repositories. It needs the GitHub CLI (gh) to be signed in.' }
    no = @{ installing = 'Installerer CI Status...'; done = "Ferdig. Installert i $dest - CI Status kj${oe}rer n${aa} og starter automatisk ved innlogging."; tip = "Tips: h${oe}yreklikk widgeten for ${aa} legge til repoer. Den trenger GitHub CLI (gh) med innlogging." }
    sv = @{ installing = 'Installerar CI Status...'; done = "Klart. Installerad i $dest - CI Status k${ouml}rs nu och startar automatiskt vid inloggning."; tip = "Tips: h${ouml}gerklicka p${aa} widgeten f${ouml}r att l${auml}gga till repon. Den beh${ouml}ver GitHub CLI (gh) med inloggning." }
    da = @{ installing = 'Installerer CI Status...'; done = "F${ae}rdig. Installeret i $dest - CI Status k${oe}rer nu og starter automatisk ved login."; tip = "Tip: h${oe}jreklik p${aa} widgetten for at tilf${oe}je repoer. Den kr${ae}ver GitHub CLI (gh) med login." }
}[$lang]

Write-Host $msg.installing -ForegroundColor Cyan
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object CommandLine -like '*CIStatus.ps1*' |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

New-Item -ItemType Directory -Force $dest | Out-Null
foreach ($f in 'CIStatus.ps1', 'Launch.vbs', 'uninstall.ps1') {
    if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot $f))) { Copy-Item (Join-Path $PSScriptRoot $f) (Join-Path $dest $f) -Force }
    else {
        # The repo is private: fetch through gh instead of raw.githubusercontent.com
        $gh = 'C:\Program Files\GitHub CLI\gh.exe'; if (-not (Test-Path $gh)) { $gh = 'gh' }
        [Console]::OutputEncoding = [Text.Encoding]::UTF8
        $txt = (& $gh api "repos/saysphilippe/CIStatus/contents/$f" -H 'Accept: application/vnd.github.raw') -join "`r`n"
        $txt = $txt.TrimStart([char]0xFEFF)
        # The widget needs a BOM (Nordic letters); the .vbs must not have one
        [IO.File]::WriteAllText((Join-Path $dest $f), $txt, (New-Object Text.UTF8Encoding ($f -eq 'CIStatus.ps1')))
    }
}
$cfg | ConvertTo-Json | Set-Content $cfgPath -Encoding UTF8

$ws = New-Object -ComObject WScript.Shell
foreach ($folder in [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Startup')) {
    $lnk = $ws.CreateShortcut((Join-Path $folder 'CI Status.lnk'))
    $lnk.TargetPath = 'wscript.exe'
    $lnk.Arguments = "`"$dest\Launch.vbs`""
    $lnk.IconLocation = 'powershell.exe,0'
    $lnk.Save()
}

Start-Process wscript.exe "`"$dest\Launch.vbs`""
Write-Host $msg.done -ForegroundColor Green
Write-Host $msg.tip
