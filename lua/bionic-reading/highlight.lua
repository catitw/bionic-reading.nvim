local Utils = require("bionic-reading.utils")

local api = vim.api

--- Highlight class
--- @module Highlight
local Highlight = {
	hl_group = "BionicReadingHL",
	namespace = api.nvim_create_namespace("bionic_reading")
}


--- Get the column range for a line based on its position (first line, last line, or middle line).
-- @param line number: The current line number.
-- @param line_start number: The starting line of the range.
-- @param line_end number: The ending line of the range.
-- @param col_start number: The starting column for the first line.
-- @param col_end number: The ending column for the last line.
-- @param line_content string: The content of the current line.
-- @return number, number: The start and end column for the current line.
local function get_column_range(line, line_start, line_end, col_start, col_end, line_content)
    if line == line_start then
        -- First line: from col_start to the end of the line
        return col_start, #line_content
    elseif line == line_end then
        -- Last line: from the start of the line to col_end
        return 0, col_end == -1 and #line_content or col_end
    else
        -- Middle lines: from the start to the end of the line
        return 0, #line_content
    end
end

--- Apply highlighting to a range of lines in a buffer, with dynamic column ranges.
-- @param bufnr number: The buffer number to apply highlighting to. Defaults to the current buffer.
-- @param line_start number: The starting line of the range. Defaults to 0.
-- @param line_end number: The ending line of the range. Defaults to the last line of the buffer.
-- @param col_start number: The starting column for the first line. Defaults to 0.
-- @param col_end number: The ending column for the last line. Defaults to -1 (end of line).
local function _apply_highlighting(bufnr, line_start, line_end, col_start, col_end)
    -- Set default parameters
    bufnr = bufnr or api.nvim_get_current_buf() -- Default to the current buffer
    line_start = line_start or 0 -- Default to the first line
    line_end = line_end or api.nvim_buf_line_count(bufnr) - 1 -- Default to the last line

    -- Ensure valid column ranges
    col_start = col_start or 0 -- Default to the first column
    col_end = col_end or -1 -- Default to the end of the line

    -- Iterate over the specified line range
    for line = line_start, line_end do
        -- Get the content of the current line
        local line_content = api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ""

        -- Determine the column range for the current line
        local start_col, end_col = get_column_range(line, line_start, line_end, col_start, col_end, line_content)

        -- Ensure the column range is within the line
        end_col = math.min(end_col, #line_content)

        -- Collect words to highlight in the current line
        local highlights = {}
        for word_index, word in string.gmatch(line_content, "()([^%s%p%d]+)") do
            -- Calculate the column range for the word
            local word_start = word_index - 1
            local word_end = word_start + Utils.highlight_on_first_syllable(word)

            -- Ensure the word is within the dynamic column range
            if word_start >= start_col and word_end <= end_col then
                table.insert(highlights, { word_start, word_end })
            end
        end

        -- Apply highlighting to the collected words
        for _, highlight in ipairs(highlights) do
            api.nvim_buf_add_highlight(
                bufnr, -- Buffer number
                Highlight.namespace, -- Highlight namespace
                Highlight.hl_group, -- Highlight group
                line, -- Line number
                highlight[1], -- Start column
                highlight[2] -- End column
            )
        end
    end
end

--- Highlight buffer using treesitter
--- @param bufnr number
--- @param line_start number
--- @param line_end number
--- @return boolean true if treesitter parser is available, false otherwise
local function _treesitter_highlight(bufnr, line_start, line_end)
	local Config = require("bionic-reading.config")

	bufnr = bufnr or api.nvim_get_current_buf()
	line_start = line_start or 0
	line_end = line_end or vim.api.nvim_buf_line_count(bufnr)

	local ok = pcall(vim.treesitter.get_parser, bufnr)

	if not ok then
		return false
	end

	-- pos is 0-indexed
	local root = vim.treesitter.get_node({ bufnr = bufnr, pos = { line_start, line_end } })

	if not root then
		return false
	end

	-- Make sure we have the top-level node
	if line_start == 0 and line_end == vim.api.nvim_buf_line_count(bufnr) then
		local parent = root:parent()

		while parent do
			root = parent
			parent = parent:parent()
		end
	end

	local filetype_node_types = Config.opts.file_types[vim.bo.filetype]

	-- Early return, if node_type is 'any' then highlight to line_end
	if type(filetype_node_types) == 'string' and filetype_node_types == 'any' then
		_apply_highlighting(bufnr, line_start, line_end);

		return true
	end

	Utils.navigate_tree(root, filetype_node_types, function(node)
		-- for _, node_type in ipairs(filetype_node_types) do
			-- if node_type == 'any' or node_type == node:type() then
				local start_row, start_col, end_row, end_col = node:range()

				_apply_highlighting(bufnr, start_row, end_row, start_col, end_col)
			-- end
		-- end
	end)

	return true
end

--- Clear all highlights in current buffer by clearing namespace
--- @param bufnr number
--- @return nil
function Highlight.clear(bufnr)
	local Buffers = require("bionic-reading.buffers")

	bufnr = bufnr or api.nvim_get_current_buf()

	Buffers:deactivate_buf(bufnr)
	api.nvim_buf_clear_namespace(bufnr, Highlight.namespace, 0, -1)
end

--- Highlight lines in current buffer
--- @param bufnr number
--- @param line_start number
--- @param line_end number
--- @return nil
function Highlight.highlight(bufnr, line_start, line_end)
	local Config = require("bionic-reading.config")
	local Buffers = require("bionic-reading.buffers")
	local ok = false

	bufnr = bufnr or api.nvim_get_current_buf()
	line_start = line_start or 0
	line_end = line_end or api.nvim_buf_line_count(bufnr)

	Buffers:activate_buf(bufnr)

	if Config.opts.treesitter then
		ok = _treesitter_highlight(bufnr, line_start, line_end)

		if ok then
			return
		end
	end

	-- If treesitter is not enabled or it failed to highlight, fallback to regex
	if not ok then
		_apply_highlighting(bufnr, line_start, line_end)
	end
end

local function init()
	local Config = require("bionic-reading.config")

	api.nvim_set_hl(0, Highlight.hl_group, Config.opts.hl_group_value)
end

init()

return Highlight
