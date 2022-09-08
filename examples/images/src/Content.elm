module Content exposing (decoder)

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
