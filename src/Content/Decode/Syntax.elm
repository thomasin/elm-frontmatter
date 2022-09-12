module Content.Decode.Syntax exposing
    ( Syntax, noContext, string, datetime, int, float, bool, list, dict, tuple2, tuple3
    , node
    )

{-| These Syntax helpers are extensible wrappers around elm-syntax, made so you can build
type and function declarations in parallel.

    syntax : Content.Decode.Syntax.Syntax () ( ( Int, String ), List ( String, String ) )
    syntax =
        Content.Decode.Syntax.tuple2
            ( Content.Decode.Syntax.tuple2 ( Content.Decode.Syntax.int, Content.Decode.Syntax.string )
            , Content.Decode.Syntax.list
                (Content.Decode.Syntax.tuple2 (Content.Decode.Syntax.string Content.Decode.Syntax.string))
            )

@docs Syntax, noContext, string, datetime, int, float, bool, list, dict, tuple2, tuple3
@docs node

-}

import Content.Internal
import Elm.Syntax.Expression
import Elm.Syntax.Import
import Elm.Syntax.Node
import Elm.Syntax.TypeAnnotation
import Time


{-| Syntax object. Fields take a `context` argument, so when you render your type
annotation, imports or expressions you can pass down meta. `Content.Decode.Decoder`s
use this to pass down the input file path so that decoders know which file they are decoding.
-}
type alias Syntax context value =
    { typeAnnotation : context -> Elm.Syntax.TypeAnnotation.TypeAnnotation
    , imports : context -> List Elm.Syntax.Import.Import
    , expression : context -> value -> Elm.Syntax.Expression.Expression
    }


{-| A very small helper to create a Syntax object that doesn't need to use or pass on any context.
-}
noContext : { typeAnnotation : Elm.Syntax.TypeAnnotation.TypeAnnotation, imports : List Elm.Syntax.Import.Import, expression : value -> Elm.Syntax.Expression.Expression } -> Syntax context value
noContext args =
    { typeAnnotation = \_ -> args.typeAnnotation
    , imports = \_ -> args.imports
    , expression = \_ value -> args.expression value
    }


{-| String
An important note is that this will escape '"' and '', as it is meant for user provided strings.
If you want to pass it hardcoded strings this might be a problem.
-}
string : Syntax context String
string =
    { typeAnnotation = \_ -> Elm.Syntax.TypeAnnotation.Typed (Content.Internal.node ( [], "String" )) []
    , imports = \_ -> []
    , expression =
        \_ value ->
            Elm.Syntax.Expression.Literal (String.replace "\"" "\\\"" (String.replace "\\" "\\\\" value))
    }


{-| Int
-}
int : Syntax context Int
int =
    { typeAnnotation = \_ -> Elm.Syntax.TypeAnnotation.Typed (Content.Internal.node ( [], "Int" )) []
    , imports = \_ -> []
    , expression = \_ value -> Elm.Syntax.Expression.Integer value
    }


{-| Float
-}
float : Syntax context Float
float =
    { typeAnnotation = \_ -> Elm.Syntax.TypeAnnotation.Typed (Content.Internal.node ( [], "Float" )) []
    , imports = \_ -> []
    , expression = \_ value -> Elm.Syntax.Expression.Floatable value
    }


{-| Bool
-}
bool : Syntax context Bool
bool =
    { typeAnnotation = \_ -> Elm.Syntax.TypeAnnotation.Typed (Content.Internal.node ( [], "Bool" )) []
    , imports = \_ -> []
    , expression =
        \_ bool_ ->
            Elm.Syntax.Expression.FunctionOrValue []
                (if bool_ then
                    "True"

                 else
                    "False"
                )
    }


{-| Datetime
-}
datetime : Syntax context Time.Posix
datetime =
    { typeAnnotation = \_ -> Elm.Syntax.TypeAnnotation.Typed (Content.Internal.node ( [ "Time" ], "Posix" )) []
    , imports =
        \_ ->
            [ { moduleName = Content.Internal.node [ "Time" ]
              , moduleAlias = Nothing
              , exposingList = Nothing
              }
            ]
    , expression =
        \context posix ->
            Elm.Syntax.Expression.Application
                [ Content.Internal.node (Elm.Syntax.Expression.FunctionOrValue [ "Time" ] "millisToPosix")
                , Content.Internal.node (int.expression context (Time.posixToMillis posix))
                ]
    }


{-| List
`list string => List String`
-}
list : Syntax context a -> Syntax context (List a)
list item =
    { typeAnnotation =
        \context ->
            Elm.Syntax.TypeAnnotation.Typed
                (Content.Internal.node ( [], "List" ))
                [ Content.Internal.node (item.typeAnnotation context) ]
    , imports = item.imports
    , expression =
        \context value ->
            Elm.Syntax.Expression.ListExpr
                (List.map (Content.Internal.node << item.expression context) value)
    }


{-| Dict
`dict string int => Dict.Dict String Int`
-}
dict : Syntax context key -> Syntax context value -> Syntax context (List ( key, value ))
dict keyItem valueItem =
    { typeAnnotation =
        \context ->
            Elm.Syntax.TypeAnnotation.Typed
                (Content.Internal.node ( [ "Dict" ], "Dict" ))
                [ Content.Internal.node (keyItem.typeAnnotation context)
                , Content.Internal.node (valueItem.typeAnnotation context)
                ]
    , imports =
        \context ->
            { moduleName = Content.Internal.node [ "Dict" ]
            , moduleAlias = Nothing
            , exposingList = Nothing
            }
                :: (keyItem.imports context ++ valueItem.imports context)
    , expression =
        \context values ->
            let
                syntax : Syntax context (List ( key, value ))
                syntax =
                    list (tuple2 ( keyItem, valueItem ))
            in
            Elm.Syntax.Expression.Application
                [ Content.Internal.node (Elm.Syntax.Expression.FunctionOrValue [ "Dict" ] "fromList")
                , Content.Internal.node (syntax.expression context values)
                ]
    }


{-| Two element tuple
`tuple2 ( string, int ) => ( String, Int )`
-}
tuple2 : ( Syntax context a, Syntax context b ) -> Syntax context ( a, b )
tuple2 ( itemA, itemB ) =
    { typeAnnotation =
        \context ->
            Elm.Syntax.TypeAnnotation.Tupled
                [ Content.Internal.node (itemA.typeAnnotation context)
                , Content.Internal.node (itemB.typeAnnotation context)
                ]
    , imports =
        \context ->
            List.concat [ itemA.imports context, itemB.imports context ]
    , expression =
        \context ( decodedA, decodedB ) ->
            Elm.Syntax.Expression.TupledExpression
                [ Content.Internal.node (itemA.expression context decodedA)
                , Content.Internal.node (itemB.expression context decodedB)
                ]
    }


{-| Three element tuple
`tuple2 ( string, float, int ) => ( String, Float, Int )`
-}
tuple3 : ( Syntax context a, Syntax context b, Syntax context c ) -> Syntax context ( a, b, c )
tuple3 ( itemA, itemB, itemC ) =
    { typeAnnotation =
        \context ->
            Elm.Syntax.TypeAnnotation.Tupled
                [ Content.Internal.node (itemA.typeAnnotation context)
                , Content.Internal.node (itemB.typeAnnotation context)
                , Content.Internal.node (itemC.typeAnnotation context)
                ]
    , imports =
        \context ->
            List.concat [ itemA.imports context, itemB.imports context, itemC.imports context ]
    , expression =
        \context ( decodedA, decodedB, decodedC ) ->
            Elm.Syntax.Expression.TupledExpression
                [ Content.Internal.node (itemA.expression context decodedA)
                , Content.Internal.node (itemB.expression context decodedB)
                , Content.Internal.node (itemC.expression context decodedC)
                ]
    }


{-| Small helper for building up Elm.Syntax expressions (zero-ed out node, empty range).
There aren't many helpers in this module for building up custom types so I would feel bad
for not at least offering this.
-}
node : a -> Elm.Syntax.Node.Node a
node =
    Content.Internal.node



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
