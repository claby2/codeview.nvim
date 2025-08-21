local M = {}

M.config = {}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	vim.api.nvim_create_user_command("CodeViewDiff", function(args)
		local diff = require("codeview.diff")
		local refs = vim.split(args.args, "%s+")

		if #refs == 0 then
			diff.open_diff(nil, nil)
		elseif #refs == 1 then
			diff.open_diff(refs[1], nil)
		elseif #refs == 2 then
			diff.open_diff(refs[1], refs[2])
		else
			vim.notify("Usage: :CodeViewDiff [ref1] [ref2]", vim.log.levels.ERROR)
		end
	end, {
		nargs = "*",
		complete = function()
			return { "main", "HEAD", "origin/main", "--staged" }
		end,
	})

	vim.api.nvim_create_user_command("CodeViewTable", function(args)
		local table = require("codeview.table")
		local refs = vim.split(args.args, "%s+")
		refs = vim.tbl_filter(function(s)
			return s ~= ""
		end, refs)

		if #refs == 0 then
			table.open_table(nil, nil)
		elseif #refs == 1 then
			table.open_table(refs[1], nil)
		elseif #refs == 2 then
			table.open_table(refs[1], refs[2])
		else
			vim.notify("Usage: :CodeViewTable [ref1] [ref2]", vim.log.levels.ERROR)
		end
	end, {
		nargs = "*",
		complete = function()
			return { "main", "HEAD", "origin/main", "--staged" }
		end,
	})

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
