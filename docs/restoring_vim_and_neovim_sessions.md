# Restoring vim and neovim sessions

## `persistence.nvim` strategy
- when using [persistence.nvim](https://github.com/folke/persistence.nvim) by Folke, tmux-resurrect will call on it to load sessions if they exist
- in `.tmux.conf` or `.config/tmux/tmux.conf`:
  
    ```sh
    set -g @resurrect-strategy-nvim 'persistence'
    ```
## native session strategy
- save vim/neovim sessions. I recommend
  [tpope/vim-obsession](https://github.com/tpope/vim-obsession) (as almost every
  plugin, it works for both vim and neovim).
- in `.tmux.conf` or `.config/tmux/tmux.conf`:
    
    ```sh
    # for vim
    set -g @resurrect-strategy-vim 'session'
    # for neovim
    set -g @resurrect-strategy-nvim 'session'
    ```
`tmux-resurrect` will now restore vim and neovim sessions if `Session.vim` file
is present.

> If you're using the vim binary provided by MacVim.app then you'll need to set `@resurrect-processes`, for example:
> ```
> set -g @resurrect-processes '~Vim -> vim'
> ```
