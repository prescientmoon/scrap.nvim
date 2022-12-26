# 🧲 Scrap.nvim

A fully-tested, pure lua implementation of vim-abolish inspired pattern expansion. Useful for generating many abbreviations.

## ❓ How to use
This plugin exposes a simple lua interface - the `expand_many` function. This function takes in an array of from-to pairs, together with a table of default options:
```lua
local scrap = require("scrap")

local patterns = {
  -- e0...9,n => ^0...^n
  -- s0...9,n => _0..._n
  {"{e,s}{0,1,2,3,4,5,6,7,8,9,n}", "{^,_}{}"}
}

-- By default, this plugin will generate capitalized versions of each pattern. 
-- Eg: {"thrf", "therefore"} will generate
--  - thrf => therefore
--  - Thrf => Therefore
-- 
-- This behavior can be turned off for the entire list (as seen bellow), or on a per pattern basis (see the features section)
--
-- This plugin also provides an `all_caps` prop, which is false by default, and allows generating extra expansions like (for the above example):
--  - THRF => THEREFORE
local expanded = scrap.expand_many(patterns, {capitalized = false})

-- This plugin allows you to do whatever you want with the expanded list. This means expanding the functionality of this plugin to other vim-abolish features should be trivial. 
-- For now, the plugin provides a convenient function for mapping all the above pairs of strings as local abbreviations:
scrap.many_local_abbreviations(expanded)
```

## ✨Features not present in vim-abolish

- ⚙️ Configure capitalization on a per-abbreviation basis

   ```lua 
   {{ "foo", "bar", options = {capitalized = false, all_caps = true}}}
   -- => foo->bar, FOO->BAR
   ```  

- 🗃️ Nested alternatives ([issue](https://github.com/tpope/vim-abolish/issues/91))

  ```lua
  {{"i{{r,}l,h}n", "I {{really,} love,hate} Neovim!"}} 
  -- irln -> I really love Neovim
  -- iln -> I love Neovim
  -- ihn -> I hate Neovim
  ```
- 🏃 Escape characters ([issue](https://github.com/tpope/vim-abolish/issues/112))

  ```lua
  {{"{happy,sad}", ":{\\},\\{}"}}
  -- happy -> :}
  -- sad -> :{
  ```
- 💥 Useful error messages - the parser keeps track of source spans at all points in the expansion process, which means errors should point out the exact spot in the input string issues arose from.

## How expansion works

There are a few simple rules which govern the way expansion takes place. Given a from-to pair of patterns, we'll refer to the `from` pattern as the one on the "left", and the `to` pattern as the one on the "right".

- if the block on the right contains no values, copy the contents of the block on the left
- otherwise, infinitely cycle the values on the right until all the values on the left are matched.

## Development

So far, I have only implemented the features I use in my day to day life. If you feel like anything is missing, feel free to open an issue! 
