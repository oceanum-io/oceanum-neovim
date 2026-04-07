local commands = require('oceanum.commands')
local config = require('oceanum.config')

describe('browser command', function()
  local original_ui_open = vim.ui.open

  after_each(function()
    vim.ui.open = original_ui_open
    vim.fn.has = nil
    vim.fn.system = nil
  end)

  describe('URL handling', function()
    it('uses datamesh_ui_url from config', function()
      local cfg = config.get()
      assert.is_not_nil(cfg.datamesh_ui_url)
      assert.equals('https://ui.datamesh.oceanum.io', cfg.datamesh_ui_url)
    end)
  end)

  describe('vim.ui.open path (Neovim 0.10+)', function()
    it('returns success when vim.ui.open succeeds', function()
      vim.ui.open = function(url)
        return true
      end

      local result = commands.browser()

      assert.is_true(result.success)
      assert.equals('https://ui.datamesh.oceanum.io', result.url)
    end)
  end)

  describe('fallback path', function()
    it('returns success when system command succeeds', function()
      vim.ui.open = nil
      vim.fn.has = function(sys)
        if sys == 'macunix' then return 0 end
        if sys == 'win32' then return 0 end
        if sys == 'win64' then return 0 end
        return 1
      end
      vim.fn.system = function(cmd)
        return ''
      end

      local result = commands.browser()

      assert.is_true(result.success)
      assert.equals('https://ui.datamesh.oceanum.io', result.url)
    end)
  end)

  describe('result structure', function()
    it('returns result with success and url fields', function()
      vim.ui.open = function(url)
        return true
      end

      local result = commands.browser()

      assert.is_boolean(result.success)
      assert.is_string(result.url)
      assert.equals('https://ui.datamesh.oceanum.io', result.url)
    end)
  end)
end)
