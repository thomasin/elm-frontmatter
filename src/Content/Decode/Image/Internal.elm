module Content.Decode.Image.Internal exposing (Manipulation, Manipulations(..), ActionDetails, createActions, encodeActionDetails)


import Json.Encode
import Json.Decode
import Content.Path


type alias Manipulation =
    { function : String
    , args : Json.Encode.Value
    }


type Manipulations
    = Single (List Manipulation)
    | Batch ( String, List Manipulation ) (List ( String, List Manipulation ))


type alias ActionDetails =
    { paths :
        { copyFromBase : String
        , copyFromPath : String
        , copyToPath : String
        , rewritePath : String
        , fileName : String
        , modifierName : String
        }
    , manipulations : List Manipulation
    }


type alias CopyArgs =
    { copyToDirectory : String
    , publicDirectory : String
    }


createActions : { pathSep : String, inputFilePath : String } -> CopyArgs -> Manipulations -> String -> Json.Decode.Decoder ( ActionDetails, List ActionDetails )
createActions args copyArgs manipulations originalSrc =
    case Result.map2 Tuple.pair (Content.Path.parse originalSrc) (Content.Path.parse args.inputFilePath) of
        Ok ( originalImagePath, inputFilePath ) ->
            Json.Decode.succeed
                (createActionDetails copyArgs manipulations originalImagePath inputFilePath)

        Err err ->
            Json.Decode.fail err


createActionDetails : CopyArgs -> Manipulations -> Content.Path.Path -> Content.Path.Path -> ( ActionDetails, List ActionDetails )
createActionDetails copyArgs manipulations originalImagePath inputFilePath =
    case manipulations of
        {-
        We need to produce three things here - the original image location, the new image location, and the src reference for that location
        -}
        Single manipulationChain ->
            ( { paths =
                { copyFromBase = Content.Path.format inputFilePath -- e.g. about/people/[person1]/content.md
                , copyFromPath = Content.Path.format originalImagePath -- e.g. ../banner.jpeg
                , copyToPath = Content.Path.join [ copyArgs.copyToDirectory, inputFilePath.dir ]  -- e.g. ../../images/about/people/[person1]/
                , rewritePath = Content.Path.join [ copyArgs.publicDirectory, inputFilePath.dir ] -- e.g. /images/about/people/[person1]/
                , fileName = originalImagePath.base  -- e.g. banner.jpeg
                , modifierName = ""
                }
              , manipulations = manipulationChain
              }
            , []
            )

        Batch firstManipulationChain manipulationChainList ->
            let
                actionDetails : ( String, List Manipulation ) -> ActionDetails
                actionDetails ( modifierName, manipulationChain ) =
                    { paths =
                        { copyFromBase = Content.Path.format inputFilePath -- e.g. about/people/[person1]/content.md
                        , copyFromPath = Content.Path.format originalImagePath -- e.g. ../banner.jpeg
                        , copyToPath = Content.Path.join [ copyArgs.copyToDirectory, inputFilePath.dir ] -- e.g. ../../images/about/people/[person1]/
                        , rewritePath = Content.Path.join [ copyArgs.publicDirectory, inputFilePath.dir ] -- e.g. /images/about/people/[person1]/
                        , fileName = originalImagePath.name ++ "-" ++ modifierName ++ originalImagePath.ext -- e.g. banner-150w.jpeg
                        , modifierName = modifierName
                        }
                    , manipulations = manipulationChain
                    }
            in
            ( actionDetails firstManipulationChain
            , List.map actionDetails manipulationChainList
            )


encodeActionDetails : ActionDetails -> Json.Encode.Value
encodeActionDetails imageArgs =
    Json.Encode.object
        [ ( "paths"
          , Json.Encode.object
            [ ( "copyFromBase", Json.Encode.string imageArgs.paths.copyFromBase )
            , ( "copyFromPath", Json.Encode.string imageArgs.paths.copyFromPath )
            , ( "copyToPath", Json.Encode.string imageArgs.paths.copyToPath )
            , ( "fileName", Json.Encode.string imageArgs.paths.fileName )
            ]
          )
        , ( "manipulations"
          , Json.Encode.list
                (\manipulation -> Json.Encode.object
                    [ ( "function", Json.Encode.string manipulation.function )
                    , ( "args", manipulation.args )
                    ]
                ) imageArgs.manipulations
          )
        ]
