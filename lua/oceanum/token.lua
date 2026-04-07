-- Copyright Oceanum Ltd. Apache 2.0
-- Token management module for Oceanum Neovim plugin

local M = {}

--- Get the API token from environment variable
---@return string|nil The token value or nil if not set
function M.get_token()
  local config = require("oceanum.config").get()
  local token = vim.env[config.token_env_var]
  if token and #token > 0 then
    return token
  end
  return nil
end

--- Check if a token is available
---@return boolean True if token is set and non-empty
function M.has_token()
  return M.get_token() ~= nil
end

return M
