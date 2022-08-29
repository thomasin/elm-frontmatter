module Main exposing (main)

import Content
import Content.Decode.File
import Content.Function
import Content.Output
import Parser
import Path
import Path.Platform
import Dict
import Json.Decode
import Json.Decode.Extra
import Modules
import Platform
import Set
import Ports


type Msg
    = Add Content.Decode.File.InputFile
    | Problem String
    | EffectsPerformed String
    | NoMoreInputFiles Int


type alias Model =
    { platform : Path.Platform
    , modulesContents : Modules.Contents
    , outputFiles : List { filePath : String, fileContents : String }
    , fileEffectsPerformed : Set.Set String
    }


main =
    Platform.worker
        { init = init
        , update = update
        , subscriptions = subscriptions
        }


init : { pathSep : String } -> ( Model, Cmd Msg )
init flags =
    ( { platform = Path.Platform.fromSeparator flags.pathSep
      , modulesContents = Dict.empty
      , outputFiles = []
      , fileEffectsPerformed = Set.empty
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        EffectsPerformed filePath ->
            ( { model | fileEffectsPerformed = Set.remove filePath model.fileEffectsPerformed }
            , if Set.isEmpty (Set.remove filePath model.fileEffectsPerformed) then
                Ports.writeFiles model.outputFiles

              else
                Cmd.none
            )

        NoMoreInputFiles _ ->
            case Content.Output.sequence (List.map (Content.Decode.File.toFile Content.decoder) (Modules.modulesToList model.modulesContents)) of
                Content.Output.Continue messages allFiles ->
                    ( { model
                      | fileEffectsPerformed = Set.fromList (List.map .filePath allFiles)
                      , outputFiles = List.map (\file -> { filePath = file.filePath, fileContents = file.fileContents }) allFiles
                      }
                    , Cmd.batch
                        [ Ports.show (Content.Output.encodeMessages messages)
                        , Cmd.batch (List.map (\file -> Ports.performEffect { filePath = file.filePath, actions = file.actions }) allFiles)
                        ]
                    )

                Content.Output.Ignore messages ->
                    ( model, Ports.show (Content.Output.encodeMessages messages) )

                Content.Output.Terminate message ->
                    ( model, Ports.terminate message )

        Add inputFile ->
            case Content.Function.fromPath inputFile.filePath of
                Content.Output.Continue messages functionDetails ->
                    ( { model | modulesContents = Modules.newFunction functionDetails inputFile model.modulesContents }
                    , Ports.show (Content.Output.encodeMessages messages)
                    )

                Content.Output.Ignore messages ->
                    ( model
                    , Ports.show (Content.Output.encodeMessages messages)
                    )

                Content.Output.Terminate message ->
                    ( model
                    , Ports.terminate message
                    )

        Problem problem ->
            ( model
            , Ports.terminate problem
            )


addRawFile : Path.Platform -> Json.Decode.Value -> Msg
addRawFile platform jsValue =
    let
        decodeInputFile : Json.Decode.Decoder Content.Decode.File.InputFile
        decodeInputFile =
            Json.Decode.map2 Content.Decode.File.InputFile
                (Json.Decode.field "filePath"
                    (Json.Decode.string
                        |> Json.Decode.andThen
                            (Json.Decode.Extra.fromResult << Path.fromString platform)
                    )
                )
                (Json.Decode.field "fileFrontmatter" Json.Decode.value)

    in  
    case Json.Decode.decodeValue decodeInputFile jsValue of
        Ok newInputFile ->
            Add newInputFile

        Err err ->
            Problem (Json.Decode.errorToString err)


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.add (addRawFile model.platform)
        , Ports.noMoreInputFiles NoMoreInputFiles
        , Ports.effectsPerformed EffectsPerformed
        ]
