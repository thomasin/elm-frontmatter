module SyntaxTests exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)


import Content.Decode.Syntax as Syntax
import Elm.Writer
import Elm.Syntax.Node
import Elm.Syntax.Range
import Time


suite : Test
suite =
    describe "helpers"
        [ describe "string"
            [ test "string expression" <|
                \() ->
                    Syntax.string.expression "plain string"
                        |> Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange
                        |> Elm.Writer.writeExpression
                        |> Elm.Writer.write
                        |> Expect.equal """\"plain string\""""
            , test "string expression escapes apostrophes" <|
                \() ->
                    Syntax.string.expression """plain "string" with"""
                        |> Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange
                        |> Elm.Writer.writeExpression
                        |> Elm.Writer.write
                        |> Expect.equal """\"plain \\\"string\\\" with\""""
            , test "string type annotation" <|
                \() ->
                    Syntax.string.typeAnnotation
                        |> Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange
                        |> Elm.Writer.writeTypeAnnotation
                        |> Elm.Writer.write
                        |> Expect.equal """String"""
            ]
        , describe "int"
            [ test "int expression" <|
                \() ->
                    Syntax.int.expression 12
                        |> Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange
                        |> Elm.Writer.writeExpression
                        |> Elm.Writer.write
                        |> Expect.equal """12"""
            , test "int type annotation" <|
                \() ->
                    Syntax.int.typeAnnotation
                        |> Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange
                        |> Elm.Writer.writeTypeAnnotation
                        |> Elm.Writer.write
                        |> Expect.equal """Int"""
            ]
        , describe "float"
            [ test "float expression" <|
                \() ->
                    Syntax.float.expression 12.2
                        |> Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange
                        |> Elm.Writer.writeExpression
                        |> Elm.Writer.write
                        |> Expect.equal """12.2"""
            , test "float type annotation" <|
                \() ->
                    Syntax.float.typeAnnotation
                        |> Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange
                        |> Elm.Writer.writeTypeAnnotation
                        |> Elm.Writer.write
                        |> Expect.equal """Float"""
            ]
        , describe "bool"
            [ test "bool expression" <|
                \() ->
                    Syntax.bool.expression True
                        |> Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange
                        |> Elm.Writer.writeExpression
                        |> Elm.Writer.write
                        |> Expect.equal """True"""
            , test "bool type annotation" <|
                \() ->
                    Syntax.bool.typeAnnotation
                        |> Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange
                        |> Elm.Writer.writeTypeAnnotation
                        |> Elm.Writer.write
                        |> Expect.equal """Bool"""
            ]
        , describe "datetime"
            [ test "datetime expression" <|
                \() ->
                    Syntax.datetime.expression (Time.millisToPosix 1)
                        |> Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange
                        |> Elm.Writer.writeExpression
                        |> Elm.Writer.write
                        |> Expect.equal """Time.millisToPosix 1"""
            , test "datetime type annotation" <|
                \() ->
                    Syntax.datetime.typeAnnotation
                        |> Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange
                        |> Elm.Writer.writeTypeAnnotation
                        |> Elm.Writer.write
                        |> Expect.equal """Time.Posix"""
            ]
        , describe "list"
            [ test "list expression" <|
                \() ->
                    (Syntax.list Syntax.string).expression [ "a", "b", "c" ]
                        |> Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange
                        |> Elm.Writer.writeExpression
                        |> Elm.Writer.write
                        |> Expect.equal """["a", "b", "c"]"""
            , test "list type annotation" <|
                \() ->
                    (Syntax.list Syntax.string).typeAnnotation
                        |> Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange
                        |> Elm.Writer.writeTypeAnnotation
                        |> Elm.Writer.write
                        |> Expect.equal """List String"""
            ]
        , describe "dict"
            [ test "dict expression" <|
                \() ->
                    (Syntax.dict Syntax.string).expression [ ( "k1", "a" ), ( "k2", "b" ) ]
                        |> Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange
                        |> Elm.Writer.writeExpression
                        |> Elm.Writer.write
                        |> Expect.equal """Dict.fromList [("k1", "a"), ("k2", "b")]"""
            , test "dict type annotation" <|
                \() ->
                    (Syntax.dict Syntax.string).typeAnnotation
                        |> Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange
                        |> Elm.Writer.writeTypeAnnotation
                        |> Elm.Writer.write
                        |> Expect.equal """Dict.Dict String"""
            ]
        , describe "tuple2"
            [ test "tuple2 expression" <|
                \() ->
                    (Syntax.tuple2 ( Syntax.string, Syntax.int )).expression ( "a", 12 )
                        |> Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange
                        |> Elm.Writer.writeExpression
                        |> Elm.Writer.write
                        |> Expect.equal """("a", 12)"""
            , test "tuple2 type annotation" <|
                \() ->
                    (Syntax.tuple2 ( Syntax.string, Syntax.int )).typeAnnotation
                        |> Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange
                        |> Elm.Writer.writeTypeAnnotation
                        |> Elm.Writer.write
                        |> Expect.equal """(String, Int)"""
            ]
        , describe "tuple3"
            [ test "tuple3 expression" <|
                \() ->
                    (Syntax.tuple3 ( Syntax.string, Syntax.int, (Syntax.list Syntax.float ))).expression ( "a", 12, [ 1.2 ] )
                        |> Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange
                        |> Elm.Writer.writeExpression
                        |> Elm.Writer.write
                        |> Expect.equal """("a", 12, [1.2])"""
            , test "tuple3 type annotation" <|
                \() ->
                    (Syntax.tuple3 ( Syntax.string, Syntax.int, (Syntax.list Syntax.float ))).typeAnnotation
                        |> Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange
                        |> Elm.Writer.writeTypeAnnotation
                        |> Elm.Writer.write
                        |> Expect.equal """(String, Int, List Float)"""
            ]
        ]
