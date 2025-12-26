# nvim-multi-cursor

## Features

- Implement by using macro recording
- Repeat your action at each virtual cursor, support all of your customized keymaps
- Press `q`/`<Esc>` to quit multi-cursor-mode
- Work together with [vscode-multi-cursor.nvim](https://github.com/vscode-neovim/vscode-multi-cursor.nvim)
- TODO: currently only support normal and insert mode, the actions in visual mode will be synced
  to virtual cursor when you return to normal mode.

## Installation

Example with lazy.nvim

```lua
  {
    "mrbeardad/nvim-multi-cursor",
    dependencies = { { "folke/flash.nvim", opts={} } },
    keys = {
      {
        "<C-j>",
        function()
          require("nvim-multi-cursor").toggle_cursor_downward()
        end,
        mode = { "n" },
        desc = "Toggle Cursor Downward",
      },
      {
        "<C-k>",
        function()
          require("nvim-multi-cursor").toggle_cursor_upward()
        end,
        mode = { "n" },
        desc = "Toggle Cursor Upward",
      },
      {
        "<Leader>mm",
        function()
          require("nvim-multi-cursor").toggle_cursor_at_curpos()
        end,
        mode = { "n" },
        desc = "Toggle Cursor",
      },
      {
        "<Leader>ms",
        function()
          require("nvim-multi-cursor").toggle_cursor_by_flash()
        end,
        mode = { "n" },
        desc = "Selection To Toggle Cursor",
      },
      {
        "<Leader>mw",
        function()
          require("nvim-multi-cursor").toggle_cursor_by_flash(vim.fn.expand("<cword>"))
        end,
        mode = { "n" },
        desc = "Selection Wrod To Toggle Cursor",
      },
    },
    opts = {
      hl_group = "IncSearch"
    },
  },
```
