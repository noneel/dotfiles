-- https://github.com/yioneko/vtsls/issues/159
-- temporarily block notifications of vtls inlayHint exception
-- can remove when issue is fixed

return {
  "folke/noice.nvim",
  event = "VeryLazy",
  -- REMOVE THIS once this issue is fixed: https://github.com/yioneko/vtsls/issues/159
  opts = {
    routes = {
      {
        filter = {
          event = "notify",
          find = "Request textDocument/inlayHint failed",
        },
        opts = { skip = true },
      },
    },
  },
}
