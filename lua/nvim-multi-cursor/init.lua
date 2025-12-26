local config = require("nvim-multi-cursor.config")
local state = require("nvim-multi-cursor.state")

local M = {}

function M.setup(opts)
  config.config = vim.tbl_extend("force", config.config, opts)

  if vim.api.nvim_get_hl(0, { name = "FlashLabelUnselected" }).bg == nil then
    vim.api.nvim_set_hl(0, "FlashLabelUnselected", { fg = "#b9bbc4", bg = "#bd0c69", italic = true, bold = true })
  end

  local ok, vmc = pcall(require, "vscode-multi-cursor")
  if ok then
    config.vmc = vmc
  end

  state.setup()
end

return M
