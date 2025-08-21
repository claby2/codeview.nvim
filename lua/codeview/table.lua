local M = {}

function M.open_table(ref1, ref2)
	local cmd, title
	local diff_args = ""

	if ref2 == nil then
		if ref1 == "--staged" then
			diff_args = "--staged"
			title = "table: staged changes"
		elseif ref1 == nil then
			diff_args = ""
			title = "table: unstaged changes"
		else
			diff_args = ref1
			title = string.format("table: working tree vs %s", ref1)
		end
	else
		diff_args = string.format("%s..%s", ref1, ref2)
		title = string.format("table: %s..%s", ref1, ref2)
	end

	cmd = string.format("git diff --numstat %s", diff_args):gsub("%s+$", "")

	local output = vim.fn.system(cmd)

	if vim.v.shell_error ~= 0 then
		vim.notify("Git diff failed: " .. output, vim.log.levels.ERROR)
		return
	end

	if output == "" or output:match("^%s*$") then
		vim.notify("No changes found", vim.log.levels.INFO)
		return
	end

	-- Parse numstat output
	local files = {}
	local total_files = 0
	for line in output:gmatch("[^\n]+") do
		local additions, deletions, filepath = line:match("^(%S+)%s+(%S+)%s+(.+)$")
		if additions and deletions and filepath then
			-- Handle binary files (shown as - in git diff --numstat)
			local add_count = (additions == "-") and 0 or tonumber(additions)
			local del_count = (deletions == "-") and 0 or tonumber(deletions)
			table.insert(files, {
				filepath = filepath,
				additions = add_count,
				deletions = del_count,
				total = add_count + del_count,
			})
			total_files = total_files + 1
		end
	end

	if #files == 0 then
		vim.notify("No changes found", vim.log.levels.INFO)
		return
	end

	-- Sort files by total changes (descending)
	table.sort(files, function(a, b)
		return a.total > b.total
	end)

	-- Check for existing buffer with the same name
	local existing_buf = nil
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) then
			local buf_name = vim.api.nvim_buf_get_name(buf)
			if buf_name:match(vim.pesc(title) .. "$") then
				existing_buf = buf
				break
			end
		end
	end

	local buf
	if existing_buf then
		-- Reuse existing buffer
		buf = existing_buf
		vim.api.nvim_set_current_buf(buf)
	else
		-- Create new buffer
		vim.cmd("enew")
		buf = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_set_name(buf, title)
	end

	-- Set buffer options
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "hide")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	vim.api.nvim_buf_set_option(buf, "filetype", "codeview-table")
	vim.api.nvim_buf_set_option(buf, "readonly", false)

	-- Build table content
	local lines = {}
	table.insert(lines, string.format("Files changed: %d", total_files))

	-- Add comparison info
	local comparison_info
	if ref2 == nil then
		if ref1 == "--staged" then
			comparison_info = "Comparing: index vs HEAD"
		elseif ref1 == nil then
			comparison_info = "Comparing: working tree vs index"
		else
			comparison_info = string.format("Comparing: working tree vs %s", ref1)
		end
	else
		comparison_info = string.format("Comparing: %s vs %s", ref1, ref2)
	end
	table.insert(lines, comparison_info)
	table.insert(lines, "")

	-- Find maximum width for alignment
	local max_add_width = 2
	local max_del_width = 2
	for _, file in ipairs(files) do
		local add_str = string.format("+%d", file.additions)
		local del_str = string.format("-%d", file.deletions)
		max_add_width = math.max(max_add_width, #add_str)
		max_del_width = math.max(max_del_width, #del_str)
	end

	-- Add file entries
	for _, file in ipairs(files) do
		local add_str = string.format("+%d", file.additions)
		local del_str = string.format("-%d", file.deletions)
		local formatted_line = string.format(
			" %s  %s  %s",
			string.format("%" .. max_add_width .. "s", add_str),
			string.format("%" .. max_del_width .. "s", del_str),
			file.filepath
		)
		table.insert(lines, formatted_line)
	end

	-- Update buffer content
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	vim.api.nvim_buf_set_option(buf, "modified", false)
	vim.api.nvim_buf_set_option(buf, "readonly", true)

	-- Store table parameters for refresh and navigation
	vim.api.nvim_buf_set_var(buf, "codeview_cmd", cmd)
	vim.api.nvim_buf_set_var(buf, "codeview_title", title)
	vim.api.nvim_buf_set_var(buf, "codeview_is_table", true)
	vim.api.nvim_buf_set_var(buf, "codeview_ref1", ref1)
	vim.api.nvim_buf_set_var(buf, "codeview_ref2", ref2)

	-- Set keymap for navigation
	vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
		noremap = true,
		silent = true,
		callback = function()
			M.goto_diff_from_table()
		end,
	})
end

function M.goto_diff_from_table()
	local current_line = vim.fn.line(".")
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

	-- Skip header lines (first 3 lines)
	if current_line <= 3 then
		return
	end

	local line = lines[current_line]
	if not line then
		return
	end

	-- Extract filepath from the formatted line
	local filepath = line:match("^%s*%+%d+%s+%-%d+%s+(.+)$")
	if not filepath then
		vim.notify("Could not determine file from current line", vim.log.levels.WARN)
		return
	end

	-- Get the table buffer's refs for creating diff
	local table_buf = vim.api.nvim_get_current_buf()
	local ok1, ref1 = pcall(vim.api.nvim_buf_get_var, table_buf, "codeview_ref1")
	local ok2, ref2 = pcall(vim.api.nvim_buf_get_var, table_buf, "codeview_ref2")

	if not ok1 then
		ref1 = nil
	end
	if not ok2 then
		ref2 = nil
	end

	-- Store current position for return navigation
	vim.cmd("normal! m'")

	-- Open diff view with the same refs as the table
	local diff = require("codeview.diff")
	diff.open_diff(ref1, ref2)

	-- Navigate to the specific file in the diff
	local diff_buf = vim.api.nvim_get_current_buf()
	local diff_lines = vim.api.nvim_buf_get_lines(diff_buf, 0, -1, false)

	-- Find the line with the file header
	for i, diff_line in ipairs(diff_lines) do
		if
			diff_line:match("^%+%+%+ b/" .. vim.pesc(filepath) .. "$")
			or diff_line:match("^%+%+%+ b/" .. vim.pesc(filepath) .. "%s")
		then
			vim.fn.cursor(i, 1)
			break
		end
	end
end

function M.refresh_table_buffer(buf)
	buf = buf or vim.api.nvim_get_current_buf()

	local ok, cmd = pcall(vim.api.nvim_buf_get_var, buf, "codeview_cmd")
	if not ok then
		return false
	end

	local output = vim.fn.system(cmd)
	if vim.v.shell_error ~= 0 then
		vim.notify("Git diff refresh failed: " .. output, vim.log.levels.ERROR)
		return false
	end

	-- Save cursor position
	local cursor_pos = vim.fn.getcurpos()

	-- Get refs for re-calling open_table
	local ok1, ref1 = pcall(vim.api.nvim_buf_get_var, buf, "codeview_ref1")
	local ok2, ref2 = pcall(vim.api.nvim_buf_get_var, buf, "codeview_ref2")

	if not ok1 then
		ref1 = nil
	end
	if not ok2 then
		ref2 = nil
	end

	-- Re-generate the table content
	M.open_table(ref1, ref2)

	-- Restore cursor position
	vim.fn.setpos(".", cursor_pos)

	return true
end

return M

