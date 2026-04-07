-- api.lua - HTTP client module for Oceanum Neovim plugin
--
-- Provides workspace fetch and AI transport foundations.
-- Currently fixture-backed pending API discovery.
-- See: .sisyphus/contracts/api-contracts.md for full API contracts.

local M = {}

-- Base URLs (from VS Code constants.ts)
local AI_BACKEND_URL = "https://ai.oceanum.io"
local DATAMESH_UI_URL = "https://ui.datamesh.oceanum.io"

-- Internal state
local _refresh_in_flight = false
local _cached_workspace = nil

--- Load workspace fixture data.
--- Currently uses a local fixture file since the VS Code extension
--- receives workspace data via postMessage from an iframe (not a direct API).
--- This provides a clear extension point for future API integration.
---
--- @return table|nil Workspace spec or nil on failure
--- @return string|nil Error message on failure
local function load_workspace_fixture()
  local plugin_root = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ':h:h:h')
  local fixture_path = plugin_root .. '/tests/fixtures/workspace.json'

  local file = io.open(fixture_path, 'r')
  if not file then
    return nil, "Workspace fixture not found: " .. fixture_path
  end

  local content = file:read('*a')
  file:close()

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok then
    return nil, "Failed to parse workspace fixture: " .. tostring(decoded)
  end

  return decoded, nil
end

--- Fetch workspace data.
---
--- For now: loads from tests/fixtures/workspace.json via fixture loader.
--- Returns { success = true, data = workspace_spec } on success.
--- Returns { success = false, error = "message" } on failure.
---
--- @return table Result with success flag and data or error
function M.fetch_workspace()
  local data, err = load_workspace_fixture()
  if not data then
    return { success = false, error = err }
  end

  _cached_workspace = data
  return { success = true, data = data }
end

--- Generic async HTTP wrapper.
---
--- Checks for plenary.curl first, falls back to vim.system (Neovim 0.10+),
--- then to curl subprocess.
---
--- @param url string The URL to request
--- @param opts table|nil Options: method, headers, body, timeout, callback
--- @return table|nil Async handle if callback not provided, nil otherwise
function M.make_request(url, opts)
  opts = opts or {}
  local method = opts.method or "GET"
  local headers = opts.headers or {}
  local body = opts.body
  local timeout = opts.timeout or 5000  -- 5 seconds default
  local callback = opts.callback

  -- Try plenary.curl first
  local has_plenary, plenary_curl = pcall(require, "plenary.curl")
  if has_plenary then
    local curl_method = method:lower()
    if plenary_curl[curl_method] then
      local request_opts = {
        url = url,
        headers = headers,
        timeout = timeout,
        callback = callback,
      }
      if body then
        request_opts.body = body
      end
      return plenary_curl[curl_method](request_opts)
    end
  end

  -- Fall back to vim.system (Neovim 0.10+)
  if vim.system then
    local cmd = { "curl", "-s", "-w", "\n%{http_code}", "-X", method }

    -- Add headers
    for key, value in pairs(headers) do
      table.insert(cmd, "-H")
      table.insert(cmd, key .. ": " .. value)
    end

    -- Add body
    if body then
      table.insert(cmd, "-d")
      table.insert(cmd, body)
    end

    -- Add timeout (convert ms to seconds)
    table.insert(cmd, "--max-time")
    table.insert(cmd, tostring(math.ceil(timeout / 1000)))

    table.insert(cmd, url)

    if callback then
      vim.system(cmd, { text = true }, function(result)
        local output = result.stdout or ""
        -- Split last line (status code) from body
        local lines = vim.split(output, "\n")
        local status_code = tonumber(lines[#lines]) or 0
        local response_body = table.concat(lines, "\n", 1, #lines - 1)

        callback({
          body = response_body,
          status_code = status_code,
          exit_code = result.code,
        })
      end)
      return nil
    else
      -- Sync call
      local result = vim.system(cmd, { text = true }):wait()
      local output = result.stdout or ""
      local lines = vim.split(output, "\n")
      local status_code = tonumber(lines[#lines]) or 0
      local response_body = table.concat(lines, "\n", 1, #lines - 1)

      return {
        body = response_body,
        status_code = status_code,
        exit_code = result.code,
      }
    end
  end

  -- Last resort: os.execute with temp file (not async)
  if callback then
    local result = M.make_request(url, vim.tbl_extend("force", opts, { callback = nil }))
    callback(result)
    return nil
  end

  return {
    body = "",
    status_code = 0,
    exit_code = -1,
    error = "No HTTP client available (install plenary.nvim or use Neovim 0.10+)",
  }
end

--- Parse HTTP response into structured result.
---
--- @param body string|nil Response body
--- @param status_code number|nil HTTP status code
--- @return table Structured result
function M.parse_response(body, status_code)
  status_code = status_code or 0

  -- 401: Authentication failure
  if status_code == 401 then
    return {
      success = false,
      error = "Invalid or expired Datamesh token.",
      code = 401,
    }
  end

  -- Other error status codes
  if status_code >= 400 then
    return {
      success = false,
      error = "Backend error: " .. (body or "Unknown error"),
      code = status_code,
    }
  end

  -- Success: attempt JSON decode
  if not body or body == "" then
    return {
      success = false,
      error = "Failed to parse response",
    }
  end

  local ok, decoded = pcall(vim.json.decode, body)
  if not ok then
    return {
      success = false,
      error = "Failed to parse response",
    }
  end

  return {
    success = true,
    data = decoded,
  }
end

--- Async workspace refresh with callback.
---
--- Calls fetch_workspace and invokes callback with result.
--- Debounces rapid calls (ignores if already in-flight).
---
--- @param callback function Callback receiving the result table
--- @return boolean True if refresh was started, false if already in-flight
function M.refresh_workspace(callback)
  if _refresh_in_flight then
    return false
  end

  _refresh_in_flight = true

  -- Use vim.defer_fn to simulate async behavior and allow debounce testing
  vim.schedule(function()
    local result = M.fetch_workspace()
    _refresh_in_flight = false

    if callback then
      callback(result)
    end
  end)

  return true
end

--- Get the cached workspace data (if any).
--- @return table|nil
function M.get_cached_workspace()
  return _cached_workspace
end

--- Clear the cached workspace data.
function M.clear_cache()
  _cached_workspace = nil
end

--- Check if a refresh is currently in flight.
--- @return boolean
function M.is_refresh_in_flight()
  return _refresh_in_flight
end

return M
