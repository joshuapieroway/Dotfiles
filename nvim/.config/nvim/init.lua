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

vim.diagnostic.config({
    float = { border = "rounded", source = "always" },
    virtual_text = { prefix = "●", spacing = 2 },
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
})

-- No colourscheme: default groups use the terminal palette, so nvim matches the terminal.
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
                dashboard.button("e", "󰉋  Browse files", ":Oil<CR>"),
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
        "nvim-treesitter/nvim-treesitter",
        lazy = false,
        build = ":TSUpdate",
        config = function()
            local treesitter = require("nvim-treesitter")
            treesitter.setup()
            -- :TSInstall needs the tree-sitter CLI; bundled parsers win anyway.
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

vim.lsp.config("clangd", {
    -- Restrict clangd to c/cpp, else libclang emits nonsense diagnostics in other files.
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

vim.keymap.set("n", "<leader>cd", "<cmd>Oil<cr>", { desc = "Open file explorer" })
vim.keymap.set("n", "-", "<cmd>Oil<cr>", { desc = "Open parent directory" })

-- <leader>w — toggle soft-wrap.
vim.keymap.set("n", "<leader>w", function()
    vim.wo.wrap = not vim.wo.wrap
    vim.notify("wrap: " .. (vim.wo.wrap and "on" or "off"))
end, { desc = "Toggle soft wrap" })
