local workspace = require('oceanum.workspace')
local api = require('oceanum.api')

describe('workspace module', function()
  local win, buf

  before_each(function()
    api.clear_cache()
    workspace.clear_selection()
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
    workspace.clear_selection()
    api.clear_cache()
  end)

  describe('workspace.open', function()
    it('returns win and buf handles', function()
      local result = workspace.open()

      assert.is_table(result)
      assert.is_number(result.win)
      assert.is_number(result.buf)
      assert.is_true(vim.api.nvim_win_is_valid(result.win))
      assert.is_true(vim.api.nvim_buf_is_valid(result.buf))

      win = result.win
      buf = result.buf
    end)

    it('buffer contains workspace name from fixture', function()
      local result = workspace.open()
      win = result.win
      buf = result.buf

      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local found_workspace_line = false

      for _, line in ipairs(lines) do
        if line:match("Workspace:") then
          found_workspace_line = true
          break
        end
      end

      assert.is_true(found_workspace_line, "Expected 'Workspace:' line in buffer")
    end)

    it('buffer contains datasource label from fixture', function()
      local result = workspace.open()
      win = result.win
      buf = result.buf

      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local buffer_text = table.concat(lines, "\n")

      assert.is_true(buffer_text:find("SST Dataset") ~= nil, "Expected 'SST Dataset' label in buffer")
    end)

    it('shows empty state when no workspace data available', function()
      local original_fetch = api.fetch_workspace
      api.fetch_workspace = function()
        return { success = false, error = "no data" }
      end

      local result = workspace.open()
      win = result.win
      buf = result.buf

      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local buffer_text = table.concat(lines, "\n")

      assert.is_true(buffer_text:find("No workspace data loaded") ~= nil, "Expected empty state message")
      assert.is_true(buffer_text:find("OceanumBrowser") ~= nil, "Expected hint to use OceanumBrowser")

      api.fetch_workspace = original_fetch
    end)
  end)

  describe('workspace.close', function()
    it('closes the workspace window', function()
      local result = workspace.open()
      win = result.win
      buf = result.buf

      assert.is_true(vim.api.nvim_win_is_valid(win))

      workspace.close()

      assert.is_false(vim.api.nvim_win_is_valid(win))
      win = nil
    end)

    it('handles being called when no window is open', function()
      local ok = pcall(function()
        workspace.close()
      end)

      assert.is_true(ok, "workspace.close should not error when no window is open")
    end)
  end)

  describe('workspace.get_selection', function()
    it('returns nil initially', function()
      local selection = workspace.get_selection()
      assert.is_nil(selection)
    end)

    it('returns nil after clear_selection', function()
      workspace.clear_selection()
      local selection = workspace.get_selection()
      assert.is_nil(selection)
    end)
  end)

  describe('workspace.refresh', function()
    it('updates buffer with refreshed data', function()
      local result = workspace.open()
      win = result.win
      buf = result.buf

      local original_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

      workspace.refresh(win, buf)

      vim.wait(100)

      local new_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.is_table(new_lines)
      assert.is_true(#new_lines > 0, "Buffer should contain refreshed data")
    end)

    it('handles invalid window handle gracefully', function()
      local ok = pcall(function()
        workspace.refresh(99999, 1)
      end)

      assert.is_true(ok, "refresh should not error with invalid window")
    end)

    it('handles invalid buffer handle gracefully', function()
      local result = workspace.open()
      win = result.win
      buf = result.buf

      local ok = pcall(function()
        workspace.refresh(win, 99999)
      end)

      assert.is_true(ok, "refresh should not error with invalid buffer")
    end)
  end)

  describe('datasource insert action', function()
    before_each(function()
      workspace.clear_selection()
      workspace.clear_last_code()
    end)

    after_each(function()
      workspace.clear_selection()
      workspace.clear_last_code()
    end)

    it('selecting a datasource from workspace popup generates and inserts code', function()
      local insert_module = require('oceanum.insert')
      local original_insert = insert_module.insert
      local captured_content = nil
      local captured_type = nil

      insert_module.insert = function(content, type)
        captured_content = content
        captured_type = type
        return { success = true }
      end

      local result = workspace.open()
      win = result.win
      buf = result.buf

      vim.api.nvim_win_set_cursor(win, { 3, 0 })

      workspace._select_current(buf, win)

      local selection = workspace.get_selection()
      assert.is_table(selection, "Selection should be set after selecting datasource")
      assert.is_equal("ds-001", selection.id)

      assert.is_not_nil(captured_content, "insert() should have been called with content")
      assert.is_equal("code", captured_type)
      assert.is_true(captured_content:find("from oceanum.datamesh import Connector") ~= nil)
      assert.is_true(captured_content:find("sst%-global%-daily") ~= nil)

      local last_code = workspace.get_last_code()
      assert.is_equal(captured_content, last_code)

      insert_module.insert = original_insert
    end)

    it('sparse datasource (only id, no label/variables) does not crash', function()
      local sparse_data = {
        name = "Sparse Workspace",
        data = {
          {
            id = "ds-sparse",
            datasource = "sparse-ds"
          }
        }
      }
      
      local original_fetch = api.fetch_workspace
      local original_get_cached = api.get_cached_workspace
      
      api.fetch_workspace = function()
        return {
          success = true,
          data = sparse_data
        }
      end
      
      api.get_cached_workspace = function()
        return sparse_data
      end
      
      api.clear_cache()

      local insert_module = require('oceanum.insert')
      local original_insert = insert_module.insert
      local captured_content = nil

      insert_module.insert = function(content, type)
        captured_content = content
        return { success = true }
      end

      local result = workspace.open()
      win = result.win
      buf = result.buf

      vim.api.nvim_win_set_cursor(win, { 3, 0 })

      local ok, err = pcall(function()
        workspace._select_current(buf, win)
      end)
      
      insert_module.insert = original_insert
      api.fetch_workspace = original_fetch
      api.get_cached_workspace = original_get_cached
      api.clear_cache()

      assert.is_true(ok, "Selecting sparse datasource should not crash. Error: " .. tostring(err))
      assert.is_not_nil(captured_content, "Code should have been generated even for sparse datasource")
      assert.is_true(captured_content:find("sparse%-ds") ~= nil)
    end)

    it('commands.insert() with no selection shows warning', function()
      workspace.clear_selection()

      local notifications = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(notifications, { msg = msg, level = level })
      end

      local commands = require('oceanum.commands')
      local ok = pcall(function()
        commands.insert()
      end)

      assert.is_true(ok, "commands.insert() with no selection should not crash")
      assert.is_equal(1, #notifications)
      assert.is_true(notifications[1].msg:find("no datasource selected") ~= nil)
      assert.is_equal(vim.log.levels.WARN, notifications[1].level)

      vim.notify = original_notify
    end)

    it('commands.insert() with selection calls insert', function()
      local result = workspace.open()
      win = result.win
      buf = result.buf

      vim.api.nvim_win_set_cursor(win, { 4, 0 })

      local insert_module = require('oceanum.insert')
      local original_insert = insert_module.insert
      local first_captured_content = nil

      insert_module.insert = function(content, type)
        first_captured_content = content
        return { success = true }
      end

      workspace._select_current(buf, win)

      local selection = workspace.get_selection()
      assert.is_table(selection)
      assert.is_equal("ds-002", selection.id)

      local second_captured_content = nil
      insert_module.insert = function(content, type)
        second_captured_content = content
        return { success = true }
      end

      local commands = require('oceanum.commands')
      commands.insert()

      assert.is_not_nil(second_captured_content, "commands.insert() should call insert.insert()")
      assert.is_true(second_captured_content:find("modis%-oc") ~= nil)

      insert_module.insert = original_insert
    end)
  end)

  describe('lifecycle loop (leak prevention)', function()
    it('repeated open/close does not leak windows', function()
      local initial_windows = #vim.api.nvim_list_wins()
      
      for i = 1, 5 do
        local result = workspace.open()
        assert.is_table(result)
        assert.is_true(vim.api.nvim_win_is_valid(result.win))
        
        workspace.close()
        
        vim.wait(10)
      end
      
      local final_windows = #vim.api.nvim_list_wins()
      assert.is_equal(initial_windows, final_windows, "No floating windows should remain after 5 open/close cycles")
    end)

    it('repeated open() reuses same window', function()
      local result1 = workspace.open()
      local win1 = result1.win
      local buf1 = result1.buf
      
      local result2 = workspace.open()
      local win2 = result2.win
      local buf2 = result2.buf
      
      assert.is_equal(win1, win2, "Second open() should reuse same window")
      assert.is_equal(buf1, buf2, "Second open() should reuse same buffer")
      
      win = win1
      buf = buf1
    end)
  end)
end)
