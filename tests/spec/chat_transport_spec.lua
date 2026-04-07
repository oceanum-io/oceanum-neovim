local chat_transport = require('oceanum.chat_transport')

describe("build_request", function()
  it("includes prompt at top level", function()
    local result = chat_transport.build_request("What is the SST?")
    
    assert.is_table(result)
    assert.equals("What is the SST?", result.prompt)
    assert.is_nil(result.chatHistory)
    assert.is_nil(result.context)
  end)

  it("includes context when provided", function()
    local result = chat_transport.build_request("Analyze this", {
      context = "import oceanum.datamesh\nprint('hello')"
    })
    
    assert.is_table(result)
    assert.equals("import oceanum.datamesh\nprint('hello')", result.context)
  end)

  it("does not include context field when context is empty string", function()
    local result = chat_transport.build_request("Test", { context = "" })
    
    assert.is_nil(result.context)
  end)

  it("does not include context field when context is nil", function()
    local result = chat_transport.build_request("Test", { context = nil })
    
    assert.is_nil(result.context)
  end)

  it("includes history in chatHistory when provided", function()
    local history = {
      { role = "user", content = "Previous question" },
      { role = "assistant", content = "Previous answer" }
    }
    
    local result = chat_transport.build_request("New question", { history = history })
    
    assert.is_table(result.chatHistory)
    assert.equals(#history, #result.chatHistory)
    assert.equals("user", result.chatHistory[1].role)
    assert.equals("Previous question", result.chatHistory[1].content)
    assert.equals("assistant", result.chatHistory[2].role)
    assert.equals("Previous answer", result.chatHistory[2].content)
  end)

  it("handles empty history by omitting chatHistory", function()
    local result = chat_transport.build_request("Test", { history = {} })
    
    assert.is_nil(result.chatHistory)
  end)

  it("combines context and history into chatHistory/context", function()
    local history = {
      { role = "user", content = "What is SST?" },
      { role = "assistant", content = "SST is sea surface temperature." }
    }
    
    local result = chat_transport.build_request("Show me code", {
      context = "import pandas as pd",
      history = history
    })
    
    assert.is_table(result.chatHistory)
    assert.equals(#history, #result.chatHistory)
    assert.equals("import pandas as pd", result.context)
  end)
end)

describe("parse_ai_response", function()
  it("parses code response with success=true, type=code, and code field", function()
    local fixture_path = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ':h:h') .. '/fixtures/ai-response-code.json'
    local file = io.open(fixture_path, 'r')
    local body = file:read('*a')
    file:close()
    
    local result = chat_transport.parse_ai_response(body, 200)
    
    assert.is_true(result.success)
    assert.is_table(result.response)
    assert.equals("code", result.response.type)
    assert.is_string(result.response.content)
    assert.is_string(result.response.code)
    assert.is_true(#result.response.code > 0)
  end)

  it("parses text response with success=true and type=text", function()
    local fixture_path = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ':h:h') .. '/fixtures/ai-response-text.json'
    local file = io.open(fixture_path, 'r')
    local body = file:read('*a')
    file:close()
    
    local result = chat_transport.parse_ai_response(body, 200)
    
    assert.is_true(result.success)
    assert.is_table(result.response)
    assert.equals("text", result.response.type)
    assert.is_string(result.response.content)
    assert.is_true(#result.response.content > 0)
  end)

  it("parses markdown response with success=true and type=markdown", function()
    local fixture_path = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ':h:h') .. '/fixtures/ai-response-markdown.json'
    local file = io.open(fixture_path, 'r')
    local body = file:read('*a')
    file:close()
    
    local result = chat_transport.parse_ai_response(body, 200)
    
    assert.is_true(result.success)
    assert.is_table(result.response)
    assert.equals("markdown", result.response.type)
    assert.is_string(result.response.content)
    assert.is_true(#result.response.content > 0)
  end)

  it("rejects unknown response type with success=false", function()
    local body = '{"type": "unknown", "message": "test"}'
    local result = chat_transport.parse_ai_response(body, 200)
    
    assert.is_false(result.success)
    assert.is_string(result.error)
    assert.matches("Unknown response type", result.error)
  end)

  it("handles 401 with success=false and auth error message", function()
    local result = chat_transport.parse_ai_response("Unauthorized", 401)
    
    assert.is_false(result.success)
    assert.equals("Invalid or expired Datamesh token.", result.error)
  end)

  it("handles 400+ status codes with success=false", function()
    local result = chat_transport.parse_ai_response("Bad request", 400)
    
    assert.is_false(result.success)
    assert.equals("Backend error: Bad request", result.error)
  end)

  it("handles 500+ status codes with success=false", function()
    local result = chat_transport.parse_ai_response("Internal server error", 500)
    
    assert.is_false(result.success)
    assert.equals("Backend error: Internal server error", result.error)
  end)

  it("handles nil body with success=false", function()
    local result = chat_transport.parse_ai_response(nil, 200)
    
    assert.is_false(result.success)
    assert.equals("Failed to parse response", result.error)
  end)

  it("handles empty body with success=false", function()
    local result = chat_transport.parse_ai_response("", 200)
    
    assert.is_false(result.success)
    assert.equals("Failed to parse response", result.error)
  end)

  it("handles invalid JSON with success=false", function()
    local result = chat_transport.parse_ai_response("not valid json {]", 200)
    
    assert.is_false(result.success)
    assert.equals("Failed to parse response", result.error)
  end)

  it("handles missing type field with success=false", function()
    local result = chat_transport.parse_ai_response('{"message": "test"}', 200)
    
    assert.is_false(result.success)
    assert.equals("Missing response type", result.error)
  end)
end)

describe("send", function()
  local original_has_token
  local original_get_token
  local original_make_request

  before_each(function()
    local token = require('oceanum.token')
    local api = require('oceanum.api')
    
    original_has_token = token.has_token
    original_get_token = token.get_token
    original_make_request = api.make_request
  end)

  after_each(function()
    local token = require('oceanum.token')
    local api = require('oceanum.api')
    
    token.has_token = original_has_token
    token.get_token = original_get_token
    api.make_request = original_make_request
  end)

  it("returns error when token not configured", function()
    local token = require('oceanum.token')
    token.has_token = function() return false end
    
    local result = chat_transport.send("Test prompt")
    
    assert.is_false(result.success)
    assert.matches("token not configured", result.error)
    assert.matches("DATAMESH_TOKEN", result.error)
  end)

  it("calls callback with error when token not configured in async mode", function()
    local token = require('oceanum.token')
    token.has_token = function() return false end
    
    local callback_result = nil
    chat_transport.send("Test prompt", {
      callback = function(result)
        callback_result = result
      end
    })
    
    assert.is_not_nil(callback_result)
    assert.is_false(callback_result.success)
    assert.matches("token not configured", callback_result.error)
  end)

  it("returns error when prompt is empty", function()
    local token = require('oceanum.token')
    token.has_token = function() return true end
    
    local result = chat_transport.send("")
    
    assert.is_false(result.success)
    assert.matches("Prompt cannot be empty", result.error)
  end)

  it("returns error when prompt is nil", function()
    local token = require('oceanum.token')
    token.has_token = function() return true end
    
    local result = chat_transport.send(nil)
    
    assert.is_false(result.success)
    assert.matches("Prompt cannot be empty", result.error)
  end)

  it("returns parsed code response from mocked make_request", function()
    local token = require('oceanum.token')
    local api = require('oceanum.api')
    
    token.has_token = function() return true end
    token.get_token = function() return "test-token-123" end
    
    local fixture_path = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ':h:h') .. '/fixtures/ai-response-code.json'
    local file = io.open(fixture_path, 'r')
    local fixture_body = file:read('*a')
    file:close()
    
    api.make_request = function(url, opts)
      return {
        body = fixture_body,
        status_code = 200,
        exit_code = 0
      }
    end
    
    local result = chat_transport.send("Generate SST code")
    
    assert.is_true(result.success)
    assert.is_table(result.response)
    assert.equals("code", result.response.type)
    assert.is_string(result.response.code)
  end)

  it("makes POST request to correct endpoint with auth header", function()
    local token = require('oceanum.token')
    local api = require('oceanum.api')
    
    token.has_token = function() return true end
    token.get_token = function() return "my-secret-token" end
    
    local captured_url = nil
    local captured_opts = nil
    
    api.make_request = function(url, opts)
      captured_url = url
      captured_opts = opts
      return {
        body = '{"type": "text", "message": "Hello"}',
        status_code = 200,
        exit_code = 0
      }
    end
    
    chat_transport.send("Test")
    
    assert.is_not_nil(captured_url)
    assert.matches("https://ai.oceanum.io/api/chat", captured_url)
    assert.equals("POST", captured_opts.method)
    assert.equals("application/json", captured_opts.headers["Content-Type"])
    assert.equals("my-secret-token", captured_opts.headers["X-Datamesh-Token"])
  end)

  it("includes context and history in request body", function()
    local token = require('oceanum.token')
    local api = require('oceanum.api')
    
    token.has_token = function() return true end
    token.get_token = function() return "token" end
    
    local captured_body = nil
    
    api.make_request = function(url, opts)
      captured_body = opts.body
      return {
        body = '{"type": "text", "message": "OK"}',
        status_code = 200,
        exit_code = 0
      }
    end
    
    chat_transport.send("New prompt", {
      context = "import oceanum",
      history = {
        { role = "user", content = "Old question" },
        { role = "assistant", content = "Old answer" }
      }
    })
    
    assert.is_not_nil(captured_body)
    local decoded = vim.json.decode(captured_body)
    assert.is_table(decoded)
    assert.equals("New prompt", decoded.prompt)
    assert.is_table(decoded.chatHistory)
    assert.equals(2, #decoded.chatHistory)
    assert.equals("import oceanum", decoded.context)
  end)
end)
