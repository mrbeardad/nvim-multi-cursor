local M = {}

M.config = {
  hl_group = "IncSearch",
  start_hook = function() end,
  post_hook = function() end,
}

M.ns_id = vim.api.nvim_create_namespace("MultipleCursors")

function M.set_extmark(line, col, id)
  local opts = { id = id }
  local line_text = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1]
  local line_length = #line_text
  -- If the line is empty or col is past the end of the line
  if line_length == 0 or col > line_length then
    -- Use virtual text to add and highlight a space
    opts.virt_text = { { " ", M.config.hl_group } }
    opts.virt_text_pos = "overlay"
  else
    -- Otherwise highlight the character
    local char_col = vim.fn.strchars(line_text:sub(1, col - 1))
    opts.end_col = #vim.fn.strcharpart(line_text, 0, char_col + 1)
    opts.hl_group = M.config.hl_group
  end
  return vim.api.nvim_buf_set_extmark(0, M.ns_id, line - 1, col - 1, opts)
end

---@class Cursor
---@field line integer 1-based line number
---@field col integer 1-based column number
---@field curwant integer 1-based wanted column number
---@field id integer extmark id

M.virtual_cursors = {}

function M.toggle_cursor(line, col, curwant)
  for index, cursor in ipairs(M.virtual_cursors) do
    if cursor.line == line and cursor.col == col then
      vim.api.nvim_buf_del_extmark(0, M.ns_id, cursor.id)
      table.remove(M.virtual_cursors, index)
      return
    end
  end

  table.insert(M.virtual_cursors, {
    line = line,
    col = col,
    curwant = curwant,
    id = M.set_extmark(line, col),
  })
end

function M.clear_cursors()
  for _, cursor in ipairs(M.virtual_cursors) do
    vim.api.nvim_buf_del_extmark(0, M.ns_id, cursor.id)
  end
  M.virtual_cursors = {}
end

function M.update_cursor(cursor)
  local pos = vim.fn.getcurpos()
  cursor.line = pos[2]
  cursor.col = pos[3]
  cursor.curwant = pos[5]
  M.set_extmark(cursor.line, cursor.col, cursor.id)
end

function M.delete_duplicate_cursors()
  local function hash(line, col, curwant)
    return string.format("%d,%d,%d", line, col, curwant)
  end
  local set = {}
  local curpos = vim.fn.getcurpos()
  set[hash(curpos[2], curpos[3], curpos[5])] = true
  local dup_indexes = {}
  for index, cursor in ipairs(M.virtual_cursors) do
    local h = hash(cursor.line, cursor.col, cursor.curwant)
    if set[h] then
      dup_indexes[#dup_indexes + 1] = index
    else
      set[h] = true
    end
  end
  for _, index in ipairs(dup_indexes) do
    vim.api.nvim_buf_del_extmark(0, M.ns_id, M.virtual_cursors[index].id)
    table.remove(M.virtual_cursors, index)
  end
end

function M.start_record()
  if vim.fn.reg_recording() ~= "" then
    vim.notify("Another recording detected", vim.log.levels.WARN)
    vim.cmd("normal! q")
  end

  vim.cmd("normal! qm")
end

function M.stop_record()
  if vim.fn.reg_recording() == "" then
    vim.notify("Recording not detected", vim.log.levels.WARN)
    return
  end

  vim.cmd("normal! q")
end

M.register_content = ""
function M.cache_register()
  M.register_content = vim.fn.getreg("m")
end

function M.resotre_register()
  vim.fn.setreg("m", M.register_content)
end

M.iterating_virtual_cursors = false
function M.normal_change()
  M.iterating_virtual_cursors = true
  M.stop_record()

  local orig_pos = vim.fn.getcurpos()
  for _, cursor in ipairs(M.virtual_cursors) do
    vim.fn.cursor({ cursor.line, cursor.col, 0, cursor.curwant })
    vim.cmd("normal! Q")
    if vim.fn.mode() ~= "n" then
      vim.cmd("normal! \27")
    end
    M.update_cursor(cursor)
  end
  vim.fn.cursor({ orig_pos[2], orig_pos[3], orig_pos[4], orig_pos[5] })
  M.delete_duplicate_cursors()

  M.start_record()
  M.iterating_virtual_cursors = false
end

-- TODO: insert mode
-- TODO: visual mode
M.multi_cursor_mode = false
function M.start()
  vim.keymap.set("n", "q", M.stop, { buffer = 0 })
  vim.keymap.set("n", "<Esc>", M.stop, { buffer = 0 })
  M.config.start_hook()
  M.cache_register()
  M.start_record()
  M.multi_cursor_mode = true
end

function M.stop(k)
  M.multi_cursor_mode = false
  M.stop_record()
  M.resotre_register()
  M.config.post_hook()
  vim.keymap.del("n", "q", { buffer = 0 })
  vim.keymap.del("n", "<Esc>", { buffer = 0 })
  M.clear_cursors()
end

function M.toggle_cursor_at_mouse()
  local pos = vim.fn.getmousepos()
  M.toggle_cursor(pos.line, pos.column)
end

function M.toggle_cursor_at_curpos()
  local pos = vim.fn.getcurpos()
  M.toggle_cursor(pos[2], pos[3], pos[5])
end

function M.setup(opts)
  vim.tbl_extend("force", M.config, opts)

  vim.on_key(function(key)
    if not M.multi_cursor_mode or M.iterating_virtual_cursors then
      return
    end
    if vim.fn.getchar(1) == 0 then
      vim.schedule(function()
        local mode = vim.fn.mode()
        if mode == "n" then
          M.normal_change()
        end
      end)
    end
  end, M.ns_id)
end

return M
