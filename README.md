# nvim-multi-cursor

## Features

- Implement by using macro recording
- Repeat your action at each virtual cursor, support all of your customized keymaps
- Press `q` to quit multi-cursor-mode
- TODO: currently only support normal mode, the actions in insert mode or visual mode will be synced
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
