module WriteTests exposing (suite)

--import Fuzz exposing (Fuzzer, int, list, string)

import Content.Decode
import Content.Write as Write
import Expect
import Json.Decode
import Json.Encode
import Test exposing (Test)


rec : Json.Decode.Value
rec =
    Json.Encode.object
        [ ( "content", Json.Encode.string "body" )
        , ( "data"
          , Json.Encode.object
                [ ( "title", Json.Encode.string "test" )
                ]
          )
        ]


dec : Content.Decode.FrontmatterDecoder
dec =
    Content.Decode.frontmatter
        [ Content.Decode.attribute "title" Content.Decode.string
        ]


suite : Test
suite =
    Test.describe "record"
        [ Test.test "accurately writes" <|
            \() ->
                Write.record
                    { functionName = "test"
                    , functionType = "Test"
                    , inputFilePath = "hello/bean.md"
                    , pathSep = "/"
                    , frontmatter = rec
                    , documentation = Nothing
                    , decoder = dec
                    }
                    |> Result.map (Write.toFileString [ "Test" ])
                    |> Result.withDefault ""
                    |> Expect.equal """module Test exposing (Test, test)

type alias Test  =
    {title : String, body : String}

test : Test
test  =
    {title = "test", body = "body"}"""
        , Test.test "accurately writes with invalid function/type/module names" <|
            \() ->
                Write.record
                    { functionName = "Test"
                    , functionType = "test"
                    , inputFilePath = "hello/bean.md"
                    , pathSep = "/"
                    , frontmatter = rec
                    , documentation = Nothing
                    , decoder = dec
                    }
                    |> Result.map (Write.toFileString [ "test" ])
                    |> Result.withDefault ""
                    |> Expect.equal """module Test exposing (Test, test)

type alias Test  =
    {title : String, body : String}

test : Test
test  =
    {title = "test", body = "body"}"""
        ]
