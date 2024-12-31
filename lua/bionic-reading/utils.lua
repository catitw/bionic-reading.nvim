--- Utils module
--- @module Utils
--- @usage local Utils = require("bionic-reading.utils")
local Utils = {}

--- Check if file type is correct
--- @return boolean
function Utils.check_file_types()
	local Config = require("bionic-reading.config")
	local correct_file_type = false

	for file_type, _ in pairs(Config.opts.file_types) do
		if vim.bo.filetype == file_type then
			correct_file_type = true
			break
		end
	end

	return correct_file_type
end

--- Send notification using nvim-notify, fallback to print
--- @param content string
--- @param type string
--- @param fallback string
--- @return nil
function Utils.notify(content, type, fallback)
	local has_notify, notify = pcall(require, "notify")
	local title = "Bionic Reading"

	type = type or "info"
	fallback = fallback or nil

	if has_notify then
		notify.notify(content, type, {
			title = title,
		})
	elseif fallback then
		print(title .. ": " .. fallback)
	end
end

--- Handles user input from prompt
--- @param input string
--- @return boolean
function Utils.prompt_answer(input)
	if input == "y" or input == "Y" or input == "Yes" or input == "YES" then
		return true
	end

	return false
end

--- Check if character is a vowel
--- @param char string
--- @return boolean
local function is_vowel(char, char_index, word)
	local vowels = { "a", "e", "i", "o", "u" }
	local prev_char = nil

	-- y is a special case, it can be a vowel or a consonant
	-- y is a consonant when it is the first letter of a word
	-- or precedes a vowel
	if char == "y" then
		if char_index == 1 then
			return false
		end

		prev_char = char
		char = string.lower(word:sub(char_index + 1, char_index + 1))
	end

	for _, vowel in ipairs(vowels) do
		if char == vowel then
			if prev_char == "y" then
				return false
			end

			return true
		end
	end

	if prev_char == "y" then
		return true
	end

	return false
end

-- NOTE: syllables are made of 3 things: onset (before vowel), nucleus (vowel), coda (after vowel)
-- We only care about the first nucleus and the preceding onset
--- Get the end index of the first syllable in a word
--- @param word string
--- @return number
function Utils.highlight_on_first_syllable(word)
	local vowel_clusters = { "au", "ai", "ea", "ee", "ei", "eu", "ie", "io", "oa", "oe", "oi", "oo", "ou", "ue", "ui" }
	local coda_exceptions = { "gh", "nd", "ld", "st" }

	if word == nil or word == "" then
		return 0
	end

	if #word == 1 then
		return 1
	end

	if #word <= 4 then
		return math.floor(#word / 2)
	end

	for cur_char_index = 1, #word do
		local substring = string.lower(word:sub(cur_char_index, cur_char_index + 1))

		for _, combination in ipairs(vowel_clusters) do
			if substring == combination then
				-- if the first vowel cluster is the last letter, we dont want to highlight the whole word
				if cur_char_index + 1 == #word then
					return math.floor(#word / 2)
				end

				-- a vowel cluster usually doesn't have a coda
				return cur_char_index + 1
			end
		end

		-- coda is the consonant(s) that follow the nucleus
		local coda = 1
		local char = string.lower(word:sub(cur_char_index, cur_char_index))
		local next_char_index = cur_char_index + coda

		if is_vowel(char, cur_char_index, word) then
			if cur_char_index == #word then
				return math.floor(#word / 2)
			end

			local next_chars = string.lower(word:sub(next_char_index, next_char_index + coda))

			-- check exceptions for coda
			for _, exception in ipairs(coda_exceptions) do
				if next_chars == exception then
					if next_char_index + coda == #word then
						return cur_char_index
					end

					coda = 2
				end
			end

			return cur_char_index + coda
		end
	end

	return 1
end

--- Recursively navigate a syntax tree and apply a callback to matching nodes.
-- @param node userdata: The current node in the syntax tree.
-- @param node_types table: A list of node types to match. If "any" is included, all nodes will match.
-- @param callback function: A function to apply to matching nodes. The function receives the node as an argument.
local function _navigate_tree(node, node_types, callback)
    -- Get the type of the current node
    local node_type = node:type()

    -- Get the range of the current node
    local start_row, start_col, end_row, end_col = node:range()

    -- Check if the current node type matches the specified types
    if vim.tbl_contains(node_types, "any") or vim.tbl_contains(node_types, node_type) then
        -- Apply the callback to the matching node
        callback(node)
    end

    -- Recursively navigate all child nodes
    for child in node:iter_children() do
        _navigate_tree(child, node_types, callback)
    end
end

--- Public function to navigate a syntax tree and apply a callback to matching nodes.
-- @param node userdata: The root node of the syntax tree.
-- @param node_types table: A list of node types to match. If "any" is included, all nodes will match.
-- @param callback function: A function to apply to matching nodes. The function receives the node as an argument.
function Utils.navigate_tree(node, node_types, callback)
    _navigate_tree(node, node_types, callback)
end

return Utils
