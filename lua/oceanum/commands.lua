-- Copyright Oceanum Ltd. Apache 2.0
-- Command implementations for Oceanum Neovim plugin

local M = {}

function M.workspace()
  require("oceanum.workspace").open()
end

function M.chat()
  require("oceanum.chat").open()
end

--- Opens Datamesh UI in system browser
-- @return {success: boolean, url: string} Result object for testability
function M.browser()
  local config = require("oceanum.config").get()
  local url = config.datamesh_ui_url

  -- Try vim.ui.open first (Neovim 0.10+)
  if vim.ui and vim.ui.open then
    local success, err = pcall(vim.ui.open, url)
    if success then
      return { success = true, url = url }
    end
  end

  -- Fallback: platform-specific system command
  local cmd
  if vim.fn.has("macunix") == 1 then
    cmd = { "open", url }
  elseif vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    cmd = { "cmd", "/c", "start", url }
  else
    cmd = { "xdg-open", url }
  end

  local result = vim.fn.system(cmd)
  if vim.v.shell_error == 0 then
    return { success = true, url = url }
  end

  -- All methods failed: notify user with raw URL
  vim.notify("Oceanum: could not open browser. Visit: " .. url, vim.log.levels.WARN)
  return { success = false, url = url }
end

--- Insert datasource code at cursor
function M.insert()
  local workspace = require("oceanum.workspace")
  local sel = workspace.get_selection()
  if not sel then
    vim.notify("Oceanum: no datasource selected. Open workspace first with :OceanumWorkspace", vim.log.levels.WARN)
    return
  end
  local codegen = require("oceanum.codegen")
  local insert = require("oceanum.insert")
  local code = codegen.generate_datasource(sel, false)
  insert.insert(code, "code")
end

function M.health()
  require("oceanum.health").run()
end

return M