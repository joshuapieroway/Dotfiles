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

-- <leader>r — compile & run the current C++ file
vim.keymap.set("n", "<leader>r", function()
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
end, { desc = "Compile & run C++ file" })

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
