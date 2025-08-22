local M = {}
local common = require("codeview.common")

function M.open_diff(ref1, ref2, filepath)
	local cmd, title = common.generate_git_command_and_title(ref1, ref2, "diff", filepath)

	local output = common.execute_git_command(cmd)
	if not output then
		return
	end

	if filepath and output == "" then
		-- Got no output, but requested filepath...
		output = common.generate_untracked_diff({ filepath })
	elseif not filepath and common.should_include_untracked(ref1, ref2) then
		-- Include untracked files if appropriate
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
	vim.bo[buf].buftype = ""
	vim.bo[buf].filetype = "diff"

	-- Set up buffer-local refresh autocmd
	common.setup_buffer_refresh_autocmd(buf, "diff")

	-- Update buffer content
	local lines = vim.split(output, "\n")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	vim.bo[buf].modified = false
	vim.bo[buf].readonly = true

	-- Store diff parameters for refresh
	vim.b[buf].codeview_cmd = cmd
	vim.b[buf].codeview_title = title
	vim.b[buf].codeview_is_diff = true
	vim.b[buf].codeview_ref1 = ref1
	vim.b[buf].codeview_ref2 = ref2
	vim.b[buf].codeview_isolated_filepath = filepath

	-- Set keymap (safe to call multiple times)
	vim.keymap.set("n", "<CR>", function()
		M.goto_file_from_diff()
	end, {
		buffer = buf,
		silent = true,
		desc = "Jump to file from diff",
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
		vim.notify(
			"Could not determine file from current line: " .. (file_path or "unknown error"),
			vim.log.levels.WARN
		)
		return
	end

	local ok2, line_number = pcall(identify_line_number, lines, current_line)
	if not ok2 then
		vim.notify("Could not determine line number: " .. (line_number or "not in a hunk"), vim.log.levels.WARN)
		return
	end

	local diff_buf = vim.api.nvim_get_current_buf()

	vim.cmd("normal! m'")

	local ok, err = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(file_path))
	if not ok then
		vim.notify("Failed to open file: " .. file_path .. " (" .. err .. ")", vim.log.levels.ERROR)
		return
	end

	if line_number and line_number > 0 then
		vim.fn.cursor(line_number, 1)
		vim.cmd("normal! zz")
	end

	vim.bo[diff_buf].modified = false
end

function M.refresh_diff_buffer(buf)
	buf = buf or vim.api.nvim_get_current_buf()

	-- Save cursor position
	local cursor_pos = vim.fn.getcurpos()

	-- Get refs and isolated state for re-calling open_diff
	local ref1 = vim.b[buf].codeview_ref1
	local ref2 = vim.b[buf].codeview_ref2
	local isolated_filepath = vim.b[buf].codeview_isolated_filepath

	-- Re-generate the diff content with proper isolated state
	M.open_diff(ref1, ref2, isolated_filepath)

	-- Restore cursor position
	vim.fn.setpos(".", cursor_pos)

	return true
end

return M
