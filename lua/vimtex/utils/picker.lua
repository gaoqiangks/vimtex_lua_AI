local M = {}

---Format the section numbers corresponding to an item into a string.
---
---@param n table The TOC entry
---@return string number
M.format_number = function(n)
  local num = {}
  for _, value in ipairs {
    n.chapter,
    n.section,
    n.subsection,
    n.subsubsection,
    n.subsubsubsection,
  } do
    if value ~= 0 then
      num[#num + 1] = value
    end
  end
  if #num == 0 then
    return ""
  end

  -- Convert appendix items numbers to letters (e.g. 1 -> A, 2 -> B)
  if n.appendix ~= 0 then
    num[1] = string.char(num[1] + 64)
  end

  for index, value in ipairs(num) do
    num[index] = tostring(value)
  end
  return table.concat(num, ".")
end

return M
