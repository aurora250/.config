# ============================================================
#  PowerShell + Windows Terminal 终端配置卸载
#
#  用法:
#      pwsh -File ps\uninstall.ps1                    # 还原配置
#      pwsh -File ps\uninstall.ps1 -PurgeTools        # 并删除 dsh-tools 工具目录
#      pwsh -File ps\uninstall.ps1 -PurgeFont         # 并删除 Meslo 用户字体
#      pwsh -File ps\uninstall.ps1 -PurgeModules      # 并删除 PSFzf 模块
#      pwsh -File ps\uninstall.ps1 -RestoreColorPrevalence   # 恢复"标题栏显示主题色"
# ============================================================
[CmdletBinding()]
param(
    [switch]$PurgeTools,
    [switch]$PurgeFont,
    [switch]$PurgeModules,
    [switch]$RestoreColorPrevalence
)

$ErrorActionPreference = 'Continue'

function Write-Step([string]$m) { Write-Host ''; Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Info([string]$m) { Write-Host "  $m" }
function Write-Warn([string]$m) { Write-Host "warning: $m" -ForegroundColor Yellow }

$ThemesDir   = Join-Path $env:USERPROFILE '.config\oh-my-posh'
$ThemeFile   = Join-Path $ThemesDir 'agnoster-dsh.omp.json'
$ToolsDir    = Join-Path $env:LOCALAPPDATA 'Programs\dsh-tools'
$UserFontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$FontRegKey  = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

function Restore-NewestBackup([string]$Path) {
    $bak = Get-ChildItem (Split-Path $Path) -Filter ((Split-Path $Path -Leaf) + '.dsh-bak-*') -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($bak) {
        Copy-Item $bak.FullName $Path -Force
        Write-Info "recovered ← $($bak.Name)"
        return $true
    }
    return $false
}

# ------------------------------------------------------------
#  1. Windows Terminal 设置
# ------------------------------------------------------------
Write-Step 'Windows Terminal config'
$wt = @()
$wt += Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -ErrorAction SilentlyContinue |
       Where-Object { $_.Name -like 'Microsoft.WindowsTerminal*' } |
       ForEach-Object { Join-Path $_.FullName 'LocalState\settings.json' }
$wt += Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json'
$wt = $wt | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($wt) {
    if (-not (Restore-NewestBackup $wt)) {
        Write-Warn 'no backup found: please check font/opacity/key/default-profile in settings.json'
    }
}
else { Write-Warn 'settings.json not found in Windows Terminal' }

# ------------------------------------------------------------
#  2. $PROFILE
# ------------------------------------------------------------
Write-Step 'PowerShell profile'
$prof = $PROFILE.CurrentUserCurrentHost
if (Test-Path $prof) {
    if (-not (Restore-NewestBackup $prof)) {
        Remove-Item $prof -Force
        Write-Info "deleted $prof"
    }
}
else { Write-Info 'skip' }

# ------------------------------------------------------------
#  3. oh-my-posh 主题
# ------------------------------------------------------------
Write-Step 'oh-my-posh theme'
if (Test-Path $ThemeFile) {
    Remove-Item $ThemeFile -Force
    Write-Info "deleted $ThemeFile"
    if (-not (Get-ChildItem $ThemesDir -Force -ErrorAction SilentlyContinue)) {
        Remove-Item $ThemesDir -Force -ErrorAction SilentlyContinue
    }
}
else { Write-Info 'skip' }

# ------------------------------------------------------------
#  4. 可选清理
# ------------------------------------------------------------
if ($PurgeTools) {
    Write-Step 'tool dir'
    if (Test-Path $ToolsDir) {
        Remove-Item $ToolsDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Info "deleted $ToolsDir"
    }
    else { Write-Info 'skip' }
}

if ($PurgeFont) {
    Write-Step 'user font'
    $files = @(Get-ChildItem $UserFontDir -Filter 'Meslo*' -ErrorAction SilentlyContinue)
    foreach ($f in $files) {
        if (Test-Path $FontRegKey) {
            (Get-ItemProperty $FontRegKey).PSObject.Properties |
                Where-Object { $_.Name -like 'Meslo*' -and $_.Value -eq $f.FullName } |
                ForEach-Object { Remove-ItemProperty -Path $FontRegKey -Name $_.Name -Force -ErrorAction SilentlyContinue }
        }
        Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
    }
    Write-Info "removed $($files.Count) files and its registry keys"
}

if ($PurgeModules) {
    Write-Step 'PSFzf module'
    $mods = @(Get-ChildItem (Join-Path $env:USERPROFILE 'Documents\PowerShell\Modules') -Directory -Filter 'PSFzf' -ErrorAction SilentlyContinue)
    foreach ($m in $mods) { Remove-Item $m.FullName -Recurse -Force -ErrorAction SilentlyContinue; Write-Info "deleted $($m.FullName)" }
    if (-not $mods) { Write-Info 'skip' }
}

if ($RestoreColorPrevalence) {
    Write-Step 'recover theme color show'
    Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\DWM' -Name ColorPrevalence -Value 1 -Type DWord -Force
    Write-Info 'DWM\ColorPrevalence = 1'
}

Write-Step 'finished'
Write-Info 'reopen Windows Terminal to take effect'
