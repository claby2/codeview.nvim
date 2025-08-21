local M = {}
local common = require("codeview.common")

function M.open_diff(ref1, ref2)
	local cmd, title = common.generate_git_command_and_title(ref1, ref2, "diff")

	local output = common.execute_git_command(cmd)
	if not output then
		return
	end

	-- Include untracked files if appropriate
	if common.should_include_untracked(ref1, ref2) then
		local untracked_files = common.get_untracked_files()
		if #untracked_files > 0 then
			local untracked_diff = common.generate_untracked_diff(untracked_files)
			if untracked_diff ~= "" then
				if output == "" then
					output = untracked_diff
				else
					output = output .. untracked_diff
				end
			end
		end
	end

	-- Check if we still have no content after including untracked files
	if output == "" then
		vim.notify("No changes found", vim.log.levels.INFO)
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
	vim.api.nvim_buf_set_var(buf, "codeview_ref1", ref1)
	vim.api.nvim_buf_set_var(buf, "codeview_ref2", ref2)

	-- Set keymap (safe to call multiple times)
	vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
		noremap = true,
		silent = true,
		callback = function()
			M.goto_file_from_diff()
		end,
	})
end

local function identify_file_path(lines, current_line)
	local file_path = nil
	for i = current_line, 1, -1 do
		local line = lines[i]
		if line:match("^%+%+%+ /dev/null") then
			error("Deleted file")
		end
		file_path = line:match("^%+%+%+ b/(.+)")
		if file_path then
			break
		end
	end
	return file_path
end

local function identify_line_number(lines, current_line)
	local line_number = nil
	local hunk_line = nil
	local hunk_position = nil
	local hunk_size = nil
	for i = current_line, 1, -1 do
		local line = lines[i]
		hunk_line, hunk_size = line:match("^@@ %-%d+,%d+ %+(%d+),(%d+) @@")
		if hunk_line and hunk_size then
			hunk_line = tonumber(hunk_line)
			hunk_size = tonumber(hunk_size)
			hunk_position = i
			break
		end
	end

	if hunk_line and hunk_position and hunk_size then
		local negatives = 0
		for i = hunk_position + 1, current_line do
			local line = lines[i]
			if line:match("^%-") then
				negatives = negatives + 1
			end
		end
		local offset = (current_line - hunk_position) - negatives
		if offset > hunk_size then
			error("Not in hunk")
		end
		line_number = hunk_line + offset - 1
	end
	if not line_number then
		error("Could not determine line number")
	end
	return line_number
end

function M.goto_file_from_diff()
	local current_line = vim.fn.line(".")
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

	local ok1, file_path = pcall(identify_file_path, lines, current_line)
	if not ok1 then
		vim.notify("Could not determine file (" .. file_path .. ")", vim.log.levels.WARN)
		return
	end

	local ok2, line_number = pcall(identify_line_number, lines, current_line)
	if not ok2 then
		vim.notify("Could not determine line number (" .. line_number .. ")", vim.log.levels.WARN)
		return
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

	-- Re-generate the diff content (this will include untracked files automatically)
	M.open_diff(ref1, ref2)

	-- Restore cursor position
	vim.fn.setpos(".", cursor_pos)

	return true
end

return M
