module Content.Decode.Syntax exposing (Syntax, fromDecoder, string, datetime, int, float, bool, list, dict, tuple2, tuple3)

{-| These Syntax helpers are extensible wrappers around elm-syntax, made so you can build
type and function declarations in parallel.

    syntax : Content.Decode.Syntax.Syntax ( ( Int, String ), List ( String, String ) )
    syntax =
        Content.Decode.Syntax.tuple2
            ( Content.Decode.Syntax.tuple2 ( Content.Decode.Syntax.int, Content.Decode.Syntax.string )
            , Content.Decode.Syntax.list
                (Content.Decode.Syntax.tuple2 ( Content.Decode.Syntax.string Content.Decode.Syntax.string ))
            )

    Elm.Writer.writeExpression
        (syntax.expression [ ( "one", "two" ), [ ( "three", "four" ) ] ]

    Elm.Writer.writeTypeAnnotation syntax.typeAnnotation

@docs Syntax, fromDecoder, string, datetime, int, float, bool, list, dict, tuple2, tuple3

-}

import Content.Decode.Internal
import Content.Internal
import Elm.Syntax.Expression
import Elm.Syntax.Import
import Elm.Syntax.TypeAnnotation
import Time


{-| Syntax object
-}
type alias Syntax a =
    { typeAnnotation : Elm.Syntax.TypeAnnotation.TypeAnnotation
    , imports : List Elm.Syntax.Import.Import
    , expression : a -> Elm.Syntax.Expression.Expression
    }


{-| Turn a decoder into a simpler Syntax object
-}
fromDecoder : Content.Decode.Internal.Decoder a -> Syntax a
fromDecoder (Content.Decode.Internal.Decoder decoder) =
    { typeAnnotation = decoder.typeAnnotation
    , imports = decoder.imports
    , expression = decoder.asExpression
    }


{-| String
-}
string : Syntax String
string =
    { typeAnnotation = Elm.Syntax.TypeAnnotation.Typed (Content.Internal.node ( [], "String" )) []
    , imports = []
    , expression = Elm.Syntax.Expression.Literal << String.replace "\"" "\\\""
    }


{-| Int
-}
int : Syntax Int
int =
    { typeAnnotation = Elm.Syntax.TypeAnnotation.Typed (Content.Internal.node ( [], "Int" )) []
    , imports = []
    , expression = Elm.Syntax.Expression.Integer
    }


{-| Float
-}
float : Syntax Float
float =
    { typeAnnotation = Elm.Syntax.TypeAnnotation.Typed (Content.Internal.node ( [], "Float" )) []
    , imports = []
    , expression = Elm.Syntax.Expression.Floatable
    }


{-| Bool
-}
bool : Syntax Bool
bool =
    { typeAnnotation = Elm.Syntax.TypeAnnotation.Typed (Content.Internal.node ( [], "Bool" )) []
    , imports = []
    , expression =
        \b ->
            Elm.Syntax.Expression.FunctionOrValue []
                (if b then
                    "True"

                 else
                    "False"
                )
    }


{-| Datetime
-}
datetime : Syntax Time.Posix
datetime =
    { typeAnnotation = Elm.Syntax.TypeAnnotation.Typed (Content.Internal.node ( [ "Time" ], "Posix" )) []
    , imports =
        [ { moduleName = Content.Internal.node [ "Time" ]
          , moduleAlias = Nothing
          , exposingList = Nothing
          }
        ]
    , expression =
        \posix ->
            Elm.Syntax.Expression.Application
                [ Content.Internal.node (Elm.Syntax.Expression.FunctionOrValue [ "Time" ] "millisToPosix")
                , Content.Internal.node (int.expression (Time.posixToMillis posix))
                ]
    }


{-| List
`list string => List String`
-}
list : Syntax a -> Syntax (List a)
list item =
    { typeAnnotation = Elm.Syntax.TypeAnnotation.Typed (Content.Internal.node ( [], "List" )) [ Content.Internal.node item.typeAnnotation ]
    , imports = item.imports
    , expression =
        \decoded ->
            Elm.Syntax.Expression.ListExpr
                (List.map (Content.Internal.node << item.expression) decoded)
    }


{-| Dict
`dict int => Dict.Dict String Int`
-}
dict : Syntax a -> Syntax (List ( String, a ))
dict item =
    { typeAnnotation = Elm.Syntax.TypeAnnotation.Typed (Content.Internal.node ( [ "Dict" ], "Dict" )) [ Content.Internal.node item.typeAnnotation ]
    , imports =
        { moduleName = Content.Internal.node [ "Dict" ]
        , moduleAlias = Nothing
        , exposingList = Nothing
        }
            :: item.imports
    , expression =
        \decoded ->
            let
                syntax : Syntax (List ( String, a ))
                syntax =
                    list (tuple2 ( string, item ))
            in
            Elm.Syntax.Expression.Application
                [ Content.Internal.node (Elm.Syntax.Expression.FunctionOrValue [ "Dict" ] "fromList")
                , Content.Internal.node (syntax.expression decoded)
                ]
    }


{-| Two element tuple
`tuple2 ( string, int ) => ( String, Int )`
-}
tuple2 : ( Syntax a, Syntax b ) -> Syntax ( a, b )
tuple2 ( itemA, itemB ) =
    { typeAnnotation =
        Elm.Syntax.TypeAnnotation.Tupled
            [ Content.Internal.node itemA.typeAnnotation
            , Content.Internal.node itemB.typeAnnotation
            ]
    , imports = List.concat [ itemA.imports, itemB.imports ]
    , expression =
        \( decodedA, decodedB ) ->
            Elm.Syntax.Expression.TupledExpression
                [ Content.Internal.node (itemA.expression decodedA)
                , Content.Internal.node (itemB.expression decodedB)
                ]
    }


{-| Three element tuple
`tuple2 ( string, float, int ) => ( String, Float, Int )`
-}
tuple3 : ( Syntax a, Syntax b, Syntax c ) -> Syntax ( a, b, c )
tuple3 ( itemA, itemB, itemC ) =
    { typeAnnotation =
        Elm.Syntax.TypeAnnotation.Tupled
            [ Content.Internal.node itemA.typeAnnotation
            , Content.Internal.node itemB.typeAnnotation
            , Content.Internal.node itemC.typeAnnotation
            ]
    , imports = List.concat [ itemA.imports, itemB.imports, itemC.imports ]
    , expression =
        \( decodedA, decodedB, decodedC ) ->
            Elm.Syntax.Expression.TupledExpression
                [ Content.Internal.node (itemA.expression decodedA)
                , Content.Internal.node (itemB.expression decodedB)
                , Content.Internal.node (itemC.expression decodedC)
                ]
    }



--{-|
--h
---}
--field : String -> Syntax a -> Syntax Elm.Syntax.Expression.RecordSetter
--field key item =
--    { typeAnnotation = Elm.Syntax.TypeAnnotation.Record
--        [ Content.Internal.node ( Content.Internal.node key, Content.Internal.node item.typeAnnotation )
--        ]
--    , imports = item.imports
--    , expression = \value ->
--        Elm.Syntax.Expression.RecordExpr
--            [ Content.Internal.node ( Content.Internal.node key, Content.Internal.node (item.expression value) ) ]
--    }
