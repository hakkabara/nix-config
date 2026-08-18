{ ... }:

let
  # ============================================================
  # Theme selection
  # ============================================================
  #
  # Change only this value to switch the active Equibop theme.
  #
  # Example:
  # activeTheme = "catppuccin";
  #
  activeTheme = "midnight";

  # All themes managed by this repository.
  #
  # To add another theme:
  #
  # 1. Put the CSS file into:
  #    /home/hakkabara/nix-config/modules/home/apps/equibop/themes/
  #
  # 2. Add it here:
  #
  #    catppuccin = ./equibop/themes/catppuccin.theme.css;
  #
  # 3. Change activeTheme above if you want to activate it.
  #
  availableThemes = {
    midnight = ./equibop/themes/midnight.theme.css;

    # Future examples:
    # catppuccin = ./equibop/themes/catppuccin.theme.css;
    # tokyo-night = ./equibop/themes/tokyo-night.theme.css;
    # dark-matter = ./equibop/themes/dark-matter.theme.css;
  };

  # Fail during evaluation instead of silently configuring
  # a theme which does not exist.
  activeThemeFile =
    if builtins.hasAttr activeTheme availableThemes then
      "${activeTheme}.css"
    else
      throw "Unknown Equibop theme '${activeTheme}'. Add it to availableThemes first.";
in
{
  programs.equibop = {
    enable = true;

    # ============================================================
    # Equibop application settings
    # ============================================================

    settings = {
      discordBranch = "stable";

      tray = true;
      minimizeToTray = true;
      clickTrayToShowHide = true;

      # We only use Equibop mainly for chat on the SurfVM.
      arRPC = false;
      arRPCProcessScanning = false;

      hardwareAcceleration = true;
      hardwareVideoAcceleration = true;

      appBadge = true;
      badgeOnlyForMentions = true;

      spellCheckLanguages = [
        "de-DE"
        "en-US"
      ];
    };

    equicord = {
      settings = {
        # ========================================================
        # Equicord
        # ========================================================

        # Equibop/Equicord updates come through Nix.
        autoUpdate = false;
        autoUpdateNotification = false;

        useQuickCss = true;

        # Local, version-controlled themes are preferred.
        enableOnlineThemes = false;
        themeLinks = [ ];
        enabledThemeLinks = [ ];

        # The selected theme is defined once at the top of this file.
        enabledThemes = [
          activeThemeFile
        ];

        notifications = {
          timeout = 5000;
          position = "bottom-right";
          useNative = "not-focused";
          missed = true;
          logLimit = 50;
        };

        plugins = {
          # ============================================================
          # Privacy / Security / URLs
          # ============================================================

          ClearURLs.enabled = true;
          AnonymiseFileNames.enabled = true;
          NoMaskedUrlPaste.enabled = true;
          SilentTyping.enabled = true;
          BetterSessions.enabled = true;

          # Explicitly requested.
          # WARNING: disables some of Discord's safety warnings.
          AlwaysTrust.enabled = true;

          ClientSideBlock.enabled = true;

          # ============================================================
          # Settings / general UX
          # ============================================================

          BetterSettings = {
            enabled = true;
            disableFade = true;
            organizeMenu = true;
            eagerLoad = true;
          };

          BetterFolders.enabled = true;
          BetterCommands.enabled = true;
          BetterUploadButton.enabled = true;
          KeepCurrentChannel.enabled = true;

          # ============================================================
          # Chat
          # ============================================================

          CharacterCounter.enabled = true;
          QuickReply.enabled = true;
          PreviewMessage.enabled = true;
          NoReplyMention.enabled = true;

          MoreQuickReactions.enabled = true;
          WhoReacted.enabled = true;

          # These complement each other:
          # TypingIndicator = channel-level indicator
          # TypingTweaks    = richer typing UI
          TypingIndicator.enabled = true;
          TypingTweaks.enabled = true;

          FullSearchContext.enabled = true;

          MessageLatency.enabled = true;

          ReadAllNotificationsButton.enabled = true;
          OnePingPerDM.enabled = true;

          # ============================================================
          # Images / GIFs / files / embeds
          # ============================================================

          ImageZoom.enabled = true;
          FixImagesQuality.enabled = true;
          ImageLink.enabled = true;
          ImageFilename.enabled = true;
          ReverseImageSearch.enabled = true;

          BetterGifPicker.enabled = true;
          BetterGifAltText.enabled = true;

          CopyEmojiMarkdown.enabled = true;
          CopyStickerLinks.enabled = true;
          CopyFileContents.enabled = true;

          DownloadAllAttachments.enabled = true;

          BetterAudioPlayer.enabled = true;

          FixSpotifyEmbeds.enabled = true;
          FixYoutubeEmbeds.enabled = true;
          YoutubeAdblock.enabled = true;

          VoiceDownload.enabled = true;

          # ============================================================
          # Information / inspection / convenience
          # ============================================================

          CopyUserURLs.enabled = true;
          CopyUserMention.enabled = true;
          CopyStatusUrls.enabled = true;

          ViewRaw.enabled = true;
          ViewIcons.enabled = true;

          ServerInfo.enabled = true;
          ShowTimeoutDuration.enabled = true;
          MemberCount.enabled = true;

          PermissionsViewer.enabled = true;
          AdvancedPermissions.enabled = true;

          # ============================================================
          # Appearance / UI
          # ============================================================

          AlwaysExpandProfiles.enabled = true;
          CollapsibleUI.enabled = true;
          Declutter.enabled = true;

          FixCodeblockGap.enabled = true;
          ShikiCodeblocks.enabled = true;

          # Explicitly requested.
          NoProfileThemes.enabled = true;

          # ============================================================
          # Server / role UX
          # ============================================================

          BetterRoleContext.enabled = true;
          BetterInvites.enabled = true;
          NewGuildSettings.enabled = true;

          # ============================================================
          # Voice
          # ============================================================

          CallTimer.enabled = true;

          DisableCallIdle.enabled = true;
          VolumeBooster.enabled = true;
          VoiceChatDoubleClick.enabled = true;
          VoiceMessages.enabled = true;

          NotificationVolume.enabled = true;

          # ============================================================
          # Utility
          # ============================================================

          Translate.enabled = true;
          SendTimestamps.enabled = true;
          CustomTimestamps.enabled = true;

          DecodeBase64.enabled = true;

          OpenInApp.enabled = true;
          ReplaceGoogleSearch.enabled = true;

          BetterForwards.enabled = true;

          # Particularly useful on X11.
          NoMiddleClickPaste.enabled = true;

          # ============================================================
          # Behaviour-changing / consciously enabled plugins
          # ============================================================

          # These are intentionally enabled because we explicitly chose
          # them. They change normal Discord behaviour more substantially.

          NoBlockedMessages.enabled = true;

          MessageLogger.enabled = true;

          ShowHiddenChannels.enabled = true;
          ShowHiddenThings.enabled = true;

          FakeNitro.enabled = true;

          # ============================================================
          # Core/API plugins
          # ============================================================
          #
          # Do NOT manually list CommandsAPI, CrashHandler,
          # UserSettingsAPI, MessageAccessoriesAPI, etc.
          # Equicord enables required dependencies itself.
        };
      };

      # ============================================================
      # Themes
      # ============================================================
      #
      # Every entry from availableThemes is installed.
      # Only activeTheme is enabled above.
      #
      themes = availableThemes;

      # ============================================================
      # QuickCSS
      # ============================================================

      extraQuickCss = builtins.readFile ./equibop/quickCss.css;
    };
  };
}
