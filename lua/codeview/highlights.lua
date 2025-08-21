local M = {}

function M.setup()
	vim.api.nvim_set_hl(0, "ReviewComment", {
		fg = "#ff9500",
		bg = "#2d1810",
		bold = true,
	})

	vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
		pattern = "*",
		callback = function()
			vim.fn.matchadd("ReviewComment", "REVIEW:.*$")
		end,
	})
end

return M

