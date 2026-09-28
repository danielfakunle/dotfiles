local now, later = Utils.now, Utils.later
local new_autocmd = Utils.new_autocmd

now(function()
	require("mini.basics").setup({
		options = { basic = false, win_borders = "double" },
		mappings = {
			windows = true,
			option_toggle_prefix = [[\]],
		},
		autocommands = {
			basic = true,
		},
	})

	require("vim._core.ui2").enable({})

	-- General ====================================================================
	vim.g.mapleader = " " -- Use `<Space>` as <Leader> key
	vim.g.maplocalleader = "\\"

	vim.o.mouse = "a" -- Enable mouse
	vim.o.switchbuf = "usetab" -- Use already opened buffers when switching
	vim.o.undofile = true -- Enable persistent undo

	vim.o.shada = "'100,<50,s10,:1000,/100,@100,h" -- Limit ShaDa file (for startup)
	vim.o.scrolloff = 4
	vim.o.sidescrolloff = 8
	vim.o.relativenumber = true
	vim.o.clipboard = "unnamedplus"

	-- UI =========================================================================
	vim.o.breakindent = true -- Indent wrapped lines to match line start
	vim.o.breakindentopt = "list:-1" -- Add padding for lists (if 'wrap' is set)
	vim.o.cursorline = true -- Enable current line highlighting
	vim.o.linebreak = true -- Wrap lines at 'breakat' (if 'wrap' is set)
	vim.o.list = true -- Show helpful text indicators
	vim.o.number = true -- Show line numbers
	vim.o.pumborder = "single" -- Use border in popup menu
	vim.o.pumheight = 10 -- Make popup menu smaller
	vim.o.pummaxwidth = 100 -- Make popup menu not too wide
	vim.o.ruler = false -- Don't show cursor coordinates
	vim.o.shortmess = "CFOSWaco" -- Disable some built-in completion messages
	vim.o.showmode = false -- Don't show mode in command line
	vim.o.signcolumn = "yes" -- Always show signcolumn (less flicker)
	vim.o.splitbelow = true -- Horizontal splits will be below
	vim.o.splitkeep = "screen" -- Reduce scroll during window split
	vim.o.splitright = true -- Vertical splits will be to the right
	vim.o.winborder = "single" -- Use border in floating windows
	vim.o.wrap = false -- Don't visually wrap lines (toggle with \w)

	vim.o.cursorlineopt = "screenline,number" -- Show cursor line per screen line

	-- Special UI symbols. More is set via 'mini.basics' later.
	vim.o.fillchars = "eob: ,fold:╌"
	vim.o.listchars = "extends:…,nbsp:␣,precedes:…,tab:  "

	-- Folds
	vim.o.foldlevel = 10 -- Fold nothing by default; set to 0 or 1 to fold
	vim.o.foldmethod = "indent" -- Fold based on indent level
	vim.o.foldnestmax = 10 -- Limit number of fold levels
	vim.o.foldtext = "" -- Show text under fold with its highlighting

	-- Editing ====================================================================
	vim.o.autoindent = true -- Use auto indent
	vim.o.expandtab = true -- Convert tabs to spaces
	vim.o.formatoptions = "rqnl1j" -- Improve comment editing
	vim.o.ignorecase = true -- Ignore case during search
	vim.o.incsearch = true -- Show search matches while typing
	vim.o.infercase = true -- Infer case in built-in completion
	vim.o.shiftwidth = 2 -- Use this number of spaces for indentation
	vim.o.smartcase = true -- Respect case if search pattern has upper case
	vim.o.smartindent = true -- Make indenting smart
	vim.o.spelloptions = "camel" -- Treat camelCase word parts as separate words
	vim.o.tabstop = 2 -- Show tab as this number of spaces
	vim.o.virtualedit = "block" -- Allow going past end of line in blockwise mode

	vim.o.iskeyword = "@,48-57,_,192-255,-" -- Treat dash as `word` textobject part

	-- Pattern for a start of numbered list (used in `gw`).
	vim.o.formatlistpat = [[^\s*[0-9\-\+\*]\+[\.\)]*\s\+]]

	-- Built-in completion
	vim.o.complete = ".,w,b,kspell" -- Use less sources
	vim.o.completeopt = "menuone,noselect,fuzzy,nosort" -- Use custom behavior
	vim.o.completetimeout = 100 -- Limit sources delay

	local f = function()
		vim.cmd("setlocal formatoptions-=c formatoptions-=o")
	end
	new_autocmd("FileType", nil, f, "Proper 'formatoptions'")

	new_autocmd("FileType", {
		"PlenaryTestPopup",
		"checkhealth",
		"dap-float",
		"dbout",
		"gitsigns-blame",
		"grug-far",
		"help",
		"lspinfo",
		"neotest-output",
		"neotest-output-panel",
		"neotest-summary",
		"notify",
		"qf",
		"spectre_panel",
		"startuptime",
		"tsplayground",
	}, function(event)
		vim.bo[event.buf].buflisted = false
		vim.schedule(function()
			vim.keymap.set("n", "q", function()
				vim.cmd("close")
				pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
			end, {
				buffer = event.buf,
				silent = true,
				desc = "Quit buffer",
			})
		end)
	end)
	new_autocmd("BufEnter", "*", function()
		local q_map = vim.fn.maparg("q", "n", false, true)
		if vim.bo.buftype == "nofile" and q_map.buffer ~= 1 then
			vim.keymap.set("n", "q", "<cmd>bd!<cr>", { buffer = true, silent = true })
		end
	end)

	vim.filetype.add({
		extension = { mdx = "mdx" },
	})
end)

local diagnostic_opts = {
	signs = { priority = 9999, severity = { min = "WARN", max = "ERROR" } },
	underline = { severity = { min = "HINT", max = "ERROR" } },
	virtual_lines = false,
	virtual_text = {
		current_line = true,
		severity = { min = "ERROR", max = "ERROR" },
	},
	update_in_insert = false,
}

later(function()
	vim.diagnostic.config(diagnostic_opts)
end)
