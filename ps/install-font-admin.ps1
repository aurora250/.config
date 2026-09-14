# ============================================================
#  把 Nerd Font 安装成"所有用户"，需要管理员权限
#
#  用法:
#      pwsh -File ps\install-font-admin.ps1
#      pwsh -File ps\install-font-admin.ps1 -Zip "$env:USERPROFILE\Downloads\Meslo.zip"
#      pwsh -File ps\install-font-admin.ps1 -SourceDir D:\fonts -Filter 'MesloLGS*Mono*.ttf'
#
#  默认会顺手清掉同名的用户级副本与 HKCU 注册项，想保留就加 -KeepUserCopy
# ============================================================
[CmdletBinding()]
param(
    [string]$SourceDir = (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'),
    [string]$Filter = 'MesloLGSDZ*NerdFontMono*.ttf',
    [string]$Zip,
    [switch]$KeepUserCopy
)

$ErrorActionPreference = 'Continue'
$LogFile = Join-Path $env:TEMP 'dsh-font-admin.log'
$SystemFontDir = Join-Path $env:SystemRoot 'Fonts'
$Hklm = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$Hkcu = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$script:Lines = @()

function Say([string]$m) { Write-Host $m; $script:Lines += $m }
function Fail([string]$m) { Say "error: $m"; if (Test-Path $LogFile) { $script:Lines | Set-Content -LiteralPath $LogFile -Encoding utf8 }; exit 1 }

# ------------------------------------------------------------
#  0. 权限
# ------------------------------------------------------------
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Say "administrator: $admin"
Say "user         : $env:USERNAME"
if (-not $admin) { Fail 'need admin permission' }

Add-Type -AssemblyName System.Drawing.Common -ErrorAction SilentlyContinue
if (-not ('Dsh.FontApi' -as [type])) {
    Add-Type -Namespace Dsh -Name FontApi -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern int AddFontResourceW(string lpFileName);
[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam, uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
'@
}

# ------------------------------------------------------------
#  1. 找字体源
# ------------------------------------------------------------
$srcFiles = @(Get-ChildItem $SourceDir -Filter $Filter -File -ErrorAction SilentlyContinue)
if (-not $srcFiles -and $Zip) {
    if (-not (Test-Path $Zip)) { Fail "cannot find zip: $Zip" }
    $ex = Join-Path $env:TEMP ('dshfontadmin_' + [IO.Path]::GetFileNameWithoutExtension($Zip))
    Remove-Item $ex -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -LiteralPath $Zip -DestinationPath $ex -Force
    $srcFiles = @(Get-ChildItem $ex -Recurse -File -Filter '*.ttf' | Where-Object { $_.Name -like '*Mono*' })
}
if (-not $srcFiles) {
    Say "no font which matchs $Filter in $SourceDir"
    Say 'note: download Meslo.zip and use -Zip option:'
    Say '  curl.exe -L -o "$env:TEMP\Meslo.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip'
    Fail 'no font file to install'
}
Say "source files: $($srcFiles.Count) counts ($($srcFiles[0].DirectoryName))"

# ------------------------------------------------------------
#  2. 安装到 C:\Windows\Fonts + HKLM
# ------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $SystemFontDir | Out-Null
$installed = @()
foreach ($f in $srcFiles) {
    $fam = $f.BaseName
    try {
        $pfc = New-Object System.Drawing.Text.PrivateFontCollection
        $pfc.AddFontFile($f.FullName)
        $fam = $pfc.Families[0].Name
        $pfc.Dispose()
    } catch { }

    $style = ''
    if     ($f.BaseName -match 'BoldItalic$') { $style = 'Bold Italic' }
    elseif ($f.BaseName -match 'Bold$')       { $style = 'Bold' }
    elseif ($f.BaseName -match 'Italic$')     { $style = 'Italic' }
    elseif ($f.BaseName -match 'Oblique$')    { $style = 'Oblique' }

    $dest = Join-Path $SystemFontDir $f.Name
    Copy-Item $f.FullName $dest -Force
    $regName = if ($style) { "$fam $style (TrueType)" } else { "$fam (TrueType)" }
    New-ItemProperty -Path $Hklm -Name $regName -Value $dest -PropertyType String -Force | Out-Null
    Say "  HKLM: $regName"
    $installed += [pscustomobject]@{ Family = $fam; Path = $dest }
}

foreach ($i in $installed) { $null = [Dsh.FontApi]::AddFontResourceW($i.Path) }
$r = [IntPtr]::Zero
[Dsh.FontApi]::SendMessageTimeout([IntPtr]0xffff, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero, 2, 3000, [ref]$r) | Out-Null
Say 'broadcast WM_FONTCHANGE to all window'

# ------------------------------------------------------------
#  3. 清掉同名的用户级副本与 HKCU 注册项，避免重复族名
# ------------------------------------------------------------
if (-not $KeepUserCopy) {
    $userDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $removed = 0
    foreach ($f in @(Get-ChildItem $userDir -Filter $Filter -File -ErrorAction SilentlyContinue)) {
        if (Test-Path $Hkcu) {
            (Get-ItemProperty $Hkcu).PSObject.Properties |
                Where-Object { $_.Value -eq $f.FullName } |
                ForEach-Object { Remove-ItemProperty -Path $Hkcu -Name $_.Name -Force -ErrorAction SilentlyContinue }
        }
        Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
        $removed++
    }
    Say "clear user registry key: $removed count (use -KeepUserCopy option to keep)"
}

# ------------------------------------------------------------
#  4. 校验
# ------------------------------------------------------------
Say ''
$fams = @((New-Object System.Drawing.Text.InstalledFontCollection).Families.Name | Where-Object { $_ -like '*Meslo*' })
if ($fams) { Say "  see in system fonts: $($fams -join ' | ')" } else { Say '  !! no Meslo in system fonts' }
foreach ($fam in ($installed.Family | Sort-Object -Unique)) {
    $t = New-Object System.Drawing.Font($fam, 12)
    Say "  construct with name '$fam' -> $($t.FontFamily.Name)"
    $t.Dispose()
}
Say "  HKLM entry: $((@((Get-ItemProperty $Hklm).PSObject.Properties | Where-Object { $_.Name -like 'Meslo*' })).Count) entries"

$script:Lines | Set-Content -LiteralPath $LogFile -Encoding utf8
Say ''
Say 'finished, reopen Windows Terminal to take effect'
