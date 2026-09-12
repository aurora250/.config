# ============================================================
#  PowerShell 配置
# ============================================================

if ($PSVersionTable.PSVersion.Major -lt 7) { return }

$ErrorActionPreference = 'Continue'

# ------------------------------------------------------------
#  0. 基础
# ------------------------------------------------------------
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding

$DshBin = Join-Path $env:LOCALAPPDATA 'Programs\dsh-tools\bin'
if ((Test-Path $DshBin) -and ($env:PATH -notlike "*$DshBin*")) {
    $env:PATH = "$DshBin;$env:PATH"
}

# ------------------------------------------------------------
#  1. PSReadLine：vi 模式 + 光标形状 + 预测输入 + 语法着色
# ------------------------------------------------------------
try {
    Import-Module PSReadLine -ErrorAction Stop

    # vi 模式；插入模式竖线、普通模式块状
    Set-PSReadLineOption -EditMode Vi
    Set-PSReadLineOption -ViModeIndicator Cursor
    Set-PSReadLineOption -BellStyle None

    # 预测输入
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle ListView

    Set-PSReadLineOption -MaximumHistoryCount 10000
    Set-PSReadLineOption -HistoryNoDuplicates

    # 语法着色
    Set-PSReadLineOption -Colors @{
        Default          = '#c5c8c6'
        Comment          = '#707880'
        Keyword          = '#b294bb'
        String           = '#b5bd68'
        Operator         = '#8abeb7'
        Variable         = '#81a2be'
        Command          = '#c5c8c6'
        Parameter        = '#b294bb'
        Type             = '#f0c674'
        Number           = '#de935f'
        Member           = '#8abeb7'
        Error            = '#cc6666'
        Emphasis         = '#f0c674'
        Selection        = "`e[48;2;45;47;58m"
        InlinePrediction = '#5f6672'
        ListPrediction   = '#707880'
    }
}
catch {
    Write-Verbose "PSReadLine 配置跳过: $_"
}

# ------------------------------------------------------------
#  2. 自动配对
# ------------------------------------------------------------
function Invoke-DshPairOpen {
    param([System.ConsoleKeyInfo]$Key)

    $pairs = @{ '(' = ')'; '[' = ']'; '{' = '}' }
    $ch    = [string]$Key.KeyChar
    $close = $pairs[$ch]
    if (-not $close) { [Microsoft.PowerShell.PSConsoleReadLine]::Insert($ch); return }

    $line = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($cursor -lt $line.Length -and [string]$line[$cursor] -eq $close) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($ch)
        return
    }

    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($ch + $close)
    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
}

function Invoke-DshPairClose {
    param([System.ConsoleKeyInfo]$Key)

    $ch   = [string]$Key.KeyChar
    $line = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($cursor -lt $line.Length -and [string]$line[$cursor] -eq $ch) {
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    }
    else {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($ch)
    }
}

function Invoke-DshPairQuote {
    param([System.ConsoleKeyInfo]$Key)

    $ch   = [string]$Key.KeyChar
    $line = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($cursor -lt $line.Length -and [string]$line[$cursor] -eq $ch) {
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
        return
    }

    $before = if ($cursor -gt 0) { $line.Substring(0, $cursor) } else { '' }

    if ($before -match '[A-Za-z0-9_]$') {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($ch)
        return
    }

    $n = 0
    foreach ($c in $before.ToCharArray()) { if ([string]$c -eq $ch) { $n++ } }
    if ($n % 2 -eq 1) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($ch)
        return
    }

    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($ch + $ch)
    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
}

function Invoke-DshBackwardDeleteChar {
    param([System.ConsoleKeyInfo]$Key)

    $pairs = @{ '(' = ')'; '[' = ']'; '{' = '}'; '"' = '"'; "'" = "'" }
    $line = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($cursor -gt 0 -and $cursor -lt $line.Length) {
        $left  = [string]$line[$cursor - 1]
        $right = [string]$line[$cursor]
        if ($pairs[$left] -and $pairs[$left] -eq $right) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace($cursor - 1, 2, '')
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor - 1)
            return
        }
    }

    [Microsoft.PowerShell.PSConsoleReadLine]::BackwardDeleteChar()
}

try {
    Set-PSReadLineKeyHandler -Key '(', '[', '{'       -ScriptBlock { param($key, $arg) Invoke-DshPairOpen $key }
    Set-PSReadLineKeyHandler -Key ')', ']', '}'       -ScriptBlock { param($key, $arg) Invoke-DshPairClose $key }
    Set-PSReadLineKeyHandler -Key '"', "'"            -ScriptBlock { param($key, $arg) Invoke-DshPairQuote $key }
    Set-PSReadLineKeyHandler -Key 'Backspace'         -ScriptBlock { param($key, $arg) Invoke-DshBackwardDeleteChar $key }
}
catch {
    Write-Verbose "自动配对绑定跳过: $_"
}

# ------------------------------------------------------------
#  3. fzf
# ------------------------------------------------------------
$env:FZF_DEFAULT_OPTS = '--height 50% --reverse --border --bind=ctrl-e:down,ctrl-u:up'

$DshFd = (Get-Command fd -ErrorAction SilentlyContinue).Source
if ($DshFd) {
    $env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --exclude .git'
}

$DshBat = (Get-Command bat -ErrorAction SilentlyContinue).Source
if ($DshBat) {
    $env:FZF_CTRL_T_OPTS = '--preview "bat --style=numbers --color=always --line-range :200 {}" --preview-window right:60%'
}

try {
    Import-Module PSFzf -ErrorAction Stop
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' `
                    -PSReadlineChordReverseHistory 'Ctrl+r' `
                    -TabExpansion
}
catch {
    Write-Verbose "PSFzf 未安装，跳过: $_"
}

# ------------------------------------------------------------
#  4. 提示符
# ------------------------------------------------------------
$DshOmpTheme = Join-Path $env:USERPROFILE '.config\oh-my-posh\agnoster-dsh.omp.json'
$DshOmp = (Get-Command oh-my-posh -ErrorAction SilentlyContinue).Source
if (-not $DshOmp) {
    $candidate = Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\bin\oh-my-posh.exe'
    if (Test-Path $candidate) { $DshOmp = $candidate }
}

if ($DshOmp -and (Test-Path $DshOmp)) {
    if (-not (Test-Path $DshOmpTheme) -and $env:POSH_THEMES_PATH) {
        $DshOmpTheme = Join-Path $env:POSH_THEMES_PATH 'agnoster.omp.json'
    }
    if (Test-Path $DshOmpTheme) {
        & $DshOmp init pwsh --config $DshOmpTheme | Invoke-Expression
    }
}
else {
    function global:prompt {
        $p = $ExecutionContext.SessionState.Path.CurrentLocation
        "PS $p$('>' * ($nestedPromptLevel + 1)) "
    }
}

# ------------------------------------------------------------
#  5. zoxide
# ------------------------------------------------------------
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# ------------------------------------------------------------
#  6. gr
# ------------------------------------------------------------
function gr {
    $root = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $root) {
        Write-Error 'gr: 不在 git 仓库中'
        return
    }
    Set-Location $root
}
