module DecodeImageTests exposing (suite)

import Content.Decode as Decode
import Content.Decode.Image as Image
import Content.Decode.Internal
import Content.Type
import Elm.Syntax.Node
import Elm.Syntax.Range
import Elm.Syntax.Expression
import Elm.Syntax.TypeAnnotation
import Elm.Writer
import Expect
import Json.Decode
import Json.Encode
import Path
import Path.Platform
import Elm.Syntax.ModuleName
import Test
import Time
import Utils


copyArgs =
    { copyToDirectory = "../static/image-gen/"
    , publicDirectory = "/image-gen/"
    }


suite : Test.Test
suite =
    Test.describe "decoders"
        [ Test.describe "process"
            [ Test.test "No manipulations - TypeAnnotation"
                (\() ->
                    let
                        imageDecoder : Image.Decoder
                        imageDecoder = Image.process copyArgs []
                            
                    in
                    Utils.testDecoder "/recipes/content.md" (Just [ "Content", "Recipes" ]) imageDecoder
                        (\context decoder ->
                            decoder.typeAnnotation context
                                |> Utils.writeTypeAnnotation
                                |> Expect.equal "String"
                        )
                )
            , Test.test "No manipulations - Expression"
                (\() ->
                    let
                        imageDecoder : Image.Decoder
                        imageDecoder = Image.process copyArgs []
                            
                    in
                    Utils.testDecoder "/recipes/content.md" (Just [ "Content", "Recipes" ]) imageDecoder
                        (\context decoder ->
                            case Json.Decode.decodeString (decoder.jsonDecoder context) "\"./banner.jpg\"" of
                                Ok actions ->
                                    decoder.asExpression context actions
                                        |> Utils.writeExpression
                                        |> Expect.equal "\"/image-gen/recipes/banner.jpg\""

                                Err err ->
                                    Expect.fail (Json.Decode.errorToString err)
                        )
                )
            , Test.test "Width resized - Expression"
                (\() ->
                    let
                        imageDecoder : Image.Decoder
                        imageDecoder = Image.process copyArgs [ Image.width 500 ]

                    in
                    Utils.testDecoder "/recipes/content.md" (Just [ "Content", "Recipes" ]) imageDecoder
                        (\context decoder ->
                            case Json.Decode.decodeString (decoder.jsonDecoder context) "\"./banner.jpg\"" of
                                Ok actions ->
                                    decoder.asExpression context actions
                                        |> Utils.writeExpression
                                        |> Expect.equal "\"/image-gen/recipes/banner.jpg\""

                                Err err ->
                                    Expect.fail (Json.Decode.errorToString err)
                        )
                )
            , Test.test "Actions"
                (\() ->
                    let
                        imageDecoder : Image.Decoder
                        imageDecoder = Image.process copyArgs [ Image.width 500 ]

                    in
                    Utils.testDecoder "/recipes/content.md" (Just [ "Content", "Recipes" ]) imageDecoder
                        (\context decoder ->
                            case Json.Decode.decodeString (decoder.jsonDecoder context) "\"./banner.jpg\"" of
                                Ok actions ->
                                    decoder.actions actions
                                        |> List.map (Json.Encode.encode 0 << .args)
                                        |> Expect.equal ["{\"paths\":{\"copyFromBase\":\"/recipes/content.md\",\"copyFromPath\":\"banner.jpg\",\"copyToPath\":\"../static/image-gen/recipes\",\"fileName\":\"banner.jpg\"},\"manipulations\":[{\"function\":\"width\",\"args\":500}]}"]

                                Err err ->
                                    Expect.fail (Json.Decode.errorToString err)
                        )
                )
            , Test.test "Actions - duplicate actions"
                (\() ->
                    let
                        imageDecoder : Image.Decoder
                        imageDecoder = Image.process copyArgs [ Image.width 500, Image.width 500 ]

                    in
                    Utils.testDecoder "/recipes/content.md" (Just [ "Content", "Recipes" ]) imageDecoder
                        (\context decoder ->
                            case Json.Decode.decodeString (decoder.jsonDecoder context) "\"./banner.jpg\"" of
                                Ok actions ->
                                    decoder.actions actions
                                        |> List.map (Json.Encode.encode 0 << .args)
                                        |> Expect.equal ["{\"paths\":{\"copyFromBase\":\"/recipes/content.md\",\"copyFromPath\":\"banner.jpg\",\"copyToPath\":\"../static/image-gen/recipes\",\"fileName\":\"banner.jpg\"},\"manipulations\":[{\"function\":\"width\",\"args\":500},{\"function\":\"width\",\"args\":500}]}"]

                                Err err ->
                                    Expect.fail (Json.Decode.errorToString err)
                        )
                )
            ]
        , Test.describe "batchProcess"
            [ Test.test "No manipulations - TypeAnnotation"
                (\() ->
                    let
                        imageDecoder : Image.Decoder
                        imageDecoder = Image.batchProcess copyArgs
                            ( "300", [ Image.width 300 ] )
                            [ ( "600", [ Image.width 600 ] )
                            , ( "1200", [ Image.width 1200 ] )
                            ]

                    in
                    Utils.testDecoder "/recipes/content.md" (Just [ "Content", "Recipes" ]) imageDecoder
                        (\context decoder ->
                            decoder.typeAnnotation context
                                |> Utils.writeTypeAnnotation
                                |> Expect.equal """((String, String), List ((String, String)))"""
                        )
                )
            , Test.test "No manipulations - Expression"
                (\() ->
                    let
                        imageDecoder : Image.Decoder
                        imageDecoder = Image.batchProcess copyArgs
                            ( "300", [] )
                            [ ( "600", [] )
                            , ( "1200", [] )
                            ]

                    in
                    Utils.testDecoder "/recipes/content.md" (Just [ "Content", "Recipes" ]) imageDecoder
                        (\context decoder ->
                            case Json.Decode.decodeString (decoder.jsonDecoder context) "\"./banner.jpg\"" of
                                Ok actions ->
                                    decoder.asExpression context actions
                                        |> Utils.writeExpression
                                        |> Expect.equal "((\"300\", \"/image-gen/recipes/banner-300.jpg\"), [(\"600\", \"/image-gen/recipes/banner-600.jpg\"), (\"1200\", \"/image-gen/recipes/banner-1200.jpg\")])"

                                Err err ->
                                    Expect.fail (Json.Decode.errorToString err)
                        )
                )
            , Test.test "Width resized - Expression"
                (\() ->
                    let
                        imageDecoder : Image.Decoder
                        imageDecoder = Image.batchProcess copyArgs
                            ( "300", [ Image.width 300 ] )
                            [ ( "600", [ Image.width 600 ] )
                            , ( "1200", [ Image.width 1200 ] )
                            ]

                    in
                    Utils.testDecoder "/recipes/content.md" (Just [ "Content", "Recipes" ]) imageDecoder
                        (\context decoder ->
                            case Json.Decode.decodeString (decoder.jsonDecoder context) "\"./banner.jpg\"" of
                                Ok actions ->
                                    decoder.asExpression context actions
                                        |> Utils.writeExpression
                                        |> Expect.equal "((\"300\", \"/image-gen/recipes/banner-300.jpg\"), [(\"600\", \"/image-gen/recipes/banner-600.jpg\"), (\"1200\", \"/image-gen/recipes/banner-1200.jpg\")])"

                                Err err ->
                                    Expect.fail (Json.Decode.errorToString err)
                        )
                )
            , Test.test "Actions"
                (\() ->
                    let
                        imageDecoder : Image.Decoder
                        imageDecoder = Image.batchProcess copyArgs
                            ( "300", [ Image.width 300 ] )
                            [ ( "600", [ Image.width 600 ] )
                            , ( "1200", [ Image.width 1200 ] )
                            ]

                    in
                    Utils.testDecoder "/recipes/content.md" (Just [ "Content", "Recipes" ]) imageDecoder
                        (\context decoder ->
                            case Json.Decode.decodeString (decoder.jsonDecoder context) "\"./banner.jpg\"" of
                                Ok actions ->
                                    decoder.actions actions
                                        |> List.map (Json.Encode.encode 0 << .args)
                                        |> Expect.equal  ["{\"paths\":{\"copyFromBase\":\"/recipes/content.md\",\"copyFromPath\":\"banner.jpg\",\"copyToPath\":\"../static/image-gen/recipes\",\"fileName\":\"banner-300.jpg\"},\"manipulations\":[{\"function\":\"width\",\"args\":300}]}","{\"paths\":{\"copyFromBase\":\"/recipes/content.md\",\"copyFromPath\":\"banner.jpg\",\"copyToPath\":\"../static/image-gen/recipes\",\"fileName\":\"banner-600.jpg\"},\"manipulations\":[{\"function\":\"width\",\"args\":600}]}","{\"paths\":{\"copyFromBase\":\"/recipes/content.md\",\"copyFromPath\":\"banner.jpg\",\"copyToPath\":\"../static/image-gen/recipes\",\"fileName\":\"banner-1200.jpg\"},\"manipulations\":[{\"function\":\"width\",\"args\":1200}]}"]

                                Err err ->
                                    Expect.fail (Json.Decode.errorToString err)
                        )
                )
            ]
        ]
