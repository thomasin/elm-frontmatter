module Content.Type exposing (Path(..), fromFunctionType, toTypeName, toString, toModuleDir)

import Content.Function

{-|

# Declaration

@docs Path, toTypeName, toModuleDir, toString

-}

type Path
    = Single String
    | Multiple String



fromFunctionType : Content.Function.FunctionType -> List String -> Path
fromFunctionType functionType moduleDir =
    case functionType of
        Content.Function.SingletonFunction ->
            Single (String.join "." moduleDir)

        Content.Function.ListItemFunction ->
            Multiple (String.join "." moduleDir)



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
