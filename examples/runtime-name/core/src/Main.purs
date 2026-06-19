module Main where

import Prelude
import Effect (Effect)
import Effect.Console (log)
import Runtime (runtimeName)

main :: Effect Unit
main = log ("Hello from PureScript — running natively on " <> runtimeName <> ".")
