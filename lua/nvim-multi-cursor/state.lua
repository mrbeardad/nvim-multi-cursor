local config = require("nvim-multi-cursor.config")
local cursor = require("nvim-multi-cursor.cursor")
local utils = require("nvim-multi-cursor.utils")

local M = {}

M.multi_cursor_mode = false
M.do_not_repeat = false
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
  utils.start_record()
  M.multi_cursor_mode = true
  utils.add_log("start")
end

function M.stop()
  if not M.multi_cursor_mode then
    return
  end
  M.multi_cursor_mode = false
  utils.stop_record()
  utils.resotre_register()
  utils.resotre_ve()
  config.config.stop_hook()
  vim.keymap.del("n", "q", { buffer = 0 })
  vim.keymap.del("n", "<Esc>", { buffer = 0 })
  cursor.clear_cursors()
  utils.add_log("stop")
  utils.break_log()
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
    cursor.delete_duplicate_cursors()
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
  end

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

  if reg ~= "" and not cursor.adding_cursor then
    cursor.update_main_cursor()
    cursor.delete_duplicate_cursors()
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
      -- utils.add_log("[%d, %d]", c.line, c.col)
      cursor.update_cursor(c)
    end
    cursor.goto_main_cursor()
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
