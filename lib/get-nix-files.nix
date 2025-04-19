dir:
builtins.map
  (name: dir + "/${name}")
  (builtins.filter
    (name: builtins.match ".*\\.nix$" name != null)
    (builtins.attrNames (builtins.readDir dir)))
