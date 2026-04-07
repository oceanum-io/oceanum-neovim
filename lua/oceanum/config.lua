-- Copyright Oceanum Ltd. Apache 2.0
-- Configuration module for Oceanum Neovim plugin

local M = {}

--- Default configuration values
local defaults = {
  token_env_var = "OCEANUM_API_KEY",
  ai_backend_url = "https://ai.oceanum.io",
  datamesh_ui_url = "https://ui.datamesh.oceanum.io",
}

--- Known configuration keys
local known_keys = {}
for key, _ in pairs(defaults) do
  known_keys[key] = true
end

--- Merge user config with defaults
---@param user_config table|nil User configuration overrides
---@return table Merged configuration
function M.merge(user_config)
  if user_config == nil then
    return vim.deepcopy(defaults)
  end

  -- Warn on unknown keys
  for key, _ in pairs(user_config) do
    if not known_keys[key] then
      vim.notify(string.format("[oceanum] warning: unknown config key '%s'", key), vim.log.levels.WARN)
    end
  end

  local config = vim.deepcopy(defaults)
  for key, value in pairs(user_config) do
    config[key] = value
  end
  return config
end

--- Get current configuration
---@return table Current configuration
function M.get()
  return M._config or defaults
end

--- Set configuration (internal use)
---@param config table Configuration to set
function M.set(config)
  M._config = config
end

return M