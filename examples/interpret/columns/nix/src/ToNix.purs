-- | The `nix` interpreter: folds the shared Catalog value into a Nix attrset
-- | and computes over it. Compiled by Nyx (PureScript -> Nix), NOT the JS
-- | backend — its FFI is the co-located `ToNix.nix` (copied by pursnix to
-- | `foreign.nix`), and it is never run under Node.
-- |
-- | Like `core/`, it is Prim-only: no prelude — the Nix primitives ARE the
-- | vocabulary. Because it lives in its own column, `spago build` here compiles
-- | ONLY this + `core` (both Prim-only), so no JS FFI stub is ever needed.
module ToNix where

import Catalog (Catalog(..), Item(..), catalog)

-- | An opaque Nix value (an int, an attrset, ...).
foreign import data Nix :: Type

-- | Lift a PureScript Int into Nix.
foreign import mkInt :: Int -> Nix

-- | `builtins.listToAttrs` — a list of `{name,value}` into an attrset.
foreign import listToAttrs :: Array { name :: String, value :: Nix } -> Nix

-- | `builtins.map`, kept FFI to avoid pulling in a prelude Functor.
foreign import mapArray :: forall a b. (a -> b) -> Array a -> Array b

-- | Sum the integer values of an attrset (`foldl' (+) 0 (attrValues ...)`).
foreign import sumValues :: Nix -> Nix

-- | Fold the catalog into `{ items = <attrset>; total = <int>; }`.
toNix :: Catalog -> { items :: Nix, total :: Nix }
toNix (Catalog c) =
  let
    entry (Item i) = { name: i.name, value: mkInt i.qty }
    items = listToAttrs (mapArray entry c.items)
  in
    { items, total: sumValues items }

-- | Nullary entry point so the emitted Nix is directly evaluable:
-- | `(import output/ToNix).result` -> `{ items = {...}; total = 11; }`.
result :: { items :: Nix, total :: Nix }
result = toNix catalog
