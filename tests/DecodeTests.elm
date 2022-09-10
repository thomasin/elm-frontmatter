module DecodeTests exposing (suite)

import Content.Decode as Decode
import Content.Decode.Internal
import Content.Type
import Elm.Syntax.Node
import Elm.Syntax.Range
import Elm.Syntax.Expression
import Elm.Syntax.TypeAnnotation
import Elm.Writer
import Expect
import Path
import Path.Platform
import Elm.Syntax.ModuleName
import Test exposing (Test, describe, test)
import Time
import Utils


suite : Test.Test
suite =
    Test.describe "decoders"
        [ Test.describe "reference"
            [ Test.test "to same module 1"
                (\() ->        
                    Utils.testDecoder "/recipes/content.md" (Just [ "Content", "Recipes" ]) (Decode.reference (Content.Type.Single [ "Content", "Recipes" ]))
                        (\context decoder ->
                            decoder.typeAnnotation context
                                |> Utils.writeTypeAnnotation
                                |> Expect.equal """Content"""
                        )
                )
            , Test.test "to same module 2"
                (\() ->
                    Utils.testDecoder "/recipes/content.md" (Just [ "Content", "Recipes" ]) (Decode.reference (Content.Type.Single [ "Content", "Recipes" ]))
                        (\context decoder ->
                            decoder.typeAnnotation context
                                |> Utils.writeTypeAnnotation
                                |> Expect.equal """Content"""
                        )
                )
            , Test.test "to same module 3"
                (\() ->
                    Utils.testDecoder "/recipes/[first-recipe].md" (Just [ "Content", "Recipes" ]) (Decode.reference (Content.Type.Collection [ "Content", "Recipes" ]))
                        (\context decoder ->
                            decoder.typeAnnotation context
                                |> Utils.writeTypeAnnotation
                                |> Expect.equal """CollectionItem"""
                        )
                )
            , Test.test "to different module 1"
                (\() ->
                    Utils.testDecoder "/recipes.md" (Just [ "Content", "Recipes" ]) (Decode.reference (Content.Type.Single [ "Content", "Recipes", "Pikelets" ]))
                        (\context decoder ->
                            decoder.typeAnnotation context
                                |> Utils.writeTypeAnnotation
                                |> Expect.equal """Content.Recipes.Pikelets.Content"""
                        )
                )
            , Test.test "to different module 2"
                (\() ->
                    Utils.testDecoder "/recipes.md" (Just [ "Content", "Recipes" ]) (Decode.reference (Content.Type.Collection [ "Content", "Recipes", "Pikelets" ]))
                        (\context decoder ->
                            decoder.typeAnnotation context
                                |> Utils.writeTypeAnnotation
                                |> Expect.equal """Content.Recipes.Pikelets.CollectionItem"""
                        )
                )
            ]
        ]
