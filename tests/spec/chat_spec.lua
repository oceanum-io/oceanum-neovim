local chat = require('oceanum.chat')
local chat_transport = require('oceanum.chat_transport')
local token = require('oceanum.token')
local insert = require('oceanum.insert')

describe('chat module', function()
  local win, buf
  local original_send, original_has_token, original_insert

  before_each(function()
    chat.clear_history()
    chat.clear_last_code()

    original_send = chat_transport.send
    original_has_token = token.has_token
    original_insert = insert.insert

    token.has_token = function() return true end
    
    chat_transport.send = function(prompt, opts)
      if opts and opts.callback then
        opts.callback({
          success = true,
          response = { type = "code", content = "Here's code", code = "import oceanum" }
        })
      end
      return nil
    end

    insert.insert = function(content, type)
      return { success = true }
    end
  end)

  after_each(function()
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    win = nil
    buf = nil

    chat_transport.send = original_send
    token.has_token = original_has_token
    insert.insert = original_insert

    chat.clear_history()
    chat.clear_last_code()
  end)

  describe('chat.open', function()
    it('returns win and buf handles', function()
      local result = chat.open()

      assert.is_table(result)
      assert.is_number(result.win)
      assert.is_number(result.buf)
      assert.is_true(vim.api.nvim_win_is_valid(result.win))
      assert.is_true(vim.api.nvim_buf_is_valid(result.buf))

      win = result.win
      buf = result.buf
    end)

    it('buffer contains welcome message initially', function()
      local result = chat.open()
      win = result.win
      buf = result.buf

      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local buffer_text = table.concat(lines, "\n")

      assert.is_true(buffer_text:find("Oceanum AI Chat") ~= nil)
      assert.is_true(buffer_text:find("Type a prompt below") ~= nil)
    end)

    it('reuses existing window if already open', function()
      local first_result = chat.open()
      local first_win = first_result.win
      local first_buf = first_result.buf

      local second_result = chat.open()

      assert.is_equal(first_win, second_result.win)
      assert.is_equal(first_buf, second_result.buf)

      win = first_win
      buf = first_buf
    end)
  end)

  describe('chat.close', function()
    it('closes the chat window', function()
      local result = chat.open()
      win = result.win
      buf = result.buf

      assert.is_true(vim.api.nvim_win_is_valid(win))

      chat.close()

      assert.is_false(vim.api.nvim_win_is_valid(win))
      win = nil
    end)

    it('handles being called when no window is open', function()
      local ok = pcall(function()
        chat.close()
      end)

      assert.is_true(ok)
    end)
  end)

  describe('chat.get_history', function()
    it('returns empty table initially', function()
      local history = chat.get_history()
      assert.is_table(history)
      assert.is_equal(0, #history)
    end)
  end)

  describe('chat.clear_history', function()
    it('resets history to empty', function()
      chat.send("test prompt")
      
      vim.wait(50)
      
      assert.is_true(#chat.get_history() > 0)

      chat.clear_history()

      local history = chat.get_history()
      assert.is_equal(0, #history)
    end)

    it('clears last code', function()
      chat.send("test prompt")
      
      vim.wait(50)
      
      chat.clear_history()

      assert.is_nil(chat.get_last_code())
    end)
  end)

  describe('chat.send', function()
    it('adds user message to history', function()
      local callback_saved = nil
      
      chat_transport.send = function(prompt, opts)
        if opts and opts.callback then
          callback_saved = opts.callback
        end
        return nil
      end

      chat.send("test prompt")

      local history = chat.get_history()
      assert.is_equal(1, #history)
      assert.is_equal("user", history[1].role)
      assert.is_equal("test prompt", history[1].content)
    end)

    it('adds assistant message to history after response', function()
      chat.send("test prompt")

      vim.wait(50)

      local history = chat.get_history()
      assert.is_equal(2, #history)
      assert.is_equal("user", history[1].role)
      assert.is_equal("assistant", history[2].role)
      assert.is_equal("Here's code", history[2].content)
    end)

    it('stores code in last_code when response contains code', function()
      chat.send("test prompt")

      vim.wait(50)

      local last_code = chat.get_last_code()
      assert.is_equal("import oceanum", last_code)
    end)

    it('does nothing when prompt is empty', function()
      chat.send("")

      local history = chat.get_history()
      assert.is_equal(0, #history)
    end)

    it('does nothing when prompt is nil', function()
      chat.send(nil)

      local history = chat.get_history()
      assert.is_equal(0, #history)
    end)

    it('shows error in history when token is missing', function()
      token.has_token = function() return false end

      local notifications = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(notifications, { msg = msg, level = level })
      end

      chat.send("test prompt")

      vim.notify = original_notify

      assert.is_equal(1, #notifications)
      assert.is_true(notifications[1].msg:find("token not configured") ~= nil)
    end)

    it('adds error to history when backend returns error', function()
      chat_transport.send = function(prompt, opts)
        if opts and opts.callback then
          opts.callback({
            success = false,
            error = "Backend error"
          })
        end
        return nil
      end

      chat.send("test prompt")

      vim.wait(50)

      local history = chat.get_history()
      assert.is_equal(2, #history)
      assert.is_equal("error", history[2].role)
      assert.is_equal("Backend error", history[2].content)
    end)
  end)

  describe('chat.insert_last_code', function()
    it('calls insert.insert with last code', function()
      local captured_content = nil
      local captured_type = nil

      insert.insert = function(content, type)
        captured_content = content
        captured_type = type
        return { success = true }
      end

      chat.send("test prompt")

      vim.wait(50)

      chat.insert_last_code()

      assert.is_equal("import oceanum", captured_content)
      assert.is_equal("code", captured_type)
    end)

    it('does nothing when last_code is nil', function()
      local insert_called = false

      insert.insert = function(content, type)
        insert_called = true
        return { success = true }
      end

      chat.insert_last_code()

      assert.is_false(insert_called)
    end)

    it('does nothing when last_code is empty string', function()
      local insert_called = false

      insert.insert = function(content, type)
        insert_called = true
        return { success = true }
      end

      chat.clear_history()
      chat.clear_last_code()

      chat.insert_last_code()

      assert.is_false(insert_called)
    end)
  end)

  describe('chat.get_last_code', function()
    it('returns nil initially', function()
      assert.is_nil(chat.get_last_code())
    end)

    it('returns code after code response', function()
      chat.send("test prompt")

      vim.wait(50)

      assert.is_equal("import oceanum", chat.get_last_code())
    end)
  end)

  describe('chat.clear_last_code', function()
    it('clears last code', function()
      chat.send("test prompt")

      vim.wait(50)

      assert.is_not_nil(chat.get_last_code())

      chat.clear_last_code()

      assert.is_nil(chat.get_last_code())
    end)
  end)

  describe('lifecycle loop (leak prevention)', function()
    it('repeated open/close does not leak windows', function()
      local initial_windows = #vim.api.nvim_list_wins()
      
      for i = 1, 5 do
        local result = chat.open()
        assert.is_table(result)
        assert.is_true(vim.api.nvim_win_is_valid(result.win))
        
        chat.close()
        
        vim.wait(10)
      end
      
      local final_windows = #vim.api.nvim_list_wins()
      assert.is_equal(initial_windows, final_windows, "No floating windows should remain after 5 open/close cycles")
    end)

    it('repeated open() reuses same window', function()
      local result1 = chat.open()
      local win1 = result1.win
      local buf1 = result1.buf
      
      local result2 = chat.open()
      local win2 = result2.win
      local buf2 = result2.buf
      
      assert.is_equal(win1, win2, "Second open() should reuse same window")
      assert.is_equal(buf1, buf2, "Second open() should reuse same buffer")
      
      win = win1
      buf = buf1
    end)
  end)
end)
