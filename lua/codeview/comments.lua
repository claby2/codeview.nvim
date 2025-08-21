local M = {}

function M.find_review_comments()
	local comments = {}
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

	for i, line in ipairs(lines) do
		if line:match("REVIEW:") then
			table.insert(comments, {
				lnum = i,
				text = line:gsub("^%s*", ""),
				filename = vim.fn.expand("%:p"),
			})
		end
	end

	return comments
end

function M.next_comment()
	local current_line = vim.fn.line(".")
	local comments = M.find_review_comments()

	for _, comment in ipairs(comments) do
		if comment.lnum > current_line then
			vim.fn.cursor(comment.lnum, 1)
			return
		end
	end

	if #comments > 0 then
		vim.fn.cursor(comments[1].lnum, 1)
	else
		vim.notify("No review comments found", vim.log.levels.INFO)
	end
end

function M.prev_comment()
	local current_line = vim.fn.line(".")
	local comments = M.find_review_comments()

	for i = #comments, 1, -1 do
		local comment = comments[i]
		if comment.lnum < current_line then
			vim.fn.cursor(comment.lnum, 1)
			return
		end
	end

	if #comments > 0 then
		vim.fn.cursor(comments[#comments].lnum, 1)
	else
		vim.notify("No review comments found", vim.log.levels.INFO)
	end
end

function M.list_comments()
	local comments = M.find_review_comments()

	if #comments == 0 then
		vim.notify("No review comments found", vim.log.levels.INFO)
		return
	end

	local qf_list = {}
	for _, comment in ipairs(comments) do
		table.insert(qf_list, {
			filename = comment.filename,
			lnum = comment.lnum,
			text = comment.text,
		})
	end

	vim.fn.setqflist(qf_list)
	vim.cmd("copen")
end

return M

