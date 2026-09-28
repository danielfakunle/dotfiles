local map_leader, map = Utils.map_leader, Utils.map

-- General
map("x", "p", [["_dP]], "Paste over selection without losing yanked text")
map({ "n", "v" }, "<leader>d", [["_d]], "Delete Without Yanking")
map("n", "<Esc>", ":nohl<CR>", "Clear search highlighting", { silent = true })
map("v", "<", "<gv", "Unindent and keep selection")
map("v", ">", ">gv", "Indent and keep selection")
map("n", "n", "nzzzv", "Next search result cursor centered")
map("n", "N", "Nzzzv", "Previous search result cursor centered")
map("n", "<leader>nr", "<cmd>restart<cr>", "Restart")

-- Explore
local explore_at_file = function()
	local path = vim.api.nvim_buf_get_name(0)
	if not MiniFiles.close() then
		MiniFiles.open(vim.uv.fs_stat(path) and path or nil, false)
		MiniFiles.reveal_cwd()
	end
end

local explore = function(...)
	if not MiniFiles.close() then
		MiniFiles.open(...)
	end
end

map_leader("n", "E", explore, "Explore Directory")
map_leader("n", "e", explore_at_file, "Explore File directory")

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
map("n", "gd", '<Cmd>Pick lsp scope="definition"<CR>', "Goto Definition", { has = "definition" })
map("n", "gD", '<Cmd>Pick lsp scope="declaration"<CR>', "Goto Declaration", { has = "declaration" })
map("n", "gy", '<Cmd>Pick lsp scope="type_definition"<CR>', "Goto T[y]pe definition")
map("n", "gr", '<Cmd>Pick lsp scope="references"<CR>', "Goto References", { nowait = true })
map("n", "gI", '<Cmd>Pick lsp scope="implementation"<CR>', "Goto Implementation")
map("n", "K", "<Cmd>lua vim.lsp.buf.hover()<CR>", "Hover")
map("n", "gK", "<Cmd>lua vim.lsp.buf.signature_help()<CR>", "Signature Help", { has = "signatureHelp" })
map("i", "<c-k>", "<Cmd>lua vim.lsp.buf.signature_help()<CR>", "Signature Help", { has = "signatureHelp" })

-- Clues
Config.leader_group_clues = {
	-- Normal Mode
	{ mode = "n", keys = "<Leader>b", desc = "+Buffer" },
	{ mode = "n", keys = "<Leader>u", desc = "+UI" },
	{ mode = "n", keys = "<Leader>n", desc = "+Neovim" },
	{ mode = "n", keys = "<Leader>c", desc = "+Code" },
	{ mode = "n", keys = "<Leader>f", desc = "+Find" },
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

-- n is for "Neovim"
map_leader({ "n", "x" }, "np", "g<", "Focus UI2 pager")

-- c is for "Code"
map_leader({ "n", "x" }, "cf", '<Cmd>lua require("conform").format()<CR>', "Format")
map_leader({ "n", "x" }, "ca", vim.lsp.buf.code_action, "Actions", { has = "codeAction" })
map_leader({ "n", "x" }, "cc", vim.lsp.codelens.run, "Lens", { has = "codeLens" })
map_leader("n", "cr", vim.lsp.buf.rename, "Rename", { has = "rename" })
map_leader("n", "cd", "<Cmd>lua vim.diagnostic.open_float()<CR>", "Diagnostic popup")

-- f is for "Fuzzy Find"
map_leader("n", "ff", function()
	local path = vim.api.nvim_buf_get_name(0)
	local fallback = path == "" and vim.fn.getcwd() or vim.fs.dirname(path)
	local cwd = vim.fs.root(0, { Config.project_root_markers }) or fallback
	MiniPick.builtin.files(nil, { source = { cwd = cwd } })
end, "Files (project)")
map_leader("n", "fF", function()
	MiniPick.builtin.files(nil, { source = { cwd = MiniMisc.find_root() } })
end, "Files (root)")
map_leader("n", "fg", "<Cmd>Pick grep_live<CR>", "Grep live")
map_leader("n", "fG", '<Cmd>Pick grep pattern="<cword>"<CR>', "Grep current word")
map_leader("x", "fG", function()
	local mode = vim.fn.mode()
	local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
	MiniPick.builtin.grep({ pattern = table.concat(lines, "\n") })
end, "Grep selection")
map_leader("n", "fh", "<Cmd>Pick help<CR>", "Help tags")
map_leader("n", "f/", '<Cmd>Pick history scope="/"<CR>', '"/" history')
map_leader("n", "f:", '<Cmd>Pick history scope=":"<CR>', '":" history')
map_leader("n", "fb", "<Cmd>Pick buffers<CR>", "Buffers")
map_leader("n", "fd", '<Cmd>Pick diagnostic scope="all"<CR>', "Diagnostic workspace")
map_leader("n", "fD", '<Cmd>Pick diagnostic scope="current"<CR>', "Diagnostic buffer")
map_leader("n", "fH", "<Cmd>Pick hl_groups<CR>", "Highlight groups")
map_leader("n", "fl", '<Cmd>Pick buf_lines scope="all"<CR>', "Lines (all)")
map_leader("n", "fL", '<Cmd>Pick buf_lines scope="current"<CR>', "Lines (buf)")
map_leader("n", "fs", '<Cmd>Pick lsp scope="workspace_symbol_live"<CR>', "Symbols workspace (live)")
map_leader("n", "fS", '<Cmd>Pick lsp scope="document_symbol"<CR>', "Symbols document")
map_leader("n", "fr", "<Cmd>Pick resume<CR>", "Resume")

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

-- x is for 'Examine'.
local explore_quickfix = function()
	vim.cmd(vim.fn.getqflist({ winid = true }).winid ~= 0 and "cclose" or "copen")
end
local explore_locations = function()
	vim.cmd(vim.fn.getloclist(0, { winid = true }).winid ~= 0 and "lclose" or "lopen")
end

map_leader("n", "xq", explore_quickfix, "Quickfix list")
map_leader("n", "xQ", explore_locations, "Location list")

-- o is for 'Other'
map_leader("n", "or", "<Cmd>lua MiniMisc.resize_window()<CR>", "Resize to default width")
map_leader("n", "ot", "<Cmd>lua MiniTrailspace.trim()<CR>", "Trim trailspace")
map_leader("n", "oz", "<Cmd>lua MiniMisc.zoom()<CR>", "Zoom toggle")

-- t is for 'Terminal'
map_leader("n", "tT", "<Cmd>horizontal term<CR>", "Terminal (horizontal)")
map_leader("n", "tt", "<Cmd>vertical term<CR>", "Terminal (vertical)")

