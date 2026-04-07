local ui = require('oceanum.ui')
local helpers = require('tests.helpers')

describe('ui.clamp_dimensions', function()
  it('clamps width and height to max values', function()
    local w, h = ui.clamp_dimensions(200, 100, 80, 40)
    assert.equals(80, w)
    assert.equals(40, h)
  end)

  it('returns dimensions when within max bounds', function()
    local w, h = ui.clamp_dimensions(50, 30, 80, 40)
    assert.equals(50, w)
    assert.equals(30, h)
  end)

  it('enforces minimum dimensions of 10x5', function()
    local w, h = ui.clamp_dimensions(1, 1, 80, 40)
    assert.equals(10, w)
    assert.equals(5, h)
  end)

  it('uses default max values when not provided', function()
    local w, h = ui.clamp_dimensions(50, 20)
    assert.equals(50, w)
    assert.equals(20, h)
  end)
end)

describe('ui.open', function()
  local win, buf

  after_each(function()
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    win = nil
    buf = nil
  end)

  it('creates a floating window and returns win+buf handles', function()
    local result = ui.open({})
    
    assert.is_table(result)
    assert.is_number(result.win)
    assert.is_number(result.buf)
    assert.is_true(vim.api.nvim_win_is_valid(result.win))
    assert.is_true(vim.api.nvim_buf_is_valid(result.buf))
    
    helpers.assert_floating_window_exists(result.win)
    
    win = result.win
    buf = result.buf
  end)

  it('accepts title option without error', function()
    local result = ui.open({ title = 'Test Window' })
    
    assert.is_table(result)
    assert.is_true(vim.api.nvim_win_is_valid(result.win))
    
    win = result.win
    buf = result.buf
  end)

  it('handles fractional width and height', function()
    local result = ui.open({ width = 0.5, height = 0.4 })
    
    assert.is_table(result)
    assert.is_true(vim.api.nvim_win_is_valid(result.win))
    
    local win_config = vim.api.nvim_win_get_config(result.win)
    assert.is_true(win_config.width > 0)
    assert.is_true(win_config.height > 0)
    
    win = result.win
    buf = result.buf
  end)

  it('handles absolute integer width and height', function()
    local result = ui.open({ width = 40, height = 20 })
    
    assert.is_table(result)
    assert.is_true(vim.api.nvim_win_is_valid(result.win))
    
    local win_config = vim.api.nvim_win_get_config(result.win)
    assert.equals(40, win_config.width)
    assert.equals(20, win_config.height)
    
    win = result.win
    buf = result.buf
  end)

  it('creates a scratch buffer with correct options', function()
    local result = ui.open({})
    
    local buftype = vim.api.nvim_buf_get_option(result.buf, 'buftype')
    local bufhidden = vim.api.nvim_buf_get_option(result.buf, 'bufhidden')
    
    assert.equals('nofile', buftype)
    assert.equals('wipe', bufhidden)
    
    win = result.win
    buf = result.buf
  end)

  it('reuses provided buffer when specified', function()
    local existing_buf = vim.api.nvim_create_buf(false, true)
    
    local result = ui.open({ buf = existing_buf })
    
    assert.equals(existing_buf, result.buf)
    assert.is_true(vim.api.nvim_win_is_valid(result.win))
    
    win = result.win
    buf = result.buf
  end)

  it('applies custom border style', function()
    local result = ui.open({ border = 'single' })
    
    local win_config = vim.api.nvim_win_get_config(result.win)
    assert.is_table(win_config.border)
    assert.equals(8, #win_config.border)
    
    win = result.win
    buf = result.buf
  end)

  it('uses rounded border by default', function()
    local result = ui.open({})
    
    local win_config = vim.api.nvim_win_get_config(result.win)
    assert.is_table(win_config.border)
    assert.equals(8, #win_config.border)
    
    win = result.win
    buf = result.buf
  end)
end)

describe('ui.close', function()
  it('closes a valid window', function()
    local result = ui.open({})
    local win = result.win
    
    assert.is_true(vim.api.nvim_win_is_valid(win))
    
    ui.close(win)
    
    assert.is_false(vim.api.nvim_win_is_valid(win))
  end)

  it('handles invalid window handle without error', function()
    local invalid_win = 99999
    
    local ok = pcall(function()
      ui.close(invalid_win)
    end)
    
    assert.is_true(ok)
  end)
end)

describe('ui.open with small terminal dimensions', function()
  local win, buf
  local original_columns, original_lines

  before_each(function()
    original_columns = vim.o.columns
    original_lines = vim.o.lines
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
    
    vim.o.columns = original_columns
    vim.o.lines = original_lines
  end)

  it('handles 40x10 terminal size without crashing', function()
    vim.o.columns = 40
    vim.o.lines = 10
    
    local ok, result = pcall(function()
      return ui.open({ width = 0.8, height = 0.6 })
    end)
    
    assert.is_true(ok, "ui.open should not crash with small terminal dimensions")
    assert.is_table(result)
    assert.is_true(vim.api.nvim_win_is_valid(result.win))
    
    local win_config = vim.api.nvim_win_get_config(result.win)
    assert.is_true(win_config.width >= 10, "Window width should be at least 10")
    assert.is_true(win_config.height >= 5, "Window height should be at least 5")
    
    win = result.win
    buf = result.buf
  end)

  it('clamps to minimum dimensions for tiny terminals', function()
    vim.o.columns = 20
    vim.o.lines = 8
    
    local result = ui.open({ width = 0.9, height = 0.8 })
    
    assert.is_table(result)
    assert.is_true(vim.api.nvim_win_is_valid(result.win))
    
    local win_config = vim.api.nvim_win_get_config(result.win)
    assert.is_true(win_config.width >= 10, "Width should be at least minimum 10")
    assert.is_true(win_config.height >= 5, "Height should be at least minimum 5")
    
    win = result.win
    buf = result.buf
  end)
end)

describe('ui.set_keymaps', function()
  local buf

  before_each(function()
    buf = vim.api.nvim_create_buf(false, true)
  end)

  after_each(function()
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    buf = nil
  end)

  it('sets keymaps from array format without error', function()
    local ok = pcall(function()
      ui.set_keymaps(buf, {
        { 'q', function() end },
        { '<Esc>', function() end },
      })
    end)
    
    assert.is_true(ok)
  end)

  it('sets keymaps with description', function()
    local ok = pcall(function()
      ui.set_keymaps(buf, {
        { 'q', function() end, 'Close window' },
      })
    end)
    
    assert.is_true(ok)
  end)

  it('handles function callbacks', function()
    local callback_called = false
    
    ui.set_keymaps(buf, {
      { 'x', function() callback_called = true end },
    })
    
    local keymaps = vim.api.nvim_buf_get_keymap(buf, 'n')
    local found = false
    for _, km in ipairs(keymaps) do
      if km.lhs == 'x' then
        found = true
        break
      end
    end
    
    assert.is_true(found)
  end)

  it('handles string command as rhs', function()
    ui.set_keymaps(buf, {
      { 'j', 'j' },
    })
    
    local keymaps = vim.api.nvim_buf_get_keymap(buf, 'n')
    local found = false
    for _, km in ipairs(keymaps) do
      if km.lhs == 'j' then
        found = true
        break
      end
    end
    
    assert.is_true(found)
  end)

  it('handles empty mappings array without error', function()
    local ok = pcall(function()
      ui.set_keymaps(buf, {})
    end)
    
    assert.is_true(ok)
  end)
end)
