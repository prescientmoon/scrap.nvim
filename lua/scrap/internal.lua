local scrap = {}

-- {{{ Helper
---Clones a list
---@generic T
---@param t T[]
---@return T[]
---@nodiscard
local function cloneList(t)
  return { unpack(t) }
end

---Clones a list
---@generic T:table
---@param t T
---@param r T
---@return T
---@nodiscard
local function merge_tables(t, r)
  local result = { unpack(t) }
  for k, v in pairs(r) do result[k] = v end

  return result
end

---Returns the tail of a list (all but the first element)
---@generic T
---@param t T[]
---@return T[]
---@nodiscard
local function listTail(t)
  return { unpack(t, 2) }
end

---Concats two lists together
---@generic T
---@param t1 T[]
---@param t2 T[]
---@return T[]
---@nodiscard
local function concat_tables(t1, t2)
  assert(type(t1) == "table")
  assert(type(t2) == "table")

  local t3 = {}
  for i = 1, #t1 do t3[#t3 + 1] = t1[i] end
  for i = 1, #t2 do t3[#t3 + 1] = t2[i] end
  return t3
end

---Index a list, with overflowing indices cycling back to the start
---@generic T
---@param list T[]
---@param index integer
---@return T
local function mod_index(list, index)
  assert(#list > 0)
  return list[(index - 1) % #list + 1]
end

---Concatenates a string n times
---@param string string
---@param times integer
---@return string
---@nodiscard
local function replicateString(string, times)
  local result = ""
  for _ = 1, times, 1 do result = result .. string end

  return result
end

---Capitalizes the first char of a string
---@param string string
---@return string
---@nodiscard
local function capitalizeString(string)
  assert(#string > 0)
  return string.upper(string.sub(string, 1, 1)) .. string.sub(string, 2)
end

---Strongly typed version of table.insert for pushing elements
---@generic T
---@param list T[]
---@param element T
local function listPush(list, element)
  list[#list + 1] = element
end

---Pops an element off a list and returns it
---@generic T
---@param list T[]
---@return T|nil
local function listPop(list)
  local last = list[#list]
  list[#list] = nil
  return last
end

---Shows a sequence for debugging
---@param seq Sequence
---@return string
function scrap.showSequence(seq)
  local result = ""

  for _, scrap in pairs(seq) do
    if type(scrap.value) == "string" then
      result = result .. scrap.value
    else
      local alternatives = scrap.value --[[@as Sequence[] ]]
      result = result .. "{"
      for i, alternative in pairs(alternatives) do
        result = result .. scrap.showSequence(alternative)
        if i == #alternatives then
          result = result .. "}"
        else
          result = result .. ","
        end
      end
    end
  end

  return result
end

-- }}}
-- {{{ Basic type definitions
---@class StringSlice
---@field start integer
---@field length integer
---@field text string

---@class Scrap
---@field value string|Sequence[]
---@field source StringSlice

---@alias Sequence Scrap[]
---@alias Abbreviation Pair<string>

---@class Pair<T>: { [1]: T, [2]: T}

---Build a string slice struct
---@param text string
---@param start integer
---@param length integer
---@return StringSlice
function scrap.mk_string_slice(text, start, length)
  return { text = text, start = start, length = length }
end

---Build a string scrap
---@param text string
---@param start integer
---@param length integer
---@param value string
---@return Scrap
function scrap.mk_string_scrap(text, start, length, value)
  return { value = value, source = scrap.mk_string_slice(text, start, length) }
end

---Build an alternative scrap
---@param text string
---@param start integer
---@param length integer
---@param alternatives Sequence[]
---@return Scrap
function scrap.mk_alternative_scrap(text, start, length, alternatives)
  return {
    value = alternatives,
    source = scrap.mk_string_slice(text, start, length)
  }
end

-- }}}
-- {{{ Error handling
---Formats a string slice in a readable manner
---@param slice StringSlice
local function formatSlice(slice)
  return slice.text .. "\n" .. replicateString(" ", slice.start - 1) ..
             replicateString("^", slice.length)
end

-- }}}
-- {{{ Parsing
-- {{{ Type definitions & helpers
---@class ParsingContext
---@field delimiters {left:string,right:string}
---@field separator string

---@class ParsingError
---@field position integer
---@field message string

---Helper for constructing errors
---@param message string
---@param position integer
---@return ParsingError
local function parsing_error(message, position)
  return { position = position, message = message }
end

---Throws a parsing error
---@param err ParsingError
---@param text string
local function throw_parsing_error(err, text)
  local lines = {
    err.message,
    formatSlice({ text = text, start = err.position, length = 1 })
  }
  error(table.concat(lines, "\n"))
end

---@class IncompleteScrap<T> {start:integer, contents: T[]}

---@class ParsingStackElement
---@field start integer
---@field contents Sequence
---@field currentChildren {start:integer, contents:Sequence[]}
-- }}}
-- {{{Main parser
---Parses the input for this plugin
---@param input string
---@param context ParsingContext
---@return Sequence|nil
---@return nil|ParsingError
function scrap.parse(input, context)
  ---@type ParsingStackElement[]
  local stack = {}
  ---@type {start:integer, contents:Sequence}
  local topmost = { start = 1, contents = {} }

  local escaped = false
  local escapedChars = {
    ["\\"] = true,
    [context.delimiters.left] = true,
    [context.delimiters.right] = true
  }

  -- Here is a quirk of the original implementation.
  --   - {a,b,} will get parsed as {"a", "b","c"}
  --   - {} will not get parsed as {""}, but as {}
  -- therefore we treat "," and "}" a little differently
  -- (endsBlock=true on "}")
  ---Saves the current element of the stack in the previous one
  ---@param endsBlock boolean
  local function saveUp(endsBlock)
    assert(#stack > 0)
    local prev = stack[#stack]

    -- We discard this result if:
    --         We haven't encountred a comma yet
    --   (and) The current {} block is empty
    --   (and) The parent {} block contains nothing before
    if endsBlock and #topmost.contents == 0 and #prev.currentChildren.contents ==
        0 then return end

    listPush(prev.currentChildren.contents, topmost.contents)
  end

  -- {{{ Main parser loop
  for position = 1, string.len(input), 1 do
    local first = string.sub(input, position, position)
    ---@type string|nil
    local next = string.sub(input, position + 1, position + 1)

    if not escaped and first == "\\" and escapedChars[next] then
      escaped = true

    elseif not escaped and first == context.delimiters.left then
      listPush(stack, {
        start = topmost.start,
        contents = topmost.contents,
        currentChildren = { contents = {}, start = position }
      })

      topmost = { start = position + 1, contents = {} }
    elseif not escaped and first == context.delimiters.right then
      if #stack == 0 then
        local message = "Delimiter " .. context.delimiters.right ..
                            " never opened"
        return nil, parsing_error(message, position)
      end

      saveUp(true)

      local prev = listPop(stack) --[[@as ParsingStackElement]]

      ---@type Scrap
      local scrap = {
        value = prev.currentChildren.contents,
        source = {
          text = input,
          start = prev.currentChildren.start,
          length = position + 1 - prev.currentChildren.start
        }
      }

      topmost = { start = prev.start, contents = prev.contents }
      listPush(topmost.contents, scrap)
    elseif not escaped and first == context.separator and #stack > 0 then
      saveUp(false)

      topmost = { start = position + 1, contents = {} }
    else
      local last = topmost.contents[#topmost.contents]

      if last and type(last.value) == "string" then
        last.value = last.value .. first
        -- We added a single char, so we increase this by 1
        local delta = 1

        -- also taking \ into account
        if escaped then delta = 2 end

        last.source.length = last.source.length + delta
      else
        local delta = 0

        -- also taking \ into account
        if escaped then delta = 1 end

        ---@type Scrap
        local scrap = scrap.mk_string_scrap(input, position - delta, 1 + delta,
                                            first)

        listPush(topmost.contents, scrap)
      end

      escaped = false
    end
  end
  -- }}}

  if #stack > 0 then
    return nil,
           parsing_error(
               "Delimiter " .. context.delimiters.left .. " never closed",
               stack[#stack].currentChildren.start)
  end

  return topmost.contents, nil
end

-- }}}
-- }}}
-- {{{ Expansion
-- {{{ Expand a single abbreviation
---Expands a pair of sequences to strings which can be used for abbreviations
---@param unprocessed Pair<Sequence>
---@param context Abbreviation
---@param out Abbreviation[]
---@return nil
local function expand(unprocessed, context, out)
  local from = unprocessed[1]
  local to = unprocessed[2]

  if #from == 0 and #to == 0 then
    listPush(out, context)
    return
  end

  for i = 1, 2, 1 do
    ---@cast i 1|2
    local head = (unprocessed[i] --[[@as Scrap[] ]] )[1]
    if head and type(head.value) == "string" then
      ---@type Pair<string>
      local context_clone = cloneList(context)

      context_clone[i] = context_clone[i] .. head.value

      ---@type Pair<Sequence>
      local unprocessed_clone = cloneList(unprocessed)
      unprocessed_clone[i] = listTail(unprocessed[i] --[[@as Sequence]] )

      return expand(unprocessed_clone, context_clone, out)
    end
  end

  if #from == 0 then
    local lines = {
      "Alternative on the right hand side of abbreviation has no match on the left:",
      formatSlice(to[1].source)
    }

    error(table.concat(lines, "\n"))
  elseif #to == 0 then
    local lines = {
      "Alternative on the left hand side of abbreviation has no match on the right:",
      formatSlice(from[1].source)
    }

    error(table.concat(lines, "\n"))
  end

  local from_alternatives = from[1].value --[[@as Sequence[] ]]
  local to_alternatives = to[1].value --[[@as Sequence[] ]]

  for i = 1, #from_alternatives, 1 do
    local when = from_alternatives[i]
    local replacement = when

    if #to_alternatives > 0 then replacement = mod_index(to_alternatives, i) end

    assert(type(when) == "table")
    assert(type(replacement) == "table")

    local unprocessed_clone = {
      concat_tables(when, listTail(from)),
      concat_tables(replacement, listTail(to))
    }

    expand(unprocessed_clone, context, out)
  end
end

-- }}}
-- {{{Expansion options & casing variations
---@class ExpansionOptions
---@field all_caps boolean|nil
---@field capitalized boolean|nil

---@type ExpansionOptions
local default_expansion_options = { capitalized = true, all_caps = false }

---@class ExpansionInput
---@field [1] string
---@field [2] string
---@field options ExpansionOptions|nil

---Adds casing variations to abbreviations
---@param input Abbreviation
---@param options ExpansionOptions
---@param out Abbreviation[]
local function with_casing(input, options, out)
  local from = input[1]
  local to = input[2]

  -- Base abbreviation
  listPush(out, { from, to })

  if options.all_caps then
    -- All uppercase
    listPush(out, { string.upper(from), string.upper(to) })
  end

  if options.all_caps then
    -- Uppercase first char
    if #from and #to then
      listPush(out, { capitalizeString(from), capitalizeString(to) })
    end
  end
end

-- }}}
-- {{{Glue code for the above
---Expands a pair of sequences to strings which can be used for abbreviations
---@param input Pair<Sequence>
---@param options ExpansionOptions
---@return Abbreviation[]
function scrap.expand(input, options)
  -- First we do the barebones expansion
  ---@type Abbreviation[]
  local result = {}

  expand({ input[1], input[2] }, { "", "" }, result)

  -- Then we add casing variations
  ---@type Abbreviation[]
  local final_result = {}

  for _, v in pairs(result) do with_casing(v, options, final_result) end

  return result
end

scrap.default_context = {
  delimiters = { left = "{", right = "}" },
  separator = ","
}

---Parse and expand a list of patterns
---@param many ExpansionInput[]
---@param options ExpansionOptions|nil
function scrap.expand_many(many, options)
  options = options or default_expansion_options
  local results = {}
  for _, entry in pairs(many) do
    local left, err_l = scrap.parse(entry[1], scrap.default_context)
    local right, err_r = scrap.parse(entry[2], scrap.default_context)

    if err_l then
      throw_parsing_error(err_l, entry[1])
    elseif err_r then
      throw_parsing_error(err_r, entry[2])
    else
      ---@cast left Sequence
      ---@cast right Sequence
      local abbreviations = scrap.expand(merge_tables(entry, { left, right }),
                                         merge_tables(options, entry))

      results = concat_tables(results, abbreviations)
    end
  end
end

-- }}}
-- }}}

return scrap
