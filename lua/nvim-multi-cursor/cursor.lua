local config = require("nvim-multi-cursor.config")
local utils = require("nvim-multi-cursor.utils")

local M = {}

---@class Cursor
---@field line integer 1-based line number
---@field col integer 1-based column number
---@field curwant integer 1-based wanted column number
---@field id integer extmark id

M.main_cursor = {} ---@type Cursor
M.virtual_cursors = {} ---@type table[Cursor]
M.ns_id = vim.api.nvim_create_namespace("MultipleCursors")

function M.set_extmark(line, col, id, hl)
  local opts = { id = id }
  local hl_group = hl or config.config.cursor_hl
  local line_text = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1]
  local line_length = #line_text
  -- If the line is empty or col is past the end of the line
  if line_length == 0 or col > line_length then
    -- Use virtual text to add and highlight a space
    opts.virt_text = { { " ", hl_group } }
    opts.virt_text_pos = "overlay"
  else
    -- Otherwise highlight the character
    local char_col = vim.fn.strchars(line_text:sub(1, col - 1))
    opts.end_col = #vim.fn.strcharpart(line_text, 0, char_col + 1)
    opts.hl_group = hl_group
  end
  return vim.api.nvim_buf_set_extmark(0, M.ns_id, line - 1, col - 1, opts)
end

local function hash(a, b, c)
  return bit.bxor(a * 73856093, b * 19349663, c * 83492791)
end

function M.toggle_cursor(line, col, curwant)
  local remove_cursor_index
  for index, cursor in ipairs(M.virtual_cursors) do
    if cursor.line == line and cursor.col == col then
      remove_cursor_index = index
      break
    end
  end

  if remove_cursor_index then
    vim.api.nvim_buf_del_extmark(0, M.ns_id, M.virtual_cursors[remove_cursor_index].id)
    table.remove(M.virtual_cursors, remove_cursor_index)
    utils.add_log("remove cursor (%d, %d)", line, col)
  else
    table.insert(M.virtual_cursors, {
      line = line,
      col = col,
      curwant = curwant,
      id = M.set_extmark(line, col),
    })
    utils.add_log("add cursor (%d, %d)", line, col)
  end

  if #M.virtual_cursors > 0 then
    require("nvim-multi-cursor.state").start()
  else
    require("nvim-multi-cursor.state").stop()
  end
end

function M.clear_cursors()
  for _, cursor in ipairs(M.virtual_cursors) do
    vim.api.nvim_buf_del_extmark(0, M.ns_id, cursor.id)
  end
  M.visual_star = false
  M.virtual_cursors = {}
end

function M.goto_cursor(cursor)
  local extmark_pos = vim.api.nvim_buf_get_extmark_by_id(0, M.ns_id, cursor.id, {})
  -- vim.api.nvim_buf_del_extmark(0, M.ns_id, cursor.id)
  if next(extmark_pos) ~= nil then
    local lnum = extmark_pos[1] + 1
    local col = extmark_pos[2] + 1
    local curswant = cursor.curwant

    -- Maintain curswant = vim.v.maxcol if the cursor is still at the end of the line
    if curswant < vim.v.maxcol and col < #vim.fn.getline(lnum) then
      curswant = col
    end

    vim.fn.cursor({ lnum, col, 0, curswant })

    cursor.line = lnum
    cursor.col = col
    cursor.curwant = curswant
  else
    -- extmark gone, restore from lnum
    vim.fn.cursor({ cursor.line, cursor.col, 0, cursor.col })
  end
end

function M.update_cursor(cursor)
  local pos = vim.fn.getcurpos()
  cursor.line = pos[2]
  cursor.col = pos[3]
  cursor.curwant = pos[5]
  cursor.id = M.set_extmark(cursor.line, cursor.col, cursor.id, cursor == M.main_cursor and "" or nil)
end

function M.goto_main_cursor()
  M.goto_cursor(M.main_cursor)
end

function M.update_main_cursor()
  M.update_cursor(M.main_cursor)
end

function M.delete_duplicate_cursors()
  local cur = vim.fn.getcurpos()
  local set = { [hash(cur[2], cur[3], cur[5])] = true }
  local new_cursors = {}
  for _, cursor in ipairs(M.virtual_cursors) do
    local h = hash(cursor.line, cursor.col, cursor.curwant)
    if not set[h] then
      set[h] = true
      table.insert(new_cursors, cursor)
    else
      utils.add_log("delete duplicate cursor (%d, %d)", cursor.line, cursor.col)
      vim.api.nvim_buf_del_extmark(0, M.ns_id, cursor.id)
    end
  end
  M.virtual_cursors = new_cursors
end

function M.toggle_cursor_upward()
  utils.adding_cursor_begin()
  local pos = vim.fn.getcurpos()
  M.toggle_cursor(pos[2], pos[3], pos[5])
  vim.cmd.normal("k")
  M.delete_duplicate_cursors()
  utils.adding_cursor_end()
end

function M.cursor_up()
  utils.adding_cursor_begin()
  vim.cmd.normal("k")
  utils.adding_cursor_end()
end

function M.toggle_cursor_downward()
  utils.adding_cursor_begin()
  local pos = vim.fn.getcurpos()
  M.toggle_cursor(pos[2], pos[3], pos[5])
  vim.cmd.normal("j")
  M.delete_duplicate_cursors()
  utils.adding_cursor_end()
end

function M.cursor_down()
  utils.adding_cursor_begin()
  vim.cmd.normal("j")
  utils.adding_cursor_end()
end

M.visual_star = false
function M.toggle_cursor_next_match()
  local visual_star = false
  utils.adding_cursor_begin()
  if vim.fn.mode() == "n" then
    if not M.visual_star then
      vim.cmd("normal! lb")
    end
  else
    visual_star = true
    vim.api.nvim_feedkeys("\027", "nx", false)
    local start_pos = vim.api.nvim_buf_get_mark(0, "<")
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    if start_pos[1] < cursor_pos[1] or start_pos[2] < cursor_pos[2] then
      vim.cmd("normal! gvo")
    else
      vim.cmd("normal! gv")
    end
  end
  local pos = vim.fn.getcurpos()
  M.toggle_cursor(pos[2], pos[3], pos[5])
  vim.cmd.normal(M.visual_star and "n" or "*")
  M.delete_duplicate_cursors()
  M.visual_star = M.visual_star or visual_star
  vim.cmd.nohlsearch()
  utils.adding_cursor_end()
end

function M.toggle_cursor_all_match()
  utils.adding_cursor_begin()
  if vim.fn.mode() == "n" then
    vim.cmd("normal! lb")
  else
    vim.api.nvim_feedkeys("\027", "nx", false)
    local start_pos = vim.api.nvim_buf_get_mark(0, "<")
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    if start_pos[1] < cursor_pos[1] or start_pos[2] < cursor_pos[2] then
      vim.cmd("normal! gvo")
    else
      vim.cmd("normal! gv")
    end
  end
  local hls = vim.o.hlsearch
  vim.o.hlsearch = false
  local pos = vim.fn.getcurpos()
  local orig_pos = pos
  local next_cmd = "*"
  while true do
    M.toggle_cursor(pos[2], pos[3], pos[5])
    vim.cmd.normal(next_cmd)
    next_cmd = "n"
    pos = vim.fn.getcurpos()
    if pos[2] == orig_pos[2] and pos[3] == orig_pos[3] then
      break
    end
  end
  M.delete_duplicate_cursors()
  vim.o.hlsearch = hls
  vim.cmd.nohlsearch()
  utils.adding_cursor_end()
end

function M.cursor_next_match()
  utils.adding_cursor_begin()
  vim.cmd.normal("*")
  vim.cmd.nohlsearch()
  utils.adding_cursor_end()
end

function M.toggle_cursor_by_flash(pattern)
  utils.adding_cursor_begin()
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
  M.delete_duplicate_cursors()
  -- disable <esc> because flash.nvim will input <esc> when it quit
  if #M.virtual_cursors > 0 then
    vim.keymap.del("n", "<Esc>", { buffer = 0 })
  end
  vim.schedule(function()
    vim.schedule(function()
      utils.adding_cursor_end()
      vim.keymap.set("n", "<Esc>", "<Cmd>lua require('nvim-multi-cursor.state').stop()<CR>", { buffer = 0 })
    end)
  end)
end

function M.add_cursors_in_visual(type)
  local mode = vim.api.nvim_get_mode().mode:sub(1, 1)

  if type == "c" then
    if mode == "v" or mode == "V" then
      vim.api.nvim_feedkeys("c", "n", false)
      return
    else
      vim.api.nvim_feedkeys("d", "nx", false)
      type = "i"
    end
  end

  -- escape to exit visual mode, then get previous visual range
  vim.api.nvim_feedkeys("\027", "nx", false)
  local start_pos = vim.api.nvim_buf_get_mark(0, "<")
  local end_pos = vim.api.nvim_buf_get_mark(0, ">")

  local orig_ve = vim.wo.virtualedit
  vim.wo.virtualedit = "onemore"
  vim.api.nvim_create_autocmd("InsertEnter", {
    once = true,
    callback = function()
      vim.wo.virtualedit = orig_ve
    end,
  })

  if mode == "v" then
    if type == "i" then
      vim.api.nvim_win_set_cursor(0, { start_pos[1], start_pos[2] })
    else
      vim.api.nvim_win_set_cursor(0, { end_pos[1], end_pos[2] })
    end
    vim.api.nvim_input(type)
  elseif mode == "V" then
    local col = type == "i" and start_pos[2] or end_pos[2]
    local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_win_set_cursor(0, { cursor_row, col })
    local start_row = cursor_row == start_pos[1] and start_pos[1] + 1 or start_pos[1]
    local end_row = cursor_row == start_pos[1] and end_pos[1] or end_pos[1] - 1
    for row = start_row, end_row do
      if #vim.fn.getline(row) > 0 then
        M.toggle_cursor(row, col, col)
      end
    end
    vim.api.nvim_input("i")
  else
    local start_vc = vim.fn.virtcol("'<")
    local end_vc = vim.fn.virtcol("'>")
    local start_dw =
      vim.fn.strdisplaywidth(vim.api.nvim_buf_get_text(0, start_pos[1] - 1, 0, start_pos[1] - 1, start_pos[2], {})[1])
    local end_dw =
      vim.fn.strdisplaywidth(vim.api.nvim_buf_get_text(0, end_pos[1] - 1, 0, end_pos[1] - 1, end_pos[2], {})[1])
    local left_vc = math.min(start_dw, end_dw) + 1
    local right_vc = math.max(start_vc, end_vc)
    local vc = type == "i" and left_vc or (right_vc + 1)

    local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
    local start = start_pos[1] == cursor_row and start_pos[1] or end_pos[1]
    local endl = start_pos[1] == cursor_row and end_pos[1] or start_pos[1]
    local dir = start_pos[1] == cursor_row and 1 or -1
    for lnum = start, endl, dir do
      local bc = vim.fn.virtcol2col(0, lnum, vc - 1)
      local text = vim.api.nvim_buf_get_text(0, lnum - 1, 0, lnum - 1, bc, {})[1]
      local dw = vim.fn.strdisplaywidth(text)
      if dw >= vc then
        text = vim.fn.strcharpart(text, 0, vim.fn.strchars(text, 1) - 1)
        bc = #text
        dw = vim.fn.strdisplaywidth(text)
      end
      local padding = vc - dw - 1
      if padding > 0 then
        vim.api.nvim_buf_set_text(0, lnum - 1, bc, lnum - 1, bc, { string.rep(" ", padding) })
      end
      bc = bc + padding
      if lnum == cursor_row then
        vim.api.nvim_win_set_cursor(0, { lnum, bc - 1 })
      else
        M.toggle_cursor(lnum, bc, vc)
      end
    end
    -- Do not input, just use this function to add cursors
    -- vim.api.nvim_input("i")
  end
  M.delete_duplicate_cursors()
  vim.wo.virtualedit = orig_ve
end

return M
