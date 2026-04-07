local api = require('oceanum.api')

describe("parse_response", function()
  it("returns success with valid JSON body and 200 status", function()
    local body = '{"name": "test", "value": 42}'
    local result = api.parse_response(body, 200)
    
    assert.is_true(result.success)
    assert.is_table(result.data)
    assert.equals("test", result.data.name)
    assert.equals(42, result.data.value)
  end)

  it("returns 401 error for unauthorized status", function()
    local result = api.parse_response("Unauthorized", 401)
    
    assert.is_false(result.success)
    assert.equals("Invalid or expired Datamesh token.", result.error)
    assert.equals(401, result.code)
  end)

  it("returns error for 400+ status codes", function()
    local result = api.parse_response("Bad request", 400)
    
    assert.is_false(result.success)
    assert.equals("Backend error: Bad request", result.error)
    assert.equals(400, result.code)
  end)

  it("returns error for 500+ status codes", function()
    local result = api.parse_response("Internal server error", 500)
    
    assert.is_false(result.success)
    assert.equals("Backend error: Internal server error", result.error)
    assert.equals(500, result.code)
  end)

  it("returns error for empty body", function()
    local result = api.parse_response("", 200)
    
    assert.is_false(result.success)
    assert.equals("Failed to parse response", result.error)
  end)

  it("returns error for nil body", function()
    local result = api.parse_response(nil, 200)
    
    assert.is_false(result.success)
    assert.equals("Failed to parse response", result.error)
  end)

  it("returns error for invalid JSON", function()
    local result = api.parse_response("not valid json {]", 200)
    
    assert.is_false(result.success)
    assert.equals("Failed to parse response", result.error)
  end)

  it("defaults status_code to 0 when nil", function()
    local result = api.parse_response('{"test": true}', nil)
    
    assert.is_true(result.success)
    assert.is_table(result.data)
    assert.is_true(result.data.test)
  end)
end)

describe("fetch_workspace", function()
  before_each(function()
    api.clear_cache()
  end)

  it("returns success with workspace data from fixture", function()
    local result = api.fetch_workspace()
    
    assert.is_true(result.success)
    assert.is_table(result.data)
    assert.equals("My Oceanum Workspace", result.data.name)
    assert.is_table(result.data.data)
  end)

  it("populates workspace.data with datasources array", function()
    local result = api.fetch_workspace()
    
    assert.is_true(result.success)
    assert.is_table(result.data.data)
    assert.equals(3, #result.data.data)
  end)

  it("provides accessible datasource fields", function()
    local result = api.fetch_workspace()
    
    assert.is_true(result.success)
    local first_ds = result.data.data[1]
    assert.equals("ds-001", first_ds.id)
    assert.equals("SST Dataset", first_ds.label)
    assert.equals("sst-global-daily", first_ds.datasource)
  end)

  it("caches workspace data after fetch", function()
    local result = api.fetch_workspace()
    assert.is_true(result.success)
    
    local cached = api.get_cached_workspace()
    assert.is_table(cached)
    assert.equals("My Oceanum Workspace", cached.name)
  end)
end)

describe("refresh_workspace", function()
  before_each(function()
    api.clear_cache()
  end)

  it("calls callback with result after async completion", function()
    local callback_result = nil
    
    local started = api.refresh_workspace(function(result)
      callback_result = result
    end)
    
    assert.is_true(started)
    
    vim.wait(200, function()
      return callback_result ~= nil
    end)
    
    assert.is_not_nil(callback_result)
    assert.is_true(callback_result.success)
    assert.equals("My Oceanum Workspace", callback_result.data.name)
  end)

  it("returns false when refresh already in flight", function()
    local first_callback_done = false
    
    local first_started = api.refresh_workspace(function()
      first_callback_done = true
    end)
    assert.is_true(first_started)
    
    local second_started = api.refresh_workspace(function() end)
    
    assert.is_false(second_started)
    
    vim.wait(200, function()
      return first_callback_done
    end)
    
    assert.is_true(first_callback_done)
  end)

  it("allows subsequent refresh after first completes", function()
    local first_done = false
    local second_done = false
    
    api.refresh_workspace(function()
      first_done = true
    end)
    
    vim.wait(200, function()
      return first_done
    end)
    
    assert.is_true(first_done)
    assert.is_false(api.is_refresh_in_flight())
    
    local second_started = api.refresh_workspace(function()
      second_done = true
    end)
    
    assert.is_true(second_started)
    
    vim.wait(200, function()
      return second_done
    end)
    
    assert.is_true(second_done)
  end)
end)

describe("get_cached_workspace", function()
  before_each(function()
    api.clear_cache()
  end)

  it("returns nil before any fetch", function()
    local cached = api.get_cached_workspace()
    assert.is_nil(cached)
  end)

  it("returns workspace data after fetch_workspace", function()
    api.fetch_workspace()
    
    local cached = api.get_cached_workspace()
    assert.is_table(cached)
    assert.equals("My Oceanum Workspace", cached.name)
  end)

  it("returns workspace data after refresh_workspace completes", function()
    local done = false
    
    api.refresh_workspace(function()
      done = true
    end)
    
    vim.wait(200, function()
      return done
    end)
    
    local cached = api.get_cached_workspace()
    assert.is_table(cached)
    assert.equals("My Oceanum Workspace", cached.name)
  end)
end)

describe("clear_cache", function()
  before_each(function()
    api.clear_cache()
  end)

  it("resets cached workspace to nil", function()
    api.fetch_workspace()
    assert.is_not_nil(api.get_cached_workspace())
    
    api.clear_cache()
    assert.is_nil(api.get_cached_workspace())
  end)

  it("requires new fetch after cache clear", function()
    api.fetch_workspace()
    assert.is_not_nil(api.get_cached_workspace())
    
    api.clear_cache()
    assert.is_nil(api.get_cached_workspace())
    
    local result = api.fetch_workspace()
    assert.is_true(result.success)
    assert.is_not_nil(api.get_cached_workspace())
  end)
end)

describe("is_refresh_in_flight", function()
  before_each(function()
    api.clear_cache()
  end)

  it("returns false when no refresh is active", function()
    assert.is_false(api.is_refresh_in_flight())
  end)

  it("returns true during refresh", function()
    api.refresh_workspace(function() end)
    
    assert.is_true(api.is_refresh_in_flight())
  end)

  it("returns false after refresh completes", function()
    local done = false
    
    api.refresh_workspace(function()
      done = true
    end)
    
    vim.wait(200, function()
      return done
    end)
    
    assert.is_false(api.is_refresh_in_flight())
  end)
end)
