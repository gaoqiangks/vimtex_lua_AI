local root = vim.env.VIMTEX_BENCH_ROOT
  or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:append(root .. "/after")
vim.o.swapfile = false
vim.g.vimtex_cache_persistent = 0
vim.g.vimtex_view_automatic = 0
vim.g.vimtex_root_auto_add_enabled = 0
vim.cmd "filetype plugin indent on"
vim.cmd "syntax enable"
local directory = vim.fn.tempname()
vim.fn.mkdir(directory, "p")
vim.g.vimtex_cache_root = directory .. "/cache"
local main = {
  "\\documentclass{article}",
  "\\usepackage{amsmath,hyperref,booktabs,xparse}",
  "\\newcommand{\\benchmain}{Main}",
  "\\bibliography{references}",
  "\\begin{document}",
}
local bib = {}
for chapter = 1, 12 do
  main[#main + 1] = "\\input{chapter" .. chapter .. "}"
  local lines = { "\\newcommand{\\benchchapter" .. chapter .. "}{Chapter}" }
  for line = 1, 1000 do
    lines[#lines + 1] = "Plain text paragraph with words and $a+b=c$."
  end
  vim.fn.writefile(lines, directory .. "/chapter" .. chapter .. ".tex")
end
main[#main + 1] = "\\end{document}"
for i = 1, 1000 do
  bib[#bib + 1] = "@article{bench"
    .. i
    .. ", author={Example Author}, title={Example title "
    .. i
    .. "}, year={2025}}"
end
vim.fn.writefile(main, directory .. "/main.tex")
vim.fn.writefile(bib, directory .. "/references.bib")
for i = 1, 100 do
  local path = directory .. "/images/sub" .. i
  vim.fn.mkdir(path, "p")
  vim.fn.writefile({}, path .. "/image.png")
end
local results = {}
local function bench(name, count, callback)
  callback()
  local samples = {}
  for batch = 1, 5 do
    collectgarbage "collect"
    local start = vim.uv.hrtime()
    for i = 1, count do
      callback(i)
    end
    samples[#samples + 1] = (vim.uv.hrtime() - start) / 1e6 / count
  end
  table.sort(samples)
  results[name] = samples[3]
end
local start = vim.uv.hrtime()
vim.cmd("silent edit " .. directory .. "/main.tex")
results.first_open_ms = (vim.uv.hrtime() - start) / 1e6
local parser = require "vimtex.parser"
local complete = require "vimtex.complete"
local project = require("vimtex.state").get(vim.b.vimtex_id)
bench("parse_warm_ms", 30, function()
  assert(#parser.tex(project.tex) > 12000)
end)
bench("preamble_warm_ms", 100, function()
  assert(#parser.preamble(project.tex) > 0)
end)
bench("completion_commands_ms", 40, function()
  assert(#complete.complete("cmd", "bench") > 0)
end)
bench("completion_rebuild_ms", 5, function()
  vim.api.nvim_exec_autocmds("InsertLeave", { buffer = 0, modeline = false })
  assert(#complete.complete("cmd", "bench") > 0)
end)
bench("completion_bib_ms", 10, function()
  assert(#complete.complete("bib", "bench9") > 0)
end)
bench("completion_graphics_ms", 5, function()
  assert(#complete.complete("img", "images") == 100)
end)
bench("source_lookup_ms", 100, function()
  assert(project.has_source(directory .. "/chapter1.tex"))
end)
vim.cmd("silent edit " .. directory .. "/chapter1.tex")
vim.api.nvim_win_set_cursor(0, { 100, 10 })
bench("syntax_mathzone_ms", 500, function()
  require("vimtex.syntax").in_mathzone()
end)
bench("matchparen_text_ms", 100, function(i)
  vim.api.nvim_win_set_cursor(0, { 100 + (i or 1) % 20, 10 })
  require("vimtex.matchparen").highlight()
end)
bench("matchparen_same_position_ms", 100, function()
  require("vimtex.matchparen").highlight()
end)
results.nvim = vim.version().major
  .. "."
  .. vim.version().minor
  .. "."
  .. vim.version().patch
print(vim.json.encode(results))
if vim.env.VIMTEX_BENCH_OUT then
  vim.fn.writefile({ vim.json.encode(results) }, vim.env.VIMTEX_BENCH_OUT)
end
vim.cmd "silent %bwipeout!"
vim.fn.delete(directory, "rf")
vim.cmd "qall!"
