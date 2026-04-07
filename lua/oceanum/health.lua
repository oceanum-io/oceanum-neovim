-- Copyright Oceanum Ltd. Apache 2.0
-- Health check module for Oceanum Neovim plugin

local M = {}

--- Run health check and return status
function M.check()
  local status = {
    ok = true,
    checks = {},
  }

  local token = require("oceanum.token")

  if token.has_token() then
    table.insert(status.checks, {
      name = "API Token",
      status = "ok",
      message = string.format("Token found via $%s", require("oceanum.config").get().token_env_var),
    })
  else
    table.insert(status.checks, {
      name = "API Token",
      status = "warning",
      message = string.format("MISSING - set %s environment variable", require("oceanum.config").get().token_env_var),
    })
    status.ok = false
  end

  local plenary_ok, _ = pcall(require, "plenary.busted")
  if plenary_ok then
    table.insert(status.checks, {
      name = "plenary.nvim",
      status = "ok",
      message = "plenary.nvim is available",
    })
  else
    table.insert(status.checks, {
      name = "plenary.nvim",
      status = "warning",
      message = "plenary.nvim not found - HTTP features require it",
    })
    status.ok = false
  end

  local lua_version = _VERSION:gsub("Lua ", "")
  table.insert(status.checks, {
    name = "Lua Version",
    status = "ok",
    message = string.format("Lua %s", lua_version),
  })

  local nvim_version = vim.fn.matchstr(vim.fn.execute("version"), "NVIM v\\zs[^-]*")
  table.insert(status.checks, {
    name = "Neovim",
    status = "ok",
    message = string.format("Neovim %s", nvim_version),
  })

  return status
end

--- Print health check results
function M.run()
  local status = M.check()
  print("Oceanum Health Check")
  print(string.rep("=", 50))

  for _, check in ipairs(status.checks) do
    local icon = check.status == "ok" and "✓" or (check.status == "warning" and "⚠" or "✗")
    print(string.format("%s %s: %s", icon, check.name, check.message))
  end

  print(string.rep("=", 50))
  if status.ok then
    print("Status: OK")
  else
    print("Status: WARNINGS")
  end
end

return M