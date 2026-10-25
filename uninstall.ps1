# Removes the CI Status program files and shortcuts. Your settings (config.json) are kept.
$dest = Join-Path $env:LOCALAPPDATA 'CIStatus'
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object CommandLine -like '*CIStatus.ps1*' |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
foreach ($folder in [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Startup')) {
    Remove-Item (Join-Path $folder 'CI Status.lnk') -ErrorAction SilentlyContinue
}
foreach ($f in 'CIStatus.ps1', 'Launch.vbs', 'uninstall.ps1') { Remove-Item (Join-Path $dest $f) -ErrorAction SilentlyContinue }
Write-Host 'CI Status uninstalled.' -ForegroundColor Green
Write-Host "Your settings were kept in $dest (config.json). Delete that folder to remove them too."
