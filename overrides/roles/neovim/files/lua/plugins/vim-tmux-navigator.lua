return {
  {
    "christoomey/vim-tmux-navigator",
    enabled = function()
      return not (vim.env.HERDR_SESSION or vim.env.HERDR_PANE_ID or vim.env.HERDR_ENV)
    end,
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
    },
    keys = {
      { "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
      { "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>" },
      { "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>" },
      { "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>" },
      { "<c-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
    },
  },
  {
    "willfish/herdr-navigator.nvim",
    lazy = false,
    config = function()
      local navigator = require("herdr-navigator")

      local function setup_mappings()
        navigator.setup()
        navigator.setup({
          mappings = {
            left = "<C-h>",
            down = "<C-j>",
            up = "<C-k>",
            right = "<C-l>",
          },
        })
        vim.keymap.set("n", "<BS>", navigator.left, { desc = "Navigate left" })
      end

      setup_mappings()
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        callback = setup_mappings,
      })
    end,
  },
}
