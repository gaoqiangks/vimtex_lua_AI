local M = {}

local values = {
  ["vimtex#re#bib_input"] = "\\v^\\s*\\zs\\\\%(addbibresource|bibliography)\\s*\\{",
  ["vimtex#re#cite_cmd"] = "\\v%(%(\\a*cite|Cite)\\a*|bibentry|%(text|block|%(for|hy)\\w+)cquote)",
  ["vimtex#re#deoplete"] = "\\\\(?:(?:\\w*cite|Cite)\\w*\\*?(?:\\s*\\[[^]]*\\]){0,2}\\s*{[^}]*|(?:\\w*cites|Cites)(?:\\s*\\([^)]*\\)){0,2}(?:(?:\\s*\\[[^]]*\\]){0,2}\\s*\\{[^}]*\\})*(?:\\s*\\[[^]]*\\]){0,2}\\s*\\{[^}]*|bibentry\\s*{[^}]*|(text|block)cquote\\*?(?:\\s*\\[[^]]*\\]){0,2}\\s*{[^}]*|(for|hy)\\w*cquote\\*?{[^}]*}(?:\\s*\\[[^]]*\\]){0,2}\\s*{[^}]*|defbibentryset{[^}]*}{[^}]*|\\w*ref(?:\\s*\\{[^}]*|range\\s*\\{[^,}]*(?:}{)?)|hyperref\\s*\\[[^]]*|includegraphics\\*?(?:\\s*\\[[^]]*\\]){0,2}\\s*\\{[^}]*|(?:include(?:only)?|input|subfile)\\s*\\{[^}]*|([cpdr]?(gls|Gls|GLS)|acr|Acr|ACR)[a-zA-Z]*\\s*\\{[^}]*|(ac|Ac|AC)\\s*\\{[^}]*|includepdf(\\s*\\[[^]]*\\])?\\s*\\{[^}]*|includestandalone(\\s*\\[[^]]*\\])?\\s*\\{[^}]*|(usepackage|RequirePackage|PassOptionsToPackage)(\\s*\\[[^]]*\\])?\\s*\\{[^}]*|documentclass(\\s*\\[[^]]*\\])?\\s*\\{[^}]*|begin(\\s*\\[[^]]*\\])?\\s*\\{[^}]*|end(\\s*\\[[^]]*\\])?\\s*\\{[^}]*|\\w*)",
  ["vimtex#re#ncm"] = {
    "\\\\[A-Za-z]+",
    "\\\\(usepackage|RequirePackage|PassOptionsToPackage)(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
    "\\\\documentclass(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
    "\\\\begin(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
    "\\\\end(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
    "\\\\([A-Za-z]*cite|Cite)[A-Za-z]*\\*?(\\[[^]]*\\]){0,2}{[^}]*",
    "\\\\([A-Za-z]*cites|Cites)(\\s*\\([^)]*\\)){0,2}((\\s*\\[[^]]*\\]){0,2}\\s*\\{[^}]*\\})*(\\s*\\[[^]]*\\]){0,2}\\s*\\{[^}]*",
    "\\\\bibentry\\s*{[^}]*",
    "\\\\(text|block)cquote\\*?(\\[[^]]*\\]){0,2}{[^}]*",
    "\\\\(for|hy)[A-Za-z]*cquote\\*?{[^}]*}(\\[[^]]*\\]){0,2}{[^}]*",
    "\\\\defbibentryset{[^}]*}{[^}]*",
    "\\\\[A-Za-z]*ref({[^}]*|range{([^,{}]*(}{)?))",
    "\\\\hyperref\\[[^]]*",
    "\\\\([cpdr]?(gls|Gls|GLS)|acr|Acr|ACR)[a-zA-Z]*\\s*\\{[^}]*",
    "\\\\(ac|Ac|AC)\\s*\\{[^}]*",
    "\\\\includegraphics\\*?(\\[[^]]*\\]){0,2}{[^}]*",
    "\\\\(include(only)?|input|subfile){[^}]*",
    "\\\\includepdf(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
    "\\\\includestandalone(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
  },
  ["vimtex#re#ncm2"] = {
    "\\\\[A-Za-z]+",
    "\\\\(usepackage|RequirePackage|PassOptionsToPackage)(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
    "\\\\documentclass(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
    "\\\\begin(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
    "\\\\end(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
    "\\\\([A-Za-z]*cite|Cite)[A-Za-z]*\\*?(\\[[^]]*\\]){0,2}{[^}]*",
    "\\\\([A-Za-z]*cites|Cites)(\\s*\\([^)]*\\)){0,2}((\\s*\\[[^]]*\\]){0,2}\\s*\\{[^}]*\\})*(\\s*\\[[^]]*\\]){0,2}\\s*\\{[^}]*",
    "\\\\bibentry\\s*{[^}]*",
    "\\\\(text|block)cquote\\*?(\\[[^]]*\\]){0,2}{[^}]*",
    "\\\\(for|hy)[A-Za-z]*cquote\\*?{[^}]*}(\\[[^]]*\\]){0,2}{[^}]*",
    "\\\\defbibentryset{[^}]*}{[^}]*",
    "\\\\[A-Za-z]*ref({[^}]*|range{([^,{}]*(}{)?))",
    "\\\\hyperref\\[[^]]*",
    "\\\\([cpdr]?(gls|Gls|GLS)|acr|Acr|ACR)[a-zA-Z]*\\s*\\{[^}]*",
    "\\\\(ac|Ac|AC)\\s*\\{[^}]*",
    "\\\\includegraphics\\*?(\\[[^]]*\\]){0,2}{[^}]*",
    "\\\\(include(only)?|input|subfile){[^}]*",
    "\\\\includepdf(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
    "\\\\includestandalone(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
  },
  ["vimtex#re#ncm2#bibtex"] = {
    "\\\\([A-Za-z]*cite|Cite)[A-Za-z]*\\*?(\\[[^]]*\\]){0,2}{[^}]*",
    "\\\\([A-Za-z]*cites|Cites)(\\s*\\([^)]*\\)){0,2}((\\s*\\[[^]]*\\]){0,2}\\s*\\{[^}]*\\})*(\\s*\\[[^]]*\\]){0,2}\\s*\\{[^}]*",
    "\\\\bibentry\\s*{[^}]*",
    "\\\\(text|block)cquote\\*?(\\[[^]]*\\]){0,2}{[^}]*",
    "\\\\(for|hy)[A-Za-z]*cquote\\*?{[^}]*}(\\[[^]]*\\]){0,2}{[^}]*",
    "\\\\defbibentryset{[^}]*}{[^}]*",
  },
  ["vimtex#re#ncm2#cmds"] = {
    "\\\\[A-Za-z]+",
    "\\\\(usepackage|RequirePackage|PassOptionsToPackage)(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
    "\\\\documentclass(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
    "\\\\begin(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
    "\\\\end(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
  },
  ["vimtex#re#ncm2#files"] = {
    "\\\\includegraphics\\*?(\\[[^]]*\\]){0,2}{[^}]*",
    "\\\\(include(only)?|input|subfile){[^}]*",
    "\\\\includepdf(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
    "\\\\includestandalone(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
  },
  ["vimtex#re#ncm2#labels"] = {
    "\\\\[A-Za-z]*ref({[^}]*|range{([^,{}]*(}{)?))",
    "\\\\hyperref\\[[^]]*",
    "\\\\([cpdr]?(gls|Gls|GLS)|acr|Acr|ACR)[a-zA-Z]*\\s*\\{[^}]*",
    "\\\\(ac|Ac|AC)\\s*\\{[^}]*",
  },
  ["vimtex#re#neocomplete"] = "\\v\\\\%(%(\\a*cite|Cite)\\a*\\*?%(\\s*\\[[^]]*\\]|\\s*\\<[^>]*\\>){0,2}\\s*\\{[^}]*|%(\\a*cites|Cites)%(\\s*\\([^)]*\\)){0,2}%(%(\\s*\\[[^]]*\\]){0,2}\\s*\\{[^}]*\\})*%(\\s*\\[[^]]*\\]){0,2}\\s*\\{[^}]*|bibentry\\s*\\{[^}]*|%(text|block)cquote\\*?%(\\s*\\[[^]]*\\]){0,2}\\s*\\{[^}]*|%(for|hy)\\w*cquote\\*?\\{[^}]*}%(\\s*\\[[^]]*\\]){0,2}\\s*\\{[^}]*|defbibentryset\\{[^}]*}\\{[^}]*|\\a*ref%(\\s*\\{[^}]*|range\\s*\\{[^,}]*%(}\\{)?)|hyperref\\s*\\[[^]]*|includegraphics\\*?%(\\s*\\[[^]]*\\]){0,2}\\s*\\{[^}]*|%(include%(only)?|input|subfile)\\s*\\{[^}]*|([cpdr]?(gls|Gls|GLS)|acr|Acr|ACR)\\a*\\s*\\{[^}]*|(ac|Ac|AC)\\s*\\{[^}]*|includepdf%(\\s*\\[[^]]*\\])?\\s*\\{[^}]*|includestandalone%(\\s*\\[[^]]*\\])?\\s*\\{[^}]*|%(usepackage|RequirePackage|PassOptionsToPackage)%(\\s*\\[[^]]*\\])?\\s*\\{[^}]*|documentclass%(\\s*\\[[^]]*\\])?\\s*\\{[^}]*|begin%(\\s*\\[[^]]*\\])?\\s*\\{[^}]*|end%(\\s*\\[[^]]*\\])?\\s*\\{[^}]*|\\a*)",
  ["vimtex#re#not_bslash"] = "\\v%(\\\\@<!%(\\\\\\\\)*)@<=",
  ["vimtex#re#not_comment"] = "\\v%(\\v%(\\\\@<!%(\\\\\\\\)*)@<=\\%.*)@<!",
  ["vimtex#re#tex_include"] = "\\v^\\c\\s*\\%\\s*!?\\s*tex\\s+root\\s*[=:]\\s*\\zs.*\\ze\\s*$|\\v^\\s*\\zs%(\\v\\\\%(input|include)\\s*\\{|\\v\\\\%(subfile%(include)?|%(sub)?%(import|%(input|include)from)\\*?\\{[^\\}]*\\})\\s*\\{)\\zs[^\\}]*\\ze\\}?|\\v\\\\%(usepackage|RequirePackage)%(\\s*\\[[^]]*\\])?\\s*\\{\\zs[^}]*\\ze\\}",
  ["vimtex#re#tex_input"] = "\\v^\\s*\\zs%(\\v\\\\%(input|include)\\s*\\{|\\v\\\\%(subfile%(include)?|%(sub)?%(import|%(input|include)from)\\*?\\{[^\\}]*\\})\\s*\\{)",
  ["vimtex#re#tex_input_import"] = "\\v\\\\%(subfile%(include)?|%(sub)?%(import|%(input|include)from)\\*?\\{[^\\}]*\\})\\s*\\{",
  ["vimtex#re#tex_input_latex"] = "\\v\\\\%(input|include)\\s*\\{",
  ["vimtex#re#tex_input_package"] = "\\v\\\\%(usepackage|RequirePackage)%(\\s*\\[[^]]*\\])?\\s*\\{\\zs[^}]*\\ze\\}",
  ["vimtex#re#tex_input_root"] = "\\v^\\c\\s*\\%\\s*!?\\s*tex\\s+root\\s*[=:]\\s*\\zs.*\\ze\\s*$",
  ["vimtex#re#youcompleteme"] = {
    "re!\\\\[A-Za-z]+",
    "re!\\\\(usepackage|RequirePackage|PassOptionsToPackage)(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
    "re!\\\\documentclass(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
    "re!\\\\begin(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
    "re!\\\\end(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
    "re!\\\\([A-Za-z]*cite|Cite)[A-Za-z]*\\*?(\\[[^]]*\\]){0,2}{[^}]*",
    "re!\\\\([A-Za-z]*cites|Cites)(\\s*\\([^)]*\\)){0,2}((\\s*\\[[^]]*\\]){0,2}\\s*\\{[^}]*\\})*(\\s*\\[[^]]*\\]){0,2}\\s*\\{[^}]*",
    "re!\\\\bibentry\\s*{[^}]*",
    "re!\\\\(text|block)cquote\\*?(\\[[^]]*\\]){0,2}{[^}]*",
    "re!\\\\(for|hy)[A-Za-z]*cquote\\*?{[^}]*}(\\[[^]]*\\]){0,2}{[^}]*",
    "re!\\\\defbibentryset{[^}]*}{[^}]*",
    "re!\\\\[A-Za-z]*ref({[^}]*|range{([^,{}]*(}{)?))",
    "re!\\\\hyperref\\[[^]]*",
    "re!\\\\([cpdr]?(gls|Gls|GLS)|acr|Acr|ACR)[a-zA-Z]*\\s*\\{[^}]*",
    "re!\\\\(ac|Ac|AC)\\s*\\{[^}]*",
    "re!\\\\includegraphics\\*?(\\[[^]]*\\]){0,2}{[^}]*",
    "re!\\\\(include(only)?|input|subfile){[^}]*",
    "re!\\\\includepdf(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
    "re!\\\\includestandalone(\\s*\\[[^]]*\\])?\\s*\\{[^}]*",
  },
}

function M.init()
  local indicators = vim.g.vimtex_include_indicators or { "input", "include" }
  values["vimtex#re#tex_input_latex"] = [[\v\\%(]]
    .. table.concat(indicators, "|")
    .. [[)\s*\{]]
  values["vimtex#re#tex_input"] = [[\v^\s*\zs%(]]
    .. values["vimtex#re#tex_input_latex"]
    .. "|"
    .. values["vimtex#re#tex_input_import"]
    .. ")"
  values["vimtex#re#tex_include"] = values["vimtex#re#tex_input_root"]
    .. "|"
    .. values["vimtex#re#tex_input"]
    .. [[\zs[^\}]*\ze\}?|]]
    .. values["vimtex#re#tex_input_package"]

  for name, value in pairs(values) do
    vim.g[name] = vim.deepcopy(value)
  end
end

return M
