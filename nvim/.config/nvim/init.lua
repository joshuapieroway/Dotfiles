-- Minimal Neovim setup: explorer, terminal-native colours, and completion.
vim.g.mapleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.termguicolors = true
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.winborder = "rounded"

-- Prose settings for markdown and plain text. A single long line of prose is
-- unreadable at nvim's default settings, so wrap it and break at word
-- boundaries instead of mid-word.
--
-- Two things about placement matter here:
--
--  1. This must be registered *before* the `syntax enable` call below. `:syntax`
--     forces filetype detection for any file named on the command line, so the
--     first FileType event fires from there — before the rest of this file has
--     run. An autocmd added further down is registered too late to see it.
--
--  2. The callback must not assume a window exists. During startup that first
--     FileType fires before the window is created, so `vim.wo[buf]` raises
--     "Invalid window id". Worse, the error aborts the remaining FileType
--     autocmds, which is what loads the filetype-scoped plugins (markview).
--     Buffer-local options are safe to set directly; window-local ones have to
--     wait for `vim.schedule`, by which point a window is showing the buffer.
local function prose_settings(buf)
  -- Buffer-local options.
  local bo = vim.bo[buf]
  bo.textwidth = 0
  bo.wrapmargin = 0
  bo.spelllang = "en"

  vim.schedule(function()
    -- `conceallevel` is deliberately left alone: markview owns it, setting it
    -- to 3 while attached and back to 0 when detached.
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      local wo = vim.wo[win]
      wo.wrap = true
      wo.linebreak = true
      wo.breakindent = true
      wo.colorcolumn = "88"
      wo.spell = true
    end
  end)
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "rmd", "quarto", "text" },
  callback = function(ev) prose_settings(ev.buf) end,
})

-- Re-apply when the buffer is shown in a new split. `b:prose_wrap_manual` is
-- set by <Space>w so that opening a split does not undo a deliberate toggle.
-- BufWinEnter matches on the file name rather than the filetype, hence the
-- extension list rather than the filetype names used above.
vim.api.nvim_create_autocmd("BufWinEnter", {
  pattern = { "*.md", "*.markdown", "*.mdown", "*.mkd", "*.rmd", "*.qmd", "*.txt" },
  callback = function(ev)
    if vim.b[ev.buf].prose_wrap_manual == nil then prose_settings(ev.buf) end
  end,
})

-- NOTE: `syntax enable` deliberately lives *after* `require("lazy").setup(...)`
-- below. `:syntax enable` forces filetype detection for the file named on the
-- command line, so it emits FileType right here. If that happens before
-- lazy.nvim has registered its `ft` handlers, a filetype-scoped plugin such as
-- markview is never loaded the normal way -- lazy only rescans buffers after
-- setup without sourcing their `plugin/` files, so markview's autocommands (and
-- therefore the rendering) never get registered.

vim.diagnostic.config({
  float = { border = "rounded", source = "always" },
  virtual_text = { prefix = "●", spacing = 2 },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})

-- Do not load a colourscheme: the default highlight groups use the terminal
-- background and palette, so Neovim fits the rest of this Zsh terminal.
for _, group in ipairs({ "Normal", "NormalNC", "NormalFloat", "FloatBorder", "SignColumn", "EndOfBuffer" }) do
  vim.api.nvim_set_hl(0, group, { bg = "none" })
end

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  {
    "goolord/alpha-nvim",
    event = "VimEnter",
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

      dashboard.section.header.val = {
        "",
        "  ██████╗ ███████╗██╗  ████████╗ █████╗    ",
        "  ██╔══██╗██╔════╝██║  ╚══██╔══╝██╔══██╗   ",
        "  ██║  ██║█████╗  ██║     ██║   ███████║   ",
        "  ██║  ██║██╔══╝  ██║     ██║   ██╔══██║   ",
        "  ██████╔╝███████╗███████╗██║   ██║  ██║   ",
        "  ╚═════╝ ╚══════╝╚══════╝╚═╝   ╚═╝  ╚═╝   ",
        "",
      }
      dashboard.section.buttons.val = {
        dashboard.button("n", "󰈔  New file", ":enew <bar> startinsert<CR>"),
        dashboard.button("e", "󰉋  Browse files", ":Cd<CR>"),
        dashboard.button("p", "󰒲  Plugins", ":Lazy<CR>"),
        dashboard.button("q", "󰗼  Quit", ":qa<CR>"),
      }
      dashboard.section.footer.val = "Press a key to begin"
      dashboard.config.layout[1].val = 6
      dashboard.config.opts.noautocmd = true

      alpha.setup(dashboard.config)
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "auto",
        globalstatus = true,
        section_separators = { left = "", right = "" },
        component_separators = { left = "", right = "" },
      },
      sections = {
        lualine_a = { { "mode", fmt = function(mode) return mode:sub(1, 1) end } },
        lualine_b = { "branch" },
        lualine_c = { { "filename", path = 1, symbols = { modified = " ●", readonly = " " } } },
        lualine_x = { "diagnostics" },
        lualine_y = { "filetype" },
        lualine_z = { "location" },
      },
      inactive_sections = {
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "location" },
      },
    },
  },
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
    config = function(_, opts)
      local autopairs = require("nvim-autopairs")
      autopairs.setup(opts)

      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      require("cmp").event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end,
  },
  {
    "stevearc/oil.nvim",
    opts = {
      view_options = { show_hidden = true },
      keymaps = { ["q"] = "actions.close" },
    },
    dependencies = { "nvim-tree/nvim-web-devicons" },
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
    },
    config = function()
      local cmp = require("cmp")
      vim.lsp.config("*", {
        capabilities = require("cmp_nvim_lsp").default_capabilities(),
      })
      cmp.setup({
        snippet = { expand = function(args) vim.snippet.expand(args.body) end },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping.select_next_item(),
          ["<S-Tab>"] = cmp.mapping.select_prev_item(),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "path" },
          { name = "buffer" },
        }),
        window = {
          completion = cmp.config.window.bordered({ border = "rounded" }),
          documentation = cmp.config.window.bordered({ border = "rounded" }),
        },
      })
    end,
  },
  { "williamboman/mason.nvim", opts = { ui = { border = "rounded" } } },
  {
    -- Readable markdown: headings, emphasis, tables, checkboxes, code blocks
    -- and links are rendered in place, so notes can be read as prose rather
    -- than as raw markup. Only needs the `markdown` and `markdown_inline`
    -- parsers, both of which ship with Neovim, so this works even though the
    -- `tree-sitter` CLI is missing.
    "OXY2DEV/markview.nvim",
    ft = { "markdown", "rmd", "quarto" },
    opts = {
      -- Render a screenful around the cursor rather than the whole buffer.
      draw_range = { 60, 60 },
      -- The default is 1000 lines and markview silently stops drawing past it.
      -- Long notes hit that quickly, so raise it well clear.
      max_buf_lines = 20000,
      markdown = {
        -- Keep the language tag beside the code instead of floating it out to
        -- the right margin, where it reads as unrelated to the block.
        code_blocks = { label_direction = "left" },
      },
    },
    config = function(_, opts)
      require("markview").setup(opts)

      -- No colourscheme is loaded in this config (see the highlight reset near
      -- the top of the file), so markview cannot sample a palette: all 78 of
      -- its highlight groups are left undefined and the output is monochrome.
      -- markview's own `highlight_groups` option is a dead key -- nothing reads
      -- it -- so the groups have to be fed to its highlighter directly. It
      -- re-applies them on VimEnter, so this survives startup.
      --
      -- Each link points at one of Neovim's builtin groups, which are always
      -- defined and resolve against the terminal palette, keeping the terminal
      -- as the single source of colour.
      require("markview.highlights").setup({
        MarkviewHeading1 = { link = "Title" },
        MarkviewHeading1Sign = { link = "Constant" },
        MarkviewHeading2 = { link = "Title" },
        MarkviewHeading2Sign = { link = "Identifier" },
        MarkviewHeading3 = { link = "Function" },
        MarkviewHeading4 = { link = "Function" },
        MarkviewHeading5 = { link = "Identifier" },
        MarkviewHeading6 = { link = "Identifier" },

        MarkviewHyperlink = { link = "Underlined" },
        MarkviewEmail = { link = "Underlined" },
        MarkviewImage = { link = "Underlined" },
        MarkviewInlineCode = { link = "Special" },

        MarkviewCode = { link = "Visual" },
        MarkviewCodeFg = { link = "Normal" },
        MarkviewCodeInfo = { link = "Comment" },

        MarkviewCheckboxChecked = { link = "Constant" },
        MarkviewCheckboxUnchecked = { link = "Comment" },
        MarkviewCheckboxPending = { link = "Constant" },
        MarkviewCheckboxProgress = { link = "Constant" },
        MarkviewCheckboxCancelled = { link = "Comment" },
        MarkviewCheckboxStriked = { link = "Comment" },

        MarkviewBlockQuoteDefault = { link = "Comment" },
        MarkviewBlockQuoteNote = { link = "Comment" },
        MarkviewBlockQuoteSpecial = { link = "Special" },
        MarkviewBlockQuoteOk = { link = "Constant" },
        MarkviewBlockQuoteWarn = { link = "Todo" },
        MarkviewBlockQuoteError = { link = "Error" },

        MarkviewTableBorder = { link = "Comment" },
        MarkviewTableHeader = { link = "Title" },

        MarkviewListItemMinus = { link = "Constant" },
        MarkviewListItemPlus = { link = "Identifier" },
        MarkviewListItemStar = { link = "Special" },

        MarkviewComment = { link = "Comment" },
        MarkviewSpecial = { link = "Special" },
        MarkviewSubscript = { link = "Comment" },
        MarkviewSuperscript = { link = "Comment" },

        MarkviewIcon0 = { link = "Comment" },
        MarkviewIcon2 = { link = "Constant" },
        MarkviewIcon3 = { link = "Identifier" },
        MarkviewIcon3Fg = { link = "Normal" },
        MarkviewIcon4 = { link = "Special" },
        MarkviewIcon5 = { link = "Function" },
        MarkviewIcon6 = { link = "Type" },

        -- Only used for the `diff` code-block style and note callouts.
        MarkviewPalette0Fg = { link = "Comment" },
        MarkviewPalette1Fg = { link = "DiffText" },
        MarkviewPalette4Fg = { link = "DiffAdd" },
        MarkviewPalette2Sign = { link = "Comment" },
        MarkviewPalette6Sign = { link = "Comment" },

        -- Decorative heading gradients; Comment keeps them muted.
        MarkviewGradient1 = { link = "Comment" },
        MarkviewGradient2 = { link = "Comment" },
        MarkviewGradient3 = { link = "Comment" },
        MarkviewGradient4 = { link = "Comment" },
        MarkviewGradient5 = { link = "Comment" },
        MarkviewGradient6 = { link = "Comment" },
        MarkviewGradient7 = { link = "Comment" },
        MarkviewGradient8 = { link = "Comment" },
        MarkviewGradient9 = { link = "Comment" },
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local treesitter = require("nvim-treesitter")
      treesitter.setup()
      -- `tree-sitter` (the CLI) is what compiles parsers from source, so
      -- :TSInstall fails without it. Neovim bundles the c, lua, vim, vimdoc,
      -- query, markdown and markdown_inline parsers, and those bundled ones
      -- always win -- so markdown rendering works regardless. Only install
      -- the rest when the CLI is actually present.
      if vim.fn.executable("tree-sitter") == 1 then
        treesitter.install({
          "bash", "c", "cpp", "css", "dockerfile", "go", "html", "java",
          "javascript", "json", "lua", "python", "rust", "sql",
          "toml", "typescript", "xml", "yaml",
        })
      end
      vim.api.nvim_create_autocmd("FileType", {
        callback = function() pcall(vim.treesitter.start) end,
      })
    end,
  },
}, {
  checker = { enabled = false },
  change_detection = { notify = false },
})

-- Enable syntax *after* lazy.nvim is set up -- see the note above. Any buffer
-- named on the command line has already been read at this point, so this is
-- where its FileType event fires and filetype-scoped plugins get loaded.
vim.cmd.syntax("enable")

-- LSP: clangd for C/C++ (native vim.lsp, no nvim-lspconfig needed)
vim.lsp.config("clangd", {
  -- Without this, `vim.lsp.enable` below attaches clangd to *every* buffer,
  -- including markdown and text, where libclang emits nonsense diagnostics
  -- ("unable to handle compilation, expected exactly one compiler job in ''").
  filetypes = { "c", "cpp" },
  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy",
    "--completion-style=detailed",
    "--header-insertion=iwyu",
    "--suggest-missing-includes",
    "-j=4",
  },
  capabilities = require("cmp_nvim_lsp").default_capabilities(),
})
vim.lsp.enable("clangd")

-- <leader>r — build & run.
--
-- Inside an Exercism C++ exercise this does exactly what
-- https://exercism.org/docs/tracks/cpp/tests documents. Each exercise ships a
-- CMakeLists.txt whose final line is
--
--   add_custom_target(test_<name> ALL DEPENDS <name> COMMAND <name>)
--
-- so the test binary is part of the *default* build target: `cmake --build
-- build` compiles the solution, links it against the Catch2 runner in test/,
-- and then runs it. The build's output is therefore already the test report
-- and there is nothing left to execute afterwards.
--
-- Reconfiguring on every run is deliberate rather than wasteful. The exercise
-- CMakeLists decides at *configure* time whether to compile the solution's
-- .cpp:
--
--   if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${file}.cpp)
--     set(exercise_cpp ${file}.cpp)
--   endif()
--
-- so an exercise whose solution is still header-only bakes a build system that
-- never links that .cpp -- and it keeps doing so after the .cpp appears, with
-- no error, because nothing re-reads the CMakeLists. Re-running `cmake -S . -B
-- build` costs a few hundred milliseconds and picks the new file up.
-- -Wno-author silences the "Compatibility with CMake < 3.10 will be removed"
-- warning that the stock `cmake_minimum_required(VERSION 3.5.1)` emits on every
-- configure, which would otherwise bury the test summary.
local function exercism_root(start)
  -- The vendored Catch2 checkout is what makes this an Exercism exercise rather
  -- than any other CMake project that happens to be open. Globs rather than
  -- stats test/catch.hpp exactly: complex-numbers ships the amalgamated build
  -- as test/catch_amalgamated.{hpp,cpp} instead, so a hardcoded filename skips
  -- one of the track's 86 exercises.
  local function is_exercise(dir)
    return vim.uv.fs_stat(dir .. "/CMakeLists.txt") ~= nil
      and vim.fn.glob(dir .. "/test/catch*", true, true) ~= ""
  end

  -- `vim.fs.parents` yields ancestors only, so test `start` (the directory of
  -- the current buffer, which is where the solution usually lives) by hand.
  if is_exercise(start) then return start end
  for dir in vim.fs.parents(start) do
    if is_exercise(dir) then return dir end
  end
end

-- The last exercise built, so a repeat press still works from inside the output
-- split. That buffer is named `exercism://<exercise>`, so its `:p:h` is the
-- *current* working directory and the walk above would resolve to nothing --
-- and the press would silently fall through to the single-file compiler path.
local last_exercise

-- The window holding the solution file, i.e. the one to return to after a build.
-- <leader>r is often pressed from the quickfix window (a compile error leaves
-- the cursor there) or from the output split, and neither is a sensible place
-- to land: the quickfix window is about to be closed by `cclose`, so it cannot
-- be a valid target at all. Remember the last ordinary window instead.
local last_focus
local function focus_window()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.b[buf].exercism_output or vim.bo[buf].buftype == "quickfix" then
    if last_focus and vim.api.nvim_win_is_valid(last_focus) then return last_focus end
  else
    last_focus = win
  end
  return win
end

-- Show build output in a reusable bottom split. A terminal is the wrong tool
-- here: its scrollback is awkward to read at a glance, and the Catch2 summary
-- is only useful if it can be jumped back to, which a plain buffer can be.
local function output_split(lines, name)
  local win
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.b[vim.api.nvim_win_get_buf(w)].exercism_output then
      win = w
      break
    end
  end

  if win then
    -- Reuse the split from the last run. Its buffer has bufhidden=wipe, so
    -- replace it rather than writing over it -- the old report is stale and
    -- the new one is shorter about as often as it is longer.
    vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(false, true))
  else
    vim.cmd("botright 16split")
    win = vim.api.nvim_get_current_win()
  end

  -- A fresh split shows the *current* buffer, so it is still the solution
  -- file. Swap in a scratch buffer before touching any buffer-local option --
  -- setting buftype=nofile on the source buffer would quietly destroy it.
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win, buf)

  local bo = vim.bo[buf]
  bo.buftype = "nofile"
  bo.swapfile = false
  bo.bufhidden = "wipe"
  vim.api.nvim_buf_set_name(buf, "exercism://" .. name)
  -- Write the report *before* locking: `modifiable` has to be true for
  -- nvim_buf_set_lines, and nothing runs between these two lines.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  bo.modifiable = false
  vim.b[buf].exercism_output = true
end

-- Drop the previous run's report, e.g. because this run failed to compile and
-- leaving a stale green "All tests passed" on screen next to a red quickfix
-- window is actively misleading.
local function close_output_split()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.b[vim.api.nvim_win_get_buf(w)].exercism_output then
      vim.api.nvim_win_close(w, true)
      return
    end
  end
end

-- A g++/gcc diagnostic is the only thing in the output that should become a
-- quickfix entry. Catch2 failures are not compiler errors and do not parse into
-- locations, so they stay in the output split.
--
-- `%f[%a]` anchors on a letter boundary, so this matches the `error:` in
-- `acronym.cpp:2:64: error: 'nope' was not declared` but not a substring of
-- some longer identifier. Do not try to anchor the *end* of the match: gcc puts
-- a UTF-8 quote there ("error: 'nope'"), and a `%f[%W]` frontier would never be
-- satisfied, silently turning every real compile error into a test failure.
-- make's "*** Error 1" is capitalised and correctly ignored.
local function is_compile_error(line)
  return line:match("%f[%a]error:") ~= nil
end

-- Run a command without blocking, invoking `on_exit` somewhere the API is
-- actually usable. `vim.system`'s third argument is the async callback
-- (`:wait()` takes only a timeout, and blocks the editor), but it is delivered
-- from a libuv check handle -- a fast event context, where `setqflist` and
-- `nvim_create_buf` raise E5560. `vim.schedule_wrap` defers it to the main loop.
local function system(cmd, opts, on_exit)
  vim.system(cmd, opts, on_exit and vim.schedule_wrap(on_exit) or nil)
end

local function build_exercise(root)
  if vim.bo.modified then vim.cmd("write") end
  local name = vim.fn.fnamemodify(root, ":t")
  last_exercise = root

  -- Opening the output split moves the cursor into it. Send the cursor back to
  -- the solution, so the natural loop -- fix, `<leader>r`, read the notification
  -- -- never needs a `Ctrl-w j` first, and so a second press resolves against
  -- the solution file. The error paths deliberately do not refocus: there the
  -- quickfix window *is* the answer, so leave the cursor in it to read it.
  local focus = focus_window()
  local function refocus()
    if vim.api.nvim_win_is_valid(focus) then vim.api.nvim_set_current_win(focus) end
  end

  vim.notify("Building " .. name .. " ...", vim.log.levels.INFO)
  system({ "cmake", "-S", ".", "-B", "build", "-Wno-author" }, { cwd = root, text = true }, function(cfg)
    if cfg.code ~= 0 then
      vim.fn.setqflist({}, "r", {
        title = "CMake configure failed",
        lines = vim.split((cfg.stdout or "") .. (cfg.stderr or ""), "\n"),
      })
      vim.cmd("copen")
      vim.notify("CMake configure failed", vim.log.levels.ERROR)
      return
    end

    system({ "cmake", "--build", "build", "--parallel" }, { cwd = root, text = true }, function(res)
      local lines = vim.split((res.stdout or "") .. (res.stderr or ""), "\n", { trimempty = true })

      for _, line in ipairs(lines) do
        if is_compile_error(line) then
          -- Push the whole log, not just the `error:` lines: the `note:` and
          -- `  ~~~^` context that follows each one is in the same stream, and
          -- quickfix only surfaces the entries it can parse into locations.
          vim.fn.setqflist({}, "r", { title = "Compile errors", lines = lines })
          close_output_split()
          vim.cmd("copen")
          vim.notify("Compilation failed", vim.log.levels.ERROR)
          return
        end
      end

      -- Reached only when it compiled, so the tail is the test report. No error
      -- to look at any more, so retire the quickfix window from the last failed
      -- run rather than leaving it to crowd the report. There is no
      -- `getqflistwin()`; `getqflist()` reports the window as `winid`, and 0
      -- when none is open.
      if vim.fn.getqflist({ winid = 1 }).winid ~= 0 then vim.cmd("cclose") end
      output_split(lines, name)
      refocus()
      local joined = table.concat(lines, "\n")
      if res.code == 0 and joined:match("All tests passed") then
        local count = joined:match("(assertions:%s*%d+)")
        vim.notify(("All tests passed%s"):format(count and (" (" .. count .. ")") or ""), vim.log.levels.INFO)
      else
        local summary = joined:match("assertions:%s*%d+ %|[^\n]*")
          or joined:match("test cases:%s*%d+ %|[^\n]*")
        vim.notify("Tests failed" .. (summary and (": " .. summary) or ""), vim.log.levels.ERROR)
      end
    end)
  end)
end

-- Fallback for a plain C/C++ file that is not an Exercism exercise: compile the
-- single translation unit and run the result in a terminal.
local function compile_and_run()
  local file = vim.fn.expand("%:p")
  local ft = vim.bo.filetype
  if ft ~= "cpp" and ft ~= "c" then
    vim.notify("Not a C/C++ file", vim.log.levels.WARN)
    return
  end
  vim.cmd("write")
  local out = vim.fn.expand("%:p:r")
  local compiler = ft == "cpp" and "g++" or "gcc"
  local flags = { "-Wall", "-Wextra", "-std=c++23", "-O2", "-o", out, file }
  if ft == "c" then flags = { "-Wall", "-Wextra", "-std=c17", "-O2", "-o", out, file } end

  vim.notify("Compiling " .. vim.fn.fnamemodify(file, ":t") .. " ...", vim.log.levels.INFO)
  local output = vim.fn.systemlist({ compiler, unpack(flags) })
  local exit = vim.v.shell_error

  if exit ~= 0 then
    vim.fn.setqflist({}, "r", {
      title = "Compile errors",
      lines = output,
    })
    vim.cmd("copen")
    vim.notify("Compilation failed (" .. #output .. " errors)", vim.log.levels.ERROR)
    return
  end

  vim.notify("Running " .. vim.fn.fnamemodify(out, ":t") .. " ...", vim.log.levels.INFO)
  vim.cmd("botright split | resize 12 | terminal " .. vim.fn.shellescape(out))
end

vim.keymap.set("n", "<leader>r", function()
  -- For an unnamed buffer `%:p` expands to the cwd itself, so `:h` would strip
  -- a real directory off the end of it. Use the cwd verbatim in that case.
  local unnamed = vim.api.nvim_buf_get_name(0) == ""
  local dir = unnamed and vim.fn.getcwd() or vim.fn.expand("%:p:h")

  -- Prefer the exercise the current buffer lives in; fall back to the last one
  -- built, so pressing again from the output split (or the quickfix window)
  -- re-runs the same exercise instead of dropping into the single-file path.
  local root = exercism_root(dir) or (last_exercise and vim.uv.fs_stat(last_exercise) and last_exercise)
  if root then
    build_exercise(root)
  else
    compile_and_run()
  end
end, { desc = "Build & run (Exercism exercise, else single C/C++ file)" })

-- :Cd [directory] changes Neovim's working directory and opens that folder.
vim.api.nvim_create_user_command("Cd", function(opts)
  local directory = opts.args == "" and vim.fn.getcwd() or vim.fn.expand(opts.args)
  directory = vim.fn.fnamemodify(directory, ":p")
  if vim.fn.isdirectory(directory) == 0 then
    vim.notify("Not a directory: " .. directory, vim.log.levels.ERROR)
    return
  end
  vim.cmd.cd(vim.fn.fnameescape(directory))
  require("oil").open(directory)
end, { nargs = "?", complete = "dir", desc = "Change directory and open explorer" })

vim.keymap.set("n", "<leader>e", "<cmd>Cd<cr>", { desc = "Open file explorer" })
vim.keymap.set("n", "-", "<cmd>Oil<cr>", { desc = "Open parent directory" })

-- <leader>w — toggle soft-wrap. Sticks across window splits.
vim.keymap.set("n", "<leader>w", function()
  vim.wo.wrap = not vim.wo.wrap
  vim.b.prose_wrap_manual = true
  vim.notify("wrap: " .. (vim.wo.wrap and "on" or "off"))
end, { desc = "Toggle soft wrap" })
