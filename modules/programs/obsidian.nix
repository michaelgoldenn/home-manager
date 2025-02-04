{ lib, config, pkgs, ... }:

with lib;

let
  cfg = config.programs.obsidian;
  pluginConfigType = types.submodule {
    options = {
      enable = mkEnableOption "plugin";
      config = mkOption {
        type = types.attrs;
        default = { };
        description = "Plugin configuration";
      };
    };
  };
in {
  meta.maintainers = [ maintainers.michaelgoldenn ];

  options.programs.obsidian = {
    enable = mkEnableOption "obsidian";
    package = mkPackageOption pkgs "obsidian" { };
    vaults = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          enable = mkEnableOption "obsidian vault";
          path = mkOption {
            type = types.str;
            default = "~/Documents/obsidian-vault";
            example = "~/path/to/obsidian/vault";
            description = "The path to your obsidian vault.";
          };
          community-plugins = mkOption {
            type = types.attrsOf pluginConfigType;
            default = { };
            description = ''
              Attribute set of community plugins.
              Each key is the plugin name and the value is its configuration.
              The full list can be found here: https://obsidian.md/plugins
            '';
            example = literalExpression ''
              {
                "obsidian-style-settings" = {
                  enable = true;
                  config = {
                    # plugin specific config
                  };
                };
                "another-plugin" = {
                  enable = true;
                  config = {};
                };
              }
            '';
          };
          core-plugins = mkOption {
            type = types.attrsOf pluginConfigType;
            default = { };
            description = ''
              Attribute set of core plugins.
              Each key is the plugin name and the value is its configuration.
              The full list can be found here: https://help.obsidian.md/Plugins/Core+plugins
            '';
            example = literalExpression ''
              {
                "file-explorer" = {
                  enable = true;
                  config = {
                    # plugin specific config
                  };
                };
                "another-plugin" = {
                  enable = true;
                  config = {};
                };
              }
            '';
          };
          extraConfig = mkOption {
            type = lib.types.attrsOf (lib.types.attrs);
            default = { };
            description =
              "Additional configuration for obsidian vault.";
            example =
              "app = { /* configuration to place into vault/.obsidian/app */}";
          };
        };
      });
      default = { };
      description = "Attribute set of obsidian vaults";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file = let
      vaultFiles = mapAttrsToList (vaultName: vaultCfg:
        let
          enabled = vaultCfg.enable;
          enabledCorePlugins =
            filterAttrs (_: p: p.enable) vaultCfg.core-plugins;
          corePluginsList = attrNames enabledCorePlugins;
          enabledCommunityPlugins =
            filterAttrs (_: p: p.enable) vaultCfg.community-plugins;
          communityPluginsList = attrNames enabledCommunityPlugins;

          vaultPath = if hasPrefix "~/" vaultCfg.path then
            "${config.home.homeDirectory}/${removePrefix "~/" vaultCfg.path}"
          else
            vaultCfg.path;

          obsidianDir = "${vaultPath}/.obsidian";

          corePluginsJson = builtins.toJSON corePluginsList;
          communityPluginsJson = builtins.toJSON communityPluginsList;

          corePluginConfigs = mapAttrs (_: p: p.config) enabledCorePlugins;
          appJson = corePluginConfigs // (vaultCfg.extraConfig.app or { });

          coreFile = if corePluginsList != [ ] then {
            "${obsidianDir}/core-plugins.json".text = corePluginsJson;
          } else
            { };
          communityFile = if communityPluginsList != [ ] then {
            "${obsidianDir}/community-plugins.json".text = communityPluginsJson;
          } else
            { };
          appFile = if appJson != { } then {
            "${obsidianDir}/app.json".text = builtins.toJSON appJson;
          } else
            { };

          communityDataFiles = foldl' (acc: pn:
            let config = enabledCommunityPlugins.${pn}.config;
            in if config != { } then
              acc // {
                "${obsidianDir}/plugins/${pn}/data.json".text =
                  builtins.toJSON config;
              }
            else
              acc) { } communityPluginsList;

          extraConfigFiltered = removeAttrs vaultCfg.extraConfig [ "app" ];
          extraConfigFiles = mapAttrs' (fn: content:
            nameValuePair "${obsidianDir}/${fn}.json" {
              text = builtins.toJSON content;
            }) (filterAttrs (_: content: content != { }) extraConfigFiltered);

          allFiles = coreFile // communityFile // appFile // communityDataFiles
            // extraConfigFiles;
        in mkIf enabled allFiles) cfg.vaults;
    in foldl' (a: b: a // b) { } vaultFiles;
  };
}
