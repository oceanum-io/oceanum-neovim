local codegen = require('oceanum.codegen')

local base_datasource = {
  id = "abc",
  label = "My Dataset",
  datasource = "my-dataset-id",
  description = "Test dataset",
}

describe("to_var_name", function()
  it("converts label to valid Python variable name", function()
    local result = codegen.to_var_name("My Dataset", "my-dataset-id")
    assert.equals("My_Dataset", result)
  end)

  it("handles spaces, hyphens, and dots", function()
    assert.equals("test_var_name", codegen.to_var_name("test-var.name", "ds"))
    assert.equals("another_test", codegen.to_var_name("another test", "ds"))
  end)

  it("removes non-alphanumeric characters", function()
    assert.equals("test123", codegen.to_var_name("test@#$123", "ds"))
  end)

  it("falls back to datasource when label is empty", function()
    assert.equals("my_dataset_id", codegen.to_var_name("", "my-dataset-id"))
    assert.equals("my_dataset_id", codegen.to_var_name(nil, "my-dataset-id"))
  end)

  it("prefixes with ds_ when starting with digit", function()
    assert.equals("ds_1bad_name", codegen.to_var_name("1bad-name", "ds"))
  end)
end)

describe("to_python_literal", function()
  it("serializes nil as None", function()
    assert.equals("None", codegen.to_python_literal(nil))
  end)

  it("serializes true as True", function()
    assert.equals("True", codegen.to_python_literal(true))
  end)

  it("serializes false as False", function()
    assert.equals("False", codegen.to_python_literal(false))
  end)

  it("serializes strings with single quotes", function()
    assert.equals("'hello'", codegen.to_python_literal("hello"))
    assert.equals("'it\\'s fine'", codegen.to_python_literal("it's fine"))
  end)

  it("serializes numbers as strings", function()
    assert.equals("42", codegen.to_python_literal(42))
    assert.equals("3.14", codegen.to_python_literal(3.14))
  end)

  it("serializes arrays as Python lists", function()
    local result = codegen.to_python_literal({"u", "v"})
    assert.equals("['u', 'v']", result)
  end)

  it("serializes dicts with proper formatting", function()
    local result = codegen.to_python_literal({times = {"2020-01-01", "2021-01-01"}})
    assert.True(result:match("'times':") ~= nil)
    assert.True(result:match("%[") ~= nil)
  end)

  it("handles nil values in nested structures (skipped in Lua)", function()
    local result = codegen.to_python_literal({type = "Polygon"})
    assert.equals("{\n  'type': 'Polygon'\n}", result)
  end)
end)

describe("generate_token_line", function()
  it("produces valid Python assignment", function()
    local line = codegen.generate_token_line()
    assert.True(line:match("^DATAMESH_TOKEN%s*=") ~= nil)
  end)
end)

describe("generate_datasource", function()
  it("generates load_datasource call for simple datasource", function()
    local code = codegen.generate_datasource(base_datasource, false)
    assert.True(code:match("from oceanum%.datamesh import Connector") ~= nil)
    assert.True(code:match("datamesh = Connector%(%)") ~= nil)
    assert.True(code:match("My_Dataset = datamesh%.load_datasource%('my%-dataset%-id'%)") ~= nil)
    assert.True(code:match("datamesh%.query") == nil)
  end)

  it("injects token argument when injectToken is true", function()
    local code = codegen.generate_datasource(base_datasource, true)
    assert.True(code:match("datamesh = Connector%(token=DATAMESH_TOKEN%)") ~= nil)
  end)

  it("uses datasource slug as fallback when label is empty", function()
    local ds = vim.deepcopy(base_datasource)
    ds.label = ""
    local code = codegen.generate_datasource(ds, false)
    assert.True(code:match("my_dataset_id = datamesh%.load_datasource") ~= nil)
  end)

  it("prefixes ds_ when variable name starts with digit", function()
    local ds = vim.deepcopy(base_datasource)
    ds.label = "1bad-name"
    local code = codegen.generate_datasource(ds, false)
    assert.True(code:match("ds_1bad_name") ~= nil)
  end)

  it("generates query call when variables are present", function()
    local ds = vim.deepcopy(base_datasource)
    ds.variables = {"u", "v"}
    local code = codegen.generate_datasource(ds, false)
    assert.True(code:match("datamesh%.query%(") ~= nil)
    assert.True(code:match("datasource='my%-dataset%-id'") ~= nil)
    assert.True(code:match("variables=%[") ~= nil)
    assert.True(code:match("'u'") ~= nil)
    assert.True(code:match("'v'") ~= nil)
    assert.True(code:match("load_datasource") == nil)
  end)

  it("generates query call when timefilter is present", function()
    local ds = vim.deepcopy(base_datasource)
    ds.timefilter = {times = {"2020-01-01", "2021-01-01"}}
    local code = codegen.generate_datasource(ds, false)
    assert.True(code:match("datamesh%.query%(") ~= nil)
    assert.True(code:match("timefilter=") ~= nil)
    assert.True(code:match("'times'") ~= nil)
  end)

  it("generates query call when geofilter is present", function()
    local ds = vim.deepcopy(base_datasource)
    ds.geofilter = {type = "Point", coordinates = {170.5, -45.0}}
    local code = codegen.generate_datasource(ds, false)
    assert.True(code:match("datamesh%.query%(") ~= nil)
    assert.True(code:match("geofilter=") ~= nil)
    assert.True(code:match("'type'") ~= nil)
    assert.True(code:match("'Point'") ~= nil)
    assert.True(code:match("'coordinates'") ~= nil)
  end)

  it("generates query call when spatialref is present", function()
    local ds = vim.deepcopy(base_datasource)
    ds.spatialref = "EPSG:4326"
    local code = codegen.generate_datasource(ds, false)
    assert.True(code:match("datamesh%.query%(") ~= nil)
    assert.True(code:match("spatialref='EPSG:4326'") ~= nil)
  end)

  it("serializes nil values correctly (Lua limitation)", function()
    local ds = vim.deepcopy(base_datasource)
    ds.geofilter = {type = "Polygon"}
    local code = codegen.generate_datasource(ds, false)
    assert.True(code:match("datamesh%.query%(") ~= nil)
    assert.True(code:match("'type': 'Polygon'") ~= nil)
  end)
end)