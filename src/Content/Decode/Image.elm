module Content.Decode.Image exposing
    ( CopyArgs
    , Decoder, ActionDetails, Manipulation, process, batchProcess
    , width
    )

{-| Copy and resize images.
Use [`process`](#process) to process an image once, or [`batchProcess`](#batchProcess) to process an image multiple times with different manipulations applied.

**[Configuration](#configuration)** ⸺
Configure copy and rewrite args

**[Decoders](#decoders)** ⸺
Decode image file paths, process the images and rewrite the file paths

**[Manipulations](#manipulations)** ⸺
Change the image while copying (e.g. resize)


## Configuration

@docs CopyArgs


## Decoders

@docs Decoder, ActionDetails, Manipulation, process, batchProcess


## Manipulations

@docs width

-}

import Content.Decode
import Content.Decode.Image.Internal
import Content.Decode.Internal
import Content.Decode.Syntax
import Json.Decode
import Json.Encode
import Path


{-| Configure where images are copied to, and how their paths are rewritten.
Passed in to the [`process`](#process) and [`batchProcess`](#batchProcess) functions.

    imageCopyArgs : Content.Decode.Image.CopyArgs
    imageCopyArgs =
        { copyToDirectory = "./static/image-gen/"
        , publicDirectory = "/image-gen/"
        }

will copy images to the `./static/image-gen/` folder, relative to
the local `package.json`. Image URLs will be rewritten with the public
directory as the root i.e. `/image-gen/banner.jpg`.

Images will be copied with directory structure intact, i.e.

    .
    └── content
        └── about
        |   ├── banner.jpg --> /static/image-gen/about/banner.jpg
        |   └── content.md --> /Content/About.elm
        └── hero.jpg --> /static/image-gen/hero.jpg

with the above `imageCopyArgs`, would result in

    .
    └── static
        └── image-gen
            └── about
            |   ├── banner.jpg
            └── hero.jpg

-}
type alias CopyArgs =
    { copyToDirectory : String
    , publicDirectory : String
    }


{-| An image decoder. Can be used with any function that accepts a decoder

    Content.Decode.frontmatterWithoutBody
        [ Content.Decode.attribute "photos"
            (Content.Decode.list (Content.Decode.Image.process imageCopyArgs []))
        ]

-}
type alias Decoder =
    Content.Decode.Decoder ( ActionDetails, List ActionDetails )


{-| Image action details. An opaque type returned from the image decoder, used to
define the manipulations to process on the image.
-}
type alias ActionDetails =
    Content.Decode.Image.Internal.ActionDetails


{-| An image manipulation. See [`width`](#width) (the only manipulation we currently have 🤭).
Can be passed into [`process`](#process) or [`batchProcess`](#batchProcess) to be performed on referenced images.
-}
type alias Manipulation =
    Content.Decode.Image.Internal.Manipulation


{-| Copy and modify an image, with possible manipulations applied.
Use `Content.Decode.Image.process imageCopyArgs []` if you just want to copy the image, not apply any manipulations.


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
            \context ( Content.Decode.Image.Internal.ActionDetails firstActionDetails, _ ) ->
                Content.Decode.Syntax.string.expression context
                    (Path.toString firstActionDetails.paths.rewritePath ++ Path.separator firstActionDetails.paths.rewritePath ++ firstActionDetails.paths.fileName)
        , actions =
            \( firstActionDetails, _ ) ->
                [ { with = "image"
                  , args = Content.Decode.Image.Internal.encodeActionDetails firstActionDetails
                  }
                ]
        }


{-| Make multiple copies of one image, with different manipulations applied.


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
        syntax : Content.Decode.Syntax.Syntax Content.Decode.Internal.DecoderContext ( ( String, String ), List ( String, String ) )
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
            \context ( Content.Decode.Image.Internal.ActionDetails firstActionDetails, restActionDetails ) ->
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
