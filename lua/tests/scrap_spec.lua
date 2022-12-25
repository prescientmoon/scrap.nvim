local S = require("scrap.internal")
require("plenary.test_harness")

---@param input string
local function parse(input)
  return S.parse(input, S.defaultContext)
end

describe("Scrap", function()
  describe("Parser", function()
    ---Expects some input to parse to some output
    ---@param input string
    ---@param output Sequence
    local function should_parse_to(input, output)
      assert.same(output, parse(input))
    end

    ---Expects some input to parse to some output
    ---@param input string
    ---@param position integer
    local function should_fail_parsing_at(input, position)
      local _, err = parse(input)
      assert.is_not_nil(err)
      ---@cast err ParsingError
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
          { S.mk_string_scrap(input, 6, 1, "c") }
        })
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
              { S.mk_string_scrap(input, 11, 5, "right") }
            })
          },
          { S.mk_string_scrap(input, 18, 4, "down") }
        })
      }

      should_parse_to(input, output)
    end)

    it("should parse sequences of strings and alternatives", function()
      local input = "bar{foo,goo}boo"
      local output = {
        S.mk_string_scrap(input, 1, 3, "bar"),
        S.mk_alternative_scrap(input, 4, 9, {
          { S.mk_string_scrap(input, 5, 3, "foo") },
          { S.mk_string_scrap(input, 9, 3, "goo") }
        }),
        S.mk_string_scrap(input, 13, 3, "boo")
      }

      should_parse_to(input, output)
    end)

    it("should parse empty alternatives before and after commas", function()
      local input = "{,hey,}"
      local output = {
        S.mk_alternative_scrap(input, 1, 7, {
          {},
          { S.mk_string_scrap(input, 3, 3, "hey") },
          {}
        })
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
        S.mk_alternative_scrap(input, 3, 2, {})
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
end)
