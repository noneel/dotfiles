return {
  {
    "mfussenegger/nvim-jdtls",
    opts = {
      jdtls = function(original_opts)
        return {
          dap = {
            config_overrides = {
              vmArgs = "",
            },
          },

          cmd = vim.list_extend(original_opts.cmd, {
            "--jvm-arg=" .. string.format("-javaagent:%s", vim.fn.expand("$MASON/share/jdtls/lombok.jar")),
          }),
        }
      end,
    },
  },
  {
    -- Code coverage for jacoco files
    "dsych/blanket.nvim",
    config = function()
      require("blanket").setup({
        report_path = vim.fn.getcwd() .. "/target/site/jacoco/jacoco.xml",
        signs = {
          -- these came from :hi
          incomplete_branch_color = "HydraPink",
          covered_color = "HydraBlue",
          uncovered_color = "HydraAmaranth",
        },
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        jdtls = {
          keys = {
            {
              "<leader>tcs",
              function()
                require("blanket").start()
              end,
              mode = "n",
              desc = "Start Test Coverage",
            },
            {
              "<leader>tcx",
              function()
                require("blanket").stop()
              end,
              mode = "n",
              desc = "Stop Test Coverage",
            },
            {
              "<leader>tcr",
              function()
                require("blanket").refresh()
              end,
              mode = "n",
              desc = "Restart Test Coverage",
            },
          },
        },
      },
    },
  },
}
