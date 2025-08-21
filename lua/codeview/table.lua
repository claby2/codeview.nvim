local M = {}
local common = require("codeview.common")

function M.open_table(ref1, ref2)
	local cmd, title = common.generate_git_command_and_title(ref1, ref2, "table")

	local output = common.execute_git_command(cmd)
	if not output then
		return
	end

	-- Parse numstat output
	local files = {}
	local total_files = 0
	if output ~= "" then
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
	end

	-- Include untracked files if appropriate
	if common.should_include_untracked(ref1, ref2) then
		local untracked_files = common.get_untracked_files()
		for _, filepath in ipairs(untracked_files) do
			-- Count lines in untracked file
			local file_content = vim.fn.readfile(filepath)
			local line_count = (vim.v.shell_error == 0) and #file_content or 0

			table.insert(files, {
				filepath = filepath,
				additions = line_count,
				deletions = 0,
				total = line_count,
			})
			total_files = total_files + 1
		end
	end

	if #files == 0 then
		vim.notify("No changes found", vim.log.levels.INFO)
		return
	end

	-- Preserve git's original file ordering (no sorting)

	local buf = common.get_or_create_buffer(title)

	-- Set buffer options
	common.set_common_buffer_options(buf)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "filetype", "codeview-table")

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

	-- Track the number of header lines for navigation
	local header_line_count = #lines

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
	vim.api.nvim_buf_set_var(buf, "codeview_header_lines", header_line_count)

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

	-- Get the number of header lines from buffer variable
	local ok, header_line_count = pcall(vim.api.nvim_buf_get_var, 0, "codeview_header_lines")
	if not ok then
		header_line_count = 3 -- fallback to default
	end

	-- Skip header lines
	if current_line <= header_line_count then
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

	-- Re-generate the table content (this will include untracked files automatically)
	M.open_table(ref1, ref2)

	-- Restore cursor position
	vim.fn.setpos(".", cursor_pos)

	return true
end

return M
