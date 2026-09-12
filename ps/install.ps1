# ============================================================
#  PowerShell + Windows Terminal 终端配置安装脚本
#
#  幂等：可以重复执行，不重复备份、不破坏已有配置
#  分层：-NoProfile / -NoTools / -NoFont / -NoTerminal 可单独跳过
#
#  用法:
#      pwsh -File ps\install.ps1                       # 全量安装
#      pwsh -File ps\install.ps1 -Opacity 35           # 更透明
#      pwsh -File ps\install.ps1 -FontSize 13
#      pwsh -File ps\install.ps1 -FontZip D:\Downloads\Meslo.zip
#      pwsh -File ps\install.ps1 -NoTools -NoFont      # 只写配置
#
#  依赖: PowerShell 7+、winget、Windows Terminal 1.19+
# ============================================================
[CmdletBinding()]
param(
    [int]$Opacity = 45,
    [int]$FontSize = 12,
    [string]$FontFace = 'MesloLGSDZ Nerd Font Mono',
    [string]$FontZip,
    [switch]$NoProfile,
    [switch]$NoTools,
    [switch]$NoFont,
    [switch]$NoTerminal
)

$ErrorActionPreference = 'Continue'
$Here = $PSScriptRoot

function Write-Step([string]$m) { Write-Host ''; Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Info([string]$m) { Write-Host "  $m" }
function Write-Note([string]$m) { Write-Host "  $m" -ForegroundColor DarkGray }
function Write-Warn([string]$m) { Write-Host "warning: $m" -ForegroundColor Yellow }
function Write-Bad([string]$m) { Write-Host "error: $m" -ForegroundColor Red }

$script:Problems = @()

$PwshGuid    = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'   # WT 里 PowerShell 7 的标准 GUID
$SchemeName  = 'Tomorrow Night (dsh)'
$ThemesDir   = Join-Path $env:USERPROFILE '.config\oh-my-posh'
$ThemeFile   = Join-Path $ThemesDir 'agnoster-dsh.omp.json'
$ToolsDir    = Join-Path $env:LOCALAPPDATA 'Programs\dsh-tools\bin'
$UserFontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$FontRegKey  = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

$Scheme = [ordered]@{
    name='Tomorrow Night (dsh)'; background='#232530'; foreground='#C5C8C6'
    cursorColor='#B294BB'; selectionBackground='#2D2F3A'
    black='#232530';  red='#CC6666';  green='#B5BD68';  yellow='#F0C674'
    blue='#81A2BE';   purple='#B294BB'; cyan='#8ABEB7'; white='#C5C8C6'
    brightBlack='#707880'; brightRed='#CC6666'; brightGreen='#B5BD68'; brightYellow='#F0C674'
    brightBlue='#81A2BE'; brightPurple='#B294BB'; brightCyan='#8ABEB7'; brightWhite='#FFFFFF'
}

# tmux 键位的 Windows Terminal 映射（n=左 i=右 u=上 e=下）
$Bindings = @(
    @{ id='User.dsh.focusLeft';    keys='alt+n';        cmd=@{ action='moveFocus';  direction='left'  } }
    @{ id='User.dsh.focusRight';   keys='alt+i';        cmd=@{ action='moveFocus';  direction='right' } }
    @{ id='User.dsh.focusUp';      keys='alt+u';        cmd=@{ action='moveFocus';  direction='up'    } }
    @{ id='User.dsh.focusDown';    keys='alt+e';        cmd=@{ action='moveFocus';  direction='down'  } }
    @{ id='User.dsh.resizeLeft';   keys='alt+shift+n';  cmd=@{ action='resizePane'; direction='left'  } }
    @{ id='User.dsh.resizeRight';  keys='alt+shift+i';  cmd=@{ action='resizePane'; direction='right' } }
    @{ id='User.dsh.resizeUp';     keys='alt+shift+u';  cmd=@{ action='resizePane'; direction='up'    } }
    @{ id='User.dsh.resizeDown';   keys='alt+shift+e';  cmd=@{ action='resizePane'; direction='down'  } }
    @{ id='User.dsh.splitLeft';    keys='ctrl+alt+n';   cmd=@{ action='splitPane'; split='left';  splitMode='duplicate' } }
    @{ id='User.dsh.splitRight';   keys='ctrl+alt+i';   cmd=@{ action='splitPane'; split='right'; splitMode='duplicate' } }
    @{ id='User.dsh.splitUp';      keys='ctrl+alt+u';   cmd=@{ action='splitPane'; split='up';    splitMode='duplicate' } }
    @{ id='User.dsh.splitDown';    keys='ctrl+alt+e';   cmd=@{ action='splitPane'; split='down';  splitMode='duplicate' } }
    @{ id='User.dsh.zoom';         keys='alt+f';        cmd='togglePaneZoom' }
    @{ id='User.dsh.closePane';    keys='alt+shift+q';  cmd='closePane' }
    @{ id='User.dsh.broadcast';    keys='alt+g';        cmd='toggleBroadcastInput' }
    @{ id='User.dsh.dupTab';       keys='alt+o';        cmd='duplicateTab' }
    @{ id='User.dsh.markMode';     keys='alt+v';        cmd='toggleMarkMode' }
    @{ id='User.dsh.palette';      keys='alt+w';        cmd='commandPalette' }
    @{ id='User.dsh.prevTab';      keys='alt+l';        cmd='prevTab' }
    @{ id='User.dsh.nextTab';      keys='alt+y';        cmd='nextTab' }
    @{ id='User.dsh.tab1'; keys='alt+1'; cmd=@{ action='switchToTab'; index=0 } }
    @{ id='User.dsh.tab2'; keys='alt+2'; cmd=@{ action='switchToTab'; index=1 } }
    @{ id='User.dsh.tab3'; keys='alt+3'; cmd=@{ action='switchToTab'; index=2 } }
    @{ id='User.dsh.tab4'; keys='alt+4'; cmd=@{ action='switchToTab'; index=3 } }
    @{ id='User.dsh.tab5'; keys='alt+5'; cmd=@{ action='switchToTab'; index=4 } }
    @{ id='User.dsh.tab6'; keys='alt+6'; cmd=@{ action='switchToTab'; index=5 } }
    @{ id='User.dsh.tab7'; keys='alt+7'; cmd=@{ action='switchToTab'; index=6 } }
    @{ id='User.dsh.tab8'; keys='alt+8'; cmd=@{ action='switchToTab'; index=7 } }
    @{ id='User.dsh.tab9'; keys='alt+9'; cmd=@{ action='switchToTab'; index=8 } }
)

$WingetPkgs = [ordered]@{
    'JanDeDobbeleer.OhMyPosh' = 'oh-my-posh'
    'junegunn.fzf'            = 'fzf'
    'ajeetdsouza.zoxide'      = 'zoxide'
    'sharkdp.fd'              = 'fd'
    'sharkdp.bat'             = 'bat'
    'BurntSushi.ripgrep.MSVC' = 'rg'
}

$ManualSources = [ordered]@{
    'oh-my-posh' = 'https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-windows-amd64.exe'
    'fzf'        = 'https://github.com/junegunn/fzf/releases   （取 fzf-*-windows_amd64.zip，解出 fzf.exe）'
    'zoxide'     = 'https://github.com/ajeetdsouza/zoxide/releases （取 zoxide-*-x86_64-pc-windows-msvc.zip）'
    'fd'         = 'https://github.com/sharkdp/fd/releases    （取 fd-*-x86_64-pc-windows-msvc.zip）'
    'bat'        = 'https://github.com/sharkdp/bat/releases   （取 bat-*-x86_64-pc-windows-msvc.zip）'
    'rg'         = 'https://github.com/BurntSushi/ripgrep/releases （取 ripgrep-*-x86_64-pc-windows-msvc.zip）'
}

# ------------------------------------------------------------
#  工具函数
# ------------------------------------------------------------
function Get-Tool([string]$Name) {
    $c = Get-Command $Name -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $f = Join-Path $ToolsDir "$Name.exe"
    if (Test-Path $f) { return $f }
    return $null
}

function Backup-File([string]$Path) {
    if (-not (Test-Path $Path)) { return $null }
    $bak = "$Path.dsh-bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -LiteralPath $Path -Destination $bak -Force
    return $bak
}

function Get-WtSettingsPath {
    $c = @()
    $c += Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -ErrorAction SilentlyContinue |
          Where-Object { $_.Name -like 'Microsoft.WindowsTerminal*' } |
          ForEach-Object { Join-Path $_.FullName 'LocalState\settings.json' }
    $c += Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json'
    return ($c | Where-Object { Test-Path $_ } | Select-Object -First 1)
}

function Remove-JsonComments([string]$Text) {
    return (($Text -split "`r?`n") | ForEach-Object { if ($_ -match '^\s*//') { '' } else { $_ } }) -join "`n"
}

function Test-NerdFontInstalled([string]$Family) {
    $pool = @()
    foreach ($k in @($FontRegKey, 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts')) {
        if (Test-Path $k) { $pool += (Get-ItemProperty $k).PSObject.Properties.Name }
    }
    $pool += (Get-ChildItem $UserFontDir -Filter '*.ttf' -ErrorAction SilentlyContinue).Name
    $pool += (Get-ChildItem 'C:\Windows\Fonts' -Filter '*.ttf' -ErrorAction SilentlyContinue).Name
    $norm = ($Family -replace '[\s\-]', '').ToLower()
    foreach ($p in $pool) {
        if ($null -eq $p) { continue }
        if ((($p -replace '[\s\-\.\(\)]', '').ToLower()).Contains($norm)) { return $true }
    }
    return $false
}

# 复制到用户字体目录 + 写 HKCU + 立即加载 + 广播
function Install-NerdFontZip([string]$ZipPath, [string]$Like) {
    Add-Type -AssemblyName System.Drawing.Common -ErrorAction SilentlyContinue
    $ex = Join-Path $env:TEMP ('dshfont_' + [IO.Path]::GetFileNameWithoutExtension($ZipPath))
    Remove-Item $ex -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $ex -Force
    $ttf = @(Get-ChildItem $ex -Recurse -Filter '*.ttf' | Where-Object { $_.Name -like $Like })
    if (-not $ttf) { $ttf = @(Get-ChildItem $ex -Recurse -Filter '*.ttf') }
    if (-not $ttf) { Write-Warn "压缩包里没有 ttf: $ZipPath"; return $false }

    New-Item -ItemType Directory -Force -Path $UserFontDir | Out-Null
    if (-not (Test-Path $FontRegKey)) { New-Item -Path $FontRegKey -Force | Out-Null }

    foreach ($f in $ttf) {
        $style = ''
        if ($f.BaseName -match '-([A-Za-z]+)$') {
            $style = switch ($Matches[1]) {
                'Regular'    { '' }
                'Bold'       { 'Bold' }
                'Italic'     { 'Italic' }
                'BoldItalic' { 'Bold Italic' }
                'Oblique'    { 'Oblique' }
                default      { $Matches[1] }
            }
        }
        $fam = $f.BaseName
        try {
            $pfc = New-Object System.Drawing.Text.PrivateFontCollection
            $pfc.AddFontFile($f.FullName)
            $fam = $pfc.Families[0].Name
            $pfc.Dispose()
        } catch { }
        $dest = Join-Path $UserFontDir $f.Name
        Copy-Item $f.FullName $dest -Force
        $regName = if ($style) { "$fam $style (TrueType)" } else { "$fam (TrueType)" }
        New-ItemProperty -Path $FontRegKey -Name $regName -Value $dest -PropertyType String -Force | Out-Null
        Write-Info "+ $($f.Name)"
    }

    try {
        if (-not ('Dsh.FontApi' -as [type])) {
            Add-Type -Namespace Dsh -Name FontApi -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern int AddFontResourceW(string lpFileName);
[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam, uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
'@
        }
        foreach ($f in $ttf) { $null = [Dsh.FontApi]::AddFontResourceW((Join-Path $UserFontDir $f.Name)) }
        $r = [IntPtr]::Zero
        [Dsh.FontApi]::SendMessageTimeout([IntPtr]0xffff, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero, 2, 2000, [ref]$r) | Out-Null
        Write-Info '已广播 WM_FONTCHANGE'
    } catch { Write-Warn "立即加载字体失败（注销后仍会生效）: $($_.Exception.Message)" }

    Remove-Item $ex -Recurse -Force -ErrorAction SilentlyContinue
    return $true
}

# ------------------------------------------------------------
#  0. 环境检查
# ------------------------------------------------------------
Write-Step '环境检查'
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Bad "需要 PowerShell 7+，当前 $($PSVersionTable.PSVersion)"
    exit 1
}
Write-Info "PowerShell : $($PSVersionTable.PSVersion)  ($([Diagnostics.Process]::GetCurrentProcess().Path))"
Write-Info "用户       : $env:USERNAME@$env:COMPUTERNAME"
$wtPath = Get-WtSettingsPath
if ($wtPath) { Write-Info "WT 配置    : $wtPath" } else { Write-Warn '没找到 Windows Terminal 的 settings.json，-NoTerminal 会自动生效' }

# ------------------------------------------------------------
#  1. $PROFILE
# ------------------------------------------------------------
Write-Step 'PowerShell profile'
if ($NoProfile) {
    Write-Info '-NoProfile，跳过'
}
else {
    $src = Join-Path $Here 'profile.ps1'
    $dst = $PROFILE.CurrentUserCurrentHost
    if (-not (Test-Path $src)) {
        Write-Bad "找不到 $src"
    }
    else {
        New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
        if (Test-Path $dst) {
            if ((Get-FileHash $src).Hash -eq (Get-FileHash $dst).Hash) {
                Write-Info '内容一致，无需改动'
            }
            else {
                $bak = Backup-File $dst
                Write-Info "备份 → $bak"
                Copy-Item $src $dst -Force
                Write-Info "写入 $dst"
            }
        }
        else {
            Copy-Item $src $dst -Force
            Write-Info "写入 $dst"
        }
    }
}

# ------------------------------------------------------------
#  2. oh-my-posh 主题
# ------------------------------------------------------------
Write-Step 'oh-my-posh 主题'
New-Item -ItemType Directory -Force -Path $ThemesDir | Out-Null
$themeSrc = Join-Path $Here 'agnoster-dsh.omp.json'
if (Test-Path $themeSrc) {
    Copy-Item $themeSrc $ThemeFile -Force
    Write-Info "写入 $ThemeFile"
}
else { Write-Bad "找不到 $themeSrc" }

# ------------------------------------------------------------
#  3. 工具链
# ------------------------------------------------------------
Write-Step '工具链'
if ($NoTools) {
    Write-Info '-NoTools，跳过'
    foreach ($t in $WingetPkgs.Values) { if (-not (Get-Tool $t)) { Write-Note "缺少 $t" } }
}
else {
    New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null
    $hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
    if (-not $hasWinget) { Write-Warn '找不到 winget，只能手动下载（见文末清单）' }

    foreach ($id in $WingetPkgs.Keys) {
        $exe = $WingetPkgs[$id]
        if (Get-Tool $exe) { Write-Info "$exe 已就位"; continue }
        if (-not $hasWinget) { continue }
        Write-Info "winget install $id …"
        $ok = $false
        for ($i = 1; $i -le 2 -and -not $ok; $i++) {
            $null = winget install -e --id $id --accept-source-agreements --accept-package-agreements --disable-interactivity 2>&1
            if ($LASTEXITCODE -eq 0) { $ok = $true }
            else { Write-Note "第 $i 次失败（GitHub 下载常被中断，可重试）" }
        }
        if ($ok) { Write-Info "$exe 安装完成" } else { $script:Problems += "$exe 未安装" }
    }

    foreach ($exe in $WingetPkgs.Values) {
        if (Get-Tool $exe) { continue }
        $f = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages') -Recurse -Filter "$exe.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($f) {
            Copy-Item $f.FullName (Join-Path $ToolsDir "$exe.exe") -Force
            Write-Info "$exe 从 winget 缓存补链"
        }
    }
}

# ------------------------------------------------------------
#  4. Nerd Font
# ------------------------------------------------------------
Write-Step "Nerd Font ($FontFace)"
if ($NoFont) {
    Write-Info '-NoFont，跳过'
}
elseif (Test-NerdFontInstalled $FontFace) {
    Write-Info '字体已安装'
}
elseif ($FontZip -and (Test-Path $FontZip)) {
    Write-Info "从本地包安装: $FontZip"
    $null = Install-NerdFontZip -ZipPath $FontZip -Like 'MesloLGS Nerd Font Mono*'
}
else {
    $omp = Get-Tool 'oh-my-posh'
    if ($omp) {
        Write-Info '尝试 oh-my-posh font install Meslo（网络不好时可能静默失败）'
        & $omp font install Meslo
    }
    if (Test-NerdFontInstalled $FontFace) {
        Write-Info '字体安装完成'
    }
    else {
        Write-Warn '字体仍未安装。手动下载后重跑并带上 -FontZip：'
        Write-Note 'curl.exe -L -o "$env:TEMP\Meslo.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip'
        Write-Note 'pwsh -File ps\install.ps1 -FontZip "$env:TEMP\Meslo.zip"'
        $script:Problems += '字体未安装'
    }
}

# ------------------------------------------------------------
#  5. Windows Terminal
# ------------------------------------------------------------
Write-Step 'Windows Terminal 设置'
if ($NoTerminal -or -not $wtPath) {
    Write-Info '跳过（-NoTerminal 或未找到配置）'
}
else {
    $bak = Backup-File $wtPath
    Write-Info "备份 → $bak"
    try {
        $json = (Remove-JsonComments (Get-Content -Raw -LiteralPath $wtPath)) | ConvertFrom-Json

        if (-not $json.profiles)          { $json | Add-Member -Force -NotePropertyName profiles  -NotePropertyValue ([pscustomobject]@{}) }
        if (-not $json.profiles.defaults) { $json.profiles | Add-Member -Force -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) }
        if (-not $json.profiles.list)     { $json.profiles | Add-Member -Force -NotePropertyName list -NotePropertyValue @() }

        $d = $json.profiles.defaults
        $d | Add-Member -Force -NotePropertyName font        -NotePropertyValue ([pscustomobject]@{ face = $FontFace; size = $FontSize })
        $d | Add-Member -Force -NotePropertyName opacity     -NotePropertyValue $Opacity
        $d | Add-Member -Force -NotePropertyName useAcrylic  -NotePropertyValue $true
        $d | Add-Member -Force -NotePropertyName colorScheme -NotePropertyValue $SchemeName
        if (-not $d.padding)     { $d | Add-Member -Force -NotePropertyName padding     -NotePropertyValue '8' }
        if (-not $d.historySize) { $d | Add-Member -Force -NotePropertyName historySize -NotePropertyValue 10000 }

        if (-not $json.schemes) { $json | Add-Member -Force -NotePropertyName schemes -NotePropertyValue @() }
        $json.schemes = @(@($json.schemes) | Where-Object { $_.name -ne $SchemeName }) + [pscustomobject]$Scheme

        $pwshExe = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
        if (-not $pwshExe) { $pwshExe = Join-Path $PSHOME 'pwsh.exe' }
        $entry = @($json.profiles.list) | Where-Object { $_.guid -ieq $PwshGuid } | Select-Object -First 1
        if ($entry) {
            $entry | Add-Member -Force -NotePropertyName commandline       -NotePropertyValue $pwshExe
            $entry | Add-Member -Force -NotePropertyName startingDirectory -NotePropertyValue '%USERPROFILE%'
        }
        else {
            $json.profiles.list = @(@($json.profiles.list)) + [pscustomobject]@{
                commandline = $pwshExe; guid = $PwshGuid; hidden = $false; name = 'PowerShell'; startingDirectory = '%USERPROFILE%'
            }
        }
        $json | Add-Member -Force -NotePropertyName defaultProfile -NotePropertyValue $PwshGuid

        if (-not $json.actions)    { $json | Add-Member -Force -NotePropertyName actions    -NotePropertyValue @() }
        if (-not $json.keybindings){ $json | Add-Member -Force -NotePropertyName keybindings -NotePropertyValue @() }
        $added = 0
        foreach ($b in $Bindings) {
            if (-not (@($json.actions) | Where-Object { $_.id -eq $b.id })) {
                $cmd = if ($b.cmd -is [hashtable]) { [pscustomobject]$b.cmd } else { $b.cmd }
                $json.actions = @(@($json.actions)) + [pscustomobject]@{ command = $cmd; id = $b.id }
                $added++
            }
            if (-not (@($json.keybindings) | Where-Object { $_.id -eq $b.id })) {
                $json.keybindings = @(@($json.keybindings)) + [pscustomobject]@{ id = $b.id; keys = $b.keys }
            }
        }

        Set-Content -LiteralPath $wtPath -Value ($json | ConvertTo-Json -Depth 100) -Encoding utf8
        $null = Get-Content -Raw -LiteralPath $wtPath | ConvertFrom-Json      # 回读校验
        Write-Info "已合并设置（新增 $added 条 action），字号 $FontSize、opacity $Opacity、acrylic 开、配色 $SchemeName"
        Write-Info "默认 profile 指向 $pwshExe"
    }
    catch {
        Write-Bad "合并失败，配置未改动以外的东西：$($_.Exception.Message)"
        Write-Note "已备份在 $bak，可直接还原"
        $script:Problems += 'WT 设置合并失败'
    }
}

# ------------------------------------------------------------
#  6. 校验
# ------------------------------------------------------------
Write-Step '校验'
if (Test-Path $PROFILE.CurrentUserCurrentHost) {
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($PROFILE.CurrentUserCurrentHost, [ref]$null, [ref]$errs)
    if ($errs -and $errs.Count) { Write-Bad "profile 语法错误 $($errs.Count) 处"; $script:Problems += 'profile 语法错误' }
    else { Write-Info 'profile 语法 OK' }
}
foreach ($t in $WingetPkgs.Values) {
    $p = Get-Tool $t
    if ($p) { Write-Info "  $t → $p" } else { Write-Info "  $t → 缺失" }
}
if (Test-NerdFontInstalled $FontFace) { Write-Info "  字体 $FontFace OK" } else { Write-Info "  字体 $FontFace 缺失" }

Write-Step '完成'
if ($script:Problems.Count) {
    Write-Warn "有 $($script:Problems.Count) 项需要处理：$($script:Problems -join '、')"
    Write-Host '  手动下载清单（解出的 exe 丢进下面这个目录即可，profile 已把它挂在 PATH 最前）：'
    Write-Host "    $ToolsDir"
    foreach ($k in $ManualSources.Keys) { Write-Host ("    {0,-12} {1}" -f $k, $ManualSources[$k]) }
}
else {
    Write-Info '全部就绪。重新打开 Windows Terminal（完全退出再开）即可看到效果'
}
Write-Note "回滚: pwsh -File ps\uninstall.ps1"
