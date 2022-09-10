module Main exposing (main)

import Browser
import Content
import SyntaxHighlight
import Parser
import Content.Docs
import Markdown.Renderer
import Html exposing (Html, button, a, div)
import Html.Attributes as Attr
import Html.Events exposing (onClick)


type Page
    = GettingStarted
    | Routes
    | Pages


type Msg
    = ChangedPage Page


type alias Model =
    { page : Page }


initialModel : Model
initialModel =
    { page = GettingStarted }


update : Msg -> Model -> Model
update msg model =
    case msg of
        ChangedPage page ->
            { model | page = page }


view : Model -> Html.Html Msg
view model =
    Html.div
        [ Attr.class "w-full grid grid-cols-[auto] md:grid-cols-[auto,auto] gap-8 p-8" ]
        [ SyntaxHighlight.useTheme SyntaxHighlight.gitHub
        , Html.div
            [ Attr.class "min-w-[300px] bg-stone-100 shadow-lg shadow-stone-100 p-8 rounded-lg" ]
            [ Html.nav
                [ Attr.class "flex flex-col gap-1" ]
                ( List.map
                    (\section ->
                        Html.a
                            [ Attr.class "block text-blue-600 hover:text-blue-800"
                            , Attr.href ("#" ++ section.slug)
                            ]
                            [ Html.text section.title
                            ]
                    )
                    Content.Docs.content.sections
                )
            , Html.div
                [ Attr.class "mt-8" ]
                ( List.map
                    (\section ->
                        Html.section
                            [ Attr.class "mt-8" ]
                            [ Html.h2
                                [ Attr.class "text-lg font-semibold" 
                                , Attr.id section.slug
                                ]
                                [ Html.text section.title ]
                            , Html.div
                                [ Attr.class "[&_h3]:text-base [&_h3]:font-semibold" ]
                                ( Markdown.Renderer.render Markdown.Renderer.defaultHtmlRenderer section.body
                                    |> Result.withDefault [ Html.text "Nothing here!" ]
                                )
                            ]
                    )
                    Content.Docs.content.sections
                )
            ]
        , Html.div
            [ Attr.class "min-w-0 md:min-w-[300px] overflow-auto" ]
            [ codeBlock "content/ structure" SyntaxHighlight.elm """content/
        docs.md
        docs/
            [01-getting-started].md
            [02-routes].md
            [03-pages].md"""
            , codeBlock "Content.elm contents" SyntaxHighlight.elm """module Content exposing (decoder)

import Content.Decode as Decode
import Content.Decode.Markdown as Markdown
import Content.Decode.Syntax as Syntax
import Content.Type as Type
import Json.Decode
import Slug


slugDecoder : Decode.Decoder String
slugDecoder =
    Decode.fromSyntax Syntax.string (always [])
        (\\_ ->
            Json.Decode.string
                |> Json.Decode.andThen
                    (\\str ->
                        case Slug.generate str of
                            Just slug ->
                                Json.Decode.succeed (Slug.toString slug)

                            Nothing ->
                                Json.Decode.fail ("Can't generate slug from \"" ++ str ++ "\"")
                    )
        )


decoder : Type.Path -> Decode.QueryResult
decoder typePath =
    case typePath of
        Type.Single [ "Content", "Docs" ] ->
            Decode.frontmatterWithoutBody
                [ Decode.attribute "title" Decode.string
                , Decode.attribute "sections" (Decode.list (Decode.reference (Type.Collection [ "Content", "Docs" ])))
                ]

        Type.Collection [ "Content", "Docs" ] ->
            Decode.frontmatter Markdown.decode
                [ Decode.attribute "title" Decode.string
                , Decode.renameTo "slug" (Decode.attribute "title" slugDecoder)
                ]

        _ ->
            Decode.throw
"""
            ]
        ]


codeBlock : String -> (String -> Result (List Parser.DeadEnd) SyntaxHighlight.HCode) -> String -> Html.Html msg
codeBlock title lang code =
    Html.div
        [ Attr.class "mt-12 first:mt-0" ]
        [ Html.h2
            [ Attr.class "text-lg font-semibold" ]
            [ Html.text title ]
        , Html.div
            [ Attr.class "mt-2 p-8 border border-blue-100 overflow-x-scroll rounded-lg text-sm font-mono" ]
            [ lang code
                |> Result.map (SyntaxHighlight.toBlockHtml Nothing)
                |> Result.mapError (Debug.log "err")
                |> Result.withDefault (Html.pre [] [ Html.code [] [ Html.text code ]])
            ]
        ]


main : Program () Model Msg
main =
    Browser.sandbox
        { init = initialModel
        , view = view
        , update = update
        }
