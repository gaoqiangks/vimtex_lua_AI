if vim.b.did_indent or vim.g.vimtex_indent_bib_enabled == 0 then
  return
end
vim.b.did_indent = 1
vim.bo.autoindent = true
vim.bo.indentexpr = "v:lua.vimtex_indent_bib()"

local function count(line, character)
  local _, total = line:gsub(vim.pesc(character), "")
  return total
end

function _G.vimtex_indent_bib()
  local current = vim.v.lnum
  local previous = vim.fn.prevnonblank(current - 1)
  if previous == 0 then
    return 0
  end

  local indent = vim.fn.indent(previous)
  local line = vim.fn.getline(previous)
  local current_line = vim.fn.getline(current)
  if current_line:match "^%s*@" then
    return 0
  end
  if line:match "^@" then
    return current_line:match "^%s*}" and 0 or vim.bo.shiftwidth
  end

  if line:find("=", 1, true) then
    if count(line, "{") - count(line, "}") > 0 then
      return vim.fn.searchpos([[.*=\s*{]], "bcne")[2]
    elseif current_line:match "^%s*}" then
      return 0
    end
  elseif count(line, "{") - count(line, "}") < 0 then
    return count(current_line, "{") - count(current_line, "}") < 0 and 0
      or vim.bo.shiftwidth
  end
  return indent
end
