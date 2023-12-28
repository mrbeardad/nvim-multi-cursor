local M = {}

M.config = {
	hl_group = "IncSearch",
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

M.virtual_cursors = {} ---@type List<Cursor>

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

function M.start_record()
	if vim.fn.reg_recording() ~= "" then
		vim.notify("Another recording detected", vim.log.levels.WARN)
		vim.cmd("normal! q")
	end

	vim.cmd("normal! qm")
end

function M.stop_record()
	if vim.fn.reg_recording() == "" then
		vim.notify("Recording not detected", vim.log.levels.ERROR)
		M.stop()
		return
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

function M.normal_change(ev)
	local input = M.stop_record()
	if input == "" then
		M.start_record()
		return
	end
	local orig_pos = vim.fn.getcurpos()
	for _, cursor in ipairs(M.virtual_cursors) do
		vim.fn.cursor({ cursor.line, cursor.col, 0, cursor.curwant })
		vim.cmd("normal! Q")
		M.update_cursor(cursor)
	end
	vim.fn.cursor({ orig_pos[2], orig_pos[3], orig_pos[4], orig_pos[5] })
	M.start_record()
end

-- TODO: collision check
-- TODO: insert mode
-- TODO: visual mode
M.augroup = 0
function M.start()
	if M.augroup ~= 0 then
		return
	end
	M.augroup = vim.api.nvim_create_augroup("MultipleCursors", { clear = true })
	vim.api.nvim_create_autocmd({ "TextChanged", "CursorMoved" }, {
		group = M.augroup,
		buffer = 0,
		callback = M.normal_change,
	})
	vim.api.nvim_create_autocmd({ "BufLeave" }, {
		group = M.augroup,
		buffer = 0,
		callback = M.stop,
	})

	vim.keymap.set("n", "q", M.stop, { buffer = 0 })
	vim.keymap.set("n", "<Esc>", M.stop, { buffer = 0 })

	M.cache_register()
	M.start_record()
end

function M.stop()
	if vim.fn.reg_recording() ~= "" then
		vim.cmd("normal! q")
	end
	M.resotre_register()
	M.clear_cursors()
	vim.api.nvim_del_augroup_by_id(M.augroup)
	M.augroup = 0
	vim.keymap.del("n", "<Esc>", { buffer = 0 })
	vim.keymap.del("n", "q", { buffer = 0 })
	vim.notify("Exit Multiple Cursors Mode")
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
	vim.keymap.set("n", "<M-LeftMouse>", M.toggle_cursor_at_mouse, {})
	vim.keymap.set("n", "mm", M.toggle_cursor_at_mouse, {})
	vim.keymap.set("n", "mc", M.start, {})
end

return M
