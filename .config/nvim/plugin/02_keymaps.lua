local map_leader, map, pick = Utils.map_leader, Utils.map, Utils.pick

-- General
map("x", "p", [["_dP]], "Paste over selection without losing yanked text")
map({ "n", "v" }, "<leader>d", [["_d]], "Delete Without Yanking")
map("n", "<Esc>", ":nohl<CR>", "Clear search highlighting", { silent = true })
map("v", "<", "<gv", "Unindent and keep selection")
map("v", ">", ">gv", "Indent and keep selection")
map("n", "n", "nzzzv", "Next search result cursor centered")
map("n", "N", "Nzzzv", "Previous search result cursor centered")
map("n", "<leader>nr", "<cmd>restart<cr>", "Restart")

-- Basic editing (explicit replacements for mini.basics)
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", "Down", { expr = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", "Up", { expr = true })
Config.put_empty_line = function(put_above)
	if type(put_above) == "boolean" then
		vim.o.operatorfunc = "v:lua.Config.put_empty_line"
		Config.empty_line_above = put_above
		return "g@l"
	end
	local line = vim.fn.line(".") - (Config.empty_line_above and 1 or 0)
	vim.fn.append(line, vim.fn["repeat"]({ "" }, vim.v.count1))
end
map("n", "go", "v:lua.Config.put_empty_line(v:false)", "Put empty line below", { expr = true })
map("n", "gO", "v:lua.Config.put_empty_line(v:true)", "Put empty line above", { expr = true })
map("x", "gy", '"+y', "Copy to system clipboard")
map("n", "gp", '"+p', "Paste from system clipboard")
map("x", "gp", '"+P', "Paste from system clipboard")
map("n", "gV", '"g`[" . strpart(getregtype(), 0, 1) . "g`]"', "Visually select changed text", {
	expr = true,
	replace_keycodes = false,
})
map("x", "g/", "<Esc>/\\%V", "Search inside visual selection", { silent = false })
local clear_commands = { "silent normal! <C-c>", "let v:hlsearch = 0", "diffupdate" }
if vim.fn.has("nvim-0.13") == 1 then
	table.insert(clear_commands, 'call nvim_buf_clear_namespace(0, nvim_create_namespace("nvim.multicursor"), 0, -1)')
end
table.insert(clear_commands, "silent normal! <C-l>")
map("n", "<C-c>", "<Cmd>" .. table.concat(clear_commands, "<CR><Cmd>") .. "<CR>", "Stop, clear, redraw")
map("n", "<C-s>", "<Cmd>silent! update | redraw<CR>", "Save")
map({ "i", "x" }, "<C-s>", "<Esc><Cmd>silent! update | redraw<CR>", "Save and go to Normal mode")

-- Windows
map("n", "<C-h>", "<C-w>h", "Go to Left Window", { remap = true })
map("n", "<C-j>", "<C-w>j", "Go to Lower Window", { remap = true })
map("n", "<C-k>", "<C-w>k", "Go to Upper Window", { remap = true })
map("n", "<C-l>", "<C-w>l", "Go to Right Window", { remap = true })
map("n", "<C-Up>", "<Cmd>resize +2<CR>", "Increase Window Height")
map("n", "<C-Down>", "<Cmd>resize -2<CR>", "Decrease Window Height")
map("n", "<C-Left>", "<Cmd>vertical resize -2<CR>", "Decrease Window Width")
map("n", "<C-Right>", "<Cmd>vertical resize +2<CR>", "Increase Window Width")
map_leader("n", "-", "<C-w>s", "Split Window Below", { remap = true })
map_leader("n", "|", "<C-w>v", "Split Window Right", { remap = true })
map_leader("n", "wd", "<C-w>c", "Delete Window", { remap = true })
map_leader("n", "wm", "<Cmd>lua MiniMisc.zoom()<CR>", "Toggle Zoom")
map_leader("n", "uZ", "<Cmd>lua MiniMisc.zoom()<CR>", "Toggle Zoom")

-- Explore
local explore_at_file = function()
	if MiniFiles.close() then
		return
	end
	local path = vim.api.nvim_buf_get_name(0)
	local root = Utils.project_root()
	local stat = vim.bo.buftype == "" and vim.uv.fs_stat(path) or nil
	local directory = vim.bo.buftype == "" and path ~= "" and vim.fs.dirname(path) or root
	if stat and stat.type == "directory" then
		directory = path
	end
	if not vim.uv.fs_stat(directory) then
		directory = root
	end
	local branch = { directory }
	while branch[1] ~= root do
		local parent = vim.fs.dirname(branch[1])
		if not parent or parent == branch[1] then
			break
		end
		table.insert(branch, 1, parent)
	end
	local depth_focus = #branch
	if stat and stat.type == "file" then
		branch[#branch + 1] = path
	end
	-- Fit the whole project-to-file branch instead of hiding its root column.
	local width = math.max(1, math.floor(vim.o.columns / (#branch + 1)) - 2)
	MiniFiles.open(root, false, {
		windows = {
			width_focus = math.min(50, width),
			width_nofocus = math.min(15, width),
			width_preview = math.min(50, width),
		},
	})
	MiniFiles.set_branch(branch, { depth_focus = depth_focus })
end

local explore = function()
	if not MiniFiles.close() then
		MiniFiles.open(vim.fn.getcwd(), false)
	end
end

map_leader("n", "eE", explore, "Explore Directory (cwd)")
map_leader("n", "ee", explore_at_file, "Explore File Directory (project visible)")

-- LSP
local remove_lsp_mapping = function(mode, lhs)
	local map_desc = vim.fn.maparg(lhs, mode, false, true).desc
	if map_desc == nil or string.find(map_desc, "vim%.lsp") == nil then
		return
	end
	vim.keymap.del(mode, lhs)
end
remove_lsp_mapping("n", "gra")
remove_lsp_mapping("x", "gra")
remove_lsp_mapping("n", "gri")
remove_lsp_mapping("n", "grn")
remove_lsp_mapping("n", "grr")
remove_lsp_mapping("n", "grt")
remove_lsp_mapping("n", "grx")
map("n", "gd", pick("lsp_definitions", { auto_confirm = true }), "Goto Definition", { has = "definition" })
map("n", "gD", pick("lsp_declarations", { auto_confirm = true }), "Goto Declaration", { has = "declaration" })
map(
	"n",
	"gy",
	pick("lsp_type_definitions", { auto_confirm = true }),
	"Goto T[y]pe Definition",
	{ has = "typeDefinition" }
)
map(
	"n",
	"gr",
	pick("lsp_references", { auto_confirm = true }),
	"Goto References",
	{ nowait = true, has = "references" }
)
map("n", "gI", pick("lsp_implementations", { auto_confirm = true }), "Goto Implementation", { has = "implementation" })
map("n", "K", "<Cmd>lua vim.lsp.buf.hover()<CR>", "Hover")
map("n", "gK", "<Cmd>lua vim.lsp.buf.signature_help()<CR>", "Signature Help", { has = "signatureHelp" })
map("i", "<c-k>", "<Cmd>lua vim.lsp.buf.signature_help()<CR>", "Signature Help", { has = "signatureHelp" })

-- Clues
Config.leader_group_clues = {
	-- Normal Mode
	{ mode = "n", keys = "<Leader>b", desc = "+Buffer" },
	{ mode = "n", keys = "<Leader>u", desc = "+UI" },
	{ mode = "n", keys = "<Leader>w", desc = "+Window" },
	{ mode = "n", keys = "<Leader>n", desc = "+Neovim" },
	{ mode = "n", keys = "<Leader>c", desc = "+Code" },
	{ mode = "n", keys = "<Leader>f", desc = "+Find" },
	{ mode = "n", keys = "<Leader>e", desc = "+Explore" },
	{ mode = "n", keys = "<Leader>p", desc = "+Plugin" },
	{ mode = "n", keys = "<Leader>x", desc = "+Examine" },
	{ mode = "n", keys = "<Leader>o", desc = "+Other" },
	{ mode = "n", keys = "<Leader>t", desc = "+Terminal" },
	{ mode = "n", keys = "<Leader>g", desc = "+Git" },
	{ mode = "n", keys = "<Leader>s", desc = "+Search" },
	{ mode = "n", keys = "<Leader>a", desc = "+AI" },

	-- Visual Mode Only
	{ mode = "x", keys = "<Leader>c", desc = "+Code" },
	{ mode = "x", keys = "<Leader>f", desc = "+Find" },
	{ mode = "x", keys = "<Leader>s", desc = "+Search" },
}

-- b is for 'Buffer'
local new_scratch_buffer = function()
	vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, true))
end

map_leader("n", "ba", "<Cmd>b#<CR>", "Alternate")
map_leader("n", "bd", "<Cmd>lua MiniBufremove.delete()<CR>", "Delete")
map_leader("n", "bD", "<Cmd>lua MiniBufremove.delete(0, true)<CR>", "Delete!")
map_leader("n", "bs", new_scratch_buffer, "Scratch")
map_leader("n", "bw", "<Cmd>lua MiniBufremove.wipeout()<CR>", "Wipeout")
map_leader("n", "bW", "<Cmd>lua MiniBufremove.wipeout(0, true)<CR>", "Wipeout!")

-- u is for "UI"
map_leader("n", "un", "<Cmd>lua MiniNotify.show_history()<CR>", "Show Notifications")
map_leader("n", "ur", "<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>", "Redraw / Clear hlsearch / Diff Update")

Utils.later(function()
	local toggle = require("snacks").toggle
	local autoformat_enabled = function()
		if vim.b.autoformat ~= nil then
			return vim.b.autoformat
		end
		return vim.g.autoformat ~= false
	end
	toggle({
		name = "Autoformat (Global)",
		get = function()
			return vim.g.autoformat ~= false
		end,
		set = function(state)
			vim.g.autoformat = state
			vim.b.autoformat = nil
		end,
	}):map("<leader>uf")
	toggle({
		name = "Autoformat (Buffer)",
		get = autoformat_enabled,
		set = function(state)
			vim.b.autoformat = state
		end,
	}):map("<leader>uF")
	toggle.option("spell", { name = "Spelling" }):map("<leader>us")
	toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
	toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
	toggle.diagnostics():map("<leader>ud")
	toggle.line_number():map("<leader>ul")
	toggle
		.option("conceallevel", {
			name = "Conceal Level",
			off = 0,
			on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2,
		})
		:map("<leader>uc")
	toggle
		.option("showtabline", {
			name = "Tabline",
			off = 0,
			on = vim.o.showtabline > 0 and vim.o.showtabline or 2,
		})
		:map("<leader>uA")
	toggle.treesitter():map("<leader>uT")
	toggle.option("background", { name = "Dark Background", off = "light", on = "dark" }):map("<leader>ub")
	if vim.lsp.inlay_hint then
		toggle.inlay_hints():map("<leader>uh")
	end
	toggle({
		name = "Indent Scope",
		get = function()
			return not (vim.g.miniindentscope_disable or vim.b.miniindentscope_disable)
		end,
		set = function(state)
			vim.b.miniindentscope_disable = not state
			if not state then
				MiniIndentscope.undraw()
			else
				MiniIndentscope.draw()
			end
		end,
	}):map("<leader>ug")
end)

-- n is for "Neovim"
map_leader({ "n", "x" }, "np", "g<", "Focus UI2 pager")

-- c is for "Code"
map_leader({ "n", "x" }, "cf", '<Cmd>lua require("conform").format()<CR>', "Format")
map_leader({ "n", "x" }, "ca", vim.lsp.buf.code_action, "Actions", { has = "codeAction" })
map_leader({ "n", "x" }, "cc", vim.lsp.codelens.run, "Lens", { has = "codeLens" })
map_leader("n", "cr", vim.lsp.buf.rename, "Rename", { has = "rename" })
map_leader("n", "cd", "<Cmd>lua vim.diagnostic.open_float()<CR>", "Diagnostic popup")

-- f is for "Fuzzy Find"
map_leader("n", "ff", pick("files"), "Find Files (project)")
map_leader("n", "fF", pick("files", { project = false }), "Find Files (cwd)")
map_leader("n", "<space>", pick("files"), "Find Files (project)")
map_leader("n", "fb", pick("buffers"), "Buffers")
map_leader("n", ",", pick("buffers"), "Buffers")
map_leader("n", "fB", pick("buffers", { hidden = true, nofile = true }), "Buffers (all)")
map_leader("n", "fc", pick("files", { cwd = vim.fn.stdpath("config") }), "Find Config Files")
map_leader("n", "fg", pick("git_files"), "Find Files (git)")
map_leader("n", "fn", "<Cmd>enew<CR>", "New File")
map_leader("n", "fr", pick("recent", { filter = { cwd = true } }), "Recent Files (project)")
map_leader("n", "fR", pick("recent", { project = false, filter = { cwd = true } }), "Recent Files (cwd)")

-- s is for "Search"
map_leader("n", "sg", pick("grep"), "Grep (project)")
map_leader("n", "/", pick("grep"), "Grep (project)")
map_leader("n", "sG", pick("grep", { project = false }), "Grep (cwd)")
map_leader({ "n", "x" }, "sw", pick("grep_word"), "Word or Selection (project)")
map_leader({ "n", "x" }, "sW", pick("grep_word", { project = false }), "Word or Selection (cwd)")
map_leader("n", "sb", pick("lines"), "Buffer Lines")
map_leader("n", "sB", pick("grep_buffers"), "Grep Open Buffers")
map_leader("n", "ss", pick("lsp_symbols"), "Document Symbols", { has = "documentSymbol" })
map_leader("n", "sS", pick("lsp_workspace_symbols"), "Workspace Symbols", { has = "workspace/symbol" })
map_leader("n", "sd", pick("diagnostics", { filter = { cwd = false } }), "Diagnostics (all buffers)")
map_leader("n", "sD", pick("diagnostics_buffer"), "Buffer Diagnostics")
map_leader("n", "sh", pick("help"), "Help Pages")
map_leader("n", "sH", pick("highlights"), "Highlights")
map_leader("n", "s/", pick("search_history"), "Search History")
map_leader("n", "sc", pick("command_history"), "Command History")
map_leader("n", ":", pick("command_history"), "Command History")
map_leader("n", "sC", pick("commands"), "Commands")
map_leader("n", 's"', pick("registers"), "Registers")
map_leader("n", "sa", pick("autocmds"), "Autocommands")
map_leader("n", "si", pick("icons"), "Icons")
map_leader("n", "sj", pick("jumps"), "Jumps")
map_leader("n", "sk", pick("keymaps"), "Keymaps")
map_leader("n", "sl", pick("loclist"), "Location List")
map_leader("n", "sq", pick("qflist"), "Quickfix List")
map_leader("n", "sm", pick("marks"), "Marks")
map_leader("n", "sM", pick("man"), "Man Pages")
map_leader("n", "sR", pick("resume"), "Resume Picker")
map_leader("n", "su", pick("undo"), "Undo History")
map_leader("n", "uC", pick("colorschemes"), "Colorschemes")

-- p is for 'Plugin File'
-- All mappings that use `edit_plugin_file` - edit 'plugin/' config files
local edit_plugin_file = function(filename)
	return string.format("<Cmd>edit %s/plugin/%s<CR>", vim.fn.stdpath("config"), filename)
end

map_leader("n", "pk", edit_plugin_file("02_keymaps.lua"), "Keymaps config")
map_leader("n", "pm", edit_plugin_file("03_mini.lua"), "MINI config")
map_leader("n", "po", edit_plugin_file("01_options.lua"), "Options config")
map_leader("n", "pp", edit_plugin_file("04_plugins.lua"), "Plugins config")
map_leader("n", "pi", "<Cmd>edit $MYVIMRC<CR>", "init.lua")

-- o is for 'Other'
map_leader("n", "or", "<Cmd>lua MiniMisc.resize_window()<CR>", "Resize to default width")
map_leader("n", "ot", "<Cmd>lua MiniTrailspace.trim()<CR>", "Trim trailspace")
map_leader("n", "oz", "<Cmd>lua MiniMisc.zoom()<CR>", "Zoom toggle")

-- t is for 'Terminal'
map_leader("n", "tT", "<Cmd>horizontal term<CR>", "Terminal (horizontal)")
map_leader("n", "tt", "<Cmd>vertical term<CR>", "Terminal (vertical)")
