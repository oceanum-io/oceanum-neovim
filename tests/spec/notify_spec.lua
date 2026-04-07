local notify = require("oceanum.notify")
describe("oceanum.notify", function()
  local original_notify
  local notify_calls
  before_each(function()
    notify_calls = {}
    original_notify = vim.notify
    vim.notify = function(msg, level)
      table.insert(notify_calls, { msg = tostring(msg), level = level })
    end
  end)
  after_each(function()
    vim.notify = original_notify
  end)

  it("issues missing_token error with actionable message", function()
    notify.missing_token()
    assert.are_equal(1, #notify_calls)
    assert.is_true(string.find(notify_calls[1].msg, "Oceanum token") ~= nil)
    assert.are_equal(vim.log.levels.ERROR, notify_calls[1].level)
  end)

  it("issues invalid_token error", function()
    notify.invalid_token()
    assert.are_equal(1, #notify_calls)
    assert.is_true(string.find(notify_calls[1].msg, "Invalid or expired Oceanum token") ~= nil)
    assert.are_equal(vim.log.levels.ERROR, notify_calls[1].level)
  end)

  it("reports network_error with message", function()
    notify.network_error("timeout")
    assert.are_equal(1, #notify_calls)
    assert.is_true(string.find(notify_calls[1].msg, "Network error: timeout") ~= nil)
    assert.are_equal(vim.log.levels.ERROR, notify_calls[1].level)
  end)

  it("reports parse_error with message", function()
    notify.parse_error("invalid-json")
    assert.are_equal(1, #notify_calls)
    assert.is_true(string.find(notify_calls[1].msg, "Failed to parse response") ~= nil)
    assert.are_equal(vim.log.levels.ERROR, notify_calls[1].level)
  end)

  it("warns when workspace is empty", function()
    notify.empty_workspace()
    assert.are_equal(1, #notify_calls)
    assert.is_true(string.find(notify_calls[1].msg, "workspace data found") ~= nil)
    assert.are_equal(vim.log.levels.WARN, notify_calls[1].level)
  end)

  it("warns browser_error with url", function()
    notify.browser_error("http://example.com")
    assert.are_equal(1, #notify_calls)
    assert.is_true(string.find(notify_calls[1].msg, "Could not open browser. Visit: http://example.com") ~= nil)
    assert.are_equal(vim.log.levels.WARN, notify_calls[1].level)
  end)

  it("sends a success message with INFO level", function()
    notify.success("ok")
    assert.are_equal(1, #notify_calls)
    assert.are_equal("ok", notify_calls[1].msg)
    assert.are_equal(vim.log.levels.INFO, notify_calls[1].level)
  end)
end)
