local M = {}

local ui = require('oceanum.ui')
local chat_transport = require('oceanum.chat_transport')
local context = require('oceanum.context')
local insert = require('oceanum.insert')
local token = require('oceanum.token')
local notify = require('oceanum.notify')

local _current_win = nil
local _current_buf = nil
local _history = {}
local _last_code = nil
local _is_loading = false

local function render_chat(buf)
  local lines = {}
  
  for _, msg in ipairs(_history) do
    if msg.role == "user" then
      table.insert(lines, "[User] " .. msg.content)
    elseif msg.role == "assistant" then
      table.insert(lines, "[Oceanum AI] " .. msg.content)
      if msg.code then
        table.insert(lines, "  Code: press 'i' to insert")
      end
    elseif msg.role == "error" then
      table.insert(lines, "[Error] " .. msg.content)
    end
    table.insert(lines, "")
  end
  
  if _is_loading then
    table.insert(lines, "[Loading...]")
  end
  
  if #lines == 0 then
    table.insert(lines, "Oceanum AI Chat")
    table.insert(lines, "Type a prompt below and press Enter to send.")
    table.insert(lines, "")
  end
  
  table.insert(lines, string.rep("─", 40))
  table.insert(lines, "> (type here and press Enter to send)")
  
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

function M.open()
  if _current_win and vim.api.nvim_win_is_valid(_current_win) then
    vim.api.nvim_set_current_win(_current_win)
    return { win = _current_win, buf = _current_buf }
  end
  
  local result = ui.open({
    title = "Oceanum AI Chat",
    width = 0.7,
    height = 0.6,
    border = "rounded"
  })
  
  _current_win = result.win
  _current_buf = result.buf
  
  render_chat(_current_buf)
  
  ui.set_keymaps(_current_buf, {
    { "q", function() M.close() end, "Close chat" },
    { "<Esc>", function() M.close() end, "Close chat" },
    { "<CR>", function()
      vim.ui.input({ prompt = "Prompt: " }, function(input)
        if input and input ~= "" then
          M.send(input)
        end
      end)
    end, "Send prompt" },
    { "i", function() M.insert_last_code() end, "Insert last code" },
  })
  
  return { win = _current_win, buf = _current_buf }
end

function M.close()
  if _current_win and vim.api.nvim_win_is_valid(_current_win) then
    ui.close(_current_win)
  end
  _current_win = nil
  _current_buf = nil
end

function M.send(prompt)
  if not prompt or prompt == "" then
    return
  end
  
  if not token.has_token() then
    notify.missing_token()
    return
  end
  
  table.insert(_history, { role = "user", content = prompt })
  _is_loading = true
  
  if _current_buf and vim.api.nvim_buf_is_valid(_current_buf) then
    render_chat(_current_buf)
  end
  
  local ctx = context.get_context()
  
  chat_transport.send(prompt, {
    context = ctx,
    callback = function(result)
      _is_loading = false
      
      if result.success and result.response then
        local resp = result.response
        local entry = {
          role = "assistant",
          content = resp.content or "",
          type = resp.type,
        }
        
        if resp.code and resp.code ~= "" then
          _last_code = resp.code
          entry.code = resp.code
        end
        
        table.insert(_history, entry)
      else
        table.insert(_history, {
          role = "error",
          content = result.error or "Unknown error"
        })
      end
      
      vim.schedule(function()
        if _current_buf and vim.api.nvim_buf_is_valid(_current_buf) then
          render_chat(_current_buf)
        end
      end)
    end
  })
end

function M.insert_last_code()
  if not _last_code or _last_code == "" then
    return
  end
  
  insert.insert(_last_code, "code")
end

function M.get_history()
  return _history
end

function M.clear_history()
  _history = {}
  _last_code = nil
  _is_loading = false
end

function M.get_last_code()
  return _last_code
end

function M.clear_last_code()
  _last_code = nil
end

return M
