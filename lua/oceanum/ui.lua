local M = {}

-- Clamp dimensions to fit within editor
-- @param width number Desired width (columns)
-- @param height number Desired height (rows)
-- @param max_w number|nil Maximum width (defaults to vim.o.columns - 4)
-- @param max_h number|nil Maximum height (defaults to vim.o.lines - 4)
-- @return number, number Clamped width, clamped height
M.clamp_dimensions = function(width, height, max_w, max_h)
  max_w = max_w or (vim.o.columns - 4)
  max_h = max_h or (vim.o.lines - 4)
  
  -- Enforce minimum dimensions
  local min_width = 10
  local min_height = 5
  
  -- Clamp to max, then enforce minimum
  local clamped_w = math.max(min_width, math.min(width, max_w))
  local clamped_h = math.max(min_height, math.min(height, max_h))
  
  return clamped_w, clamped_h
end

-- Open a floating window
-- @param opts table: { title?, width?, height?, border?, buf? }
--   - title: window title string (optional)
--   - width: desired width as fraction of editor (0.0-1.0, default 0.8) OR integer columns
--   - height: desired height as fraction of editor (0.0-1.0, default 0.6) OR integer rows
--   - border: border style (default 'rounded')
--   - buf: reuse this buffer (optional, creates new scratch buffer if nil)
-- @return table { win=window_id, buf=buffer_id }
M.open = function(opts)
  opts = opts or {}
  
  -- Parse width and height (fractional or absolute)
  local width = opts.width or 0.8
  local height = opts.height or 0.6
  
  -- Convert fractional to integer
  if type(width) == 'number' and width > 0 and width <= 1.0 then
    width = math.floor(vim.o.columns * width)
  end
  if type(height) == 'number' and height > 0 and height <= 1.0 then
    height = math.floor(vim.o.lines * height)
  end
  
  -- Clamp to available screen space
  width, height = M.clamp_dimensions(width, height)
  
  -- Calculate centered position
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- Create or reuse buffer
  local buf = opts.buf
  if not buf then
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  end
  
  -- Build window config
  local win_opts = {
    relative = 'editor',
    row = row,
    col = col,
    width = width,
    height = height,
    style = 'minimal',
    border = opts.border or 'rounded',
  }
  
  -- Add title if provided
  if opts.title then
    win_opts.title = opts.title
    win_opts.title_pos = 'center'
  end
  
  -- Open window
  local win = vim.api.nvim_open_win(buf, true, win_opts)
  
  return { win = win, buf = buf }
end

-- Close a floating window by window ID
-- @param win number Window handle from nvim_open_win
M.close = function(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

-- Set normal-mode keymaps on a buffer
-- @param buf number Buffer handle
-- @param mappings table Array of { lhs, rhs (string or function), desc? }
M.set_keymaps = function(buf, mappings)
  for _, mapping in ipairs(mappings) do
    local lhs = mapping[1] or mapping.lhs
    local rhs = mapping[2] or mapping.rhs
    local desc = mapping[3] or mapping.desc
    
    local keymap_opts = {
      buffer = buf,
      silent = true,
      noremap = true,
    }
    
    if desc then
      keymap_opts.desc = desc
    end
    
    vim.keymap.set('n', lhs, rhs, keymap_opts)
  end
end

return M
