local S = require("scrap.internal")
require("plenary.test_harness")

---@param input string
local function parse(input)
	return S.parse(input, S.default_context)
end

describe("Scrap", function()
	-- {{{ Parser
	describe("Parser", function()
		---Expects some input to parse to some output
		---@param input string
		---@param output ScrapSequence
		local function should_parse_to(input, output)
			assert.same(output, parse(input))
		end

		---Expects some input to parse to some output
		---@param input string
		---@param position integer
		local function should_fail_parsing_at(input, position)
			local _, err = parse(input)
			assert.is_not_nil(err)
			---@cast err ScrapParsingError
			assert.equal(position, err.position)
		end

		it("should parse basic strings", function()
			local input = "foo"
			local output = { S.mk_string_scrap(input, 1, 3, input) }

			should_parse_to(input, output)
		end)

		it("should parse basic alternatives", function()
			local input = "{a,b,c}"
			local output = {
				S.mk_alternative_scrap(input, 1, 7, {
					{ S.mk_string_scrap(input, 2, 1, "a") },
					{ S.mk_string_scrap(input, 4, 1, "b") },
					{ S.mk_string_scrap(input, 6, 1, "c") },
				}),
			}

			should_parse_to(input, output)
		end)

		it("should parse empty alternatives", function()
			local input = "{}"
			local output = { S.mk_alternative_scrap(input, 1, 2, {}) }

			should_parse_to(input, output)
		end)

		it("should parse nested alternatives", function()
			local input = "{up,{left,right},down}"
			local output = {
				S.mk_alternative_scrap(input, 1, string.len(input), {
					{ S.mk_string_scrap(input, 2, 2, "up") },
					{
						S.mk_alternative_scrap(input, 5, 12, {
							{ S.mk_string_scrap(input, 6, 4, "left") },
							{ S.mk_string_scrap(input, 11, 5, "right") },
						}),
					},
					{ S.mk_string_scrap(input, 18, 4, "down") },
				}),
			}

			should_parse_to(input, output)
		end)

		it("should parse sequences of strings and alternatives", function()
			local input = "bar{foo,goo}boo"
			local output = {
				S.mk_string_scrap(input, 1, 3, "bar"),
				S.mk_alternative_scrap(input, 4, 9, {
					{ S.mk_string_scrap(input, 5, 3, "foo") },
					{ S.mk_string_scrap(input, 9, 3, "goo") },
				}),
				S.mk_string_scrap(input, 13, 3, "boo"),
			}

			should_parse_to(input, output)
		end)

		it("should parse empty alternatives before and after commas", function()
			local input = "{,hey,}"
			local output = {
				S.mk_alternative_scrap(input, 1, 7, {
					{},
					{ S.mk_string_scrap(input, 3, 3, "hey") },
					{},
				}),
			}

			should_parse_to(input, output)
		end)

		it("should allow escaping brackets", function()
			for _, c in pairs({ "{", "}" }) do
				local input = "\\" .. c
				local output = { S.mk_string_scrap(input, 1, 2, c) }

				should_parse_to(input, output)
			end
		end)

		it("should allow escaping backslashes", function()
			local input = "\\\\{}"
			local output = {
				S.mk_string_scrap(input, 1, 2, "\\"),
				S.mk_alternative_scrap(input, 3, 2, {}),
			}

			should_parse_to(input, output)
		end)

		it("should keep backslashes before normal chars", function()
			local input = "\\a"
			local output = { S.mk_string_scrap(input, 1, 2, input) }

			should_parse_to(input, output)
		end)

		it("should allow toplevel commas", function()
			local input = "a,b"
			local output = { S.mk_string_scrap(input, 1, 3, input) }

			should_parse_to(input, output)
		end)

		it("should error out on brackets without matching", function()
			should_fail_parsing_at("a{b", 2)
			should_fail_parsing_at("a}b", 2)
			should_fail_parsing_at("{}{}}", 5)
		end)
	end)
	-- }}}
	-- {{{ Expansion
	describe("Expansion", function()
		---@type ScrapExpansionOptions
		local no_casing = { all_caps = false, capitalized = false }

		---Make sure some patterns expand to some result
		---@param patterns ScrapExpansionInput[]
		---@param expected ScrapAbbreviation[]
		local function should_expand_to(patterns, expected)
			assert.same(expected, S.expand_many(patterns, no_casing))
		end

		-- To test this kind of stuff we check that
		--   - we error out
		--   - the error contains the correct span
		---Make sure some patterns expand to some result
		---@param patterns ScrapExpansionInput[]
		---@param slice ScrapStringSlice
		local function should_fail_expanding(patterns, slice)
			assert.error_match(function()
				local _ = S.expand_many(patterns, no_casing)
			end, S.formatSlice(slice))
		end

		it("should properly expand a basic expression", function()
			local input = { { "foo{up,m{left,right}m,down}goo", "g{a,h{b,c}h,d}f" } }
			local output = {
				{ "fooupgoo",      "gaf" },
				{ "foomleftmgoo",  "ghbhf" },
				{ "foomrightmgoo", "ghchf" },
				{ "foodowngoo",    "gdf" },
			}

			should_expand_to(input, output)
		end)

		it("should cycle alternatives on the right", function()
			local input = { { "{1,2,3,4,5}", "{odd,even}" } }
			local output = {
				{ "1", "odd" },
				{ "2", "even" },
				{ "3", "odd" },
				{ "4", "even" },
				{ "5", "odd" },
			}

			should_expand_to(input, output)
		end)

		it("should copy alternatives on the left if block on the right is empty", function()
			local input = { { "{1,2,3}", "{}" } }
			local output = { { "1", "1" }, { "2", "2" }, { "3", "3" } }

			should_expand_to(input, output)
		end)

		it("should ignore extra options on the right", function()
			local input = { { "{1,2,3}", "{a,b,c,d,e,f,g}" } }
			local output = { { "1", "a" }, { "2", "b" }, { "3", "c" } }

			should_expand_to(input, output)
		end)

		it("should stop expanding strings where the number of blocks differs", function()
			do
				local problematic_right = "{}abcd{}"
				local input = { { "ab{1,2,3}cd", problematic_right } }

				should_fail_expanding(input, S.mk_string_slice(problematic_right, 7, 2))
			end

			do
				local problematic_left = "{1,2}abcd{3,4}"
				local input = { { problematic_left, "ab{1,2,3}cd" } }

				should_fail_expanding(input, S.mk_string_slice(problematic_left, 10, 5))
			end
		end)

		it("should fail on empty block on the left", function()
			local problematic_left = "e{}f"
			local input = { { problematic_left, "{1,2,3}" } }

			should_fail_expanding(input, S.mk_string_slice(problematic_left, 2, 2))
		end)

		it("should produce capitalized variants by default", function()
			local input = { { "something", "something" } }
			local output = {
				{ "something", "something" },
				{ "Something", "Something" },
			}

			assert.same(output, S.expand_many(input))
		end)

		it("should allow turning down capitalization globally", function()
			local input = { { "something", "something" }, { "else", "else" } }
			local output = { { "something", "something" }, { "else", "else" } }

			assert.same(output, S.expand_many(input, { capitalized = false }))
		end)

		it("should allow turning down capitalization locally", function()
			local input = {
				{ "something", "something" },
				{ "else",      "else",     options = { capitalized = false } },
			}

			local output = {
				{ "something", "something" },
				{ "Something", "Something" },
				{ "else",      "else" },
			}

			assert.same(output, S.expand_many(input))
		end)

		it("should allow turning on all caps mode", function()
			local input = {
				{ "something", "something", options = { all_caps = true } },
			}

			local output = {
				{ "something", "something" },
				{ "SOMETHING", "SOMETHING" },
			}

			assert.same(output, S.expand_many(input, { capitalized = false }))
		end)
	end)
	-- }}}
end)
