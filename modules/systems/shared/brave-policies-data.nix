# Brave managed policies — shared data
#
# Single source of truth for the policy attrset applied to Brave on every
# host that enables `custom.appBrave.enable`. Imported as a function: the
# OS-specific writers in `modules/systems/{nixos,darwin}/brave-policies.nix`
# call it with optional `extensions` overrides and render the result to the
# right on-disk format:
#
#   - Linux:  /etc/brave/policies/managed/debrand.json (JSON)
#   - Darwin: ~/Library/Managed Preferences/com.brave.Browser (plist via
#             nix-darwin's system.defaults.CustomUserPreferences)
#
# Brave honors both Brave-specific policies (BraveRewardsDisabled etc.) and
# standard Chromium policies (MetricsReportingEnabled etc.). All policies
# here are FORCED — the in-app UI cannot override them. Removing a policy
# or rebuilding without it restores the default behaviour.
#
# Policy references:
#   - Brave: https://support.brave.com/hc/en-us/articles/360039248271
#   - Chromium: https://chromeenterprise.google/policies/
#
# Scope — what enterprise policies CAN and CANNOT control:
#
#   ✅ Product-level Brave features: Rewards, Wallet, VPN, AI, Talk, Tor,
#      News, Sync (BraveRewardsDisabled, BraveWalletDisabled, etc.).
#   ✅ Standard Chromium controls: telemetry, Safe Browsing, password
#      manager, autofill, force-installed extensions, default-browser
#      nags, welcome pages, Web Store icon visibility.
#
#   ❌ User-side preferences — NOT policy-controllable, even though they
#      look like settings. Examples that have NO managed-policy equivalent:
#        - New-tab page elements (background image, stats row, clock,
#          top-sites tiles). Internally these are prefs under
#          `brave.new_tab_page.*` but Brave does not expose them via
#          policy. There is no `BraveNewTabPageShowBackgroundImage`.
#        - Default search engine, fonts, themes, zoom, startup pages.
#        - Bookmark bar visibility, omnibox suggestions.
#      These are owned by **Brave Sync** in this repo: configure once on
#      any device in the chain, sync propagates to the rest. See the
#      "Brave Sync intentionally NOT disabled" note below.
#
# Editing checklist:
#   - Adding/removing an extension on every host: edit `defaultExtensions`
#     below. Each entry is the bare Chrome Web Store ID; the function
#     appends the standard CWS update URL.
#   - Overriding extensions on a specific host: set
#     `custom.appBrave.extensions = [ "<id>" ... ];` on that host (use
#     `[]` to disable force-install entirely for that host).
#   - Adding a new policy: drop it into the attrset; rebuild; verify on
#     `chrome://policy` that Status: OK and Source: Platform. If it shows
#     "Policy not recognized" it does not exist (likely a user pref — see
#     the Scope note above).

{
  # Per-host override. Pass `null` (default) to inherit the shared
  # `defaultExtensions` list below; pass a list of CWS extension IDs to
  # replace it (pass `[]` to disable force-install entirely on this host).
  extensions ? null,
}:

let
  # Chrome Web Store update endpoint. Brave honours this just like Chrome.
  cwsUpdate = "https://clients2.google.com/service/update2/crx";

  # Default cross-host force-install set. Hosts that don't set
  # `custom.appBrave.extensions` inherit this list. Each entry is the bare
  # extension ID; the `;<update-url>` suffix is added below.
  defaultExtensions = [
    "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
    "fnaicdffflnofjppbagibeoednhnbjhg" # Floccus bookmark sync
    "mnjggcdmjocbbbhaepdhchncahnbgone" # SponsorBlock for YouTube
    "jcgpghgjhhahcefnfpbncdmhhddedhnk" # Click to remove element
    "fdpohaocaechififmbbbbbknoalclacl" # GoFullPage — full page screen capture
    # "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin — uncomment to force-install on every host (cannot be installed-disabled via policy)
  ];

  resolvedExtensions = if extensions == null then defaultExtensions else extensions;
in
{
  # --- Brave-specific: kill the "Brave company" surface ---
  BraveRewardsDisabled = true; # remove BAT / Rewards entirely
  BraveWalletDisabled = true; # remove built-in crypto wallet
  BraveVPNDisabled = true; # remove Brave VPN promo / menu
  BraveAIChatEnabled = false; # disable Leo AI assistant
  BraveNewsDisabled = true; # remove Brave News from the new-tab page
  BraveTalkDisabled = true; # remove Brave's own video-chat (does NOT affect WebRTC / Teams / Zoom / Meet)
  TorDisabled = true; # remove "New private window with Tor"

  # Brave Sync intentionally NOT disabled — used to sync settings + bookmarks
  # across devices. Brave Sync also owns user-side preferences that have no
  # managed-policy equivalent (NTP layout, default search engine, fonts,
  # etc. — see the Scope note in the header).
  # Brave Shields intentionally NOT touched — defaults stay (Shields-up).

  # --- Privacy / telemetry ---
  MetricsReportingEnabled = false; # no anonymous usage telemetry
  SafeBrowsingProtectionLevel = 0; # 0 = off, 1 = standard, 2 = enhanced. We want zero Google contact.

  # --- Disable built-in password / form managers ---
  PasswordManagerEnabled = false; # no "Save password?" prompts; Bitwarden owns this
  AutofillAddressEnabled = false; # no address autofill
  AutofillCreditCardEnabled = false; # no credit-card autofill

  # --- Stop the nags ---
  PromotionalTabsEnabled = false; # no "what's new" / promo tabs
  DefaultBrowserSettingEnabled = false; # don't pester about being default browser (it already is)
  WelcomePageOnOSUpgradeEnabled = false; # no welcome page after OS upgrades
  HideWebStoreIcon = true; # hide the Web Store tile on the new-tab page (store still reachable via chrome://extensions)

  # --- Force-installed extensions ---
  # Format: "<chrome-web-store-id>;<update-url>". The user cannot remove or
  # disable these — that's the point of force-install. See `extensions`
  # parameter above for per-host override.
  ExtensionInstallForcelist = map (id: "${id};${cwsUpdate}") resolvedExtensions;
}
