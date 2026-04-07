local plugin_root = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ':h:h')
vim.opt.runtimepath:prepend(plugin_root)
vim.opt.runtimepath:prepend('/tmp/plenary.nvim')

vim.opt.swapfile = false
vim.opt.updatecount = 0
vim.opt.undofile = false
vim.opt.hidden = true

require('plenary.busted')
