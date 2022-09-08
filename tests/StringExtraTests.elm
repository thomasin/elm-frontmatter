module StringExtraTests exposing (suite)

import Content.Decode.Syntax as Syntax
import String.Extra as String
import Elm.Syntax.Node
import Elm.Syntax.Range
import Elm.Writer
import Expect
import Test
import Time


suite : Test.Test
suite =
    Test.describe "all"
        [ Test.describe "camelize"
            [ Test.test """"01-intro\\" == "intro" """ <|
                \() ->
                    String.camelize "01-intro\\"
                        |> Expect.equal "intro"
            , Test.test """""-moz-transform" == "mozTransform" """ <|
                \() ->
                    String.camelize "-moz-transform"
                        |> Expect.equal "mozTransform"
            , Test.test """""ClassifiedWords" == "classifiedWords" """ <|
                \() ->
                    String.camelize "ClassifiedWords"
                        |> Expect.equal "classifiedWords"
            , Test.test """""01-getting-started/" == "gettingStarted" """ <|
                \() ->
                    String.camelize "01-getting-started/" 
                        |> Expect.equal "gettingStarted"
            , Test.test """""[01-getting-started]" == "gettingStarted" """ <|
                \() ->
                    String.camelize "[01-getting-started]" 
                        |> Expect.equal "gettingStarted"
            , Test.test """""-------" == "" """ <|
                \() ->
                    String.camelize "-------"
                        |> Expect.equal ""
            , Test.test """" "" == "" """ <|
                \() ->
                    String.camelize ""
                        |> Expect.equal ""
            ]
        , Test.describe "classify"
            [ Test.test """"01-intro\\" == "Intro" """ <|
                \() ->
                    String.classify "01-intro\\"
                        |> Expect.equal "Intro"
            , Test.test """""-moz-transform" == "MozTransform" """ <|
                \() ->
                    String.classify "-moz-transform"
                        |> Expect.equal "MozTransform"
            , Test.test """""ClassifiedWords" == "ClassifiedWords" """ <|
                \() ->
                    String.classify "ClassifiedWords"
                        |> Expect.equal "ClassifiedWords"
            , Test.test """""01-getting-started/" == "GettingStarted" """ <|
                \() ->
                    String.classify "01-getting-started/" 
                        |> Expect.equal "GettingStarted"
            , Test.test """""[01-getting-started]" == "GettingStarted" """ <|
                \() ->
                    String.classify "[01-getting-started]" 
                        |> Expect.equal "GettingStarted"
            , Test.test """""-------" == "" """ <|
                \() ->
                    String.classify "-------"
                        |> Expect.equal ""
            , Test.test """" "" == "" """ <|
                \() ->
                    String.classify ""
                        |> Expect.equal ""
            ]
        ]
