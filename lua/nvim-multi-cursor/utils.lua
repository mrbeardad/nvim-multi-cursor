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

M.orig_ve = ""

function M.cache_ve()
  M.orig_ve = vim.wo.virtualedit
  vim.wo.virtualedit = "onemore"
end

function M.resotre_ve()
  vim.wo.virtualedit = M.orig_ve
end

return M
