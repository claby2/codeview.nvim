local M = {}

-- Generate git command and title based on refs
function M.generate_git_command_and_title(ref1, ref2, view_type)
	local cmd, title
	local diff_cmd_base = view_type == "table" and "git diff --numstat" or "git diff"
	local title_prefix = view_type == "table" and "table:" or "diff:"

	if ref2 == nil then
		if ref1 == "--staged" then
			cmd = diff_cmd_base .. " --staged"
			title = title_prefix .. " staged changes"
		elseif ref1 == nil then
			cmd = diff_cmd_base
			title = title_prefix .. " unstaged changes"
		else
			cmd = string.format("%s %s", diff_cmd_base, ref1)
			title = string.format("%s working tree vs %s", title_prefix, ref1)
		end
	else
		cmd = string.format("%s %s..%s", diff_cmd_base, ref1, ref2)
		title = string.format("%s %s..%s", title_prefix, ref1, ref2)
	end

	-- Clean up trailing spaces for table commands
	if view_type == "table" then
		cmd = cmd:gsub("%s+$", "")
	end

	return cmd, title
end

-- Validate git is available
function M.validate_git()
	local result = vim.fn.executable("git")
	if result == 0 then
		vim.notify("Git command not found. Please install git.", vim.log.levels.ERROR)
		return false
	end
	return true
end

-- Execute git command with error handling
function M.execute_git_command(cmd)
	local output = vim.fn.system(cmd)

	if vim.v.shell_error ~= 0 then
		vim.notify("Git command failed: " .. output, vim.log.levels.ERROR)
		return nil
	end

	if output == "" or (output:match("^%s*$")) then
		return ""
	end

	return output
end

-- Find existing buffer by title, or create new one
function M.get_or_create_buffer(title)
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

	return buf
end

-- Set common buffer options
function M.set_common_buffer_options(buf)
	vim.api.nvim_buf_set_option(buf, "bufhidden", "hide")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	vim.api.nvim_buf_set_option(buf, "readonly", false)
end

-- Check if untracked files should be included based on refs
function M.should_include_untracked(ref1, ref2)
	-- Include untracked files only when comparing against working tree
	-- Don't include for staged-only changes or commit-to-commit comparisons
	if ref1 == "--staged" then
		return false -- staged changes don't include untracked
	end
	if ref2 ~= nil then
		return false -- commit-to-commit comparisons don't include untracked
	end
	return true -- working tree vs index/HEAD includes untracked
end

-- Get list of untracked files
function M.get_untracked_files()
	local cmd = "git ls-files --others --exclude-standard"
	local output = vim.fn.system(cmd)

	if vim.v.shell_error ~= 0 then
		return {}
	end

	local files = {}
	for line in output:gmatch("[^\n]+") do
		if line ~= "" then
			table.insert(files, line)
		end
	end

	return files
end

-- Generate diff output for untracked files
function M.generate_untracked_diff(files)
	if #files == 0 then
		return ""
	end

	local diff_output = {}

	for _, file in ipairs(files) do
		-- Add diff header for new file
		table.insert(diff_output, "diff --git a/" .. file .. " b/" .. file)
		table.insert(diff_output, "new file mode 100644")
		table.insert(diff_output, "index 0000000..0000000")
		table.insert(diff_output, "--- /dev/null")
		table.insert(diff_output, "+++ b/" .. file)

		-- Read file content and add as additions
		local file_content = vim.fn.readfile(file)
		if vim.v.shell_error == 0 and #file_content > 0 then
			-- Calculate line count for hunk header
			local line_count = #file_content
			table.insert(diff_output, "@@ -0,0 +1," .. line_count .. " @@")

			-- Add each line as an addition
			for _, content_line in ipairs(file_content) do
				table.insert(diff_output, "+" .. content_line)
			end
		else
			-- Empty file or read error
			table.insert(diff_output, "@@ -0,0 +1 @@")
		end
	end

	return table.concat(diff_output, "\n")
end

return M
