local config = require("nvim-multi-cursor.config")
local cursor = require("nvim-multi-cursor.cursor")
local utils = require("nvim-multi-cursor.utils")

local M = {}

M.multi_cursor_mode = false
M.iterating_virtual_cursors = false
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
  utils.clear_vmc_augroup()
  utils.start_record()
  M.multi_cursor_mode = true
  utils.add_log("start")
end

function M.stop()
  if not M.multi_cursor_mode then
    return
  end
  M.multi_cursor_mode = false
  M.iterating_virtual_cursors = false
  M.last_handle_mode = "n"
  utils.stop_record()
  utils.restore_vmc_augroup()
  utils.resotre_register()
  utils.resotre_ve()
  config.config.stop_hook()
  vim.keymap.del("n", "q", { buffer = 0 })
  vim.keymap.del("n", "<Esc>", { buffer = 0 })
  cursor.clear_cursors()
  utils.add_log("stop")
  utils.break_log()
  -- vim.print(utils.last_log)
end

function M.normal_change()
  M.iterating_virtual_cursors = true
  local reg = utils.stop_record()
  if cursor.adding_cursor then
    utils.add_log("normal_change last_mode:%s @m:%s(discarded)", M.last_handle_mode, reg)
  else
    utils.add_log("normal_change last_mode:%s @m:%s", M.last_handle_mode, reg)
  end

  if reg ~= "" and not cursor.adding_cursor then
    cursor.update_main_cursor()
    for _, c in ipairs(cursor.virtual_cursors) do
      cursor.goto_cursor(c)
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
  end

  config.config.normal_changed_hook()
  utils.start_record()
  M.iterating_virtual_cursors = false
end

function M.insert_change()
  M.iterating_virtual_cursors = true
  local reg = utils.stop_record()
  if cursor.adding_cursor then
    utils.add_log("insert_change last_mode:%s mode:%s @m:%s(discarded)", M.last_handle_mode, vim.fn.mode(), reg)
  else
    utils.add_log("insert_change last_mode:%s mode:%s @m:%s", M.last_handle_mode, vim.fn.mode(), reg)
  end

  local vmc = config.vmc
  if vmc then
    vim.go.operatorfunc = [[v:lua.require'vscode-multi-cursor'.create_cursor]]
    config.config.orig_cursor_hl = config.config.cursor_hl
    config.config.cursor_hl = "VSCodeNone"
  end

  if reg ~= "" and not cursor.adding_cursor then
    cursor.update_main_cursor()
    for _, c in ipairs(cursor.virtual_cursors) do
      cursor.goto_cursor(c)
      if M.last_handle_mode == "n" then
        local eol = #vim.fn.getline(".")
        if reg == "A" or c.col == eol and reg == "a" then
          vim.fn.cursor(c.line, eol + 1, eol + 1)
        else
          vim.cmd.execute([["normal! \<Esc>\<Right>Q"]]) -- unexpected behavior when at EOL
        end
      else
        vim.cmd("normal i" .. reg)
        vim.cmd.execute([["normal \<Right>"]])
      end
      if vmc then
        vim.cmd("normal g@l") -- add vscode-multi-cursor
      end
      -- utils.add_log("[%d, %d]", c.line, c.col)
      cursor.update_cursor(c)
    end
    cursor.goto_main_cursor()
    cursor.delete_duplicate_cursors()
    if vmc then
      vim.cmd("normal g@l")
    end
  end

  if vmc and M.last_handle_mode == "n" then
    utils.add_log("go into vscode-multi-cursor")
    vim.keymap.set({ "n" }, "mi", vmc.start_left, { desc = "Start cursors on the left", buffer = true })
    vim.keymap.set({ "n" }, "mI", vmc.start_left_edge, { desc = "Start cursors on the left edge", buffer = true })
    vim.keymap.set({ "n" }, "ma", vmc.start_left, { desc = "Start cursors on the right", buffer = true })
    vim.keymap.set({ "n" }, "mA", vmc.start_left, { desc = "Start cursors on the right", buffer = true })

    vim.api.nvim_create_autocmd({ "InsertEnter" }, {
      once = true,
      callback = vmc.cancel,
    })
    vim.api.nvim_create_autocmd({ "InsertLeave" }, {
      once = true,
      callback = function()
        vim.api.nvim_create_autocmd({ "InsertLeave" }, {
          once = true,
          callback = function()
            -- return from vscode-multi-cursor to nvim-multi-cursor
            vim.keymap.del({ "n" }, "mi", { buffer = true })
            vim.keymap.del({ "n" }, "mI", { buffer = true })
            vim.keymap.del({ "n" }, "ma", { buffer = true })
            vim.keymap.del({ "n" }, "mA", { buffer = true })
            cursor.goto_main_cursor()
            utils.start_record()
            config.config.cursor_hl = config.config.orig_cursor_hl
            -- redraw cursors, if you mapped following key, what can i say, man!
            vim.api.nvim_input("<D-F7>")
            M.last_handle_mode = "n"
            M.iterating_virtual_cursors = false
          end,
        })
      end,
    })
    -- fix on empty line
    for _, curs in ipairs(require("vscode-multi-cursor.state").cursors) do
      if curs.start_pos[1] ~= curs.end_pos[1] then
        curs.start_pos = curs.end_pos
        curs.range.start = curs.range["end"]
      end
    end
    -- call start_left directly does not work, seems there's <esc> come from somewhere
    vim.api.nvim_input("<Esc>m" .. reg)
    return
  end

  utils.start_record()
  M.iterating_virtual_cursors = false
end

function M.setup()
  vim.on_key(function(key)
    if not M.multi_cursor_mode or M.iterating_virtual_cursors then
      return
    end

    -- Schedule it in order to iterate the virtual cursors after the real cursor has done
    vim.schedule(function()
      if not M.multi_cursor_mode then
        return
      end

      local mode = vim.fn.mode()
      local state = vim.fn.state()
      -- Break change mode into normal/insert mode
      if mode == "i" and state == "o" then
        vim.api.nvim_input("<Esc>")
        vim.schedule(function()
          vim.api.nvim_input("a")
        end)
        return
      end
      -- Quit when something is pending
      if state ~= "" then
        return
      end

      if mode == "n" then
        M.normal_change()
        M.last_handle_mode = mode
      elseif mode == "i" then
        M.insert_change()
        M.last_handle_mode = mode
      end
    end)
  end, cursor.ns_id)
end

return M
