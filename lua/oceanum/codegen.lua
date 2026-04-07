-- Copyright Oceanum Ltd. Apache 2.0
local M = {}

function M.to_var_name(label, datasource)
  local base = label
  if base == nil or base == "" then base = datasource end
  base = base:gsub("[%s%-%._]", "_")
  base = base:gsub("[^a-zA-Z0-9_]", "")
  if base:match("^%d") then
    return "ds_" .. base
  end
  return base
end

function M.to_python_literal(value, indent)
  indent = indent or ""
  
  if value == nil then return "None" end
  if value == true then return "True" end
  if value == false then return "False" end
  if type(value) == "string" then
    local escaped = value:gsub("'", "\\'")
    return "'" .. escaped .. "'"
  end
  if type(value) == "number" then return tostring(value) end
  if type(value) == "table" then
    local is_array = true
    local max_index = 0
    local count = 0
    for k, v in pairs(value) do
      count = count + 1
      if type(k) == "number" and k > 0 and k == math.floor(k) then
        max_index = math.max(max_index, k)
      else
        is_array = false
      end
    end
    if is_array and max_index == count and max_index > 0 then
      local items = {}
      for i = 1, max_index do
        table.insert(items, M.to_python_literal(value[i], indent))
      end
      return "[" .. table.concat(items, ", ") .. "]"
    end
    
    local inner = indent .. "  "
    local pairs_list = {}
    for k, v in pairs(value) do
      if type(k) == "string" then
        table.insert(pairs_list, string.format("%s'%s': %s", inner, k, M.to_python_literal(v, inner)))
      end
    end
    return "{\n" .. table.concat(pairs_list, ",\n") .. "\n" .. indent .. "}"
  end
  return vim.fn.json_encode(value)
end

function M.generate_token_line()
  return "DATAMESH_TOKEN=''  # Set your Datamesh token here"
end

function M.generate_datasource(datasource, inject_token)
  local var_name = M.to_var_name(datasource.label, datasource.datasource)
  
  local token_arg = ""
  if inject_token then
    token_arg = "token=DATAMESH_TOKEN"
  end
  
  local header = string.format("from oceanum.datamesh import Connector\ndatamesh = Connector(%s)", token_arg)
  
  local has_query = datasource.variables or datasource.geofilter or datasource.timefilter or datasource.spatialref
  
  if not has_query then
    return string.format("%s\n%s = datamesh.load_datasource('%s')", header, var_name, datasource.datasource)
  end
  
  local query_args = { string.format("  datasource='%s'", datasource.datasource) }
  
  if datasource.variables then
    local vars_literal = M.to_python_literal(datasource.variables, "  ")
    table.insert(query_args, string.format("  variables=%s", vars_literal))
  end
  
  if datasource.timefilter then
    local tf_literal = M.to_python_literal(datasource.timefilter, "  ")
    table.insert(query_args, string.format("  timefilter=%s", tf_literal))
  end
  
  if datasource.geofilter then
    local gf_literal = M.to_python_literal(datasource.geofilter, "  ")
    table.insert(query_args, string.format("  geofilter=%s", gf_literal))
  end
  
  if datasource.spatialref then
    table.insert(query_args, string.format("  spatialref='%s'", datasource.spatialref))
  end
  
  return string.format("%s\n%s = datamesh.query(\n%s\n)", header, var_name, table.concat(query_args, ",\n"))
end

return M