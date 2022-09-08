module Main exposing (main)

import Browser
import Content.Index
import Html exposing (Html)
import Html.Attributes as Attr
import Parser
import SyntaxHighlight


type alias Model =
    {}


type Msg
    = NoOp


initialModel : Model
initialModel =
    {}


update : Msg -> Model -> Model
update _ _ =
    {}


view : Model -> Html Msg
view _ =
    Html.div
        [ Attr.class "w-full grid grid-cols-[auto] md:grid-cols-[auto,auto] gap-8 p-8" ]
        [ SyntaxHighlight.useTheme SyntaxHighlight.gitHub
        , Html.div
            [ Attr.class "bg-stone-100 shadow-lg shadow-stone-100 p-8 rounded-lg flex flex-col items-center" ]
            (List.map
                (\animal ->
                    Html.section
                        [ Attr.class "mt-12 first:mt-0 max-w-[500px]" ]
                        [ Html.h2
                            [ Attr.class "text-lg font-semibold" ]
                            [ Html.text animal.name ]
                        , Html.img
                            [ Attr.class "mt-2"
                            , Attr.src animal.photo
                            ]
                            []
                        , Html.a
                            [ Attr.class "text-sm text-blue-700"
                            , Attr.href animal.link
                            ]
                            [ Html.text animal.attribution ]
                        ]
                )
                Content.Index.content.animals
            )
        , Html.div
            [ Attr.class "min-w-0 md:min-w-[300px] overflow-auto" ]
            [ codeBlock "content/ structure" SyntaxHighlight.elm """content/
        index.md
        animals/
            [cheetah]/
                cheetah.jpeg
                content.md
            [mouse]/
                computer_mouse.jpeg
                content.md
            [yellow-eyed-penguin]/
                penguin.jpeg
                content.md"""
            , codeBlock "Content.elm contents" SyntaxHighlight.elm """module Content exposing (decoder)

import Content.Decode as Decode
import Content.Decode.Image as Image
import Content.Type as Type


copyArgs : Image.CopyArgs
copyArgs =
    { copyToDirectory = "./public/images/"
    , publicDirectory = "./public/images/"
    }


decoder : Type.Path -> Decode.QueryResult
decoder typePath =
    case typePath of
        Type.Single [ "Content", "Index" ] ->
            Decode.frontmatterWithoutBody
                [ Decode.attribute "title" Decode.string
                , Decode.attribute "animals" (Decode.list (Decode.reference (Type.Collection [ "Content", "Animals" ])))
                ]

        Type.Collection [ "Content", "Animals" ] ->
            Decode.frontmatterWithoutBody
                [ Decode.attribute "name" Decode.string
                , Decode.attribute "photo" (Image.process copyArgs [ Image.width 500 ])
                , Decode.attribute "attribution" Decode.string
                , Decode.attribute "link" Decode.string
                ]

        _ ->
            Decode.throw
"""
            ]
        ]


codeBlock : String -> (String -> Result (List Parser.DeadEnd) SyntaxHighlight.HCode) -> String -> Html msg
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
                |> Result.withDefault (Html.pre [] [ Html.code [] [ Html.text code ] ])
            ]
        ]


main : Program () Model Msg
main =
    Browser.sandbox
        { init = initialModel
        , view = view
        , update = update
        }
