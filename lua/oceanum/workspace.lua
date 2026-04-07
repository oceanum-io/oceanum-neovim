-- workspace.lua - Workspace browser popup for Oceanum Neovim plugin
--
-- Displays workspace name and datasource list in a floating window.
-- Supports keyboard navigation, refresh, and datasource selection.

local M = {}
local ui = require("oceanum.ui")
local api = require("oceanum.api")

-- Internal state
local _selection = nil
local _current_win = nil
local _current_buf = nil
local _last_code = nil

--- Get the last selected datasource.
--- @return table|nil datasource table or nil
function M.get_selection()
  return _selection
end

--- Clear selection state (for tests).
function M.clear_selection()
  _selection = nil
end

--- Get the last generated code (set on insert action).
--- @return string|nil generated code or nil
function M.get_last_code()
  return _last_code
end

--- Clear last code state (for tests).
function M.clear_last_code()
  _last_code = nil
end

--- Render workspace data into buffer lines.
--- @param workspace table Workspace data from API
--- @return table Array of lines to display
local function render_workspace(workspace)
  local lines = {}
  
  -- Header: workspace name
  table.insert(lines, "Workspace: " .. (workspace.name or "Unknown"))
  table.insert(lines, string.rep("─", 40))
  
  -- Datasource list
  local datasources = workspace.data or {}
  if #datasources == 0 then
    table.insert(lines, "")
    table.insert(lines, "No datasources in workspace.")
    table.insert(lines, "")
    table.insert(lines, "Use :OceanumBrowser to open Datamesh UI.")
  else
    for i, ds in ipairs(datasources) do
      local label = ds.label or ds.id or "Unnamed"
      local ds_type = ds.type or ds.datasource or "unknown"
      local line = string.format("%d. %s   [%s]", i, label, ds_type)
      table.insert(lines, line)
    end
  end
  
  return lines
end

--- Render empty state into buffer lines.
--- @return table Array of lines to display
local function render_empty_state()
  return {
    "No workspace data loaded.",
    "",
    "Press 'r' to refresh or run :OceanumBrowser to open Datamesh UI.",
  }
end

--- Select datasource at current cursor line.
--- @param buf number Buffer handle
--- @param win number Window handle
local function select_current(buf, win)
  local cursor = vim.api.nvim_win_get_cursor(win)
  local line_num = cursor[1]
  
  -- Get workspace data
  local workspace = api.get_cached_workspace()
  if not workspace or not workspace.data then
    return
  end
  
  local datasources = workspace.data
  
  -- Lines 1-2 are header, datasources start at line 3
  local ds_index = line_num - 2
  
  if ds_index >= 1 and ds_index <= #datasources then
    local datasource = datasources[ds_index]
    _selection = datasource
    
    local codegen = require("oceanum.codegen")
    local insert = require("oceanum.insert")
    
    local code = codegen.generate_datasource(datasource, false)
    _last_code = code
    
    insert.insert(code, "code")
    
    M.close()
  end
end

--- Exposed for testing: trigger datasource selection action
function M._select_current(buf, win)
  return select_current(buf, win)
end

--- Refresh workspace data and re-render buffer.
--- @param win number Window handle
--- @param buf number Buffer handle
function M.refresh(win, buf)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end
  
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  
  -- Show loading indicator
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "Refreshing workspace data...",
  })
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  
  -- Fetch fresh data
  api.refresh_workspace(function(result)
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    
    local lines
    if result.success and result.data then
      lines = render_workspace(result.data)
    else
      lines = render_empty_state()
    end
    
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_set_option(buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(buf, "modifiable", false)
      end
    end)
  end)
end

--- Close the workspace popup if open.
function M.close()
  if _current_win then
    ui.close(_current_win)
    _current_win = nil
    _current_buf = nil
  end
end

--- Open the workspace browser popup.
--- Fetches workspace data (or uses cached), renders datasources in a floating window.
--- Returns the window/buf handles for testability.
--- @return table|nil { win, buf } or nil on error
function M.open()
  if _current_win and vim.api.nvim_win_is_valid(_current_win) then
    vim.api.nvim_set_current_win(_current_win)
    return { win = _current_win, buf = _current_buf }
  end
  
  local result = api.fetch_workspace()
  
  local lines
  if result.success and result.data then
    lines = render_workspace(result.data)
  else
    lines = render_empty_state()
  end
  
  -- Open floating window
  local handles = ui.open({
    title = " Oceanum Workspace ",
    width = 0.6,
    height = 0.7,
  })
  
  local win = handles.win
  local buf = handles.buf
  
  -- Store handles for close() and refresh()
  _current_win = win
  _current_buf = buf
  
  -- Populate buffer
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  
  -- Set keymaps
  ui.set_keymaps(buf, {
    { "q", function() M.close() end, "Close workspace browser" },
    { "<Esc>", function() M.close() end, "Close workspace browser" },
    { "<CR>", function() select_current(buf, win) end, "Select datasource" },
    { "r", function() M.refresh(win, buf) end, "Refresh workspace" },
  })
  
  return { win = win, buf = buf }
end

return M
