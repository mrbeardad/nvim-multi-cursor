# nvim-multi-cursor

## Features

- Implement by using macro recording
- Repeat your action at each virtual cursor, support all of your customized keymaps
- Press `q`/`<Esc>` to quit multi-cursor-mode
- Split pasting, which means every cursor works as if it has independent register for change, delete, yank and paste
- Work with popup completion
- Work together with [vscode-neovim](https://github.com/vscode-neovim/vscode-neovim.nvim),
  use vscode multi cursor for insert mode
- TODO: currently only support normal and insert mode, the actions in visual mode will be synced
  to virtual cursor when you return to normal mode.
- TODO: Undo spliting

## Installation

Example of [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
  {
    "mrbeardad/nvim-multi-cursor",
    -- stylua: ignore
    keys = {
      { "<C-J>", function() require("nvim-multi-cursor.cursor").toggle_cursor_downward() end, mode = { "n" }, desc = "Add Cursor Downward" },
      { "<C-S-J>", function() require("nvim-multi-cursor.cursor").cursor_down() end, mode = { "n" }, desc = "Move Cursor Down" },
      { "<C-K>", function() require("nvim-multi-cursor.cursor").toggle_cursor_upward() end, mode = { "n" }, desc = "Add Cursor Upward" },
      { "<C-S-K>", function() require("nvim-multi-cursor.cursor").cursor_up() end, mode = { "n" }, desc = "Move Cursor Up" },
      { "<C-N>", function() require("nvim-multi-cursor.cursor").toggle_cursor_next_match() end, mode = { "n", "x" }, desc = "Add Cursor at Next Match" },
      { "<C-S-N>", function() require("nvim-multi-cursor.cursor").cursor_next_match() end, mode = { "n" }, desc = "Move Cursor to Next Match" },
      { "<Leader>mw", function() require("nvim-multi-cursor.cursor").toggle_cursor_by_flash([[\<\w*\>]]) end, mode = { "n" }, desc = "Selection Wrod To Add Cursor" },
      { "<Leader>mm", function() require("nvim-multi-cursor.cursor").toggle_cursor_by_flash() end, mode = { "n" }, desc = "Selection To Add Cursor" },
    },
    opts = {
      start_hook = function()
        -- vim.keymap.set({ "n", "x" }, "p", function()
        --   require("nvim-multi-cursor.utils").on_put_pre()
        --   return "p"
        -- end, { buffer = true, expr = true })
        -- vim.keymap.set({ "n", "x" }, "P", function()
        --   require("nvim-multi-cursor.utils").on_put_pre()
        --   return "P"
        -- end, { buffer = true, expr = true })
        vim.keymap.set("i", "<C-r>", function()
          local ch = vim.fn.getcharstr()
          local reg_pattern = [[^[a-zA-Z0-9"_%#*+\-.:/=]$]]
          if string.match(ch, reg_pattern) then
            require("nvim-multi-cursor.utils").on_put_pre(ch)
          end
          return "<C-r>" .. ch
        end, { expr = true, buffer = true })
      end,
      stop_hook = function()
        -- vim.keymap.del({ "n", "x" }, "p", { buffer = true })
        -- vim.keymap.del({ "n", "x" }, "P", { buffer = true })
        vim.keymap.del("i", "<C-r>", { buffer = true })
      end,
      hl_group = "IncSearch"
    },
    vscode = true,
  },
```

Works together with [yanky](https://github.com/gbprod/yanky.nvim)

```lua
  {
    "gbprod/yanky.nvim",
    opts = {
      ring = {
        permanent_wrapper = function(callback)
          return function(state, do_put)
            require("nvim-multi-cursor.utils").on_put_pre()
            return callback(state, do_put)
          end
        end,
      },
    },
  },
```

> This plugin is part of [my nvim config](https://github.com/mrbeardad/nvim),
> you can find more detail config there, such as how to works together with blink.cmp and flash.nvim
