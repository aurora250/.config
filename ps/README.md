# PowerShell 7 + Windows Terminal

```
ps/
├── README.md                本文件
├── install.ps1              安装
├── uninstall.ps1            回滚
├── install-font-admin.ps1   机器级字体安装
├── profile.ps1              $PROFILE
├── agnoster-dsh.omp.json    oh-my-posh 主题
└── settings.json            Windows Terminal 配置参考
```

---

## 快速开始

```powershell
pwsh -File ps\install.ps1                                    # 全量安装
pwsh -File ps\install.ps1 -Opacity 35 -FontSize 13           # 透明 / 字号
pwsh -File ps\install.ps1 -FontZip D:\Downloads\Meslo.zip    # 使用本地字体包
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
| 终端配置   | Windows Terminal 的`settings.json`                                                             |
| 工具链     | `%LOCALAPPDATA%\Programs\dsh-tools\bin`                                                        |
| 字体       | `%LOCALAPPDATA%\Microsoft\Windows\Fonts` + `HKCU\...\Fonts`                                    |
