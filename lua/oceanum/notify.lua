local M = {}

-- Centralized user-facing notifications for Oceanum Neovim plugin
-- Each function issues a vim.notify with an appropriate level.
function M.missing_token()
  local msg = "Oceanum token not configured. Set the DATAMESH_TOKEN environment variable."
  vim.notify(msg, vim.log.levels.ERROR)
end

function M.invalid_token()
  local msg = "Invalid or expired Oceanum token. Check DATAMESH_TOKEN."
  vim.notify(msg, vim.log.levels.ERROR)
end

function M.network_error(msg)
  local full = "Network error: " .. tostring(msg)
  vim.notify(full, vim.log.levels.ERROR)
end

function M.parse_error(msg)
  local full = "Failed to parse response: " .. tostring(msg)
  vim.notify(full, vim.log.levels.ERROR)
end

function M.empty_workspace()
  local full = "No workspace data found. Open Datamesh UI with :OceanumBrowser"
  vim.notify(full, vim.log.levels.WARN)
end

function M.browser_error(url)
  local full = "Could not open browser. Visit: " .. tostring(url)
  vim.notify(full, vim.log.levels.WARN)
end

function M.success(msg)
  vim.notify(tostring(msg), vim.log.levels.INFO)
end

return M
