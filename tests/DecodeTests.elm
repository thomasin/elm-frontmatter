module DecodeTests exposing (suite)

import Content.Decode as Decode
import Content.Type
import Expect
import Test
import Utils


suite : Test.Test
suite =
    Test.describe "decoders"
        [ Test.describe "reference"
            [ Test.test "to same module 1"
                (\() ->
                    Utils.testDecoder "/recipes/content.md"
                        (Just [ "Content", "Recipes" ])
                        (Decode.reference (Content.Type.Single [ "Content", "Recipes" ]))
                        (\context decoder ->
                            decoder.typeAnnotation context
                                |> Utils.writeTypeAnnotation
                                |> Expect.equal """Content"""
                        )
                )
            , Test.test "to same module 2"
                (\() ->
                    Utils.testDecoder "/recipes/content.md"
                        (Just [ "Content", "Recipes" ])
                        (Decode.reference (Content.Type.Single [ "Content", "Recipes" ]))
                        (\context decoder ->
                            decoder.typeAnnotation context
                                |> Utils.writeTypeAnnotation
                                |> Expect.equal """Content"""
                        )
                )
            , Test.test "to same module 3"
                (\() ->
                    Utils.testDecoder "/recipes/[first-recipe].md"
                        (Just [ "Content", "Recipes" ])
                        (Decode.reference (Content.Type.Collection [ "Content", "Recipes" ]))
                        (\context decoder ->
                            decoder.typeAnnotation context
                                |> Utils.writeTypeAnnotation
                                |> Expect.equal """CollectionItem"""
                        )
                )
            , Test.test "to different module 1"
                (\() ->
                    Utils.testDecoder "/recipes.md"
                        (Just [ "Content", "Recipes" ])
                        (Decode.reference (Content.Type.Single [ "Content", "Recipes", "Pikelets" ]))
                        (\context decoder ->
                            decoder.typeAnnotation context
                                |> Utils.writeTypeAnnotation
                                |> Expect.equal """Content.Recipes.Pikelets.Content"""
                        )
                )
            , Test.test "to different module 2"
                (\() ->
                    Utils.testDecoder "/recipes.md"
                        (Just [ "Content", "Recipes" ])
                        (Decode.reference (Content.Type.Collection [ "Content", "Recipes", "Pikelets" ]))
                        (\context decoder ->
                            decoder.typeAnnotation context
                                |> Utils.writeTypeAnnotation
                                |> Expect.equal """Content.Recipes.Pikelets.CollectionItem"""
                        )
                )
            ]
        ]
