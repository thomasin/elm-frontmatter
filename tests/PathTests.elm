module PathTests exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)


import Content.Path as Path
import Elm.Writer
import Elm.Syntax.Node
import Elm.Syntax.Range
import Time


suite : Test
suite =
    describe "Content.Path"
        [ describe "parse"
            [ test "absolute" <|
                \() ->
                    Path.parse "/abs/dir/content.md"
                        |> Expect.equal (Ok
                            { root = Just "/"
                            , dir = "/abs/dir"
                            , base = "content.md"
                            , ext = ".md"
                            , name = "content"
                            })
            , test "single dot" <|
                \() ->
                    Path.parse "./relative/dir/content.md"
                        |> Expect.equal (Ok
                            { root = Nothing
                            , dir = "./relative/dir"
                            , base = "content.md"
                            , ext = ".md"
                            , name = "content"
                            })
            , test "two dots" <|
                \() ->
                    Path.parse "../relative/dir/content.md"
                        |> Expect.equal (Ok
                            { root = Nothing
                            , dir = "../relative/dir"
                            , base = "content.md"
                            , ext = ".md"
                            , name = "content"
                            })
            , test "just file name" <|
                \() ->
                    Path.parse "content.md"
                        |> Expect.equal (Ok
                            { root = Nothing
                            , dir = ""
                            , base = "content.md"
                            , ext = ".md"
                            , name = "content"
                            })
            , test "hidden file" <|
                \() ->
                    Path.parse ".content.md"
                        |> Expect.equal (Ok
                            { root = Nothing
                            , dir = ""
                            , base = ".content.md"
                            , ext = ".md"
                            , name = ".content"
                            })
            , test "just directory path" <|
                \() ->
                    Path.parse "/abs/dir"
                        |> Expect.equal (Ok
                            { root = Just "/"
                            , dir = "/abs"
                            , base = "dir"
                            , ext = ""
                            , name = "dir"
                            })
            , test "just directory path - trailing slash" <|
                \() ->
                    Path.parse "/abs/dir/"
                        |> Expect.equal (Ok
                            { root = Just "/"
                            , dir = "/abs"
                            , base = "dir"
                            , ext = ""
                            , name = "dir"
                            })
            , test "file name in directory name" <|
                \() ->
                    Path.parse "/abs/dir.md/content.md"
                        |> Expect.equal (Ok
                            { root = Just "/"
                            , dir = "/abs/dir.md"
                            , base = "content.md"
                            , ext = ".md"
                            , name = "content"
                            })
            ]
        ]
