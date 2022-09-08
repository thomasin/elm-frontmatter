module Content.Decode.Image.Internal exposing (ActionDetails(..), Manipulation, Manipulations(..), createActions, encodeActionDetails)

import Json.Decode
import Json.Encode
import Path


type alias Manipulation =
    { function : String
    , args : Json.Encode.Value
    }


type Manipulations
    = Single (List Manipulation)
    | Batch ( String, List Manipulation ) (List ( String, List Manipulation ))


type ActionDetails =
    ActionDetails
        { paths :
            { copyFromBase : Path.Path
            , copyFromPath : Path.Path
            , copyToPath : Path.Path
            , rewritePath : Path.Path
            , fileName : String
            , modifierName : String
            }
        , manipulations : List Manipulation
        }


type alias CopyArgs =
    { copyToDirectory : String
    , publicDirectory : String
    }


createActions : { inputFilePath : Path.Path } -> CopyArgs -> Manipulations -> String -> Json.Decode.Decoder ( ActionDetails, List ActionDetails )
createActions args copyArgs manipulations originalSrc =
    let
        copyFromPathResult : Result String Path.Path
        copyFromPathResult =
            Path.fromString (Path.platform args.inputFilePath) originalSrc

        copyToPathResult : Result String Path.Path
        copyToPathResult =
            Path.fromList (Path.platform args.inputFilePath) [ copyArgs.copyToDirectory, Path.dir args.inputFilePath ]

        rewritePathResult : Result String Path.Path
        rewritePathResult =
            Path.fromList (Path.platform args.inputFilePath) [ copyArgs.publicDirectory, Path.dir args.inputFilePath ]
    in
    case Result.map3 (\a b c -> ( a, b, c )) copyFromPathResult copyToPathResult rewritePathResult of
        Ok ( copyFromPath, copyToPath, rewritePath ) ->
            Json.Decode.succeed
                (createActionDetails manipulations args.inputFilePath copyFromPath copyToPath rewritePath)

        Err err ->
            Json.Decode.fail err


createActionDetails : Manipulations -> Path.Path -> Path.Path -> Path.Path -> Path.Path -> ( ActionDetails, List ActionDetails )
createActionDetails manipulations inputFilePath copyFromPath copyToPath rewritePath =
    case manipulations of
        {-
           We need to produce three things here - the original image location, the new image location, and the src reference for that location
        -}
        Single manipulationChain ->
            ( ActionDetails
                    { paths =
                        { copyFromBase = inputFilePath -- e.g. about/people/[person1]/content.md
                        , copyFromPath = copyFromPath -- e.g. ../banner.jpeg
                        , copyToPath = copyToPath -- e.g. ../../images/about/people/[person1]/
                        , rewritePath = rewritePath -- e.g. /images/about/people/[person1]/
                        , fileName = Path.base copyFromPath -- e.g. banner.jpeg
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
                    ActionDetails
                        { paths =
                            { copyFromBase = inputFilePath -- e.g. about/people/[person1]/content.md
                            , copyFromPath = copyFromPath -- e.g. ../banner.jpeg
                            , copyToPath = copyToPath -- e.g. ../../images/about/people/[person1]/
                            , rewritePath = rewritePath -- e.g. /images/about/people/[person1]/
                            , fileName = Path.name copyFromPath ++ "-" ++ modifierName ++ Path.ext copyFromPath -- e.g. banner-150w.jpeg
                            , modifierName = modifierName
                            }
                        , manipulations = manipulationChain
                        }
            in
            ( actionDetails firstManipulationChain
            , List.map actionDetails manipulationChainList
            )


encodeActionDetails : ActionDetails -> Json.Encode.Value
encodeActionDetails (ActionDetails imageArgs) =
    Json.Encode.object
        [ ( "paths"
          , Json.Encode.object
                [ ( "copyFromBase", Json.Encode.string (Path.toString imageArgs.paths.copyFromBase) )
                , ( "copyFromPath", Json.Encode.string (Path.toString imageArgs.paths.copyFromPath) )
                , ( "copyToPath", Json.Encode.string (Path.toString imageArgs.paths.copyToPath) )
                , ( "fileName", Json.Encode.string imageArgs.paths.fileName )
                ]
          )
        , ( "manipulations"
          , Json.Encode.list
                (\manipulation ->
                    Json.Encode.object
                        [ ( "function", Json.Encode.string manipulation.function )
                        , ( "args", manipulation.args )
                        ]
                )
                imageArgs.manipulations
          )
        ]
