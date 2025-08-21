local M = {}
local common = require("codeview.common")

function M.open_diff(ref1, ref2)
	local cmd, title = common.generate_git_command_and_title(ref1, ref2, "diff")

	local output = common.execute_git_command(cmd)
	if not output then
		return
	end

	local buf = common.get_or_create_buffer(title)

	-- Set buffer options
	common.set_common_buffer_options(buf)
	vim.api.nvim_buf_set_option(buf, "buftype", "")
	vim.api.nvim_buf_set_option(buf, "filetype", "diff")

	-- Update buffer content
	local lines = vim.split(output, "\n")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	vim.api.nvim_buf_set_option(buf, "modified", false)
	vim.api.nvim_buf_set_option(buf, "readonly", true)

	-- Store diff parameters for refresh
	vim.api.nvim_buf_set_var(buf, "codeview_cmd", cmd)
	vim.api.nvim_buf_set_var(buf, "codeview_title", title)
	vim.api.nvim_buf_set_var(buf, "codeview_is_diff", true)

	-- Set keymap (safe to call multiple times)
	vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
		noremap = true,
		silent = true,
		callback = function()
			M.goto_file_from_diff()
		end,
	})
end

function M.goto_file_from_diff()
	local current_line = vim.fn.line(".")
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

	local file_path = nil
	local line_number = nil
	local is_deleted_file = false

	-- Look for file path in diff headers
	for i = current_line, 1, -1 do
		local line = lines[i]
		local file_match = line:match("^%+%+%+ b/(.+)")
		if file_match then
			file_path = file_match
			break
		end
		-- Check for deleted file (--- a/file +++ /dev/null)
		if line:match("^%+%+%+ /dev/null") then
			-- Look for the corresponding --- a/file line
			for j = i, 1, -1 do
				local prev_line = lines[j]
				local deleted_match = prev_line:match("^%-%-%- a/(.+)")
				if deleted_match then
					file_path = deleted_match
					is_deleted_file = true
					break
				end
			end
			break
		end
	end

	if not file_path then
		vim.notify("Could not determine file", vim.log.levels.WARN)
		return
	end

	if is_deleted_file then
		vim.notify("Cannot open deleted file: " .. file_path, vim.log.levels.ERROR)
		return
	end

	-- Calculate the exact line number in the target file
	-- This involves parsing diff hunks and counting lines relative to the cursor position
	--
	-- Process:
	-- 1. Search backwards from cursor to find the relevant hunk header (@@ -old_start,old_count +new_start,new_count @@)
	-- 2. Extract the starting line number in the new file (new_start)
	-- 3. Count lines from the hunk header to the cursor position that exist in the new file:
	--    - Lines starting with '+' (additions) count toward new file
	--    - Lines starting with ' ' (context) count toward new file
	--    - Lines starting with '-' (deletions) do NOT count toward new file
	-- 4. Final line number = new_start + counted_lines - 1

	local hunk_line = nil
	local hunk_position = nil
	for i = current_line, 1, -1 do
		local line = lines[i]
		local new_line_match = line:match("^@@ %-%d+,%d+ %+(%d+),%d+ @@")
		if new_line_match then
			hunk_line = tonumber(new_line_match)
			hunk_position = i
			break
		end
	end

	if hunk_line and hunk_position then
		local new_file_line_count = 0
		for i = hunk_position + 1, current_line do
			local line = lines[i]
			if line:match("^%+") or line:match("^ ") then
				new_file_line_count = new_file_line_count + 1
			end
		end
		line_number = hunk_line + new_file_line_count - 1
	end

	local diff_buf = vim.api.nvim_get_current_buf()

	vim.cmd("normal! m'")
	vim.cmd("edit " .. file_path)

	if line_number and line_number > 0 then
		vim.fn.cursor(line_number, 1)
	end

	vim.api.nvim_buf_set_option(diff_buf, "modified", false)
end

function M.refresh_diff_buffer(buf)
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

	-- Temporarily disable readonly to update content
	vim.api.nvim_buf_set_option(buf, "readonly", false)

	local lines = vim.split(output, "\n")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- Restore settings
	vim.api.nvim_buf_set_option(buf, "modified", false)
	vim.api.nvim_buf_set_option(buf, "readonly", true)

	-- Restore cursor position
	vim.fn.setpos(".", cursor_pos)

	return true
end

return M
