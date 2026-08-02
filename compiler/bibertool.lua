if vim.b.current_compiler then
  return
end
vim.b.current_compiler = "bibertool"

vim.bo.makeprg =
  "biber --nodieonerror --noconf --nolog --output-file=- --validate-datamodel --tool %:S"
vim.bo.errorformat = table.concat({
  "%-PINFO - Globbing data source '%f'",
  "%EERROR - %*[^,], line %l, %m",
  "%WWARN - Datamodel: Entry '%s' (%f): %m",
  "%WWARN - Datamodel: %m",
  "%-G%.%#",
}, ",")
