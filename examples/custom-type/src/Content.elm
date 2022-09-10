module Content exposing (decoder, Page(..))

import Content.Decode as Decode
import Content.Decode.Syntax as Syntax
import Content.Type as Type
import Elm.Syntax.Expression
import Elm.Syntax.TypeAnnotation
import Json.Decode


type Page
    = HomePage
    | AboutPage


pageDecoder : Decode.Decoder Page
pageDecoder =
    let
        pageSyntax : Syntax.Syntax context Page
        pageSyntax =
            Syntax.noContext
                { typeAnnotation =
                    Elm.Syntax.TypeAnnotation.Typed (Syntax.node ( [ "Content" ], "Page" )) []
                , imports =
                    [ { moduleName = Syntax.node [ "Content" ]
                      , moduleAlias = Nothing
                      , exposingList = Nothing
                      }
                    ]
                , expression = \page ->
                    case page of
                        HomePage ->
                            Elm.Syntax.Expression.FunctionOrValue [ "Content" ] "HomePage"

                        AboutPage ->
                            Elm.Syntax.Expression.FunctionOrValue [ "Content" ] "AboutPage"
                }

    in
    Decode.fromSyntax pageSyntax (always [])
        (\_ ->
            Json.Decode.string
                |> Json.Decode.andThen
                    (\str ->
                        case String.toLower str of
                            "home" ->
                                Json.Decode.succeed HomePage

                            "about" ->
                                Json.Decode.succeed AboutPage

                            _ ->
                                Json.Decode.fail ("Don't recognise page: " ++ str)
                    )
        )


decoder : Type.Path -> Decode.QueryResult
decoder typePath =
    case typePath of
        Type.Single [ "Content", "Index" ] ->
            Decode.frontmatter Decode.string
                [ Decode.attribute "title" Decode.string
                , Decode.attribute "current-page" pageDecoder
                ]

        Type.Single [ "Content", "About" ] ->
            Decode.frontmatter Decode.string
                [ Decode.attribute "title" Decode.string
                , Decode.attribute "current-page" pageDecoder
                ]

        _ ->
            Decode.throw

