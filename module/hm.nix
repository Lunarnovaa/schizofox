self: {
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
  inherit (lib) mkIf mkEnableOption mkOption mkPackageOption mdDoc maintainers types literalExpression;

  cfg = config.programs.schizofox;

  darkreader = self.packages.${pkgs.system}.darkreader;

  mozillaConfigPath =
    if isDarwin
    then "Library/Application Support/Mozilla"
    else ".mozilla";

  firefoxConfigPath =
    if isDarwin
    then "Library/Application Support/Firefox"
    else mozillaConfigPath + "/firefox";

  profilesPath =
    if isDarwin
    then "${firefoxConfigPath}/Profiles"
    else firefoxConfigPath;

  defaultProfile = "${profilesPath}/schizo.default";
in {
  meta.maintainers = with maintainers; [sioodmy NotAShelf];

  options.programs.schizofox = {
    enable = mkEnableOption (mdDoc "Schizophrenic Firefox ESR setup for the delusional");
    package = mkPackageOption pkgs "firefox-esr-102-unwrapped" {
      example = "firefox-esr-115-unwrapped";
    };

    theme = {
      font = mkOption {
        type = types.str;
        example = "Lato";
        default = "Lexend";
        description = "Default firefox font";
      };

      background-darker = mkOption {
        type = types.str;
        example = "181825";
        default = "181825";
        description = "Darker background color";
      };

      background = mkOption {
        type = types.str;
        example = "1e1e2e";
        default = "1e1e2e";
        description = "Dark reader background color";
      };

      foreground = mkOption {
        type = types.str;
        example = "cdd6f4";
        default = "cdd6f4";
        description = "Dark reader text color";
      };
    };

    bookmarks = mkOption {
      type = with types; listOf attrs;
      default = [];
      description = "List of bookmarks to add to your Schizofox configuration";
      example = literalExpression ''
        [
          {
            Title = "Example";
            URL = "https://example.com";
            Favicon = "https://example.com/favicon.ico";
            Placement = "toolbar";
            Folder = "FolderName";
          }
        ]
      '';
    };

    search = {
      defaultSearchEngine = mkOption {
        type = types.str;
        example = "DuckDuckGo";
        default = "Brave";
        description = "Default search engine";
      };

      addEngines = mkOption {
        type = with types; listOf attrs;
        default = import ./engineList.nix cfg;
        description = "List of search engines to add to your Schizofox configuration";
        example = literalExpression ''
          [
            {
              Name = "Etherscan";
              Description = "Checking balances";
              Alias = "!eth";
              Method = "GET";
              URLTemplate = "https://etherscan.io/search?f=0&q={searchTerms}";
            }
          ]
        '';
      };

      removeEngines = mkOption {
        type = with types; listOf str;
        default = ["Google" "Bing" "Amazon.com" "eBay" "Twitter" "Wikipedia"];
        description = "List of default search engines to remove";
        example = literalExpression ["Google"];
      };

      searxUrl = mkOption {
        type = types.str;
        default = "https://searx.be";
        description = "Searx instance url";
        example = literalExpression "https://search.example.com";
      };

      searxQuery = mkOption {
        type = types.str;
        default = "${cfg.search.searxUrl}/search?q={searchTerms}&categories=general";
        description = "Search query for searx (or any other schizo search engine)";
        example = literalExpression "https://searx.be/search?q={searchTerms}&categories=general";
      };
    };

    security = {
      userAgent = mkOption {
        type = types.str;
        default = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:110.0) Gecko/20100101 Firefox/110.0";
        description = "Spoof user agent";
        example = literalExpression "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:106.0) Gecko/20100101 Firefox/106.0";

        /*
        Some other user agents
        Mozilla/5.0 (X11; Linux x86_64; rv:110.0) Gecko/20100101 Firefox/110.0
        Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:110.0) Gecko/20100101 Firefox/110.0
        Mozilla/5.0 (X11; Fedora; Linux x86_64; rv:110.0) Gecko/20100101 Firefox/110.0
        */
      };

      sanitizeOnShutdown = mkOption {
        type = types.bool;
        default = true;
        example = true;
        description = ''
          Clear cookies, history and other data on shutdown.
          Disabled on default, because it's quite annoying. Tip: use ctrl+i";
        '';
      };
    };

    misc = {
      drmFix = mkOption {
        type = types.bool;
        default = false;
        example = true;
        description = "netflix no worky (just use torrents lmao)";
      };

      disableWebgl = mkOption {
        type = types.bool;
        default = false;
        example = true;
        description = ''
          Force WebGL to be disabled.
          Do note that it'll break plenty of websites that mess with the canvas (practically anything at this point)
        '';
      };
    };

    extensions = {
      extraExtensions = mkOption {
        type = types.attrs;
        default = {};
        description = "Extra extensions to be installed";
        example = literalExpression ''
          {
            "webextension@metamask.io".install_url = "https://addons.mozilla.org/firefox/downloads/latest/ether-metamask/latest.xpi";
          }
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    home.file = {
      # profile config
      "${firefoxConfigPath}/profiles.ini".text = ''
        [Profile0]
        Name=default
        IsRelative=1
        Path=schizo.default
        Default=1

        [General]
        StartWithLastProfile=1
        Version=2
      '';
      # userChrome content
      "${defaultProfile}/chrome/userChrome.css".text = with cfg; import ./firefox/userChrome.nix {inherit theme;};

      # userContent
      "${defaultProfile}/chrome/userContent.css".text = import ./firefox/userContent.nix {};
    };

    home.packages = [
      (pkgs.wrapFirefox cfg.package {
        # see https://github.com/mozilla/policy-templates/blob/master/README.md
        extraPolicies = {
          CaptivePortal = false;
          DisableFirefoxStudies = true;
          DisablePocket = true;
          DisableTelemetry = true;
          DisableFirefoxAccounts = true;
          DisableFormHistory = true;
          DisplayBookmarksToolbar = false;
          DontCheckDefaultBrowser = true;

          # FIXME: im gonna kms, it hurts my eyes
          ExtensionSettings = import ./extensions {inherit cfg darkreader pkgs lib;};
          SearchEngines = import ./config/engines.nix {inherit cfg;};
          Bookmarks = lib.optionalAttrs (cfg.bookmarks != {}) cfg.bookmarks;
          FirefoxHome = {
            Pocket = false;
            Snippets = false;
          };

          PasswordManagerEnabled = false;
          PromptForDownloadLocation = true;

          UserMessaging = {
            ExtensionRecommendations = false;
            SkipOnboarding = true;
          };

          DisableSetDesktopBackground = true;
          SanitizeOnShutdown = cfg.security.sanitizeOnShutdown;

          Cookies = {
            Behavior = "accept";
            ExpireAtSessionEnd = false;
            Locked = false;
          };

          Preferences = import ./config/preferences.nix {inherit cfg;};
        };
      })
    ];
  };
}
