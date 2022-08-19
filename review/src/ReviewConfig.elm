module ReviewConfig exposing (config)

import NoExposingEverything
import NoUnused.CustomTypeConstructorArgs
import NoUnused.CustomTypeConstructors
import NoUnused.Dependencies
import NoUnused.Exports
import NoUnused.Modules
import NoUnused.Parameters
import NoUnused.Patterns
import NoUnused.Variables
import Review.Rule exposing (Rule)

{- NoExposingEverything
https://package.elm-lang.org/packages/jfmengels/elm-review-common/latest/
-}

{- NoUnused
https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/
-}

config : List Rule
config =
    [ NoExposingEverything.rule
    , NoUnused.CustomTypeConstructors.rule []
    , NoUnused.CustomTypeConstructorArgs.rule
    , NoUnused.Dependencies.rule
    , NoUnused.Exports.rule
    , NoUnused.Modules.rule
    , NoUnused.Parameters.rule
    , NoUnused.Patterns.rule
    , NoUnused.Variables.rule
    ]   
