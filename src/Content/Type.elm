module Content.Type exposing (Path(..), toTypeName, toString, toModuleDir)

{-|

# Declaration

@docs Path, toTypeName, toModuleDir, toString

-}


{-| Path
-}
type Path
    = Single String
    | Multiple String



{-|

h
-}
toTypeName : Path -> String
toTypeName path =
    case path of
        Single _ ->
            "Content"

        Multiple _ ->
            "ListItem"


{-|

h
-}
toModuleDir : Path -> List String
toModuleDir path =
    case path of
        Single modules ->
            String.split "." modules

        Multiple modules ->
            String.split "." modules


{-|

h
-}
toString : Path -> String
toString path =
    case path of
        Single modules ->
            modules ++ ".Content"

        Multiple modules ->
            modules ++ ".ListItem"
