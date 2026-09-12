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
        Write-Info "已还原 ← $($bak.Name)"
        return $true
    }
    return $false
}

# ------------------------------------------------------------
#  1. Windows Terminal 设置
# ------------------------------------------------------------
Write-Step 'Windows Terminal 设置'
$wt = @()
$wt += Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -ErrorAction SilentlyContinue |
       Where-Object { $_.Name -like 'Microsoft.WindowsTerminal*' } |
       ForEach-Object { Join-Path $_.FullName 'LocalState\settings.json' }
$wt += Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json'
$wt = $wt | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($wt) {
    if (-not (Restore-NewestBackup $wt)) {
        Write-Warn '没找到备份；请手动检查 settings.json 里的字体/opacity/键位/默认 profile'
    }
}
else { Write-Warn '没找到 Windows Terminal 的 settings.json' }

# ------------------------------------------------------------
#  2. $PROFILE
# ------------------------------------------------------------
Write-Step 'PowerShell profile'
$prof = $PROFILE.CurrentUserCurrentHost
if (Test-Path $prof) {
    if (-not (Restore-NewestBackup $prof)) {
        Remove-Item $prof -Force
        Write-Info "已删除 $prof（无备份可还原）"
    }
}
else { Write-Info '不存在，跳过' }

# ------------------------------------------------------------
#  3. oh-my-posh 主题
# ------------------------------------------------------------
Write-Step 'oh-my-posh 主题'
if (Test-Path $ThemeFile) {
    Remove-Item $ThemeFile -Force
    Write-Info "已删除 $ThemeFile"
    if (-not (Get-ChildItem $ThemesDir -Force -ErrorAction SilentlyContinue)) {
        Remove-Item $ThemesDir -Force -ErrorAction SilentlyContinue
        Write-Info '空目录一并删除'
    }
}
else { Write-Info '不存在，跳过' }

# ------------------------------------------------------------
#  4. 可选清理
# ------------------------------------------------------------
if ($PurgeTools) {
    Write-Step '工具目录'
    if (Test-Path $ToolsDir) {
        Remove-Item $ToolsDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Info "已删除 $ToolsDir"
    }
    else { Write-Info '不存在，跳过' }
}

if ($PurgeFont) {
    Write-Step '用户字体'
    $files = @(Get-ChildItem $UserFontDir -Filter 'Meslo*' -ErrorAction SilentlyContinue)
    foreach ($f in $files) {
        if (Test-Path $FontRegKey) {
            (Get-ItemProperty $FontRegKey).PSObject.Properties |
                Where-Object { $_.Name -like 'Meslo*' -and $_.Value -eq $f.FullName } |
                ForEach-Object { Remove-ItemProperty -Path $FontRegKey -Name $_.Name -Force -ErrorAction SilentlyContinue }
        }
        Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
    }
    Write-Info "已移除 $($files.Count) 个字体文件与其注册项（注销后彻底生效）"
}

if ($PurgeModules) {
    Write-Step 'PSFzf 模块'
    $mods = @(Get-ChildItem (Join-Path $env:USERPROFILE 'Documents\PowerShell\Modules') -Directory -Filter 'PSFzf' -ErrorAction SilentlyContinue)
    foreach ($m in $mods) { Remove-Item $m.FullName -Recurse -Force -ErrorAction SilentlyContinue; Write-Info "已删除 $($m.FullName)" }
    if (-not $mods) { Write-Info '不存在，跳过' }
}

if ($RestoreColorPrevalence) {
    Write-Step '恢复"在标题栏和窗口边框上显示主题色"'
    Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\DWM' -Name ColorPrevalence -Value 1 -Type DWord -Force
    Write-Info 'DWM\ColorPrevalence = 1（注销后完全生效）'
}

Write-Step '完成'
Write-Info '重新打开 Windows Terminal 生效'
