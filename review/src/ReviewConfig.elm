module ReviewConfig exposing (config)

import NoExposingEverything
import NoImportingEverything
import NoMissingTypeAnnotation
import NoMissingTypeAnnotationInLetIn
import NoMissingTypeExpose
import NoPrematureLetComputation
import NoUnused.CustomTypeConstructorArgs
import NoUnused.CustomTypeConstructors
import NoUnused.Dependencies
import NoUnused.Exports
import NoUnused.Modules
import NoUnused.Parameters
import NoUnused.Patterns
import NoUnused.Variables
import Simplify
import Review.Rule exposing (Rule)

{- NoExposingEverything
https://package.elm-lang.org/packages/jfmengels/elm-review-common/latest/
-}

{- NoUnused
https://package.elm-lang.org/packages/jfmengels/elm-review-unused/latest/
-}

{- Simplify
https://package.elm-lang.org/packages/jfmengels/elm-review-simplify/latest
-}

config : List Rule
config =
    [ NoExposingEverything.rule
    , NoImportingEverything.rule []
        |> Review.Rule.ignoreErrorsForFiles [ "src/Content/ElmSyntaxWriter.elm" ]
    , NoMissingTypeAnnotation.rule
    , NoMissingTypeAnnotationInLetIn.rule
        |> Review.Rule.ignoreErrorsForFiles [ "src/Content/ElmSyntaxWriter.elm" ]
    , NoMissingTypeExpose.rule
    , NoPrematureLetComputation.rule
    , NoUnused.CustomTypeConstructors.rule []
    , NoUnused.CustomTypeConstructorArgs.rule
    , NoUnused.Dependencies.rule
    , NoUnused.Exports.rule
    , NoUnused.Modules.rule
    , NoUnused.Parameters.rule
    , NoUnused.Patterns.rule
    , NoUnused.Variables.rule
    , Simplify.rule Simplify.defaults
    ]   
