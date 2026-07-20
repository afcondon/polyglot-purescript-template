-- | The shared VALUE — the data axis's `core/`.
-- |
-- | Deliberately **Prim-only**: no prelude, only ADTs, records, arrays, ints
-- | and strings. That is what lets the SAME module compile under BOTH the JS
-- | backend (for the `docs` interpreter) and Nyx / PureScript->Nix (for the
-- | `nix` interpreter) without a per-backend shim. It carries data, never
-- | behaviour — the behaviour lives in the interpreter columns.
module Catalog where

-- | One line item: a name and a quantity.
newtype Item = Item { name :: String, qty :: Int }

-- | A named catalog of items.
data Catalog = Catalog { title :: String, items :: Array Item }

-- | Smart constructor — reads nicely in the value below.
item :: String -> Int -> Item
item name qty = Item { name, qty }

-- | The one source of truth. Two interpreters fold exactly this value.
catalog :: Catalog
catalog = Catalog
  { title: "Provisions"
  , items:
      [ item "apples" 6
      , item "flour" 2
      , item "coffee" 3
      ]
  }
