module Content.Decode.Image exposing (Decoder, ActionDetails, CopyArgs, Manipulation, process, batchProcess, width)

{-|

@docs Decoder, CopyArgs, Manipulation, ActionDetails, process, batchProcess, width

-}

import Content.Decode
import Content.Decode.Image.Internal
import Content.Decode.Internal
import Content.Decode.Syntax
import Path
import Json.Decode
import Json.Encode


{-| Image processing configuration

    imageCopyArgs : Content.Decode.Image.CopyArgs
    imageCopyArgs =
        { copyToDirectory = "../static/image-gen/"
        , publicDirectory = "/image-gen/"
        }

will copy images to the `../static/image-gen/` folder, relative to
the local `package.json`. Image URLs will be written with the public
directory as the root i.e. `/image-gen/banner.jpg`

-}
type alias CopyArgs =
    { copyToDirectory : String
    , publicDirectory : String
    }


{-| An image decoder
-}
type alias Decoder =
    Content.Decode.Decoder ( ActionDetails, List ActionDetails )


{-| An image manipulation
-}
type alias Manipulation =
    Content.Decode.Image.Internal.Manipulation


{-| Image action details
-}
type alias ActionDetails =
    Content.Decode.Image.Internal.ActionDetails


{-| Copy and modify an image


    imageCopyArgs : Content.Decode.Image.CopyArgs
    imageCopyArgs =
        { copyToDirectory = "../static/image-gen/"
        , publicDirectory = "/image-gen/"
        }

    decoder : Content.Type.Path -> Content.Decode.QueryResult
    decoder typePath =
        case typePath of
            Content.Type.Single [ "Content", "About" ] ->
                Content.Decode.decode
                    [ Content.Decode.attribute "title" Content.Decode.string
                    , Content.Decode.attribute "banner"
                        (Content.Decode.Image.process imageCopyArgs [ Content.Decode.Image.width 1600 ])
                    ]

            _ ->
                Content.Decode.ignore

    {- =>
       type alias Content =
           { title : String
           , banner : String
           }


       content : Content
       content =
           { title = "About"
           , banner = "/image-gen/banner.jpeg"
           }
    -}

-}
process : CopyArgs -> List Manipulation -> Decoder
process copyArgs manipulations =
    Content.Decode.Internal.Decoder
        { typeAnnotation = Content.Decode.Syntax.string.typeAnnotation
        , imports = always []
        , jsonDecoder =
            \context ->
                Json.Decode.string
                    |> Json.Decode.andThen (Content.Decode.Image.Internal.createActions context copyArgs (Content.Decode.Image.Internal.Single manipulations))
        , asExpression =
            \context ( (Content.Decode.Image.Internal.ActionDetails firstActionDetails), _ ) ->
                Content.Decode.Syntax.string.expression context
                    (Path.toString firstActionDetails.paths.rewritePath ++ Path.separator firstActionDetails.paths.rewritePath ++ firstActionDetails.paths.fileName)
        , actions =
            \( firstActionDetails, _ ) ->
                [ { with = "image"
                  , args = Content.Decode.Image.Internal.encodeActionDetails firstActionDetails
                  }
                ]
        }


{-| Make multiple copies of one image.


    imageCopyArgs : Content.Decode.Image.CopyArgs
    imageCopyArgs =
        { copyToDirectory = "../static/image-gen/"
        , publicDirectory = "/image-gen/"
        }

    decoder : Content.Type.Path -> Content.Decode.QueryResult
    decoder typePath =
        case typePath of
            Content.Type.Collection [ "Content", "About", "People" ] ->
                Content.Decode.decodeWithoutBody
                    [ Content.Decode.attribute "name" Content.Decode.string
                    , Content.Decode.attribute "position" Content.Decode.string
                    , Content.Decode.attribute "thumbnail"
                        (Content.Decode.Image.batchProcess imageCopyArgs
                            ( "300", [ Content.Decode.Image.width 300 ] )
                            [ ( "600", [ Content.Decode.Image.width 600 ] )
                            , ( "1200", [ Content.Decode.Image.width 1200 ] )
                            ]
                        )
                    ]

            _ ->
                Content.Decode.ignore

    {-
       type alias CollectionItem =
           { name : String
           , position : String
           , thumbnail : ( ( String, String ), List ( String, String ) )
           }

       person1 : CollectionItem
       person1 =
           { name = "Person 1", position = "Astronaut"
           , thumbnail =
               ( ( "300", "/image-gen/about/people/[person1]/banner-300.jpeg" )
               , [ ( "600", "/image-gen/about/people/[person1]/banner-600.jpeg" )
                 , ( "1200", "/image-gen/about/people/[person1]/banner-1200.jpeg" )
                 ]
               )
           }
    -}

-}
batchProcess : CopyArgs -> ( String, List Manipulation ) -> List ( String, List Manipulation ) -> Decoder
batchProcess copyArgs firstManipulation manipulations =
    let
        syntax : Content.Decode.Syntax.Syntax { inputFilePath : Path.Path } ( ( String, String ), List ( String, String ) )
        syntax =
            Content.Decode.Syntax.tuple2
                ( Content.Decode.Syntax.tuple2 ( Content.Decode.Syntax.string, Content.Decode.Syntax.string )
                , Content.Decode.Syntax.list
                    (Content.Decode.Syntax.tuple2 ( Content.Decode.Syntax.string, Content.Decode.Syntax.string ))
                )
    in
    Content.Decode.Internal.Decoder
        { typeAnnotation = syntax.typeAnnotation
        , imports = always []
        , jsonDecoder =
            \context ->
                Json.Decode.string
                    |> Json.Decode.andThen (Content.Decode.Image.Internal.createActions context copyArgs (Content.Decode.Image.Internal.Batch firstManipulation manipulations))
        , asExpression =
            \context ( (Content.Decode.Image.Internal.ActionDetails firstActionDetails), restActionDetails ) ->
                syntax.expression context
                    ( ( firstActionDetails.paths.modifierName
                      , Path.toString firstActionDetails.paths.rewritePath ++ Path.separator firstActionDetails.paths.rewritePath ++ firstActionDetails.paths.fileName
                      )
                    , List.map
                        (\(Content.Decode.Image.Internal.ActionDetails actionDetails) ->
                            ( actionDetails.paths.modifierName
                            , Path.toString actionDetails.paths.rewritePath ++ Path.separator actionDetails.paths.rewritePath ++ actionDetails.paths.fileName
                            )
                        )
                        restActionDetails
                    )
        , actions =
            \( firstActionDetails, restActionDetails ) ->
                List.map
                    (\actionDetails ->
                        { with = "image"
                        , args = Content.Decode.Image.Internal.encodeActionDetails actionDetails
                        }
                    )
                    (firstActionDetails :: restActionDetails)
        }


{-| Resize the generated image to a specified width.
The image will evenly scale.
-}
width : Int -> Manipulation
width resizeToWidth =
    { function = "width"
    , args = Json.Encode.int resizeToWidth
    }
