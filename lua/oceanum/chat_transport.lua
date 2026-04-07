-- chat_transport.lua - AI chat request transport for Oceanum Neovim plugin
--
-- Handles sending prompts to https://ai.oceanum.io/api/chat with token auth,
-- context, and chat history. Parses text/code/markdown responses.

local M = {}

local api = require('oceanum.api')
local token = require('oceanum.token')
local config = require('oceanum.config')

--- Build a chat request payload.
--- @param prompt string User prompt text
--- @param opts table|nil { context?, history? }
---   - context: string|nil Buffer context to include
---   - history: table|nil Array of { role, content } message objects
--- @return table JSON-serializable request body
function M.build_request(prompt, opts)
  opts = opts or {}
  local req = { prompt = prompt }
  if opts.history and #opts.history > 0 then
    local history_arr = {}
    for _, msg in ipairs(opts.history) do
      table.insert(history_arr, { role = msg.role, content = msg.content })
    end
    req.chatHistory = history_arr
  end
  if opts.context and opts.context ~= "" then
    req.context = opts.context
  end
  return req
end

--- Parse a raw AI API response body.
--- @param body string|nil Raw JSON response body
--- @param status_code number HTTP status code
--- @return table { success, response?, error? }
---   response: { type, content, code? } where type is 'text'|'code'|'markdown'
function M.parse_ai_response(body, status_code)
  -- Handle 401 authentication errors
  if status_code == 401 then
    return {
      success = false,
      error = "Invalid or expired Datamesh token."
    }
  end
  
  -- Handle other error status codes
  if status_code >= 400 then
    return {
      success = false,
      error = "Backend error: " .. (body or "Unknown error")
    }
  end
  
  -- Handle empty or nil body
  if not body or body == "" then
    return {
      success = false,
      error = "Failed to parse response"
    }
  end
  
  -- Attempt to decode JSON
  local ok, decoded = pcall(vim.json.decode, body)
  if not ok then
    return {
      success = false,
      error = "Failed to parse response"
    }
  end
  
  -- Extract response type
  local response_type = decoded.type
  if not response_type then
    return {
      success = false,
      error = "Missing response type"
    }
  end
  
  -- Build response based on type
  if response_type == "code" then
    return {
      success = true,
      response = {
        type = "code",
        content = decoded.message or "",
        code = decoded.code or ""
      }
    }
  elseif response_type == "text" then
    return {
      success = true,
      response = {
        type = "text",
        content = decoded.message or ""
      }
    }
  elseif response_type == "markdown" then
    return {
      success = true,
      response = {
        type = "markdown",
        content = decoded.content or ""
      }
    }
  else
    return {
      success = false,
      error = "Unknown response type: " .. tostring(response_type)
    }
  end
end

--- Send a chat request to the AI backend.
--- Uses api.make_request() under the hood.
--- Returns parsed result synchronously (no streaming).
--- @param prompt string User prompt
--- @param opts table|nil { context?, history?, callback? }
---   If opts.callback is provided, call asynchronously.
--- @return table { success, response? } or nil if async
function M.send(prompt, opts)
  opts = opts or {}
  
  -- Guard against empty prompts
  if not prompt or prompt == "" then
    local err = { success = false, error = "Prompt cannot be empty" }
    if opts.callback then
      opts.callback(err)
      return nil
    end
    return err
  end
  
  -- Check for token before making request
  if not token.has_token() then
    local err = { success = false, error = "Oceanum token not configured. Set OCEANUM_API_KEY." }
    if opts.callback then
      opts.callback(err)
      return nil
    end
    return err
  end
  
  -- Build request payload
  local request_body = M.build_request(prompt, opts)
  local body_json = vim.json.encode(request_body)
  
  -- Get configuration
  local cfg = config.get()
  local url = cfg.ai_backend_url .. "/api/chat"
  local auth_token = token.get_token()
  
  -- Build request options
  local request_opts = {
    method = "POST",
    headers = {
      ["Content-Type"] = "application/json",
      ["X-Datamesh-Token"] = auth_token
    },
    body = body_json,
    timeout = 30000  -- 30 seconds for AI requests
  }
  
  -- Handle async vs sync
  if opts.callback then
    request_opts.callback = function(result)
      local parsed = M.parse_ai_response(result.body, result.status_code)
      opts.callback(parsed)
    end
    api.make_request(url, request_opts)
    return nil
  else
    local result = api.make_request(url, request_opts)
    return M.parse_ai_response(result.body, result.status_code)
  end
end

return M
