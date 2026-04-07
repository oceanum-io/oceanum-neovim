# oceanum.nvim

Oceanum Neovim is a plugin for interacting with [Oceanum Datamesh](https://ui.datamesh.oceanum.io) and AI services directly from your editor. It provides a workspace browser for datasets and an AI chat interface for code generation.

## Features

- **Workspace Browser**: Browse your datasources in a floating window and insert Python connector code with one keystroke.
- **AI Chat**: Interact with Oceanum AI to ask questions about data analysis or generate snippets based on your current buffer context.
- **System Integration**: Open the Datamesh UI in your default browser from Neovim.
- **Health Check**: Quickly verify your configuration and dependency setup.

## Requirements

- Neovim >= 0.8.0
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (required for HTTP requests)
- An Oceanum API token

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "oceanum-io/oceanum-neovim.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("oceanum").setup({
      -- token_env_var = "OCEANUM_API_KEY", -- optional, this is the default
    })
  end,
}
```

## Configuration

The plugin is configured by passing a table to the `setup` function.

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `token_env_var` | `string` | `"OCEANUM_API_KEY"` | Environment variable name for the Oceanum API token. |
| `ai_backend_url` | `string` | `"https://ai.oceanum.io"` | URL for the Oceanum AI service. |
| `datamesh_ui_url` | `string` | `"https://ui.datamesh.oceanum.io"` | URL for the Oceanum Datamesh UI. |

## Commands

- `:OceanumWorkspace`: Open the floating workspace browser.
- `:OceanumChat`: Open the floating AI chat window.
- `:OceanumBrowser`: Open the Datamesh UI in your default browser.
- `:OceanumInsert`: Insert Python connector code for the last selected datasource.
- `:OceanumHealth`: Run a health check to verify your setup.

## Usage

### Workspace Browser

Run `:OceanumWorkspace` to open a floating window listing your available datasources.

- Use `j`/`k` to navigate the list.
- Press `Enter` on a datasource to generate Python connector code and insert it into your current buffer.
- Press `Esc` or `q` to close the window.

### AI Chat

Run `:OceanumChat` to open a floating chat window. You can ask questions about data analysis or request code snippets.

- Press `i` in the chat window to insert the most recent code block from the chat into your main buffer.
- The chat context includes the contents of your current active buffer.

## Troubleshooting

### Missing Token

If you see "MISSING - set OCEANUM_API_KEY environment variable" in the health check, ensure you have exported your API key:

```bash
export OCEANUM_API_KEY=your_token_here
```

### Empty Workspace

The workspace browser requires a valid token and access to datasources in your Oceanum account. If it appears empty, check your token and network connection.

### Network Errors

The plugin requires an internet connection to communicate with Oceanum API services. Ensure your firewall or proxy allows connections to the configured backend URLs.
