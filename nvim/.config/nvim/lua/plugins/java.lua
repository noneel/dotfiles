return {
  "mfussenegger/nvim-jdtls",
  opts = {
    jdtls = function(original_opts)
      return {
        dap = {
          config_overrides = {
            vmArgs = "'-Dspring.profiles.active=local' '-Dhttps.proxyHost=134.223.121.43' '-Dhttps.proxyPort=80' '-Dhttps.proxySet=true' '-Djavax.net.ssl.trustStore=/data/PROJECTS/SPACE/SPABOK/sso.nasic.af.mil.keystore' '-Djavax.net.ssl.trustStorePassword=s3cr3tqi'",
          },
        },

        cmd = vim.list_extend(original_opts.cmd, {
          "--jvm-arg=" .. string.format("-javaagent:%s", vim.fn.expand("$MASON/share/jdtls/lombok.jar")),
        }),
      }
    end,
  },
}
