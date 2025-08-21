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

	vim.cmd("new")
	local buf = vim.api.nvim_get_current_buf()

	vim.api.nvim_buf_set_option(buf, "buftype", "")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "hide")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	vim.api.nvim_buf_set_option(buf, "filetype", "diff")
	vim.api.nvim_buf_set_option(buf, "modified", false)

	local lines = vim.split(output, "\n")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	vim.api.nvim_buf_set_name(buf, title)

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

	for i = current_line, 1, -1 do
		local line = lines[i]
		local file_match = line:match("^%+%+%+ b/(.+)")
		if file_match then
			file_path = file_match
			break
		end
	end

	if not file_path then
		vim.notify("Could not determine file", vim.log.levels.WARN)
		return
	end

	local hunk_line = nil
	for i = current_line, 1, -1 do
		local line = lines[i]
		local new_line_match = line:match("^@@ %-%d+,%d+ %+(%d+),%d+ @@")
		if new_line_match then
			hunk_line = tonumber(new_line_match)
			break
		end
	end

	if hunk_line then
		local offset = 0
		for i = current_line, 1, -1 do
			local line = lines[i]
			if line:match("^@@ ") then
				break
			elseif line:match("^%+") then
				offset = offset + 1
			elseif line:match("^%-") then
				offset = offset - 1
			end
		end
		line_number = hunk_line + offset - 1
	end

	vim.cmd("normal! m'")
	vim.cmd("edit " .. file_path)

	if line_number and line_number > 0 then
		vim.fn.cursor(line_number, 1)
	end
end

return M

