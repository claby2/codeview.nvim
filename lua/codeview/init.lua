local M = {}

M.config = {}

-- Helper function to create codeview commands with shared logic
local function create_codeview_command(name, module_name, func_name)
	vim.api.nvim_create_user_command(name, function(args)
		local module = require(module_name)
		local refs = vim.split(args.args, "%s+")

		refs = vim.tbl_filter(function(s)
			return s ~= ""
		end, refs)

		if #refs == 0 then
			module[func_name](nil, nil)
		elseif #refs == 1 then
			module[func_name](refs[1], nil)
		elseif #refs == 2 then
			module[func_name](refs[1], refs[2])
		else
			vim.notify(string.format("Usage: :%s [ref1] [ref2]", name), vim.log.levels.ERROR)
		end
	end, {
		nargs = "*",
		complete = function()
			return { "main", "HEAD", "origin/main", "--staged" }
		end,
	})
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	-- Create commands using the helper function
	create_codeview_command("CodeViewDiff", "codeview.diff", "open_diff")
	create_codeview_command("CodeViewTable", "codeview.table", "open_table")

	-- Auto-refresh diff and table buffers when returning to them
	vim.api.nvim_create_autocmd("BufEnter", {
		callback = function()
			local buf = vim.api.nvim_get_current_buf()
			local ok_diff, is_diff = pcall(vim.api.nvim_buf_get_var, buf, "codeview_is_diff")
			local ok_table, is_table = pcall(vim.api.nvim_buf_get_var, buf, "codeview_is_table")

			if ok_diff and is_diff then
				require("codeview.diff").refresh_diff_buffer(buf)
			elseif ok_table and is_table then
				require("codeview.table").refresh_table_buffer(buf)
			end
		end,
	})
end

return M
