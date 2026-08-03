local M = {}

local cache = require "vimtex.cache"
local paths = require "vimtex.paths"
local tex = require "vimtex.parser.tex"
local util = require "vimtex.util"

local function input_line_parser(line, source)
  local file = line:match "\\@input{([^}]+)}" or ""
  file = file:gsub("%.aux", "", 1)
  file = file:gsub('^[%s"]*', ""):gsub('[%s"]*$', "") .. ".aux"
  if not paths.is_abs(file) then
    file = vim.fn.fnamemodify(source, ":p:h") .. "/" .. file
  end
  return file
end

local function parse_recursive(file, parsed)
  if parsed[file] then
    return {}
  end
  local content, readable = util.readfile(file)
  if not readable then
    return {}
  end
  parsed[file] = true
  local lines = {}
  for _, line in ipairs(content) do
    lines[#lines + 1] = line
    if line:find("\\@input{", 1, true) then
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
      and not original:find "tocindent%-?%d"
    then
      local tree = util.tex2tree(util.tex2unicode(original))
      if #tree >= 2 then
        local name_tree = tree[2]
        local name = type(name_tree) == "table" and (name_tree[1] or "") or ""
        if name ~= "" then
          local context = tree[3]
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
    if line:find("\\externaldocument", 1, true) then
      local name = line:match "{([^}]*)}" or ""
      result[#result + 1] = {
        tex = name .. ".tex",
        aux = name .. ".aux",
        opt = line:match "%[([^]]*)%]" or "",
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
  local files = { { state.compiler.get_file "aux", "" } }
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
    local stat = vim.uv.fs_stat(file)
    if stat and stat.type == "file" then
      local current = store:get(file)
      local file_time = stat.mtime.sec
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
    if not line:find "^%s*%%" then
      local start = 1
      while true do
        local comment = line:find("%", start, true)
        if not comment then
          break
        end
        if comment == 1 or line:sub(comment - 1, comment - 1) ~= "\\" then
          line = line:sub(1, comment - 1)
          break
        end
        start = comment + 1
      end
      for label in line:gmatch "\\label%s*{([^}]+)}" do
        if label ~= "" then
          labels[#labels + 1] = label
        end
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
