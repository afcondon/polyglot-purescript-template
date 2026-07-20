-- | The `docs` interpreter: folds the shared Catalog value into Markdown.
-- | Compiled by the ordinary JS backend. Unlike `core/`, this module DOES use
-- | the prelude — an interpreter is behaviour, and it lives in the column so
-- | that `core/` can stay Prim-only.
module ToText (render) where

import Prelude

import Data.String.Common (joinWith)
import Catalog (Catalog(..), Item(..))

render :: Catalog -> String
render (Catalog c) =
  joinWith "\n" ([ "# " <> c.title, "" ] <> map line c.items)
  where
  line (Item i) = "- " <> i.name <> " ×" <> show i.qty
