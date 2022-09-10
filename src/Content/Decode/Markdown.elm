module Content.Decode.Markdown exposing (decode)

{-|
Decode a field into a `List Markdown.Block.Block` from the [dillonkearns/elm-markdown](https://package.elm-lang.org/packages/dillonkearns/elm-markdown/latest/) package.

This lets you do some pretty cool things! To render the Markdown blocks into HTML, see [Markdown.Renderer](https://package.elm-lang.org/packages/dillonkearns/elm-markdown/latest/Markdown-Renderer)

@docs decode
-}

import Content.Decode.Internal
import Content.Decode.Syntax
import Content.Internal

import Elm.Syntax.TypeAnnotation
import Elm.Syntax.Expression
import Elm.Syntax.Node

import Json.Decode
import Json.Decode.Extra

import Markdown.Block
import Markdown.Html
import Markdown.Parser


-- I am just not sure if this is helpful, getting a list of blocks doesn't
-- guarantee that they will be able to be rendered, so you still have to handle a Result
-- at runtime.


node = Content.Internal.node


{-|
```elm
decoder : Content.Type.Path -> Content.Decode.QueryResult
decoder typePath =
    case typePath of
        Content.Type.Single [ "Content", "Index" ] ->
            Content.Decode.frontmatter Content.Decode.Markdown.decode
                [ Content.Decode.attribute "title" Content.Decode.string
                , Content.Decode.attribute "description" Content.Decode.string
                ]

        _ ->
            Content.Decode.throw
```
-}
decode : Content.Decode.Internal.Decoder (List Markdown.Block.Block)
decode =
    Content.Decode.Internal.Decoder
        { typeAnnotation =
            \_ ->
                Elm.Syntax.TypeAnnotation.Typed (node ( [], "List" ))
                    [ node (Elm.Syntax.TypeAnnotation.Typed (node ( [ "Markdown", "Block" ], "Block" )) []) ]
        , imports =
            \_ ->
                [ { moduleName = node [ "Markdown", "Block" ]
                  , moduleAlias = Nothing
                  , exposingList = Nothing
                  }
                ]
        , jsonDecoder = \_ ->
            Json.Decode.string
                |> Json.Decode.andThen (\str ->
                    Markdown.Parser.parse str
                        |> Result.mapError (String.join "\n" << List.map Markdown.Parser.deadEndToString)
                        |> Json.Decode.Extra.fromResult
                )
        , asExpression = \_ blocks ->
                Elm.Syntax.Expression.ListExpr
                    (List.map (node << mapBlock) blocks)
        , actions = always []
        }



mapBlock : Markdown.Block.Block -> Elm.Syntax.Expression.Expression
mapBlock block =
    case block of
        Markdown.Block.HtmlBlock html ->
            Elm.Syntax.Expression.Application
                [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "HtmlBlock")
                , node (Elm.Syntax.Expression.ParenthesizedExpression
                    (node (mapHtml html)))
                ]

        Markdown.Block.UnorderedList listSpacing listOfListItems ->
            let
                listSpacingSyntax : Elm.Syntax.Expression.Expression
                listSpacingSyntax =
                    case listSpacing of
                        Markdown.Block.Loose ->
                            Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "Loose"

                        Markdown.Block.Tight ->
                            Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "Tight"

                taskSyntax : Markdown.Block.Task -> Elm.Syntax.Expression.Expression
                taskSyntax task =
                    case task of
                        Markdown.Block.NoTask ->
                             Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "NoTask"

                        Markdown.Block.IncompleteTask ->
                             Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "IncompleteTask"

                        Markdown.Block.CompletedTask ->
                             Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "CompletedTask"

                listItemSyntax : Markdown.Block.ListItem Markdown.Block.Block -> Elm.Syntax.Expression.Expression
                listItemSyntax (Markdown.Block.ListItem task items) =
                    Elm.Syntax.Expression.Application
                        [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "ListItem")
                        , node (taskSyntax task)
                        , node (Elm.Syntax.Expression.ListExpr (List.map (node << mapBlock) items))
                        ]
            in
            Elm.Syntax.Expression.Application
                [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "UnorderedList")
                , node listSpacingSyntax
                , node (Elm.Syntax.Expression.ListExpr (List.map (node << listItemSyntax) listOfListItems))
                ]

        Markdown.Block.OrderedList listSpacing startingIndex listOfListItems ->
            let
                startingIndexSyntax : Elm.Syntax.Expression.Expression
                startingIndexSyntax =
                    Elm.Syntax.Expression.Integer startingIndex

                listSpacingSyntax : Elm.Syntax.Expression.Expression
                listSpacingSyntax =
                    case listSpacing of
                        Markdown.Block.Loose ->
                            Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "Loose"

                        Markdown.Block.Tight ->
                            Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "Tight"

            in
            Elm.Syntax.Expression.Application
                [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "OrderedList")
                , node listSpacingSyntax
                , node startingIndexSyntax
                , node (Elm.Syntax.Expression.ListExpr (List.map (\listItems ->
                    node (Elm.Syntax.Expression.ListExpr (List.map (node << mapBlock) listItems))
                  ) listOfListItems))
                ]

        Markdown.Block.BlockQuote blocks ->
            Elm.Syntax.Expression.Application
                [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "BlockQuote")
                , node (Elm.Syntax.Expression.ListExpr (List.map (node << mapBlock) blocks))
                ]

        Markdown.Block.Heading headingLevel inlines ->
            Elm.Syntax.Expression.Application
                [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "Heading")
                , node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ]
                    ("H" ++ String.fromInt (Markdown.Block.headingLevelToInt headingLevel)))
                , node (Elm.Syntax.Expression.ListExpr (List.map (node << mapInline) inlines))
                ]

        Markdown.Block.Paragraph inlines ->
            Elm.Syntax.Expression.Application
                [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "Paragraph")
                , node (Elm.Syntax.Expression.ListExpr (List.map (node << mapInline) inlines))
                ]

        Markdown.Block.Table headerDetails listOfListOfInlines ->
            let
                headerDetailsSyntax : { label : List Markdown.Block.Inline, alignment : Maybe Markdown.Block.Alignment } -> Elm.Syntax.Expression.Expression
                headerDetailsSyntax details =
                    Elm.Syntax.Expression.RecordExpr
                        [ node ( node "label", node
                            (Elm.Syntax.Expression.ListExpr (List.map (node << mapInline) details.label) ))
                        , node ( node "alignment", node
                            ( case details.alignment of
                                Just Markdown.Block.AlignLeft ->
                                    Elm.Syntax.Expression.Application
                                        [ node (Elm.Syntax.Expression.FunctionOrValue [] "Just")
                                        , node (Elm.Syntax.Expression.Literal "AlignLeft")
                                        ]

                                Just Markdown.Block.AlignRight ->
                                    Elm.Syntax.Expression.Application
                                        [ node (Elm.Syntax.Expression.FunctionOrValue [] "Just")
                                        , node (Elm.Syntax.Expression.Literal "AlignRight")
                                        ]

                                Just Markdown.Block.AlignCenter ->
                                    Elm.Syntax.Expression.Application
                                        [ node (Elm.Syntax.Expression.FunctionOrValue [] "Just")
                                        , node (Elm.Syntax.Expression.Literal "AlignCenter")
                                        ]

                                Nothing ->
                                    Elm.Syntax.Expression.FunctionOrValue [] "Nothing"
                            )
                          )
                        ]

            in
            Elm.Syntax.Expression.Application
                [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "Table")
                , node (Elm.Syntax.Expression.ListExpr (List.map (node << headerDetailsSyntax) headerDetails))
                , node (Elm.Syntax.Expression.ListExpr (List.map (\listOfInlines ->
                    node (Elm.Syntax.Expression.ListExpr (List.map (\inlines ->
                        node (Elm.Syntax.Expression.ListExpr (List.map (node << mapInline) inlines))
                    ) listOfInlines))
                  ) listOfListOfInlines))
                ]

        Markdown.Block.CodeBlock details ->
            let
                languageSyntax : Elm.Syntax.Expression.Expression
                languageSyntax =
                    case details.language of
                        Just language ->
                            Elm.Syntax.Expression.Application
                                [ node (Elm.Syntax.Expression.FunctionOrValue [] "Just")
                                , node (Elm.Syntax.Expression.Literal (Content.Decode.Internal.escapedString language))
                                ]

                        Nothing ->
                            Elm.Syntax.Expression.FunctionOrValue [] "Nothing"

            in
            Elm.Syntax.Expression.Application
                [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "CodeBlock")
                , node
                    ( Elm.Syntax.Expression.RecordExpr
                        [ node ( node "body", node (Elm.Syntax.Expression.Literal (Content.Decode.Internal.escapedString details.body)) )
                        , node ( node "language", node languageSyntax )
                        ]
                    )
                ]

        Markdown.Block.ThematicBreak ->
            Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "ThematicBreak"



mapInline : Markdown.Block.Inline -> Elm.Syntax.Expression.Expression
mapInline inline =
    case inline of
        Markdown.Block.HtmlInline html ->
            Elm.Syntax.Expression.Application
                [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "HtmlInline")
                , node (Elm.Syntax.Expression.ParenthesizedExpression
                    (node (mapHtml html)))
                ]

        Markdown.Block.Link destination maybeTitle inlines ->
            let
                titleSyntax : Elm.Syntax.Expression.Expression
                titleSyntax =
                    case maybeTitle of
                        Just title ->
                            Elm.Syntax.Expression.ParenthesizedExpression
                                ( node
                                    ( Elm.Syntax.Expression.Application
                                        [ node (Elm.Syntax.Expression.FunctionOrValue [] "Just")
                                        , node (Elm.Syntax.Expression.Literal (Content.Decode.Internal.escapedString title))
                                        ]
                                    )
                                )

                        Nothing ->
                            Elm.Syntax.Expression.FunctionOrValue [] "Nothing"

            in
            Elm.Syntax.Expression.Application
                [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "Link")
                , node (Elm.Syntax.Expression.Literal (Content.Decode.Internal.escapedString destination))
                , node titleSyntax
                , node (Elm.Syntax.Expression.ListExpr (List.map (node << mapInline) inlines))
                ]

        Markdown.Block.Image src maybeTitle inlines ->
            let
                titleSyntax : Elm.Syntax.Expression.Expression
                titleSyntax =
                    case maybeTitle of
                        Just title ->
                            Elm.Syntax.Expression.ParenthesizedExpression
                                ( node
                                    ( Elm.Syntax.Expression.Application
                                        [ node (Elm.Syntax.Expression.FunctionOrValue [] "Just")
                                        , node (Elm.Syntax.Expression.Literal (Content.Decode.Internal.escapedString title))
                                        ]
                                    )
                                )

                        Nothing ->
                            Elm.Syntax.Expression.FunctionOrValue [] "Nothing"

            in
            Elm.Syntax.Expression.Application
                [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "Image")
                , node (Elm.Syntax.Expression.Literal (Content.Decode.Internal.escapedString src))
                , node titleSyntax
                , node (Elm.Syntax.Expression.ListExpr (List.map (node << mapInline) inlines))
                ]


        Markdown.Block.Emphasis inlines ->
            Elm.Syntax.Expression.Application
                [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "Emphasis")
                , node (Elm.Syntax.Expression.ListExpr (List.map (node << mapInline) inlines))
                ]

        Markdown.Block.Strong inlines ->
            Elm.Syntax.Expression.Application
                [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "Strong")
                , node (Elm.Syntax.Expression.ListExpr (List.map (node << mapInline) inlines))
                ]

        Markdown.Block.Strikethrough inlines ->
            Elm.Syntax.Expression.Application
                [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "Strikethrough")
                , node (Elm.Syntax.Expression.ListExpr (List.map (node << mapInline) inlines))
                ]

        Markdown.Block.CodeSpan str ->
            Elm.Syntax.Expression.Application
                [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "CodeSpan")
                , node (Elm.Syntax.Expression.Literal (Content.Decode.Internal.escapedString str))
                ]

        Markdown.Block.Text str ->
            Elm.Syntax.Expression.Application
                [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "Text")
                , node (Elm.Syntax.Expression.Literal (Content.Decode.Internal.escapedString str))
                ]

        Markdown.Block.HardLineBreak ->
            Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "HardLineBreak"



mapHtml : Markdown.Block.Html Markdown.Block.Block -> Elm.Syntax.Expression.Expression
mapHtml html =
    case html of
        Markdown.Block.HtmlElement tag htmlAttributes blocks ->
            let
                htmlAttributeSyntax : Markdown.Block.HtmlAttribute -> Elm.Syntax.Expression.Expression
                htmlAttributeSyntax htmlAttribute =
                    Elm.Syntax.Expression.RecordExpr
                        [ node ( node "name", node (Elm.Syntax.Expression.Literal (Content.Decode.Internal.escapedString htmlAttribute.name)) )
                        , node ( node "value", node (Elm.Syntax.Expression.Literal (Content.Decode.Internal.escapedString htmlAttribute.value)) )
                        ]

            in
            Elm.Syntax.Expression.Application
                [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "HtmlElement")
                , node (Elm.Syntax.Expression.Literal (Content.Decode.Internal.escapedString tag))
                , node (Elm.Syntax.Expression.ListExpr (List.map (node << htmlAttributeSyntax) htmlAttributes))
                , node (Elm.Syntax.Expression.ListExpr (List.map (node << mapBlock) blocks))
                ]


        Markdown.Block.HtmlComment str ->
            Elm.Syntax.Expression.Application
                [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "HtmlComment")
                , node (Elm.Syntax.Expression.Literal (Content.Decode.Internal.escapedString str))
                ]

        Markdown.Block.ProcessingInstruction str ->
            Elm.Syntax.Expression.Application
                [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "ProcessingInstruction")
                , node (Elm.Syntax.Expression.Literal (Content.Decode.Internal.escapedString str))
                ]

        Markdown.Block.HtmlDeclaration str1 str2 ->
            Elm.Syntax.Expression.Application
                [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "HtmlDeclaration")
                , node (Elm.Syntax.Expression.Literal (Content.Decode.Internal.escapedString str1))
                , node (Elm.Syntax.Expression.Literal (Content.Decode.Internal.escapedString str2))
                ]

        Markdown.Block.Cdata str ->
            Elm.Syntax.Expression.Application
                [ node (Elm.Syntax.Expression.FunctionOrValue [ "Markdown", "Block" ] "Cdata")
                , node (Elm.Syntax.Expression.Literal (Content.Decode.Internal.escapedString str))
                ]