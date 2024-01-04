local M = {}

M.last_log = {}
M.log = {}

M.config = {
  hl_group = "IncSearch",
  start_hook = function() end,
  stop_hook = function() end,
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
M.adding_cursor = false
function M.toggle_cursor(line, col, curwant)
  M.adding_cursor = true

  local remove_cursor_index
  for index, cursor in ipairs(M.virtual_cursors) do
    if cursor.line == line and cursor.col == col then
      remove_cursor_index = index
    end
  end

  if remove_cursor_index then
    vim.api.nvim_buf_del_extmark(0, M.ns_id, M.virtual_cursors[remove_cursor_index].id)
    table.remove(M.virtual_cursors, remove_cursor_index)
    M.log[#M.log + 1] = string.format("remove cursor (%d, %d)", line, col)
  else
    table.insert(M.virtual_cursors, {
      line = line,
      col = col,
      curwant = curwant,
      id = M.set_extmark(line, col),
    })
    M.log[#M.log + 1] = string.format("add cursor (%d, %d)", line, col)
  end

  if #M.virtual_cursors > 0 then
    M.start()
  else
    M.stop()
  end
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
    local cursor = M.virtual_cursors[index]
    M.log[#M.log + 1] = string.format("delete duplicate cursor (%d, %d)", cursor.line, cursor.col)
    vim.api.nvim_buf_del_extmark(0, M.ns_id, cursor.id)
    table.remove(M.virtual_cursors, index)
  end
end

function M.toggle_cursor_at_mouse()
  local pos = vim.fn.getmousepos()
  M.toggle_cursor(pos.line, pos.column)
end

function M.toggle_cursor_at_curpos()
  local pos = vim.fn.getcurpos()
  M.toggle_cursor(pos[2], pos[3], pos[5])
end

function M.toggle_cursor_upward()
  local pos = vim.fn.getcurpos()
  M.toggle_cursor(pos[2], pos[3], pos[5])
  vim.cmd.normal("k")
end

function M.toggle_cursor_downward()
  local pos = vim.fn.getcurpos()
  M.toggle_cursor(pos[2], pos[3], pos[5])
  vim.cmd.normal("j")
end

function M.toggle_cursor_by_flash(pattern)
  local selected_labels = {}

  local function find_label(match)
    for i, pos in ipairs(selected_labels) do
      if pos[1] == match.pos[1] and pos[2] == match.pos[2] then
        return i
      end
    end
    return nil
  end

  require("flash").jump({
    pattern = pattern,
    search = {
      mode = "search",
    },
    jump = {
      pos = "range",
    },
    label = {
      format = function(opts)
        return {
          {
            opts.match.label,
            find_label(opts.match) and opts.hl_group or "FlashLabelUnselected",
          },
        }
      end,
    },
    action = function(match, state)
      local i = find_label(match)
      if i then
        table.remove(selected_labels, i)
      else
        table.insert(selected_labels, { match.pos[1], match.pos[2], match.end_pos[1], match.end_pos[2] })
      end
      state:_update()
      require("flash").jump({ continue = true })
    end,
  })

  for index, pos in ipairs(selected_labels) do
    if index < #selected_labels then
      M.toggle_cursor(pos[1], pos[2] + 1, pos[2] + 1)
    else
      vim.api.nvim_win_set_cursor(0, { pos[1], pos[2] })
    end
  end
end

function M.start_record()
  if vim.fn.reg_recording() ~= "" then
    M.log[#M.log + 1] = "start record but already exist"
    vim.cmd("normal! q")
  end

  vim.cmd("normal! qm")
end

function M.stop_record()
  if vim.fn.reg_recording() == "" then
    M.log[#M.log + 1] = "stop record but not exist"
    return ""
  end

  vim.cmd("normal! q")
  return vim.fn.getreg("m")
end

M.register_content = ""
function M.cache_register()
  M.register_content = vim.fn.getreg("m")
end

function M.resotre_register()
  vim.fn.setreg("m", M.register_content)
end

M.multi_cursor_mode = false
function M.start()
  if M.multi_cursor_mode then
    return
  end
  vim.keymap.set("n", "q", M.stop, { buffer = 0 })
  -- vim.keymap.set("n", "<Esc>", M.stop, { buffer = 0 })
  M.config.start_hook()
  M.cache_register()
  M.start_record()
  M.multi_cursor_mode = true
  M.log[#M.log + 1] = "start"
end

function M.stop()
  if not M.multi_cursor_mode then
    return
  end
  M.multi_cursor_mode = false
  M.stop_record()
  M.resotre_register()
  M.config.stop_hook()
  vim.keymap.del("n", "q", { buffer = 0 })
  -- vim.keymap.del("n", "<Esc>", { buffer = 0 })
  M.clear_cursors()
  M.log[#M.log + 1] = "stop"
  M.last_log = M.log
  M.log = {}
end

M.iterating_virtual_cursors = false
function M.normal_change()
  M.iterating_virtual_cursors = true
  local reg = M.stop_record()
  if M.adding_cursor then
    M.log[#M.log + 1] = "adding cursor @m:" .. reg
  else
    M.log[#M.log + 1] = "@m:" .. reg
  end

  if reg ~= "" and not M.adding_cursor then
    local orig_pos = vim.fn.getcurpos()
    for _, cursor in ipairs(M.virtual_cursors) do
      vim.fn.cursor({ cursor.line, cursor.col, 0, cursor.curwant })
      vim.cmd("normal! Q")
      if vim.fn.mode() ~= "n" then -- Sometime the trailing <esc> will be ignore by :normal
        vim.cmd("normal! \27")
      end
      M.update_cursor(cursor)
    end
    vim.fn.cursor({ orig_pos[2], orig_pos[3], orig_pos[4], orig_pos[5] })
    M.delete_duplicate_cursors()
  end

  M.adding_cursor = false
  M.start_record()
  M.iterating_virtual_cursors = false
end

-- TODO: insert mode
-- TODO: visual mode
function M.setup(opts)
  vim.tbl_extend("force", M.config, opts)

  vim.on_key(function(key)
    if not M.multi_cursor_mode or M.iterating_virtual_cursors then
      return
    end

    -- Schedule it in order to cycle the virtual cursors after the real cursor has done
    vim.schedule(function()
      -- Quit multi_cursor_mode or nothing is pending
      if not M.multi_cursor_mode or vim.fn.state() ~= "" then
        return
      end

      local mode = vim.fn.mode()
      if mode == "n" then
        M.normal_change()
      end
    end)
  end, M.ns_id)
end

return M
