{ # The Nix primitives the fold uses. Co-located with ToNix.purs, exactly as a
  # .js foreign co-locates with a .purs; pursnix copies it to foreign.nix.
  mkInt       = x: x;
  listToAttrs = builtins.listToAttrs;
  mapArray    = f: builtins.map f;
  sumValues   = attrs: builtins.foldl' (a: b: a + b) 0 (builtins.attrValues attrs);
}
