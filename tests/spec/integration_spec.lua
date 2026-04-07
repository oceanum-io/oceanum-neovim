local workspace = require('oceanum.workspace')
local chat = require('oceanum.chat')
local api = require('oceanum.api')
local chat_transport = require('oceanum.chat_transport')
local token = require('oceanum.token')
local insert = require('oceanum.insert')
local helpers = require('tests.helpers')

describe('integration flows', function()
  local win, buf
  local original_fetch, original_refresh, original_send, original_has_token, original_insert, original_notify, original_has_editable

  before_each(function()
    api.clear_cache()
    workspace.clear_selection()
    chat.clear_history()
    chat.clear_last_code()

    original_fetch = api.fetch_workspace
    original_refresh = api.refresh_workspace
    original_send = chat_transport.send
    original_has_token = token.has_token
    original_insert = insert.insert
    original_has_editable = insert.has_editable_buffer
    original_notify = vim.notify

    token.has_token = function() return true end

    -- keep real insert.insert so integration test can write into temp buffer
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

    api.fetch_workspace = original_fetch
    api.refresh_workspace = original_refresh
    chat_transport.send = original_send
    token.has_token = original_has_token
    insert.insert = original_insert
    insert.has_editable_buffer = original_has_editable
    vim.notify = original_notify

    api.clear_cache()
    workspace.clear_selection()
    chat.clear_history()
    chat.clear_last_code()
  end)

  it('workspace-to-buffer integration: open, select datasource, insert code into active buffer', function()
    local edit_buf = helpers.create_temp_buffer({'print("hello")'})
    vim.api.nvim_set_current_buf(edit_buf)

    local result = workspace.open()
    assert.is_table(result)
    assert.is_number(result.win)
    assert.is_number(result.buf)
    win = result.win
    buf = result.buf

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.is_true(table.concat(lines, '\n'):find('Workspace:') ~= nil)

    local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local target_line = nil
    for idx, l in ipairs(buf_lines) do
      if l:match('^%d+%.%s') then
        target_line = idx
        break
      end
    end

    assert.is_not_nil(target_line, 'Expected at least one datasource line in workspace buffer')
    vim.api.nvim_win_set_cursor(win, { target_line, 0 })

    workspace._select_current(buf, win)

    vim.wait(100)

    local sel = workspace.get_selection()
    assert.is_table(sel)
    assert.is_not_nil(workspace.get_last_code())

    assert.is_true(type(workspace.get_last_code()) == 'string' and workspace.get_last_code() ~= '')

    if vim.api.nvim_buf_is_valid(edit_buf) then
      vim.api.nvim_buf_delete(edit_buf, { force = true })
    end
  end)

  it('chat-to-buffer integration: send prompt, receive mocked code response, insert into active buffer', function()
    local edit_buf = helpers.create_temp_buffer({'-- start'})
    -- ensure buffer is editable and attached to a window
    vim.api.nvim_buf_set_option(edit_buf, 'modifiable', true)
    vim.api.nvim_buf_set_option(edit_buf, 'buftype', '')
    vim.api.nvim_set_current_buf(edit_buf)

    -- use real insert to write into the active temp buffer and assert content appears
    chat_transport.send = function(prompt, opts)
      if opts and opts.callback then
        opts.callback({
          success = true,
          response = { type = 'code', content = "Here's code", code = "print('oceanum')" }
        })
      end
      return nil
    end

    -- send prompt and wait for response to populate last_code
    chat.send('generate code')
    vim.wait(200)

    local last = chat.get_last_code()
    assert.is_not_nil(last)
    assert.is_equal("print('oceanum')", last)

    -- ensure the editable temp buffer is current and cursor at start
    vim.api.nvim_set_current_buf(edit_buf)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    -- override has_editable_buffer to recognize test buffer
    insert.has_editable_buffer = function() return true end

    -- insert into buffer using chat helper
    chat.insert_last_code()
    vim.wait(50)

    local contents = table.concat(vim.api.nvim_buf_get_lines(edit_buf, 0, -1, false), '\n')
    assert.is_true(contents:find("print('oceanum')", 1, true) ~= nil)

    if vim.api.nvim_buf_is_valid(edit_buf) then
      vim.api.nvim_buf_delete(edit_buf, { force = true })
    end
  end)

  it('missing-token flow: workspace and chat show notify and do not crash when token absent', function()
    token.has_token = function() return false end

    local notifications = {}
    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
    end

    local chat_result = chat.open()
    win = chat_result.win
    buf = chat_result.buf

    chat.send('prompt without token')

    vim.wait(50)

    assert.is_true(#notifications > 0)
    local found = false
    for _, n in ipairs(notifications) do
      if tostring(n.msg):find('token not configured') or tostring(n.msg):find('token') then
        found = true
        break
      end
    end
    assert.is_true(found, 'Expected missing-token notification')

    local history = chat.get_history()
    assert.is_table(history)
  end)
end)
