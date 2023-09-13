# 🧲 Scrap.nvim

A fully-tested, pure lua implementation of vim-abolish inspired pattern expansion. Useful for generating many abbreviations.

## 💡The idea

Abbreviations are super useful! For instance, as a math student, I very often use `thrf => therefore`. It is often useful to automatically generate capitalized versions of similar abbreviations (i.e.: `Thrf => Therefore`).

It's often useful to create multiple similar abbreviations. For instance, someone taking a simple calculus course might be interested in having something like:

- `ips => integration by substitution`
- `ipp => integration by parts`

This plugin allows us to do better by marking alternatives using brackets — `ip{s,p} => integration by {substitution,parts}`.

Specifying plural forms for words appears to be a very common pattern — `grho{,s} => group homomorphism{,s}`. Notice how the brackets have the same content on both sides? We can go ahead and omit them from the right hand side — `grho{,s} => group homomorphism{}`, which will still produce:

- `grho => group homomorphism`
- `grhos => group homomorphisms`

Although not super useful in practice (implemented for the sake of feature parity with `vim-abolish`), values on the right hand side are automatically cycled indefinitely. For instance, `parity-of-{0,1,2,3} => {even,odd}` will produce

- `parity-of-0 => even`
- `parity-of-1 => odd`
- `parity-of-2 => even`
- `parity-of-3 => odd`

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
-- This plugin also provides an `all_caps` option (false by default), which does what you would expect. For instance, this additional abbreviation would be generated in the above example:
--  - THRF => THEREFORE
local expanded = scrap.expand_many(patterns, {all_caps = true})

-- This plugin lets you do whatever you want with the expanded list, hence expanding the functionality of this plugin to other vim-abolish features should be trivial.
-- For now, the plugin provides a convenient function for mapping all the above pairs of strings as local abbreviations:
scrap.many_local_abbreviations(expanded)
```

## ✨ Additional features over vim-abolish

- ⚙️ Configure capitalization on a per-abbreviation basis

  ```lua
  {{ "foo", "bar", options = {capitalized = false, all_caps = true}}}
  -- foo => bar, FOO => BAR
  ```

- 🗃️ Nested alternatives ([issue](https://github.com/tpope/vim-abolish/issues/91))

  ```lua
  {{"i{{r,}l,h}n", "I {{really,} love,hate} Neovim!"}}
  -- irln => I really love Neovim
  -- iln => I love Neovim
  -- ihn => I hate Neovim
  ```

- 🏃 Escape characters ([issue](https://github.com/tpope/vim-abolish/issues/112))

  ```lua
  {{"{happy,sad}", ":{\\},\\{}"}}
  -- happy => :}
  -- sad => :{
  ```

- 💥 Useful error messages - the parser keeps track of source spans at all points in the expansion process, which means errors should point out the exact spot in the input string issues arose from:

  ```
  E5108: Error executing lua ....local/share/nvim/lazy/scrap.nvim/lua/scrap/internal.lua:211: Delimiter { never closed
  fr{om
    ^
  ```

## 💻 Development

So far, I have only implemented the features I use in my day to day life. If you feel like anything is missing, feel free to open an issue!

## 👷 Contributing

This repository provides a nix flake for development. Simply run `nix develop` to enter a shell which provides a `nvim-local` command. This command will open a clean copy of neovim with nothing but the local copy of this plugin installed.

Moreover, you can run tests with `nix run .#tests`.
