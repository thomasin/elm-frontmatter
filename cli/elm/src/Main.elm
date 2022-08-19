module Main exposing (main)

import Content
import Content.Decode.File
import Content.File
import Content.Internal
import Dict
import Json.Decode
import Platform
import Set
import Ports


type Msg
    = Add Content.File.InputFile
    | Problem String
    | EffectsPerformed String
    | NoMoreInputFiles Int


type alias Model =
    { pathSep : String
    , fileContents : Content.File.Files
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
    ( { pathSep = flags.pathSep
      , fileContents = Dict.empty
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
            case Content.Internal.sequence (List.map (Content.Decode.File.toFile model.pathSep Content.decoder) (Content.File.filesToList model.fileContents)) of
                Content.Internal.Continue messages allFiles ->
                    ( { model
                      | fileEffectsPerformed = Set.fromList (List.map .filePath allFiles)
                      , outputFiles = List.map (\file -> { filePath = file.filePath, fileContents = file.fileContents }) allFiles
                      }
                    , Cmd.batch
                        [ Ports.show (Content.Internal.encodeMessages messages)
                        , Cmd.batch (List.map (\file -> Ports.performEffect { filePath = file.filePath, actions = file.actions }) allFiles)
                        ]
                    )

                Content.Internal.Ignore messages ->
                    ( model, Ports.show (Content.Internal.encodeMessages messages) )

                Content.Internal.Terminate message ->
                    ( model, Ports.terminate message )

        Add inputFile ->
            case Content.File.outputPath model.pathSep inputFile.filePath of
                Content.Internal.Continue messages fileDetails ->
                    ( { model | fileContents = Content.File.newFile fileDetails inputFile model.fileContents }
                    , Ports.show (Content.Internal.encodeMessages messages)
                    )

                Content.Internal.Ignore messages ->
                    ( model
                    , Ports.show (Content.Internal.encodeMessages messages)
                    )

                Content.Internal.Terminate message ->
                    ( model
                    , Ports.terminate message
                    )

        Problem problem ->
            ( model
            , Ports.terminate problem
            )


addRawFile : Json.Decode.Value -> Msg
addRawFile jsValue =
    case Json.Decode.decodeValue Content.File.decodeInputFile jsValue of
        Ok newFile ->
            Add newFile

        Err err ->
            Problem (Json.Decode.errorToString err)


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Ports.add addRawFile
        , Ports.noMoreInputFiles NoMoreInputFiles
        , Ports.effectsPerformed EffectsPerformed
        ]
