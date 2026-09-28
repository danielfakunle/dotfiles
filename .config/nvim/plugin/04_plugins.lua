local now, now_if_args, later, new_autocmd = Utils.now, Utils.now_if_args, Utils.later, Utils.new_autocmd
local add, gh, map, map_leader, jump_lsp_reference =
	Utils.add, Utils.gh, Utils.map, Utils.map_leader, Utils.jump_lsp_reference

-- Treesitter
now_if_args(function()
	local ts_update = function()
		vim.cmd("TSUpdate")
	end
	Utils.on_packchanged("nvim-treesitter", { "update" }, ts_update, ":TSUpdate")

	add({
		gh("nvim-treesitter/nvim-treesitter"),
		gh("nvim-treesitter/nvim-treesitter-textobjects"),
	})

	local languages = {
		"typescript",
		"javascript",
		"tsx",
		"html",
		"css",
		"json",
		"bash",
		"http",
		"dockerfile",
		"latex",
		"yaml",
	}
	local isnt_installed = function(lang)
		return #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".*", false) == 0
	end
	local to_install = vim.tbl_filter(isnt_installed, languages)
	if #to_install > 0 then
		require("nvim-treesitter").install(to_install)
	end

	local filetypes = {}
	for _, lang in ipairs(languages) do
		for _, ft in ipairs(vim.treesitter.language.get_filetypes(lang)) do
			table.insert(filetypes, ft)
		end
	end
	local ts_start = function(ev)
		vim.treesitter.start(ev.buf)
	end
	new_autocmd("FileType", filetypes, ts_start, "Start tree-sitter")
end)

-- LSP
now_if_args(function()
	add({
		gh("neovim/nvim-lspconfig"),
		gh("mason-org/mason.nvim"),
		gh("mason-org/mason-lspconfig.nvim"),
		gh("WhoIsSethDaniel/mason-tool-installer.nvim"),
		gh("b0o/schemastore.nvim"),
	})

	require("mason").setup()

	vim.lsp.config("*", {
		root_markers = { ".git" },
	})

	vim.lsp.config("lua_ls", {
		settings = {
			Lua = {
				json = {
					schemas = require("schemastore").json.schemas(),
					validate = { enable = true },
				},
				workspace = {
					checkThirdParty = false,
					library = {
						vim.env.VIMRUNTIME,
						vim.api.nvim_get_runtime_file("lua/lspconfig", false)[1],
					},
				},
			},
		},
	})

	vim.lsp.config("tailwindcss", {
		settings = {
			tailwindCSS = {
				classFunctions = { "cva", "cx", "cn" },
				experimental = {
					classRegex = {
						{ '[cls|className]\\s\\:\\=\\s"([^"]*)' },
					},
				},
			},
		},
	})

	vim.lsp.config("yamlls", {
		capabilities = {
			textDocument = {
				foldingRange = {
					dynamicRegistration = false,
					lineFoldingOnly = true,
				},
			},
		},
		settings = {
			redhat = { telemetry = { enabled = false } },
			yaml = {
				schemas = require("schemastore").yaml.schemas(),
				keyOrdering = false,
				format = {
					enable = true,
				},
				validate = true,
				schemaStore = {
					enable = false,
					url = "",
				},
			},
		},
	})

	require("mason-lspconfig").setup({
		automatic_enable = {
			exclude = {
				"oxfmt",
			},
		},
	})

	require("mason-tool-installer").setup({
		ensure_installed = {
			-- LSP
			"lua_ls",
			"tsc",
			"oxlint",
			"yamlls",
			"jsonls",
			"tailwindcss",
			-- Formatters
			"stylua",
			"oxfmt",
		},
	})

	map({ "n", "x" }, "]]", function()
		jump_lsp_reference(vim.v.count1)
	end, "Next Reference", { has = "documentHighlight" })
	map({ "n", "x" }, "[[", function()
		jump_lsp_reference(-vim.v.count1)
	end, "Prev Reference", { has = "documentHighlight" })
end)

-- Formatting
later(function()
	add({ gh("stevearc/conform.nvim") })

	require("conform").setup({
		default_format_opts = {
			lsp_format = "fallback",
		},
		format_on_save = true,
		formatters_by_ft = {
			lua = { "stylua" },
			javascript = { "oxfmt" },
			javascriptreact = { "oxfmt" },
			typescript = { "oxfmt" },
			typescriptreact = { "oxfmt" },
			json = { "oxfmt" },
			vue = { "oxfmt" },
			markdown = { "oxfmt" },
			mdx = { "oxfmt" },
		},
	})
end)

-- Snippets
later(function()
	add({ gh("rafamadriz/friendly-snippets") })
end)

-- Colorscheme
now(function()
	add({ gh("danielfakunle/grisaille") })

	require("grisaille").setup()

	vim.cmd.colorscheme("grisaille")
end)

-- Misc
now_if_args(function()
	add({
		gh("windwp/nvim-ts-autotag"),
		gh("MagicDuck/grug-far.nvim"),
	})
	require("nvim-ts-autotag").setup()

	require("grug-far").setup()
	map_leader({ "n", "x" }, "sr", function()
		local grug = require("grug-far")
		local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
		grug.open({
			transient = true,
			prefills = {
				filesFilter = ext and ext ~= "" and "*." .. ext or nil,
			},
		})
	end, "Replace")
end)

-- Lazygit
later(function()
	add({
		gh("kdheepak/lazygit.nvim"),
	})
	map("n", "<leader>gg", "<cmd>LazyGit<cr>", "LazyGit")
end)

-- AI
later(function()
	add({
		gh("folke/sidekick.nvim"),
	})
	require("sidekick").setup({
		nes = { enabled = false },
		cli = {
			win = {
				split = {
					width = 0.4,
				},
			},
		},
	})

	map("n", "<c-.>", function()
		require("sidekick.cli").focus({ name = "opencode" })
	end, "Focus AI Buffer")
	map_leader("n", "aa", function()
		require("sidekick.cli").toggle({ name = "opencode" })
	end, "Toggle CLI")
	map_leader("n", "as", function()
		require("sidekick.cli").select({ filter = { installed = true } })
	end, "Select CLI")
	map_leader("n", "ad", function()
		require("sidekick.cli").close()
	end, "Detach a CLI Session")
	map_leader({ "n", "x" }, "at", function()
		require("sidekick.cli").send({ msg = "{this}", name = "opencode" })
	end, "Send This")
	map_leader("n", "af", function()
		require("sidekick.cli").send({ msg = "{file}", name = "opencode" })
	end, "Send File")
	map_leader("x", "av", function()
		require("sidekick.cli").send({ msg = "{selection}", name = "opencode" })
	end, "Send Visual Selection")
	map_leader({ "n", "x" }, "ap", function()
		require("sidekick.cli").prompt({ name = "opencode" })
	end, "Select Prompt")
end)
