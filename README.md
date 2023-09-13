# 🧲 Scrap.nvim

A fully-tested, pure lua implementation of vim-abolish inspired pattern expansion. Useful for generating many abbreviations.

## 💡The idea

Abbreviations are super useful! For instance, I very often make use of `thrf => therefore`. How can we improve the workflow of setting up new abbreviations?

1. We can automatically generate capitalized versions of similar abbreviations (i.e.: `Thrf => Therefore`). This is handled automatically by this plugin! (see the [usage](#-how-to-use) section for more details)

2. We often want to create multiple similar abbreviations. For instance, someone taking a simple calculus course might come up with something like:

   - `ips => integration by substitution`
   - `ipp => integration by parts`

   This plugin allows us to do better by marking alternatives using brackets:

   ```
   ip{s,p} => integration by {substitution,parts}
   ```

3. Specifying plural forms for words appears to be a very common pattern — `grho{,s} => group homomorphism{,s}`. Notice how the brackets have the same content on both sides? We can go ahead and omit them from the right hand side — `grho{,s} => group homomorphism{}`, which will still produce:

   - `grho => group homomorphism`
   - `grhos => group homomorphisms`

   More generally, scrap will copy the contents of the brackets on the left when the brackets on the right are empty.

4. Although not super useful in practice (implemented for the sake of feature parity with `vim-abolish`), values on the right hand side are automatically cycled indefinitely. For instance, `parity-of-{0,1,2,3} => {even,odd}` will produce

   - `parity-of-0 => even`
   - `parity-of-1 => odd`
   - `parity-of-2 => even`
   - `parity-of-3 => odd`

## ❓ How to use

This plugin exposes a simple lua interface — the `expand_many` function. This function takes in an array of from-to pairs, together with a table of default options:

```lua
local scrap = require("scrap")

local patterns = {
  { "mx{,s}", "matri{x,ces}" }
}

local expanded = scrap.expand_many(patterns)
-- - mx => matrix
-- - Mx => Matrix
-- - mxs => matrices
-- - Mxs => Matrices

-- This plugin lets you do whatever you want with the expanded list, hence expanding the functionality of this plugin to other vim-abolish features should be trivial.
-- Lets use this convenient function for mapping all the pairs as local abbreviations:
scrap.many_local_abbreviations(expanded)
```

Capitalization can be fine tuned using the options table:

```lua
scrap.expand_many(
    {{ "thrf", "therefore" }},
    { all_caps = true, capitalized = false }
)
-- - thrf => therefore
-- - THRF => THEREFORE
```

## ✨ Additional features not present in vim-abolish

- ⚙️ Override capitalization settings on a per-abbreviation basis

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

This repository provides a nix flake for development!

- Create a clean copy of neovim with this plugin installed by running:

  ```sh
  nix run .#nix-dev
  ```

- Run the test suite with:

  ```sh
  nix run .#tests
  ```
