module Content exposing (decoder)

import Content.Decode as Decode
import Content.Decode.Markdown as Markdown
import Content.Decode.Syntax as Syntax
import Content.Type as Type
import Json.Decode
import Slug


slugDecoder : Decode.Decoder String
slugDecoder =
    Decode.fromSyntax Syntax.string
        (\_ ->
            Json.Decode.string
                |> Json.Decode.andThen
                    (\str ->
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
