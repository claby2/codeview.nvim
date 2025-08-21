local M = {}

M.config = {
	highlight_group = "Comment",
	review_pattern = "REVIEW:",
}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	require("codeview.highlights").setup()

	vim.api.nvim_create_user_command("ReviewDiff", function(args)
		local diff = require("codeview.diff")
		local refs = vim.split(args.args, "%s+")

		if #refs == 0 then
			diff.open_diff(nil, nil)
		elseif #refs == 1 then
			diff.open_diff(refs[1], nil)
		elseif #refs == 2 then
			diff.open_diff(refs[1], refs[2])
		else
			vim.notify("Usage: :ReviewDiff [ref1] [ref2]", vim.log.levels.ERROR)
		end
	end, {
		nargs = "*",
		complete = function()
			return { "main", "HEAD", "origin/main", "--staged" }
		end,
	})

	vim.api.nvim_create_user_command("ReviewList", function()
		require("codeview.comments").list_comments()
	end, {})

	local comments = require("codeview.comments")
	vim.keymap.set("n", "]r", comments.next_comment, { desc = "Next review comment" })
	vim.keymap.set("n", "[r", comments.prev_comment, { desc = "Previous review comment" })
end

return M

