describe('oceanum.context', function()
  local ctx = require('oceanum.context')

  before_each(function()
    -- Create a new empty buffer for each test
    vim.api.nvim_command('enew')
  end)

  after_each(function()
    -- Close the current buffer to avoid test pollution
    vim.api.nvim_command('bd!')
  end)

  it('get_buffer_context() returns the full buffer content as a string', function()
    -- Setup buffer content
    local lines = { 'hello', 'world' }
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    local res = ctx.get_buffer_context()
    assert.are.equal('hello\nworld', res)
  end)

  it('get_buffer_context() returns nil for empty buffer', function()
    -- Ensure empty buffer
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
    local res = ctx.get_buffer_context()
    assert.is_nil(res)
  end)

  it('get_buffer_context() returns nil for whitespace-only buffer', function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { '   ', '\t' })
    local res = ctx.get_buffer_context()
    assert.is_nil(res)
  end)

  it('get_context() delegates to get_buffer_context()', function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'alpha', 'beta' })
    local res = ctx.get_context()
    assert.are.equal('alpha\nbeta', res)
  end)
end)
