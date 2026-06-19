-- | The FFI seam. ONE declaration here; a different real implementation
-- | per runtime (Runtime.js for node, ffi-jl/Runtime_foreign.jl for julia, …).
module Runtime where

foreign import runtimeName :: String
