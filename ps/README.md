# PowerShell 7 + Windows Terminal

把 `files/zshrc` + `files/tmux.conf` + `gnome/` 这套配置移植到 **Windows 原生 PowerShell**
（不使用 WSL）。覆盖**外观层**与 **shell 层**；tmux 那一层换成 Windows Terminal 的窗格与键位。

```
ps/
├── README.md               本文件
├── install.ps1             安装（幂等，可分层跳过）
├── uninstall.ps1           回滚
├── profile.ps1             可复用 $PROFILE（对应 files/zshrc）
├── agnoster-dsh.omp.json   oh-my-posh 主题（agnoster + 右侧执行耗时）
└── settings.json           部署后的 Windows Terminal 配置参考
```

---

## 快速开始

```powershell
pwsh -File ps\install.ps1                                    # 全量安装
pwsh -File ps\install.ps1 -Opacity 35 -FontSize 13           # 更透明 / 更大字号
pwsh -File ps\install.ps1 -FontZip D:\Downloads\Meslo.zip    # 字体包已在本地时直接用它
pwsh -File ps\install.ps1 -NoTools -NoFont -NoTerminal       # 只写 shell 配置
```

回滚：

```powershell
pwsh -File ps\uninstall.ps1                                  # 还原配置，保留工具与字体
pwsh -File ps\uninstall.ps1 -PurgeTools -PurgeFont -PurgeModules
pwsh -File ps\uninstall.ps1 -RestoreColorPrevalence          # 恢复"标题栏显示主题色"
```

安装脚本写入位置：


| 产物       | 路径                                                                                           |
| ---------- | ---------------------------------------------------------------------------------------------- |
| shell 配置 | `$PROFILE.CurrentUserCurrentHost`（`~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`） |
| 提示符主题 | `~\.config\oh-my-posh\agnoster-dsh.omp.json`                                                   |
| 终端配置   | Windows Terminal 的`settings.json`（**合并**写入，先备份为 `settings.json.dsh-bak-<时间戳>`）  |
| 工具链     | `%LOCALAPPDATA%\Programs\dsh-tools\bin`（profile 已把它挂在 PATH 最前）                        |
| 字体       | `%LOCALAPPDATA%\Microsoft\Windows\Fonts` + `HKCU\...\Fonts`（仅当前用户，不需要管理员）        |
