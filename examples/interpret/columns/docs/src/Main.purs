-- | JS entry point for the `docs` lowering: render the shared value and print
-- | it. `poly run docs` builds this column and runs `main`.
module Main where

import Prelude

import Effect (Effect)
import Effect.Console (log)
import Catalog (catalog)
import ToText (render)

main :: Effect Unit
main = log (render catalog)
