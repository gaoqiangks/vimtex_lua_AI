local equation = { open = [[\begin{equation}]], close = [[\end{equation}]] }
local environments = { displaymath = equation, ["equation*"] = equation }

-- The inner environment owns the original row breaks, alignment tabs and,
-- for alignedat, the column count immediately following the opening token.
local function multiline(names, inner, args)
  local pair = {
    open = equation.open .. "\\begin{" .. inner .. "}" .. (args or ""),
    close = "\\end{" .. inner .. "}" .. equation.close,
    multiline = true,
  }
  for _, name in ipairs(names) do
    environments[name] = pair
  end
end

multiline({ "align", "align*", "flalign", "flalign*" }, "aligned")
multiline(
  { "alignat", "alignat*", "xalignat", "xalignat*", "xxalignat" },
  "alignedat"
)
multiline({ "gather", "gather*", "multline", "multline*" }, "gathered")
-- eqnarray is kernel LaTeX, so its replacement must work without amsmath.
multiline({ "eqnarray", "eqnarray*" }, "array", "{rcl}")

return environments
