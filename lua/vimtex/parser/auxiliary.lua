local M = {}

local cache = require "vimtex.cache"
local tex = require "vimtex.parser.tex"
local util = require "vimtex.util"

local function input_line_parser(line, source)
  local file = vim.fn.matchstr(line, [[\\@input{\zs[^}]\+\ze}]])
  file = vim.fn.substitute(file, [[\.aux]], "", "")
  file = vim.fn.substitute(file, [[^\(\s\|"\)*]], "", "")
  file = vim.fn.substitute(file, [[\(\s\|"\)*$]], "", "") .. ".aux"
  if vim.fn.match(file, [[\v^(\/|[A-Z]:)]]) < 0 then
    file = vim.fn.fnamemodify(source, ":p:h") .. "/" .. file
  end
  return vim.fn.filereadable(file) == 1 and file or ""
end

local function parse_recursive(file, parsed)
  if vim.fn.filereadable(file) == 0 or parsed[file] then
    return {}
  end
  parsed[file] = true
  local lines = {}
  for _, line in ipairs(vim.fn.readfile(file)) do
    lines[#lines + 1] = line
    if vim.fn.match(line, [[\\@input{]]) >= 0 then
      vim.list_extend(
        lines,
        parse_recursive(input_line_parser(line, file), parsed)
      )
    end
  end
  return lines
end

function M.parse(file)
  return parse_recursive(file, {})
end

local function parse_number(tree)
  if type(tree) == "table" then
    if #tree == 0 then
      return "-"
    end
    return parse_number(tree[#tree == 1 and 1 or 2])
  end
  local matches =
    vim.fn.matchlist(tree, [[\v(^|.*\s)((\u|\d+)(\.\d+)*\S?)($|\s.*)]])
  return #matches > 3 and matches[3] or "-"
end

local function parse_labels(file, prefix)
  local labels = {}
  for _, original in ipairs(M.parse(file)) do
    if
      original:find("\\newlabel{", 1, true)
      and not original:find("@cref", 1, true)
      and not original:find("sub@", 1, true)
      and vim.fn.match(original, [=[tocindent-\?[0-9]]=]) < 0
    then
      local tree = util.tex2tree(util.tex2unicode(original))
      table.remove(tree, 1)
      if #tree >= 2 then
        local name_tree = table.remove(tree, 1)
        local name = type(name_tree) == "table" and (name_tree[1] or "") or ""
        if name ~= "" then
          local context = table.remove(tree, 1)
          if type(context) == "table" and #context > 1 then
            local menu = ""
            local ok, label_type = pcall(function()
              return context[4][1]:gsub("%..*$", " "):gsub("AMS", "Equation")
            end)
            if ok and label_type ~= "" then
              menu = label_type:sub(1, 1):upper() .. label_type:sub(2)
            end
            local number = parse_number(context[1])
            if menu:find("Equation", 1, true) then
              number = "(" .. number .. ")"
            end
            menu = menu .. number
            if type(context[2]) == "table" and context[2][1] then
              menu = menu .. " [p. " .. context[2][1] .. "]"
            end
            labels[#labels + 1] = { word = prefix .. name, menu = menu }
          end
        end
      end
    end
  end
  return labels
end

local function external_files()
  local state = vim.b.vimtex
  if type(state) ~= "table" then
    return {}
  end
  local result = {}
  for _, line in ipairs(tex.parse_preamble(state.tex)) do
    if vim.fn.match(line, [[\\externaldocument]]) >= 0 then
      local name = vim.fn.matchstr(line, [[{\zs[^}]*\ze}]])
      result[#result + 1] = {
        tex = name .. ".tex",
        aux = name .. ".aux",
        opt = vim.fn.matchstr(line, [=[\[\zs[^]]*\ze\]]=]),
      }
    end
  end
  return result
end

function M.labels()
  local state = vim.b.vimtex
  if type(state) ~= "table" or type(state.compiler) ~= "table" then
    return {}
  end
  local files = { { vim.fn.eval [[b:vimtex.compiler.get_file('aux')]], "" } }
  local local_state = vim.b.vimtex_local
  if
    type(local_state) == "table"
    and (local_state.active == true or local_state.active == 1)
  then
    local main = require("vimtex.state").get(local_state.main_id)
    files[#files + 1] = { main.compiler.get_file "aux", "" }
  end
  for _, item in ipairs(external_files()) do
    files[#files + 1] = { item.aux, item.opt }
  end

  local store = cache.open("refcomplete", {
    ["local"] = true,
    default = { labels = {}, ftime = -1 },
  })
  local labels = {}
  for _, item in ipairs(files) do
    local file, prefix = item[1], item[2]
    if vim.fn.filereadable(file) == 1 then
      local current = store:get(file)
      local file_time = vim.fn.getftime(file)
      if file_time > current.ftime then
        current.ftime = file_time
        current.labels = parse_labels(file, prefix)
        store.modified = true
      end
      vim.list_extend(labels, current.labels)
    end
  end
  store:write()
  return labels
end

function M.labels_manual()
  local state = vim.b.vimtex
  if type(state) ~= "table" then
    return {}
  end
  local labels = {}
  for _, line in ipairs(tex.parse(state.tex, { detailed = false })) do
    if vim.fn.match(line, [[^\s*%]]) < 0 then
      local clean = vim.fn.substitute(line, [[\\\@<!%.*$]], "", "")
      local position = 0
      while true do
        local found =
          vim.fn.matchstrpos(clean, [[\\label\s*{\([^}]\+\)}]], position)
        if found[2] < 0 then
          break
        end
        local label = vim.fn.matchstr(found[1], [[\\label\s*{\zs[^}]\+\ze}]])
        if label ~= "" then
          labels[#labels + 1] = label
        end
        position = found[3]
      end
    end
  end
  local result = {}
  for _, label in ipairs(util.uniq_unsorted(labels)) do
    result[#result + 1] = { word = label, menu = "[manual]" }
  end
  return result
end

return M
