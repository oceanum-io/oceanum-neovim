local helpers = {}

local function get_fixtures_dir()
  local tests_dir = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ':h:h')
  return tests_dir .. '/fixtures'
end

function helpers.load_fixture(name)
  local filepath = get_fixtures_dir() .. '/' .. name
  local file = io.open(filepath, 'r')
  if not file then
    error('Fixture not found: ' .. name)
  end
  local content = file:read('*a')
  file:close()
  return vim.json.decode(content)
end

function helpers.create_temp_buffer(lines)
  local buf = vim.api.nvim_create_buf(true, false)
  if type(lines) == 'table' then
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
  elseif type(lines) == 'string' then
    local content = vim.split(lines, '\n', { plain = true })
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, content)
  end
  return buf
end

function helpers.mock_http_response(url, response_body, status_code)
  status_code = status_code or 200
  local mock = {
    url = url,
    response = { body = response_body, status_code = status_code }
  }
  return mock
end

function helpers.assert_floating_window_exists(win_id)
  local win_config = vim.api.nvim_win_get_config(win_id)
  local is_float = win_config.relative and win_config.relative ~= ''
  if not is_float then
    error('Window ' .. win_id .. ' is not floating')
  end
  return true
end

return helpers
