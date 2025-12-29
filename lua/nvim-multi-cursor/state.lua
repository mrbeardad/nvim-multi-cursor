local config = require("nvim-multi-cursor.config")
local cursor = require("nvim-multi-cursor.cursor")
local utils = require("nvim-multi-cursor.utils")

local M = {}

M.multi_cursor_mode = false
M.adding_cursor = false
M.iterating_virtual_cursors = false
M.completed_item_word = nil
M.current_cursor_id = 0
M.last_handle_mode = "n"

function M.start()
  if M.multi_cursor_mode then
    return
  end
  vim.keymap.set("n", "q", M.stop, { buffer = 0 })
  vim.keymap.set("n", "<Esc>", M.stop, { buffer = 0 })
  config.config.start_hook()
  utils.cache_ve()
  utils.cache_register()
  utils.start_record()
  M.multi_cursor_mode = true
  utils.add_log("start")
end

function M.stop()
  if not M.multi_cursor_mode then
    return
  end
  M.multi_cursor_mode = false
  M.adding_cursor = false
  M.iterating_virtual_cursors = false
  M.completed_item_word = nil
  M.last_handle_mode = "n"
  cursor.clear_cursors()
  utils.stop_record()
  utils.resotre_register()
  utils.resotre_ve()
  utils.clear_reg_queues()
  config.config.stop_hook()
  vim.keymap.del("n", "q", { buffer = 0 })
  vim.keymap.del("n", "<Esc>", { buffer = 0 })
  utils.add_log("stop")
  utils.break_log()
  -- vim.print(utils.last_log)
end

function M.normal_change()
  M.iterating_virtual_cursors = true
  local reg = utils.stop_record()
  utils.add_log("normal_change last_mode:%s @m:%s", M.last_handle_mode, reg)

  if reg ~= "" then
    cursor.update_main_cursor()
    for _, c in ipairs(cursor.virtual_cursors) do
      cursor.goto_cursor(c)
      M.current_cursor_id = c.id
      if M.last_handle_mode == "i" then
        vim.cmd("normal i" .. reg)
      else
        vim.cmd("normal! Q")
        -- Sometime the trailing <esc> will be ignore by :normal
        if vim.fn.mode() ~= "n" then
          vim.cmd("normal! \27")
        end
      end
      -- utils.add_log("[%d, %d]", c.line, c.col)
      cursor.update_cursor(c)
    end
    cursor.goto_main_cursor()
    cursor.delete_duplicate_cursors()
    M.current_cursor_id = 0
  end

  utils.start_record()
  M.iterating_virtual_cursors = false
end

function M.insert_change()
  M.iterating_virtual_cursors = true
  local reg = utils.stop_record()
  local cmp = M.completed_item_word and M.completed_item_word:sub(2) or ""
  utils.add_log("insert_change last_mode:%s @m:%s cmp:%s", M.last_handle_mode, reg, cmp)

  if vim.g.vscode then
    -- hide virtual cursors
    config.config.orig_cursor_hl = config.config.cursor_hl
    config.config.cursor_hl = "VSCodeNone"
  end

  if reg ~= "" then
    cursor.update_main_cursor()
    for _, c in ipairs(cursor.virtual_cursors) do
      cursor.goto_cursor(c)
      M.current_cursor_id = c.id
      if M.last_handle_mode == "n" then
        if reg == "o" then
          -- There's a bug for o
          vim.cmd.execute([["normal! \<End>a\<CR>\<C-o>"]])
        else
          -- When use :normal to do command, it will add <esc> if the command is not complete, such as stay in insert mode.
          -- However, the <esc> moves cursor left if the cursor is not at the first column.
          -- Thus, append a <c-o> after Q, since <c-o> stops insert mode and keeps cursor position not moved
          vim.cmd.execute([["normal! Q\<C-o>"]])
        end
      elseif cmp ~= "" then
        local cword = utils.is_keyword_char_left_of_cursor() and [[\<C-w>]] or ""
        vim.cmd.execute([["normal i]] .. cword .. cmp .. [[\<C-o>"]])
        M.completed_item_word = nil
      else
        vim.cmd.execute([["normal i]] .. reg .. [[\<C-o>"]])
      end
      cursor.update_cursor(c)
      -- utils.add_log("[%d, %d]", c.line, c.col)
      if vim.g.vscode then
        c.lsp_pos = vim.lsp.util.make_position_params(0, "utf-16").position
      end
    end
    cursor.goto_main_cursor()
    cursor.delete_duplicate_cursors()
    M.current_cursor_id = 0
  end

  if vim.g.vscode then
    utils.add_log("go into vscode-multi-cursor")
    local vscode = require("vscode")

    -- force vscode cursor into insert mode
    vim.api.nvim_input("<C-o>i")
    vscode.with_insert(function()
      for _, curs in ipairs(cursor.virtual_cursors) do
        vscode.action("createCursor", {
          args = {
            position = {
              lineNumber = curs.line,
              column = curs.lsp_pos.character + 1,
            },
          },
        })
      end
    end)

    vim.api.nvim_create_autocmd({ "InsertLeave" }, {
      once = true,
      callback = function()
        vim.api.nvim_create_autocmd({ "InsertLeave" }, {
          once = true,
          callback = function()
            utils.add_log("go back to nvim-multi-cursor")
            vscode.call("removeSecondaryCursors")
            -- TODO: Sync the cursor positions from vscode after edit
            cursor.goto_main_cursor()
            utils.start_record()
            config.config.cursor_hl = config.config.orig_cursor_hl
            -- redraw virtual cursors, if you mapped following key, what can i say, man!
            vim.api.nvim_input("<D-F7>")
            M.last_handle_mode = "n"
            M.iterating_virtual_cursors = false
          end,
        })
      end,
    })
    return
  end

  utils.start_record()
  M.iterating_virtual_cursors = false
end

function M.setup()
  vim.on_key(function(key)
    if not M.multi_cursor_mode or M.iterating_virtual_cursors or M.adding_cursor then
      return
    end

    -- Schedule it in order to iterate the virtual cursors after the real cursor has done
    vim.schedule(function()
      if not M.multi_cursor_mode or M.iterating_virtual_cursors or M.adding_cursor then
        return
      end

      local mode = vim.fn.mode()
      local state = vim.fn.state()
      -- Change mode keeps (mode == "i" and state == "o") until exit insert mode, so let's break it
      if mode == "i" and state == "o" then
        vim.api.nvim_input("<C-o>i")
        return
      end
      -- Quit when operation is pending, waiting for further key input
      if state ~= "" then
        return
      end

      -- It is time to replay the marco operations
      if mode == "n" then
        M.normal_change()
        M.last_handle_mode = mode
      elseif mode == "i" then
        M.insert_change()
        M.last_handle_mode = mode
      end
    end)
  end, cursor.ns_id)

  vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("NvimMultiCursorYank", {}),
    callback = function()
      if not M.multi_cursor_mode then
        return
      end
      utils.on_yank_post()
    end,
  })

  vim.api.nvim_create_autocmd("CompleteDonePre", {
    group = vim.api.nvim_create_augroup("NvimMultiCursorCompleteDone", {}),
    callback = function()
      if not M.multi_cursor_mode then
        return
      end
      M.completed_item_word = vim.v.completed_item.word
    end,
  })
end

return M
