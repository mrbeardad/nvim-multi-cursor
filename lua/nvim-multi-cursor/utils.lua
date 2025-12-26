local config = require("nvim-multi-cursor.config")
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
    M.add_log("start record but already exist")
    vim.cmd("normal! q")
  end

  vim.cmd("normal! qm")
end

function M.stop_record()
  if vim.fn.reg_recording() == "" then
    M.add_log("stop record but not exist")
    return ""
  end

  vim.cmd("normal! q")
  return vim.fn.getreg("m")
end

M.orig_ve = ""

function M.cache_ve()
  M.orig_ve = vim.wo.virtualedit
  vim.wo.virtualedit = "onemore"
end

function M.resotre_ve()
  vim.wo.virtualedit = M.orig_ve
end

function M.clear_vmc_augroup()
  pcall(vim.api.nvim_del_augroup_by_name, "vscode-multiple-cursors")
end

function M.restore_vmc_augroup()
  if config.vmc then
    local group = vim.api.nvim_create_augroup("vscode-multiple-cursors", { clear = true })
    vim.api.nvim_create_autocmd({ "VimEnter", "ColorScheme" }, { group = group, callback = config.vmc.set_highlight })
    vim.api.nvim_create_autocmd({ "WinEnter" }, {
      group = group,
      callback = require("vscode-multi-cursor.state").check_buffer,
    })
    vim.api.nvim_create_autocmd({ "InsertEnter", "TextChanged" }, {
      group = group,
      callback = config.vmc.cancel,
    })
  end
end

return M
