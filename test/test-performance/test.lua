local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
vim.opt.runtimepath:prepend(root)
vim.g.vimtex_cache_persistent = 0
vim.g.vimtex_view_enabled = 0
vim.g.vimtex_root_auto_add_enabled = 0
vim.o.swapfile = false
vim.cmd "filetype plugin on"

local directory = vim.fn.tempname()
vim.fn.mkdir(directory, "p")
vim.g.vimtex_cache_root = directory .. "/cache"

local function write(name, lines, timestamp)
  local file = directory .. "/" .. name
  vim.fn.writefile(lines, file)
  if timestamp then
    assert(vim.uv.fs_utime(file, timestamp, timestamp))
  end
  return file
end

local function test(name, callback)
  local ok, message = xpcall(callback, debug.traceback)
  if not ok then
    vim.fn.assert_report(name .. ": " .. message)
  end
end

local util = require "vimtex.util"
local tex = require "vimtex.parser.tex"

test("text reader preserves Vim readfile semantics", function()
  for _, text in ipairs {
    "",
    "one",
    "one\n",
    "\n\n",
    "one\r\ntwo\r\n",
    "one\0two\nthree",
    "one\r",
    string.rep("long line", 10000),
  } do
    local file = directory .. "/reader"
    local fd = assert(vim.uv.fs_open(file, "w", 420))
    assert(vim.uv.fs_write(fd, text, 0))
    assert(vim.uv.fs_close(fd))
    vim.fn.assert_equal(vim.fn.readfile(file), util.readfile(file))
  end
  local lines, readable = util.readfile(directory .. "/absent")
  assert(not readable and #lines == 0)
end)

local main = write("main.tex", {
  "\\documentclass{article}",
  "\\input{settings}",
  "\\begin{document}",
  "\\input{child}",
  "\\end{document}",
}, 1700000010)
write("settings.tex", { "\\newcommand{\\fromsettings}{Old}" }, 1700000010)
write("child.tex", {
  "\\section{Alpha}",
  "\\newcommand{\\oldchild}{Old}",
  "\\bibitem{first} First",
}, 1700000010)
vim.cmd("silent edit " .. vim.fn.fnameescape(main))

test("preamble refreshes included files with older mtimes", function()
  local options = { root = directory }
  local initial = tex.parse_preamble(main, options)
  assert(table.concat(initial, "\n"):find("Old", 1, true))
  write("settings.tex", { "\\newcommand{\\fromsettings}{New}" }, 1700000000)
  local refreshed = tex.parse_preamble(main, options)
  assert(table.concat(refreshed, "\n"):find("New", 1, true))
  refreshed[1] = "mutated"
  assert(
    tex.parse_preamble(main, { root = directory, cached = true })[1]
      ~= "mutated"
  )
end)

test(
  "project caches refresh child changes, deletion, and recreation",
  function()
    local parser = require "vimtex.parser"
    local complete = require "vimtex.complete"
    assert(#complete.complete("cmd", "oldchild") == 1)
    assert(#complete.complete("bib", "first") == 1)
    local function has_section(title)
      for _, entry in ipairs(parser.toc()) do
        if entry.title == title then
          return true
        end
      end
      return false
    end
    assert(has_section "Alpha")
    write("child.tex", {
      "\\section{Beta}",
      "\\newcommand{\\newchild}{New}",
      "\\bibitem{second} Second",
    }, 1700000000)
    assert(has_section "Beta")
    assert(not has_section "Alpha")
    assert(#complete.complete("cmd", "oldchild") == 0)
    assert(#complete.complete("cmd", "newchild") == 1)
    assert(#complete.complete("bib", "first") == 0)
    local candidates = complete.complete("bib", "second")
    assert(#candidates == 1)
    candidates[1].word = "mutated"
    assert(complete.complete("bib", "second")[1].word == "second")
    assert(vim.fn.delete(directory .. "/child.tex") == 0)
    assert(#complete.complete("cmd", "newchild") == 0)
    assert(not has_section "Beta")
    write(
      "child.tex",
      { "\\section{Restored}", "\\newcommand{\\restoredchild}{Restored}" },
      1699999990
    )
    assert(#complete.complete("cmd", "restoredchild") == 1)
    assert(has_section "Restored")
  end
)

test(
  "file completion respects hidden files, symlinks, and wildignore",
  function()
    vim.fn.mkdir(directory .. "/images/sub", "p")
    vim.fn.mkdir(directory .. "/images/.hidden", "p")
    write("images/sub/a.png", {})
    write("images/sub/UPPER.PNG", {})
    write("images/sub/skip.png", {})
    write("images/sub/not-an-image.txt", {})
    write("images/.hidden/invisible.png", {})
    write("images/.invisible.png", {})
    local images = directory .. "/images"
    -- A directory symlink is a valid source of graphics. A cycle must terminate.
    if vim.fn.has "win32" == 0 then
      assert(vim.uv.fs_symlink(images .. "/sub", images .. "/linked"))
      assert(vim.uv.fs_symlink(images, images .. "/sub/cycle"))
    end
    local files = util.find_files(images, { png = true }, true)
    assert(vim.tbl_contains(files, images .. "/sub/a.png"))
    assert(vim.tbl_contains(files, images .. "/sub/UPPER.PNG"))
    assert(not vim.tbl_contains(files, images .. "/.invisible.png"))
    assert(not vim.tbl_contains(files, images .. "/.hidden/invisible.png"))
    if vim.fn.has "win32" == 0 then
      assert(vim.tbl_contains(files, images .. "/linked/a.png"))
      assert(vim.uv.fs_unlink(images .. "/sub/cycle"))
    end
    local ignore = vim.o.wildignore
    vim.o.wildignore = "*skip.png"
    local filtered = util.find_files(images, { png = true }, true)
    vim.o.wildignore = ignore
    assert(not vim.tbl_contains(filtered, images .. "/sub/skip.png"))
    write("images/new.png", {})
    assert(
      vim.tbl_contains(
        util.find_files(images, { png = true }, true),
        images .. "/new.png"
      )
    )
  end
)

test("syntax group lookup preserves ignorecase and regex semantics", function()
  vim.cmd "enew"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "comment" })
  vim.cmd "syntax match texComment /comment/"
  local syntax = require "vimtex.syntax"
  local ignore_case = vim.o.ignorecase
  vim.o.ignorecase = true
  assert(syntax.in_group("texcomment", 1, 1))
  vim.o.ignorecase = false
  assert(not syntax.in_group("texcomment", 1, 1))
  assert(syntax.in_group([[tex\%(Comment\)]], 1, 1))
  vim.o.ignorecase = ignore_case
  vim.bo.modified = false
end)

test("a completed compiler job only reports its result once", function()
  vim.g.vimtex_compiler_method = "generic"
  vim.g.vimtex_compiler_generic = {
    command = "printf '%s\\n' vimtex_compiler_callback_compiling vimtex_compiler_callback_success",
  }
  local file = write("callback.tex", {
    "\\documentclass{article}",
    "\\begin{document}",
    "content",
    "\\end{document}",
  })
  vim.cmd("silent edit " .. vim.fn.fnameescape(file))
  local successes, failures = 0, 0
  local autocmd = vim.api.nvim_create_autocmd("User", {
    pattern = { "VimtexEventCompileSuccess", "VimtexEventCompileFailed" },
    callback = function(args)
      if args.match == "VimtexEventCompileSuccess" then
        successes = successes + 1
      else
        failures = failures + 1
      end
    end,
  })
  local compiler = require("vimtex.state").get(vim.b.vimtex_id).compiler
  require("vimtex.compiler").compile_ss()
  assert(vim.wait(2000, function()
    return successes > 0 and not compiler.is_running()
  end))
  vim.wait(50, function()
    return false
  end)
  vim.api.nvim_del_autocmd(autocmd)
  vim.fn.assert_equal(1, successes)
  vim.fn.assert_equal(0, failures)
end)

test("same-directory operations do not emit DirChanged", function()
  local paths = require "vimtex.paths"
  local current = vim.fn.getcwd()
  local changes = 0
  local autocmd = vim.api.nvim_create_autocmd("DirChanged", {
    callback = function()
      changes = changes + 1
    end,
  })
  paths.pushd(current .. "/")
  paths.popd()
  vim.fn.assert_equal(0, changes)
  paths.pushd(directory)
  paths.pushd(directory .. "/")
  paths.popd()
  vim.fn.assert_equal(vim.fn.fnamemodify(directory, ":p:h"), vim.fn.getcwd())
  paths.popd()
  vim.fn.assert_equal(current, vim.fn.getcwd())
  vim.fn.assert_equal(2, changes)
  vim.api.nvim_del_autocmd(autocmd)
end)

test("relative paths respect directory boundaries", function()
  local paths = require "vimtex.paths"
  vim.fn.assert_equal(
    "../chapter-two/file.tex",
    paths.relative("/project/chapter-two/file.tex", "/project/chapter")
  )
  vim.fn.assert_equal(
    "../sibling/file.tex",
    paths.relative("/sibling/file.tex", "/project")
  )
  vim.fn.assert_equal("file.tex", paths.relative("/file.tex", "/"))
end)

vim.cmd "silent %bwipeout!"
vim.fn.delete(directory, "rf")
require("vimtex.test").finished()
