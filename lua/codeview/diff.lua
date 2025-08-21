local M = {}

function M.open_diff(ref1, ref2)
	local cmd, title

	if ref2 == nil then
		if ref1 == "--staged" then
			cmd = "git diff --staged"
			title = "diff: staged changes"
		elseif ref1 == nil then
			cmd = "git diff"
			title = "diff: unstaged changes"
		else
			cmd = string.format("git diff %s", ref1)
			title = string.format("diff: working tree vs %s", ref1)
		end
	else
		cmd = string.format("git diff %s..%s", ref1, ref2)
		title = string.format("diff: %s..%s", ref1, ref2)
	end

	local output = vim.fn.system(cmd)

	if vim.v.shell_error ~= 0 then
		vim.notify("Git diff failed: " .. output, vim.log.levels.ERROR)
		return
	end

	if output == "" then
		vim.notify("No changes found", vim.log.levels.INFO)
		return
	end

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
	vim.api.nvim_buf_set_option(buf, "buftype", "")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "hide")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	vim.api.nvim_buf_set_option(buf, "filetype", "diff")
	vim.api.nvim_buf_set_option(buf, "readonly", false)

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
