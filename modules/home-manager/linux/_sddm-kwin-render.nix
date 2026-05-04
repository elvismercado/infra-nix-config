# SDDM kwinoutputconfig.json renderer (internal helper, not a module)
#
# Pure Nix function: given a single profile attrset (matching the schema
# of `custom.hmDisplayProfiles.profiles.<name>`) and an optional list of
# connectors to disable, returns a `pkgs.writeText` derivation containing
# the JSON KWin's Wayland greeter consumes.
#
# Used by `modules/home-manager/linux/sddm-monitor-layout.nix`.
#
# Schema reference: captured live `~/.config/kwinoutputconfig.json`
# from a Plasma 6 session on FENNEC.
#
# Position resolution mirrors the bash daemon in display-profiles.nix:
# `right-of-X` → anchor.x + anchor.logicalWidth
# `left-of-X`  → anchor.x - self.logicalWidth
# literal "X,Y" → X
# missing      → 0
# logicalWidth accounts for rotation (portrait swaps W↔H) and scale.

{ pkgs, lib }:

{
  profile, # single profile attrset: { match = {...}; outputs = {...}; }
  disabledOutputs ? [ ],
}:

let
  # Connector list, sorted (Nix attrset keys are already alphabetical;
  # we use this order for both outputIndex and non-primary priority).
  connectors = lib.attrNames profile.outputs;

  # Map orientation string → KWin transform enum string.
  # right→Rotated270 confirmed against live file (M2 was "right" + "Rotated270").
  transformOf =
    orientation:
    {
      "normal" = "Normal";
      "right" = "Rotated270";
      "inverted" = "Rotated180";
      "left" = "Rotated90";
    }
    .${orientation} or "Normal";

  # Parse "WIDTHxHEIGHT" → { w, h } (ints).
  parseRes =
    res:
    let
      parts = lib.splitString "x" res;
    in
    {
      w = lib.toInt (builtins.elemAt parts 0);
      h = lib.toInt (builtins.elemAt parts 1);
    };

  # Logical pixel width of an output after rotation+scale, as int.
  logicalWidth =
    connector:
    let
      o = profile.outputs.${connector};
      r = parseRes o.resolution;
      rotated = o.orientation == "left" || o.orientation == "right";
      base = if rotated then r.h else r.w;
      scale = o.scale or 1.0;
    in
    builtins.floor (1.0 * base / scale);

  # Recursive x-offset resolver. depth limit prevents infinite loops on
  # accidental circular position references.
  maxDepth = 10;
  xOffset =
    connector: depth:
    let
      o = profile.outputs.${connector};
      pos = o.position or null;
    in
    if depth >= maxDepth then
      0
    else if pos == null then
      0
    else if lib.hasPrefix "right-of-" pos then
      let
        anchor = lib.removePrefix "right-of-" pos;
      in
      if profile.outputs ? ${anchor} then xOffset anchor (depth + 1) + logicalWidth anchor else 0
    else if lib.hasPrefix "left-of-" pos then
      let
        anchor = lib.removePrefix "left-of-" pos;
      in
      if profile.outputs ? ${anchor} then xOffset anchor (depth + 1) - logicalWidth connector else 0
    else
      # Literal "X,Y"
      lib.toInt (builtins.elemAt (lib.splitString "," pos) 0);

  # Identify the primary connector (or null if none flagged).
  primaryConnector = lib.findFirst (
    c: (profile.outputs.${c}.primary or false) == true
  ) null connectors;

  # Priority assignment: primary→0, others→1..N in alphabetical (connectors)
  # order. If no primary is flagged, all connectors get 0..N-1.
  priorityOf =
    connector:
    if primaryConnector == null then
      lib.lists.findFirstIndex (c: c == connector) 0 connectors
    else if connector == primaryConnector then
      0
    else
      let
        nonPrimary = lib.filter (c: c != primaryConnector) connectors;
      in
      1 + (lib.lists.findFirstIndex (c: c == connector) 0 nonPrimary);

  # ── outputs[] entries (top-level "outputs" data array) ─────────────
  outputEntries = map (
    connector:
    let
      o = profile.outputs.${connector};
      r = parseRes o.resolution;
    in
    {
      connectorName = connector;
      mode = {
        width = r.w;
        height = r.h;
        # KWin stores refresh rate in milliHz (160Hz → 160000).
        refreshRate = o.refreshRate * 1000;
      };
      scale = o.scale or 1.0;
      transform = transformOf (o.orientation or "normal");
      # Empty EDID identifiers → KWin matches by connectorName.
      uuid = "";
      edidHash = "";
      edidIdentifier = "";
    }
  ) connectors;

  # ── setups[] entries (single setup matching this profile) ──────────
  setupOutputs = lib.imap0 (idx: connector: {
    enabled = !(builtins.elem connector disabledOutputs);
    outputIndex = idx;
    position = {
      x = xOffset connector 0;
      y = 0;
    };
    priority = priorityOf connector;
    replicationSource = "";
  }) connectors;

  json = [
    {
      name = "outputs";
      data = outputEntries;
    }
    {
      name = "setups";
      data = [
        {
          lidClosed = false;
          outputs = setupOutputs;
        }
      ];
    }
  ];
in
pkgs.writeText "kwinoutputconfig.json" (builtins.toJSON json)
