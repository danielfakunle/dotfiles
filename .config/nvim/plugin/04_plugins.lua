local now, now_if_args, later, new_autocmd = Utils.now, Utils.now_if_args, Utils.later, Utils.new_autocmd
local add, gh, map, map_leader, jump_lsp_reference =
	Utils.add, Utils.gh, Utils.map, Utils.map_leader, Utils.jump_lsp_reference

-- Like LazyVim, replace defaults/runtime settings but preserve custom local options.
local fold_defaults = { foldmethod = vim.o.foldmethod, foldexpr = vim.o.foldexpr }
local managed_fold_values = {}
local set_fold_default = function(option, value)
	local current = vim.api.nvim_get_option_value(option, { scope = "local" })
	managed_fold_values[option .. "=" .. value] = true
	if current ~= fold_defaults[option] and not managed_fold_values[option .. "=" .. current] then
		local info = vim.api.nvim_get_option_info2(option, { scope = "local" })
		local runtime_setting = false
		for _, script in ipairs(vim.fn.getscriptinfo()) do
			if script.sid == info.last_set_sid and vim.startswith(script.name, vim.env.VIMRUNTIME) then
				runtime_setting = true
				break
			end
		end
		if not runtime_setting then
			return false
		end
	end
	vim.api.nvim_set_option_value(option, value, { scope = "local" })
	return true
end

local has_treesitter_folds = function(buf)
	local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
	if not lang or not pcall(vim.treesitter.language.add, lang) then
		return false
	end
	local ok, query = pcall(vim.treesitter.query.get, lang, "folds")
	return ok and query ~= nil
end

Config.foldexpr = function()
	return has_treesitter_folds(0) and vim.treesitter.foldexpr() or "0"
end

-- Completion (before LSP setup so every server receives Blink capabilities)
now(function()
	add({
		{ src = gh("saghen/blink.cmp"), version = vim.version.range("1.*") },
		gh("rafamadriz/friendly-snippets"),
	})

	require("blink.cmp").setup({
		snippets = { preset = "mini_snippets" },
		appearance = { nerd_font_variant = "mono" },
		keymap = {
			preset = "enter",
			["<C-y>"] = { "select_and_accept", "fallback" },
			-- Signature help is handled by the capability-aware LSP mapping.
			["<C-k>"] = false,
		},
		completion = {
			accept = { auto_brackets = { enabled = true } },
			menu = { draw = { treesitter = { "lsp" } } },
			documentation = { auto_show = true, auto_show_delay_ms = 200 },
		},
		sources = { default = { "lsp", "path", "snippets", "buffer" } },
		cmdline = {
			enabled = true,
			keymap = { preset = "cmdline", ["<Right>"] = false, ["<Left>"] = false },
			completion = {
				list = { selection = { preselect = false } },
				menu = {
					auto_show = function()
						return vim.fn.getcmdtype() == ":"
					end,
				},
				ghost_text = { enabled = true },
			},
		},
	})
	vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
end)

-- Picker and toggles: retain MiniFiles, MiniNotify, and the existing startup UI.
now(function()
	add({ gh("folke/snacks.nvim") })
	require("snacks").setup({
		toggle = { which_key = false },
		picker = {
			enabled = true,
			win = {
				input = {
					keys = { ["<a-c>"] = { "toggle_cwd", mode = { "n", "i" } } },
				},
			},
			actions = {
				toggle_cwd = function(picker)
					local root = Utils.project_root(picker.input.filter.current_buf)
					local cwd = vim.fn.getcwd()
					picker:set_cwd(picker:cwd() == root and cwd or root)
					picker:find()
				end,
			},
		},
	})
end)

-- Statusline
now(function()
	add({ gh("nvim-lualine/lualine.nvim") })
	require("lualine").setup({
		options = {
			theme = "auto",
			disabled_filetypes = { statusline = { "ministarter" } },
		},
		sections = {
			lualine_a = { "mode" },
			lualine_b = { "branch" },
			lualine_c = { "diagnostics", { "filename", path = 1 } },
			lualine_x = { "diff", "filetype" },
			lualine_y = { "progress" },
			lualine_z = { "location" },
		},
	})
end)

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
		"lua",
		"markdown",
		"markdown_inline",
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
		pcall(vim.treesitter.start, ev.buf)
	end
	new_autocmd("FileType", filetypes, ts_start, "Start tree-sitter")
	new_autocmd("FileType", nil, function(ev)
		if has_treesitter_folds(ev.buf) and set_fold_default("foldmethod", "expr") then
			set_fold_default("foldexpr", "v:lua.Config.foldexpr()")
		end
	end, "Enable Tree-sitter folds when supported")
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

	require("snacks").util.lsp.on({ method = "textDocument/foldingRange" }, function(buf)
		-- Fold options belong to windows, not buffers; update every visible split.
		for _, win in ipairs(vim.fn.win_findbuf(buf)) do
			vim.api.nvim_win_call(win, function()
				if set_fold_default("foldmethod", "expr") then
					set_fold_default("foldexpr", "v:lua.vim.lsp.foldexpr()")
				end
			end)
		end
	end)

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
		format_on_save = function(buf)
			local enabled = vim.b[buf].autoformat
			if enabled == nil then
				enabled = vim.g.autoformat ~= false
			end
			if enabled then
				return {}
			end
		end,
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

	-- A tool name alone also matches external sessions and opens a picker.
	local opencode = function(action, opts)
		local cli = require("sidekick.cli")
		local State = require("sidekick.cli.state")
		opts = opts or {}
		-- Render before opening a terminal so file/selection context stays intact.
		if action == "send" and not opts.text then
			local msg, text = cli.render(opts)
			if msg == "" or not text then
				vim.notify("Nothing to send.", vim.log.levels.WARN)
				return
			end
			opts.text = text
		end
		local state = State.get({ name = "opencode", external = false, cwd = true })[1]
		if not state then
			if action == "close" then
				return
			end
			if vim.fn.executable("opencode") ~= 1 then
				vim.notify("OpenCode is not installed.", vim.log.levels.ERROR)
				return
			end
			local Session = require("sidekick.cli.session")
			state = State.attach(State.get_state(Session.new({ tool = "opencode", backend = "terminal" })))
			-- Starting the terminal already opens it; don't immediately toggle it off.
			if action == "toggle" or action == "focus" then
				action = "show"
			end
		end
		opts.filter = { name = "opencode", session = state.session.id }
		cli[action](opts)
	end

	map("n", "<c-.>", function()
		opencode("focus")
	end, "Focus AI Buffer")
	map_leader("n", "aa", function()
		opencode("toggle")
	end, "Toggle CLI")
	map_leader("n", "as", function()
		require("sidekick.cli").select({ filter = { installed = true } })
	end, "Select CLI")
	map_leader("n", "ad", function()
		opencode("close")
	end, "Detach a CLI Session")
	map_leader({ "n", "x" }, "at", function()
		opencode("send", { msg = "{this}" })
	end, "Send This")
	map_leader("n", "af", function()
		opencode("send", { msg = "{file}" })
	end, "Send File")
	map_leader("x", "av", function()
		opencode("send", { msg = "{selection}" })
	end, "Send Visual Selection")
	map_leader({ "n", "x" }, "ap", function()
		require("sidekick.cli").prompt({
			cb = function(_, text)
				if text then
					opencode("send", { text = text })
				end
			end,
		})
	end, "Select Prompt")
end)
