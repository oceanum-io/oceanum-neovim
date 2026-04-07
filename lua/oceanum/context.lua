local M = {}

-- Get the current buffer's full content as a single string.
-- Returns nil if the buffer is empty or contains only whitespace.
function M.get_buffer_context()
  -- Read all lines from the current buffer (0, 0, -1, false) matches Neovim API
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  if not lines or #lines == 0 then
    return nil
  end

  local content = table.concat(lines, "\n")
  -- If content is empty or whitespace-only, return nil
  if content == nil or content == "" or content:gsub("%s+", "") == "" then
    return nil
  end
  return content
end

-- Main entry point for building a context payload for AI requests.
-- Currently, only the current buffer context is collected.
function M.get_context()
  return M.get_buffer_context()
end

return M
