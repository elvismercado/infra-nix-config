# Brave managed policies — shared data
#
# Single source of truth for the policy attrset applied to Brave on every
# host that enables `custom.appBrave.enable`. Pure data: no function args,
# no `let`, no `mkIf`. The OS-specific writers in
# `modules/systems/{nixos,darwin}/brave-policies.nix` import this file and
# render it to the right on-disk format:
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
# Editing checklist:
#   - Adding/removing an extension: edit the ExtensionInstallForcelist below.
#     Each entry is "<extension-id>;<update-url>". Brave reads from the
#     Chrome Web Store, so the update URL is the standard CWS endpoint.
#   - Adding a new policy: drop it into the attrset; rebuild; verify on
#     `chrome://policy` that Status: OK and Source: Platform.

let
  # Chrome Web Store update endpoint. Brave honours this just like Chrome.
  cwsUpdate = "https://clients2.google.com/service/update2/crx";
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

  # Brave Sync intentionally NOT disabled — used to sync settings + bookmarks.
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
  # disable these — that's the point of force-install. To allow user-managed
  # install instead, omit the entry; users can install manually from CWS.
  ExtensionInstallForcelist = [
    "nngceckbapebfimnlniiiahkandclblb;${cwsUpdate}" # Bitwarden
    "fnaicdffflnofjppbagibeoednhnbjhg;${cwsUpdate}" # Floccus bookmark sync
    "mnjggcdmjocbbbhaepdhchncahnbgone;${cwsUpdate}" # SponsorBlock for YouTube
    "jcgpghgjhhahcefnfpbncdmhhddedhnk;${cwsUpdate}" # Click to remove element
    "fdpohaocaechififmbbbbbknoalclacl;${cwsUpdate}" # GoFullPage — full page screen capture
    # "cjpalhdlnbpafiamejdnhcphjbkeiagm;${cwsUpdate}" # uBlock Origin — uncomment to force-install (cannot be installed-disabled via policy)
  ];
}
