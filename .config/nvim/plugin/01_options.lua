local now, later = Utils.now, Utils.later
local new_autocmd = Utils.new_autocmd

now(function()
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
	vim.o.winborder = "rounded" -- Use border in floating windows
	vim.o.wrap = false -- Don't visually wrap lines (toggle with <Leader>uw)

	vim.o.cursorlineopt = "screenline,number" -- Show cursor line per screen line

	-- Special UI symbols
	vim.opt.fillchars = { eob = " ", fold = " ", foldopen = "", foldclose = "", foldsep = " " }
	vim.o.listchars = "extends:…,nbsp:␣,precedes:…,tab:  "

	-- Folds
	vim.o.foldlevel = 99 -- Keep folds open by default
	vim.o.foldmethod = "indent" -- Fallback when Tree-sitter/LSP folding is unavailable
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

	new_autocmd({ "FocusGained", "TermClose", "TermLeave" }, nil, function()
		if vim.bo.buftype ~= "nofile" then
			vim.cmd("checktime")
		end
	end, "Check for externally changed files")
	new_autocmd("TextYankPost", nil, function()
		if vim.fn.has("nvim-0.13") == 1 then
			vim.hl.hl_op()
		else
			(vim.hl or vim.highlight).on_yank()
		end
	end, "Highlight yanked text")
	new_autocmd("VimResized", nil, function()
		local current_tab = vim.fn.tabpagenr()
		vim.cmd("tabdo wincmd =")
		vim.cmd("tabnext " .. current_tab)
	end, "Equalize splits after resizing")
	new_autocmd("FileType", "man", function(event)
		vim.bo[event.buf].buflisted = false
	end, "Unlist man pages")
	new_autocmd("FileType", { "text", "plaintex", "typst", "gitcommit", "markdown" }, function()
		vim.opt_local.wrap = true
		vim.opt_local.spell = true
	end, "Wrap and spell-check text")
	new_autocmd("FileType", { "json", "jsonc", "json5" }, function()
		vim.opt_local.conceallevel = 0
	end, "Disable JSON concealment")
	new_autocmd("BufWritePre", nil, function(event)
		if event.match:match("^%w%w+:[\\/][\\/]") then
			return
		end
		local file = vim.uv.fs_realpath(event.match) or event.match
		vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
	end, "Create missing parent directories")
	new_autocmd(
		"TermOpen",
		"term://*",
		vim.schedule_wrap(function(event)
			if vim.api.nvim_get_current_buf() == event.buf and vim.bo.buftype == "terminal" then
				vim.cmd("startinsert")
			end
		end),
		"Start terminal in Insert mode"
	)

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
