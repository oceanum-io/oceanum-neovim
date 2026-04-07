local M = {}

function M.get_cursor_position()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return { row = cursor[1], col = cursor[2] }
end

function M.has_editable_buffer()
  local buf = vim.api.nvim_get_current_buf()
  local modifiable = vim.api.nvim_buf_get_option(buf, 'modifiable')
  if not modifiable then
    return false
  end
  local buf_type = vim.api.nvim_buf_get_option(buf, 'buftype')
  if buf_type ~= '' and buf_type ~= 'acwrite' then
    return false
  end
  return true
end

function M.insert_code(content)
  return M.insert(content, "code")
end

function M.insert_markdown(content)
  return M.insert(content, "markdown")
end

function M.insert(content, type)
  if content == nil or content == '' then
    return { success = false, error = "Empty content" }
  end
  
  if not M.has_editable_buffer() then
    vim.fn.setreg('+', content)
    vim.notify("Oceanum: no active editor — code copied to clipboard.", vim.log.levels.WARN)
    return { success = false, error = "No editable buffer", fallback = "clipboard" }
  end
  
  local buf = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]
  
  local lines = vim.split(content, '\n', { plain = true })
  table.insert(lines, '')
  
  vim.api.nvim_buf_set_text(buf, row, col, row, col, lines)
  
  return { success = true }
end

return M