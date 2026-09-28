_G.Utils = {}

local gr = vim.api.nvim_create_augroup("custom-config", {})

Utils.new_autocmd = function(event, pattern, callback, desc)
	local opts = { group = gr, pattern = pattern, callback = callback, desc = desc }
	vim.api.nvim_create_autocmd(event, opts)
end

Utils.on_packchanged = function(plugin_name, kinds, callback, desc)
	local f = function(ev)
		local name, kind = ev.data.spec.name, ev.data.kind
		if not (name == plugin_name and vim.tbl_contains(kinds, kind)) then
			return
		end
		if not ev.data.active then
			vim.cmd.packadd(plugin_name)
		end
		callback(ev.data)
	end
	Utils.new_autocmd("PackChanged", "*", f, desc)
end

Utils.gh = function(x)
	return "https://github.com/" .. x
end

Utils.add = function(specs, confirm)
	vim.pack.add(specs, { confirm = confirm == true })
end

Utils.add({ Utils.gh("nvim-mini/mini.nvim") })

local misc = require("mini.misc")
Utils.now = function(f)
	misc.safely("now", f)
end
Utils.later = function(f)
	misc.safely("later", f)
end
Utils.now_if_args = vim.fn.argc(-1) > 0 and Utils.now or Utils.later

Utils.map = function(mode, lhs, rhs, desc, opts)
	opts = vim.tbl_deep_extend("force", { desc = desc }, opts or {})
	local has = opts.has
	opts.has = nil

	if not has then
		vim.keymap.set(mode, lhs, rhs, opts)
		return
	end

	has = type(has) == "table" and has or { has }
	for i, method in ipairs(has) do
		if not method:find("/", 1, true) then
			has[i] = "textDocument/" .. method
		end
	end

	Utils.new_autocmd("LspAttach", "*", function(event)
		local client = vim.lsp.get_client_by_id(event.data.client_id)
		if client and vim.iter(has):all(function(method)
			return client:supports_method(method, event.buf)
		end) then
			vim.keymap.set(mode, lhs, rhs, vim.tbl_deep_extend("force", opts, { buffer = event.buf }))
		end
	end, "Set LSP capability keymap")
end

Utils.map_leader = function(mode, suffix, rhs, desc, opts)
	Utils.map(mode, "<Leader>" .. suffix, rhs, desc, opts)
end

---@param count? number
---@param cycle? boolean
function Utils.jump_lsp_reference(count, cycle)
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local references, current = {}, nil
	local seen = {}
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/documentHighlight" })) do
		local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
		local response = client:request_sync("textDocument/documentHighlight", params, 1000, bufnr)
		for _, highlight in ipairs(response and response.result or {}) do
			local range = highlight.range
			local start_line = vim.api.nvim_buf_get_lines(bufnr, range.start.line, range.start.line + 1, false)[1] or ""
			local end_line = vim.api.nvim_buf_get_lines(bufnr, range["end"].line, range["end"].line + 1, false)[1] or ""
			local from_col = vim.str_byteindex(start_line, client.offset_encoding, range.start.character, false)
			local to_col = vim.str_byteindex(end_line, client.offset_encoding, range["end"].character, false)
			local key = table.concat({ range.start.line, from_col, range["end"].line, to_col }, ":")
			if not seen[key] then
				seen[key] = true
				references[#references + 1] = {
					from = { range.start.line + 1, from_col },
					to = { range["end"].line + 1, to_col },
				}
			end
		end
	end
	table.sort(references, function(a, b)
		return a.from[1] < b.from[1] or (a.from[1] == b.from[1] and a.from[2] < b.from[2])
	end)

	for index, reference in ipairs(references) do
		local after_start = cursor[1] > reference.from[1]
			or (cursor[1] == reference.from[1] and cursor[2] >= reference.from[2])
		local before_end = cursor[1] < reference.to[1] or (cursor[1] == reference.to[1] and cursor[2] < reference.to[2])
		if after_start and before_end then
			current = index
			break
		end
	end

	if not current then
		return
	end

	local index = current + (count or 1)
	if cycle then
		index = (index - 1) % #references + 1
	end

	local target = references[index]
	if not target then
		vim.notify("No more references", vim.log.levels.WARN)
		return
	end

	vim.cmd.normal({ "m`", bang = true })
	vim.api.nvim_win_set_cursor(0, target.from)
	vim.cmd.normal({ "zv", bang = true })
end

_G.Config = {}

Config.project_root_markers = {
	"package.json",
	"pyproject.toml",
	"Cargo.toml",
	"go.mod",
	"pom.xml",
	"build.gradle",
	"build.gradle.kts",
	"Gemfile",
	"mix.exs",
	"composer.json",
	"Makefile",
	"CMakeLists.txt",
	".git",
}
