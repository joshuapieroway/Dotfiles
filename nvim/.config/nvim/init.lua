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
vim.cmd.syntax("enable")

vim.diagnostic.config({ float = { border = "rounded" } })

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
  { "neovim/nvim-lspconfig" },
  { "williamboman/mason.nvim", opts = { ui = { border = "rounded" } } },
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
    opts = { automatic_enable = true },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local treesitter = require("nvim-treesitter")
      treesitter.setup()
      if vim.fn.executable("tree-sitter") == 1 then
        treesitter.install({
          "bash", "c", "cpp", "css", "dockerfile", "go", "html", "java",
          "javascript", "json", "lua", "markdown", "python", "rust", "sql",
          "toml", "typescript", "vim", "vimdoc", "xml", "yaml",
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
