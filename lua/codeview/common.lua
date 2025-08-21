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

-- Execute git command with error handling
function M.execute_git_command(cmd)
	local output = vim.fn.system(cmd)

	if vim.v.shell_error ~= 0 then
		vim.notify("Git diff failed: " .. output, vim.log.levels.ERROR)
		return nil
	end

	if output == "" or (output:match("^%s*$")) then
		vim.notify("No changes found", vim.log.levels.INFO)
		return nil
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

return M
