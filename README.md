# .config

一套 zsh + tmux 个人终端配置（另含 PowerShell 7 + Windows Terminal 的原生移植版，见 [`ps/`](ps/README.md)）

---

## 目录结构

```
zsh-config/
├── README.md                      README
├── install.sh                     安装
├── uninstall.sh                   回滚
├── files/
│   ├── zshrc                      可复用 .zshrc
│   ├── tmux.conf                  可复用 .tmux.conf
│   └── 99-powerline-pua.conf      fontconfig
└── gnome/
    ├── terminal.sh                终端字体 + 透明度
    └── blur.sh                    Blur my Shell
```

```
ps/                                PowerShell 7 + Windows Terminal 版（不使用 WSL）
├── README.md                      分层对照表、键位、已知差异
├── install.ps1                    安装（幂等，可分层跳过）
├── uninstall.ps1                  回滚
├── profile.ps1                    可复用 $PROFILE
├── agnoster-dsh.omp.json          oh-my-posh 主题
└── settings.json                  Windows Terminal 配置参考
```

---

## 快速开始

```bash
bash install.sh                 # 全量安装
bash install.sh --no-blur       # 不做 GNOME Blur
bash install.sh --no-tmux       # 不做 tmux
bash install.sh --transparency=50
bash install.sh --help
```

> 脚本带 `--chsh` 才会切换默认 shell；不加则只打印命令

回滚：

```bash
bash uninstall.sh                          # 保留扩展与 tmux 插件
bash uninstall.sh --purge-extension        # 删除 Blur my Shell
bash uninstall.sh --purge-tmux-plugins     # 删除 ~/.tmux/plugins
```

---

## PowerShell

`ps/` 是把这套配置移植到 **PowerShell 7 + Windows Terminal** 的版本

```powershell
pwsh -File ps\install.ps1                                   # 全量安装
pwsh -File ps\install.ps1 -Opacity 35 -FontSize 13
pwsh -File ps\install.ps1 -FontZip D:\Downloads\Meslo.zip    # 字体包已在本地时直接用它
pwsh -File ps\install.ps1 -NoTools -NoFont                   # 只写配置，不装依赖

pwsh -File ps\uninstall.ps1                                  # 还原配置
pwsh -File ps\uninstall.ps1 -PurgeTools -PurgeFont -PurgeModules
```



## zsh

### 配置项


| # | 项                     | 实现                                                | 依赖              |
| - | ---------------------- | --------------------------------------------------- | ----------------- |
| 1 | **fzf**                | `^R` 搜索历史 / `^T` 跳目录 / `^P` 选文件并插入路径 | fzf, fd-find, bat |
| 2 | **fzf-tab**            | 把补全菜单换成 fzf 界面，`Tab` 触发                 | fzf-tab 插件      |
| 3 | **command usage**      | 超过 0.5s 的命令在右提示符显示耗时                  | 无                |
| 4 | **vi-mode + 光标形状** | 插入模式竖线光标、普通模式块状光标                  | 无                |
| 5 | **zsh-autopair**       | 括号引号自动配对                                    | zsh-autopair 插件 |
| 6 | **zoxide**             | `z <关键字>` 智能跳转、`zi` 交互选择                | zoxide            |
| 7 | **`gr`**               | 跳到 git 仓库根目录                                 | 无                |

---

## tmux

要求 **tmux >= 3.3**

### 基础项


| 项                               | 值              | 解释                                                   |
| -------------------------------- | --------------- | ------------------------------------------------------ |
| `mouse`                          | `on`            | 鼠标选择窗格/滚动/调整大小                             |
| `escape-time`                    | `0`             | vim/neovim 用户**必加**，默认 500ms 会让模式切换发粘 |
| `focus-events`                   | `on`            | vim/nvim 的 autoread 依赖它                            |
| `history-limit`                  | `10000`         |                                                        |
| `base-index` / `pane-base-index` | `1`             | 与浏览器标签页的肌肉记忆一致                           |
| `renumber-windows`               | `on`            | 关掉窗口后不留空号                                     |
| `automatic-rename`               | `on`            | 按当前路径命名窗口                                     |
| `detach-on-destroy`              | `off`           | 关窗口不连带杀会话                                     |
| `allow-passthrough`              | `on`            |                                                        |
| `set-clipboard`                  | `on`            | 经 OSC 52 把复制内容送到系统剪贴板                     |
| `default-terminal`               | `tmux-256color` | ↓ 真彩色三件套                                        |
| `terminal-features`              | `,*256col*:RGB` |                                                        |
| `terminal-overrides`             | `,*256col*:Tc`  |                                                        |

### 进阶项


| 项                 | 说明                                                                                                           |
| ------------------ | -------------------------------------------------------------------------------------------------------------- |
| **前缀改 `C-s`**   | `C-s` 默认是终端的 **XOFF 软件流控键**。不关掉的话，按前缀会把终端"阻塞"                                       |
| **Alt 无前缀导航** | `M-n/e/u/i` 选窗格、`M-N/E/U/I` 调大小、`M-1~9` 跳窗口、`M-o` 新窗口、`M-Q` 关窗格、`M-f` 缩放、`M-v` 复制模式 |
| **双行状态栏**     | `status 2`。第 0 行自定义为「会话名 / ZOOM 提示 / 当前窗格路径」，第 1 行用 tmux 内建布局                      |
| **窗格标题栏**     | `pane-border-status top` + `pane-border-format`，显示序号/命令/路径                                            |
| **copy-mode-vi**   | `n/i/u/e` 移动、`U/E` 翻 5 行、`Y` 复制到行尾、`y` 复制并结束                                                  |
| **会话持久化**     | `tmux-resurrect` + `tmux-continuum`                                                                            |
| **同步输入窗格**   | `C-g` 开关，开启时活动边框变红作视觉警示                                                                       |

---

## 快捷键

### zsh（vi 模式）

#### 提示符编辑


| 按键        | 功能                                            |
| ----------- | ----------------------------------------------- |
| `^R`        | fzf 搜索历史命令                                |
| `^T`        | fzf 选择目录并`cd`                              |
| `^P`        | fzf 选择文件，路径插入命令行                    |
| `Tab`       | fzf-tab 补全菜单                                |
| `^W`        | 删除光标前一个词（autopair 版，会连带处理配对） |
| `^?` / `^H` | 退格（autopair 版，会连带删除配对符号）         |
| `Esc`       | 进入 vi 普通模式                                |

#### 自动配对

输入 `(` `[` `{` `"` `'` `` ` `` 会自动补上右半边并把光标停在中间

#### 命令


| 命令         | 功能                |
| ------------ | ------------------- |
| `z <关键字>` | zoxide 智能跳转     |
| `zi`         | zoxide 交互式选择   |
| `gr`         | 跳到 git 仓库根目录 |

---

### 6.2 tmux

前缀 `C-s`

**会话 / 窗口**


| 按键          | 功能                           |
| ------------- | ------------------------------ |
| `C-s`         | 发送字面前缀                   |
| `C-c`         | 新建会话                       |
| `C-p` / `C-n` | 上一个 / 下一个窗口            |
| `.`           | 重命名会话                     |
| `,`           | 重命名窗口                     |
| `W`           | 浏览窗口/会话树（choose-tree） |
| `d`           | 断开客户端                     |
| `$`           | 重命名会话                     |

**窗格**


| 按键      | 功能                             |
| --------- | -------------------------------- |
| `n`       | 横向分屏，新窗格在上             |
| `i`       | 横向分屏，新窗格在下             |
| `u`       | 纵向分屏，新窗格在左             |
| `e`       | 纵向分屏，新窗格在右             |
| `S`       | 纵向移动窗格（choose-tree 选择） |
| `V`       | 横向移动窗格（choose-tree 选择） |
| `>` / `<` | 向下 / 向上交换窗格位置          |
| `|`       | 与上一个窗格交换                 |
| `Space`   | 切换布局                         |
| `z`       | 缩放/还原窗格                    |
| `x`       | 关闭窗格                         |
| `q`       | 显示窗格编号                     |
| `o`       | 切换到下一个窗格                 |
| `C-g`     | **开关同步输入窗格**             |

**复制粘贴**


| 按键            | 功能           |
| --------------- | -------------- |
| `M-v`（无前缀） | 进入复制模式   |
| `b`             | 列出剪贴板缓冲 |
| `p`             | 粘贴缓冲       |

**会话持久化**


| 按键  | 功能                              |
| ----- | --------------------------------- |
| `C-y` | 手动保存会话                      |
| `C-r` | 恢复会话                          |
| —    | 每 5 分钟自动保存；**不自动恢复** |

**插件管理**


| 按键  | 功能                       |
| ----- | -------------------------- |
| `I`   | 安装`@plugin` 列表中的插件 |
| `U`   | 更新插件                   |
| `M-u` | 清理不再声明的插件         |

**其它**


| 按键      | 功能                |
| --------- | ------------------- |
| `r`       | 重载配置            |
| `t`       | 时钟模式            |
| `s` / `w` | 会话 / 窗口选择界面 |

#### 无前缀键（Alt 组合）


| 按键          | 功能                     |
| ------------- | ------------------------ |
| `M-1` ~ `M-9` | 直接跳到第 1~9 号窗口    |
| `M-n` / `M-i` | 焦点左移 / 右移          |
| `M-u` / `M-e` | 焦点上移 / 下移          |
| `M-N` / `M-I` | 左 / 右调整窗格宽度 3 格 |
| `M-U` / `M-E` | 上 / 下调整窗格高度 3 格 |
| `M-l` / `M-y` | 上一个 / 下一个窗口      |
| `M-o`         | 在当前路径新建窗口       |
| `M-Q`         | 直接关闭当前窗格         |
| `M-f`         | 缩放 / 还原当前窗格      |
| `M-v`         | 进入复制模式             |

> 方向映射：**`n`=左 `i`=右 `u`=上 `e`=下**。

#### 复制模式（`M-v` 进入，vi 风格）


| 按键          | 功能                 |
| ------------- | -------------------- |
| `n` / `i`     | 光标左 / 右          |
| `u` / `e`     | 光标上 / 下          |
| `U` / `E`     | 向上 / 向下滚动 5 行 |
| `C-u` / `C-e` | 向上 / 向下滚动 5 行 |
| `N` / `I`     | 行首 / 行尾          |
| `h`           | 下一个词尾           |
| `v`           | 开始选择             |
| `C-v`         | 矩形选择             |
| `y`           | 复制并退出           |
| `Y`           | 复制到行尾           |
| `=`           | 重复搜索             |
| `Enter`       | 复制并退出           |
| `q`           | **退出复制模式**     |
| `Esc`         | 清除当前选择         |
