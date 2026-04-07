-- Copyright Oceanum Ltd. Apache 2.0
local config = require("oceanum.config")
local commands = require("oceanum.commands")

local M = {}

local registered = false

function M.setup(user_config)
  local cfg = config.merge(user_config)
  config.set(cfg)

  if not registered then
    vim.api.nvim_create_user_command("OceanumWorkspace", function()
      commands.workspace()
    end, { desc = "Open Oceanum workspace browser" })

    vim.api.nvim_create_user_command("OceanumChat", function()
      commands.chat()
    end, { desc = "Open Oceanum AI chat" })

    vim.api.nvim_create_user_command("OceanumBrowser", function()
      commands.browser()
    end, { desc = "Open Datamesh UI in browser" })

    vim.api.nvim_create_user_command("OceanumInsert", function()
      commands.insert()
    end, { desc = "Insert datasource code at cursor" })

    vim.api.nvim_create_user_command("OceanumHealth", function()
      commands.health()
    end, { desc = "Run Oceanum health check" })

    registered = true
  end
end

function M.get_config()
  return config.get()
end

return M