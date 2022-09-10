module Main exposing (main)

import Browser
import Content
import Content.About
import Content.Index
import Html
import Parser
import SyntaxHighlight
import Html.Events
import Html.Attributes as Attr


type Msg
    = ChangedPage Content.Page


type alias Model =
    { page : Content.Page }


initialModel : Model
initialModel =
    { page = Content.HomePage }


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
                [ Attr.class "w-full flex gap-4 justify-items-stretch" ]
                [ Html.button
                    [ Attr.class "grow-1 w-full bg-amber-500 hover:bg-amber-600 text-stone-900 rounded py-2 px-4 text-amber-900 leading-none"
                    , Html.Events.onClick (ChangedPage Content.HomePage)
                    ]
                    [ Html.text "Home" ]
                , Html.button
                    [ Attr.class "grow-1 w-full bg-amber-500 hover:bg-amber-600 text-stone-900 rounded py-2 px-4 text-amber-900 leading-none"
                    , Html.Events.onClick (ChangedPage Content.AboutPage)
                    ]
                    [ Html.text "About" ]
                ]
            , case model.page of
                Content.HomePage ->
                    Html.div
                        [ Attr.class "mt-6" ]
                        [ Html.h1
                            [ Attr.class "text-lg font-semibold" ]
                            [ Html.text Content.Index.content.title ]
                        , Html.text Content.Index.content.body
                        ]

                Content.AboutPage ->
                    Html.div
                        [ Attr.class "mt-6" ]
                        [ Html.h1
                            [ Attr.class "text-lg font-semibold" ]
                            [ Html.text Content.About.content.title ]
                        , Html.text Content.About.content.body
                        ]
            ]
        , Html.div
            [ Attr.class "min-w-0 md:min-w-[300px] overflow-auto" ]
            [ codeBlock "content/ structure" SyntaxHighlight.elm """content/
        about.md
        index.md"""
            , codeBlock "Content.elm contents" SyntaxHighlight.elm """module Content exposing (decoder, Page(..))

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
                , expression = \\page ->
                    case page of
                        HomePage ->
                            Elm.Syntax.Expression.FunctionOrValue [ "Content" ] "HomePage"

                        AboutPage ->
                            Elm.Syntax.Expression.FunctionOrValue [ "Content" ] "AboutPage"
                }

    in
    Decode.fromSyntax pageSyntax (always [])
        (\\_ ->
            Json.Decode.string
                |> Json.Decode.andThen
                    (\\str ->
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
