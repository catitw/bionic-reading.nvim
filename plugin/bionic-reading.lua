local M = { enabled = false }
local namespace = "bionic-reading"
local ns_id = vim.api.nvim_create_namespace(namespace)

vim.g.flow_strength = vim.g.flow_strength or 0.7

function M.create(opts)
	local line_start = 0
	local line_end = vim.api.nvim_buf_line_count(0)

	M.enabled = true

	if opts and opts.range == 2 then
		line_start = vim.api.nvim_buf_get_mark(0, "<")[1] - 1
		line_end = vim.api.nvim_buf_get_mark(0, ">")[1]
	end

	local lines = vim.api.nvim_buf_get_lines(0, line_start, line_end, true)
	local index = line_start - 1

	for _, line in pairs(lines) do
		local line_length = #line

		index = index + 1

		vim.api.nvim_buf_set_extmark(0, ns_id, index, 0, {
			hl_group = "BRSuffix",
			end_col = line_length,
		})

		local st = nil

		for j = 1, line_length do
			local current = string.sub(line, j, j)
			local re = current:match("[%w']+")

			if st then
				if j == line_length then
					if re then
						j = j + 1
						re = nil
					end
				end

				if not re then
					local en = j - 1

					vim.api.nvim_buf_set_extmark(0, ns_id, index, st - 1, {
						hl_group = "BRPrefix",
						end_col = math.floor(st + math.min((en - st) / 2, (en - st) * vim.g.flow_strength)),
					})

					st = nil
				end
			elseif re then
				st = j
			end
		end
	end
end

function M.clear()
	M.enabled = false
	vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
	ns_id = vim.api.nvim_create_namespace(namespace)
end

function M.toggle(opts)
	M.enabled = not M.enabled

	if M.enabled then
		M.create(opts)
	else
		M.clear()
	end
end

vim.api.nvim_create_user_command("BRShow", function(opts)
	M.create(opts)
end, {
	range = 2,
})

vim.api.nvim_create_user_command("BRHide", function()
	M.clear()
end, {
	range = 2,
})

vim.api.nvim_create_user_command("BRToggle", function(opts)
	M.toggle(opts)
end, {
	range = 2,
})

function M.highlight()
	vim.api.nvim_set_hl(0, "BRPrefix", { bold = true })
	vim.api.nvim_set_hl(0, "BRSuffix", { default = true })
end

M.highlight()

vim.api.nvim_create_autocmd("ColorScheme", {
	group = vim.api.nvim_create_augroup("BRColorScheme", { clear = true }),
	pattern = "*",
	callback = function()
		M.highlight()
	end,
})
