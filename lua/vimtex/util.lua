local jobs = require "vimtex.jobs"

local M = {}

local unicode_pairs = {
  { '\\C\\\\"A', "Ä" },
  { '\\C\\\\"E', "Ë" },
  { '\\C\\\\"I', "Ï" },
  { '\\C\\\\"O', "Ö" },
  { '\\C\\\\"U', "Ü" },
  { '\\C\\\\"Y', "Ÿ" },
  { '\\C\\\\"\\\\i', "ï" },
  { '\\C\\\\"a', "ä" },
  { '\\C\\\\"e', "ë" },
  { '\\C\\\\"i', "ï" },
  { '\\C\\\\"o', "ö" },
  { '\\C\\\\"u', "ü" },
  { '\\C\\\\"y', "ÿ" },
  { "\\C\\\\'A", "Á" },
  { "\\C\\\\'C", "Ć" },
  { "\\C\\\\'E", "É" },
  { "\\C\\\\'G", "Ǵ" },
  { "\\C\\\\'I", "Í" },
  { "\\C\\\\'L", "Ĺ" },
  { "\\C\\\\'N", "Ń" },
  { "\\C\\\\'O", "Ó" },
  { "\\C\\\\'R", "Ŕ" },
  { "\\C\\\\'S", "Ś" },
  { "\\C\\\\'U", "Ú" },
  { "\\C\\\\'Y", "Ý" },
  { "\\C\\\\'Z", "Ź" },
  { "\\C\\\\'\\\\i", "í" },
  { "\\C\\\\'a", "á" },
  { "\\C\\\\'c", "ć" },
  { "\\C\\\\'e", "é" },
  { "\\C\\\\'g", "ǵ" },
  { "\\C\\\\'i", "í" },
  { "\\C\\\\'i", "í" },
  { "\\C\\\\'l", "ĺ" },
  { "\\C\\\\'n", "ń" },
  { "\\C\\\\'o", "ó" },
  { "\\C\\\\'r", "ŕ" },
  { "\\C\\\\'s", "ś" },
  { "\\C\\\\'u", "ú" },
  { "\\C\\\\'y", "ý" },
  { "\\C\\\\'z", "ź" },
  { "\\C\\\\=A", "Ā" },
  { "\\C\\\\=E", "Ē" },
  { "\\C\\\\=I", "Ī" },
  { "\\C\\\\=O", "Ō" },
  { "\\C\\\\=U", "Ū" },
  { "\\C\\\\=a", "ā" },
  { "\\C\\\\=e", "ē" },
  { "\\C\\\\=i", "ī" },
  { "\\C\\\\=o", "ō" },
  { "\\C\\\\=u", "ū" },
  { "\\C\\\\HO", "Ő" },
  { "\\C\\\\HU", "Ű" },
  { "\\C\\\\Ho", "ő" },
  { "\\C\\\\Hu", "ű" },
  { "\\C\\\\\\%(\\~\\|tilde\\)A", "Ã" },
  { "\\C\\\\\\%(\\~\\|tilde\\)E", "Ẽ" },
  { "\\C\\\\\\%(\\~\\|tilde\\)I", "Ĩ" },
  { "\\C\\\\\\%(\\~\\|tilde\\)N", "Ñ" },
  { "\\C\\\\\\%(\\~\\|tilde\\)O", "Õ" },
  { "\\C\\\\\\%(\\~\\|tilde\\)U", "Ũ" },
  { "\\C\\\\\\%(\\~\\|tilde\\)Y", "Ỹ" },
  { "\\C\\\\\\%(\\~\\|tilde\\)\\\\i", "ĩ" },
  { "\\C\\\\\\%(\\~\\|tilde\\)a", "ã" },
  { "\\C\\\\\\%(\\~\\|tilde\\)e", "ẽ" },
  { "\\C\\\\\\%(\\~\\|tilde\\)i", "ĩ" },
  { "\\C\\\\\\%(\\~\\|tilde\\)n", "ñ" },
  { "\\C\\\\\\%(\\~\\|tilde\\)o", "õ" },
  { "\\C\\\\\\%(\\~\\|tilde\\)u", "ũ" },
  { "\\C\\\\\\%(\\~\\|tilde\\)y", "ỹ" },
  { "\\C\\\\\\.A", "Ȧ" },
  { "\\C\\\\\\.C", "Ċ" },
  { "\\C\\\\\\.E", "Ė" },
  { "\\C\\\\\\.G", "Ġ" },
  { "\\C\\\\\\.I", "İ" },
  { "\\C\\\\\\.O", "Ȯ" },
  { "\\C\\\\\\.Z", "Ż" },
  { "\\C\\\\\\.\\\\i", "į" },
  { "\\C\\\\\\.a", "ȧ" },
  { "\\C\\\\\\.c", "ċ" },
  { "\\C\\\\\\.e", "ė" },
  { "\\C\\\\\\.g", "ġ" },
  { "\\C\\\\\\.i", "į" },
  { "\\C\\\\\\.o", "ȯ" },
  { "\\C\\\\\\.z", "ż" },
  { "\\C\\\\^A", "Â" },
  { "\\C\\\\^C", "Ĉ" },
  { "\\C\\\\^E", "Ê" },
  { "\\C\\\\^G", "Ĝ" },
  { "\\C\\\\^I", "Î" },
  { "\\C\\\\^L", "Ľ" },
  { "\\C\\\\^O", "Ô" },
  { "\\C\\\\^S", "Ŝ" },
  { "\\C\\\\^U", "Û" },
  { "\\C\\\\^W", "Ŵ" },
  { "\\C\\\\^Y", "Ŷ" },
  { "\\C\\\\^\\\\i", "î" },
  { "\\C\\\\^a", "â" },
  { "\\C\\\\^c", "ĉ" },
  { "\\C\\\\^e", "ê" },
  { "\\C\\\\^g", "ĝ" },
  { "\\C\\\\^h", "ĥ" },
  { "\\C\\\\^i", "î" },
  { "\\C\\\\^l", "ľ" },
  { "\\C\\\\^o", "ô" },
  { "\\C\\\\^s", "ŝ" },
  { "\\C\\\\^u", "û" },
  { "\\C\\\\^w", "ŵ" },
  { "\\C\\\\^y", "ŷ" },
  { "\\C\\\\`A", "À" },
  { "\\C\\\\`E", "È" },
  { "\\C\\\\`I", "Ì" },
  { "\\C\\\\`N", "Ǹ" },
  { "\\C\\\\`O", "Ò" },
  { "\\C\\\\`U", "Ù" },
  { "\\C\\\\`Y", "Ỳ" },
  { "\\C\\\\`\\\\i", "ì" },
  { "\\C\\\\`a", "à" },
  { "\\C\\\\`e", "è" },
  { "\\C\\\\`i", "ì" },
  { "\\C\\\\`n", "ǹ" },
  { "\\C\\\\`o", "ò" },
  { "\\C\\\\`y", "ỳ" },
  { "\\C\\\\cC", "Ç" },
  { "\\C\\\\cE", "Ȩ" },
  { "\\C\\\\cG", "Ģ" },
  { "\\C\\\\cK", "Ķ" },
  { "\\C\\\\cL", "Ļ" },
  { "\\C\\\\cN", "Ņ" },
  { "\\C\\\\cR", "Ŗ" },
  { "\\C\\\\cS", "Ş" },
  { "\\C\\\\cT", "Ţ" },
  { "\\C\\\\cc", "ç" },
  { "\\C\\\\ce", "ȩ" },
  { "\\C\\\\cg", "ģ" },
  { "\\C\\\\ck", "ķ" },
  { "\\C\\\\cl", "ļ" },
  { "\\C\\\\cn", "ņ" },
  { "\\C\\\\cr", "ŗ" },
  { "\\C\\\\cs", "ş" },
  { "\\C\\\\ct", "ţ" },
  { "\\C\\\\kA", "Ą" },
  { "\\C\\\\kE", "Ę" },
  { "\\C\\\\kI", "Į" },
  { "\\C\\\\kO", "Ǫ" },
  { "\\C\\\\kU", "Ų" },
  { "\\C\\\\ka", "ą" },
  { "\\C\\\\ke", "ę" },
  { "\\C\\\\ki", "į" },
  { "\\C\\\\ko", "ǫ" },
  { "\\C\\\\ks", "ȿ" },
  { "\\C\\\\ku", "ų" },
  { "\\C\\\\o", "ø" },
  { "\\C\\\\rA", "Å" },
  { "\\C\\\\rU", "Ů" },
  { "\\C\\\\ra", "å" },
  { "\\C\\\\ru", "ů" },
  { "\\C\\\\uA", "Ă" },
  { "\\C\\\\uE", "Ĕ" },
  { "\\C\\\\uG", "Ğ" },
  { "\\C\\\\uI", "Ĭ" },
  { "\\C\\\\uO", "Ŏ" },
  { "\\C\\\\uU", "Ŭ" },
  { "\\C\\\\u\\\\i", "ĭ" },
  { "\\C\\\\ua", "ă" },
  { "\\C\\\\ue", "ĕ" },
  { "\\C\\\\ug", "ğ" },
  { "\\C\\\\ui", "ĭ" },
  { "\\C\\\\uo", "ŏ" },
  { "\\C\\\\uu", "ŭ" },
  { "\\C\\\\vA", "Ǎ" },
  { "\\C\\\\vC", "Č" },
  { "\\C\\\\vD", "Ď" },
  { "\\C\\\\vE", "Ě" },
  { "\\C\\\\vG", "Ǧ" },
  { "\\C\\\\vH", "Ȟ" },
  { "\\C\\\\vI", "Ǐ" },
  { "\\C\\\\vJ", "ǰ" },
  { "\\C\\\\vK", "Ǩ" },
  { "\\C\\\\vL", "Ľ" },
  { "\\C\\\\vN", "Ň" },
  { "\\C\\\\vO", "Ǒ" },
  { "\\C\\\\vR", "Ř" },
  { "\\C\\\\vS", "Š" },
  { "\\C\\\\vT", "Ť" },
  { "\\C\\\\vU", "Ǔ" },
  { "\\C\\\\vZ", "Ž" },
  { "\\C\\\\va", "ǎ" },
  { "\\C\\\\vc", "č" },
  { "\\C\\\\vd", "ď" },
  { "\\C\\\\ve", "ě" },
  { "\\C\\\\vg", "ǧ" },
  { "\\C\\\\vh", "ȟ" },
  { "\\C\\\\vi", "ǐ" },
  { "\\C\\\\vk", "ǩ" },
  { "\\C\\\\vl", "ľ" },
  { "\\C\\\\vn", "ň" },
  { "\\C\\\\vo", "ǒ" },
  { "\\C\\\\vr", "ř" },
  { "\\C\\\\vs", "š" },
  { "\\C\\\\vt", "ť" },
  { "\\C\\\\vu", "ǔ" },
  { "\\C\\\\vz", "ž" },
  { "\\C\\\\¨A", "Ä" },
  { "\\C\\\\¨E", "Ë" },
  { "\\C\\\\¨I", "Ï" },
  { "\\C\\\\¨O", "Ö" },
  { "\\C\\\\¨U", "Ü" },
  { "\\C\\\\¨a", "ä" },
  { "\\C\\\\¨e", "ë" },
  { "\\C\\\\¨i", "ï" },
  { "\\C\\\\¨o", "ö" },
  { "\\C\\\\¨u", "ü" },
}

function M.command(command)
  return vim.split(
    vim.api.nvim_exec2(command, { output = true }).output,
    "\n",
    { plain = true, trimempty = true }
  )
end

function M.count(line, pattern)
  if pattern == "" then
    return 0
  end
  local total = 0
  while vim.fn.match(line, pattern, 0, total + 1) >= 0 do
    total = total + 1
  end
  return total
end

function M.count_open(line, opening, closing)
  local index = vim.fn.match(line, opening)
  if index < 0 then
    return 0
  end
  local total, first = 0, index
  while index >= 0 do
    total = total + 1
    index = index + #vim.fn.matchstr(line, opening, index)
    index = vim.fn.match(line, opening, index)
  end
  index = vim.fn.match(line, closing, first)
  while index >= 0 do
    total = total - 1
    index = index + #vim.fn.matchstr(line, closing, index)
    index = vim.fn.match(line, closing, index)
  end
  return math.max(total, 0)
end

function M.count_close(line, opening, closing)
  local index = vim.fn.match(line, closing)
  if index < 0 then
    return 0
  end
  local total, last = 0, index
  while index >= 0 do
    total, last = total + 1, index
    index = index + #vim.fn.matchstr(line, closing, index)
    index = vim.fn.match(line, closing, index)
  end
  index = vim.fn.match(line, opening)
  while index >= 0 and index < last do
    total = total - 1
    index = index + #vim.fn.matchstr(line, opening, index)
    index = vim.fn.match(line, opening, index)
  end
  return math.max(total, 0)
end

function M.flatten(list)
  local result = {}
  for _, value in ipairs(list) do
    if type(value) == "table" and vim.islist(value) then
      vim.list_extend(result, M.flatten(value))
    else
      result[#result + 1] = value
    end
  end
  return result
end

function M.is_win()
  return vim.fn.has "win32" == 1 or vim.fn.has "win32unix" == 1
end

function M.get_os()
  if M.is_win() then
    return "win"
  end
  local name = vim.uv.os_uname().sysname
  return name == "Darwin" and "mac" or "linux"
end

function M.win_clean_output(lines)
  return vim.tbl_map(function(line)
    return line:gsub("\r$", "")
  end, lines)
end

function M.extend_recursive(first, second, behavior)
  behavior = behavior or "force"
  if behavior ~= "force" and behavior ~= "keep" and behavior ~= "error" then
    error("E475: Invalid argument: " .. behavior)
  end
  for key, value in pairs(second) do
    if first[key] == nil then
      first[key] = value
    elseif type(value) == "table" and not vim.islist(value) then
      M.extend_recursive(first[key], value, behavior)
    elseif behavior == "error" then
      error("E737: Key already exists: " .. key)
    elseif behavior == "force" then
      first[key] = value
    end
  end
  return first
end

function M.materialize_property(object, name, ...)
  if type(object[name]) ~= "function" then
    return
  end
  local ok, value = pcall(object[name], ...)
  object[name] = ok and value or ""
  if not ok then
    vim.notify(
      "Could not materialize property " .. name .. ": " .. value,
      vim.log.levels.ERROR
    )
  end
end

function M.shellescape(command)
  return vim.fn.escape(vim.fn.shellescape(command), "\\")
end

function M.tex2unicode(line)
  for _, pair in ipairs(unicode_pairs) do
    line = vim.fn.substitute(line, pair[1], pair[2], "g")
  end
  return vim.fn.substitute(
    line,
    [[\C\\IeC\s*{\s*\([^}]\{-}\)\s*}]],
    [[\1]],
    "g"
  )
end

function M.tex2tree(text)
  local tree, start, cursor, depth = {}, 1, 0, 0
  while cursor < #text do
    local found = text:find("[{}]", cursor + 1)
    cursor = found or (#text + 1)
    local char = text:sub(cursor, cursor)
    if cursor > #text or char == "{" then
      if depth == 0 then
        local item = vim.trim(text:sub(start, cursor - 1))
        if item ~= "" then
          tree[#tree + 1] = item
        end
        start = cursor + 1
      end
      depth = depth + 1
    else
      depth = depth - 1
      if depth == 0 then
        tree[#tree + 1] = M.tex2tree(text:sub(start, cursor - 1))
        start = cursor + 1
      end
    end
  end
  return tree
end

function M.texsplit(text)
  if text == "" then
    return {}
  end
  local result, start, depth = {}, 1, 0
  for index = 1, #text do
    local char = text:sub(index, index)
    if char == "{" then
      depth = depth + 1
    elseif char == "}" then
      depth = depth - 1
    elseif char == "," and depth == 0 then
      result[#result + 1], start = text:sub(start, index - 1), index + 1
    end
  end
  result[#result + 1] = text:sub(start)
  return result
end

function M.uniq_unsorted(list)
  local result, seen = {}, {}
  for _, value in ipairs(list) do
    local key = vim.inspect(value)
    if not seen[key] then
      seen[key], result[#result + 1] = true, value
    end
  end
  return result
end

function M.undostore()
  if vim.fn.mode() ~= "i" then
    vim.cmd.normal { args = { "ix" }, bang = true }
    vim.cmd.normal { args = { "x" }, bang = true }
  end
end

function M.url_encode(text)
  return (
    text:gsub("[^A-Za-z0-9_.~-]", function(char)
      return ("%%%02X"):format(char:byte())
    end)
  )
end

function M.www(url)
  local commands = { linux = "xdg-open", mac = "open", win = "start" }
  return jobs.start(
    commands[M.get_os()] .. " " .. M.shellescape(url),
    { detached = true }
  )
end

for name, func in pairs(M) do
  _G["vimtex_util_" .. name] = func
end

return M
