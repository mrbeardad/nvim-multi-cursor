local M = {}

M.last_log = {}
M.log = {}

function M.add_log(fmt, ...)
  M.log[#M.log + 1] = string.format(fmt, ...)
end

function M.break_log()
  if #M.log == 0 then
    return
  end
  M.last_log = M.log
  M.log = {}
end

M.reg = "m"
M.orig_reg_content = ""

function M.cache_register()
  M.orig_reg_content = vim.fn.getreg("m")
end

function M.resotre_register()
  vim.fn.setreg("m", M.orig_reg_content)
end

function M.start_record()
  if vim.fn.reg_recording() ~= "" then
    vim.cmd("normal! q")
  end

  vim.cmd("normal! qm")
end

function M.stop_record()
  if vim.fn.reg_recording() == "" then
    return ""
  end

  vim.cmd("normal! q")
  return vim.fn.getreg("m")
end

function M.adding_cursor_begin()
  M.stop_record()
  require("nvim-multi-cursor.state").adding_cursor = true
end

function M.adding_cursor_end()
  vim.schedule(function()
    M.start_record()
    require("nvim-multi-cursor.state").adding_cursor = false
  end)
end

M.cursor_regs = {}
function M.on_yank_post()
  local regname = vim.v.event.regname
  if regname == "" then
    if vim.o.clipboard == "unnamed" then
      regname = "*"
    elseif vim.o.clipboard == "unnamedplus" then
      regname = "+"
    else
      regname = '"'
    end
  end
  local regnames = { regname }
  if vim.v.event.operator == "y" then
    regnames[#regnames + 1] = "0"
  elseif
    (vim.v.event.operator == "c" or vim.v.event.operator == "d")
    and (#vim.v.event.regcontents == 1 and vim.v.event.regtype ~= "V")
  then
    regnames[#regnames + 1] = "-"
  end

  for _, regname in ipairs(regnames) do
    M.cursor_regs[regname] = M.cursor_regs[regname] or {}
    local reg = M.cursor_regs[regname]
    reg[require("nvim-multi-cursor.state").current_cursor_id] =
      { regcontents = vim.v.event.regcontents, regtype = vim.v.event.regtype }
  end
end

function M.on_put_pre(regname)
  regname = regname or vim.v.register
  local reg = M.cursor_regs[regname]
  local id = require("nvim-multi-cursor.state").current_cursor_id
  if reg and reg[id] then
    vim.fn.setreg(regname, reg[id].regcontents, reg[id].regtype)
  end
end

function M.clear_reg_queues()
  M.cursor_regs = {}
end

M.orig_ve = ""

function M.cache_ve()
  M.orig_ve = vim.wo.virtualedit
  vim.wo.virtualedit = "onemore"
end

function M.resotre_ve()
  vim.wo.virtualedit = M.orig_ve
end

function M.is_keyword_char_left_of_cursor()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  if col == 0 then
    return false
  end

  local line = vim.api.nvim_get_current_line()
  local char = line:sub(col, col)
  return vim.fn.match(char, "\\k") ~= -1
end

return M
