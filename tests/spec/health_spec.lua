local health = require("oceanum.health")

describe("Oceanum health module", function()
  local original_print
  local captured = {}

  before_each(function()
    captured = {}
    original_print = _G.print
    _G.print = function(...)
      local args = { ... }
      local line = table.concat(args, " ")
      table.insert(captured, line)
    end
  end)

  after_each(function()
    _G.print = original_print
    vim.env.OCEANUM_API_KEY = nil
  end)

  it("check() with token present returns ok and API Token = ok", function()
    vim.env.OCEANUM_API_KEY = "test-token"
    local result = health.check()
    assert.is_truthy(result and result.ok)

    local found = false
    for _, c in ipairs(result.checks or {}) do
      if c.name == "API Token" then
        found = true
        assert.equal("ok", c.status)
      end
    end
    assert.is_true(found)
  end)

  it("check() without token returns not ok and API Token = warning", function()
    vim.env.OCEANUM_API_KEY = nil
    local result = health.check()
    assert.is_false(result.ok)

    local tok = nil
    for _, c in ipairs(result.checks or {}) do
      if c.name == "API Token" then tok = c end
    end
    assert.is_not_nil(tok)
    assert.equal("warning", tok.status)
    local msg = tok.message or ""
    assert.match("OCEANUM_API_KEY", msg)
  end)

  it("check() includes Lua Version and Neovim checks and has at least 3 items", function()
    local result = health.check()
    assert.is_table(result.checks)
    assert.is_true(#result.checks >= 3)

    local has_lua_ok = false
    local has_neovim_check = false
    for _, c in ipairs(result.checks or {}) do
      if c.name == "Lua Version" and c.status == "ok" then has_lua_ok = true end
      if type(c.name) == "string" and string.find(c.name, "Neovim") then has_neovim_check = true end
    end
    assert.is_true(has_lua_ok)
    assert.is_true(has_neovim_check)
  end)

  it("run() prints header (and at least one more line) and does not error", function()
    vim.env.OCEANUM_API_KEY = "test-token"
    health.run()
    -- Expect at least one line printed, with a header line
    assert.is_true(#captured > 0)
    assert.match("Oceanum Health Check", captured[1] or "")
    assert.is_true(#captured >= 2)
  end)
end)
