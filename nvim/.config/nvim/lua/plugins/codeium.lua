-- Api Key pulled from https://codeium.com/install/vscode
-- search for user_token and pull it out of that request the format is a JWT token. DUMB!!!
-- Also ~/.curlrc needed to have a proxy statement as defined by the FTC confluence page
return {
  "Exafunction/codeium.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "hrsh7th/nvim-cmp",
  },
  opts = {
    api = {
      host = "",
      port = "443",
    },
    enterprise_mode = true,
    enable_chat = true,
    detect_proxy = true,
  },
}
