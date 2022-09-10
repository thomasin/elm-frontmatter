module Main exposing (main)

import Content
import Content.Function
import Content.Module
import Content.Type
import Content.Decode
import Dict
import Json.Decode
import Json.Decode.Extra
import Modules
import Output
import Path
import Path.Platform
import Platform
import Ports
import Set


contentDecoder : Content.Type.Path -> Content.Decode.QueryResult
contentDecoder =
    Content.decoder
    --always Content.Decode.ignore


contentModulePrefix : List String
contentModulePrefix =
    [ "Content" ]


type Msg
    = Add Modules.InputFile
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


functionPathResultToOutput : Result Content.Function.PathError Content.Function.Function -> Output.Output Content.Function.Function
functionPathResultToOutput functionOutput =
    case functionOutput of
        Ok function ->
            Output.Continue [] function

        Err Content.Function.PathIsHidden ->
            Output.Ignore [ Output.Info "Ignoring hidden file" ]

        Err Content.Function.PathIsEmpty ->
            Output.Ignore []

        Err (Content.Function.PathIsInvalid message) ->
            Output.Terminate message


moduleGenerationToOutput : List String -> Result Content.Module.GenerationError Content.Module.Module -> Output.Output Content.Module.Module
moduleGenerationToOutput moduleDir generationOutput =
    case generationOutput of
        Ok generatedModule ->
            Output.Continue [ Output.Success ("✨ Successfully generated \"" ++ String.join "." moduleDir ++ "\"") ] generatedModule

        Err (Content.Module.NoMatchingDecoder typePath) ->
            Output.Terminate ("No decoder found for \"" ++ Content.Type.toString typePath ++ "\"")

        Err Content.Module.ModuleIsEmpty ->
            Output.Ignore [ Output.Info ("🌥  Ignoring empty module \"" ++ String.join "." moduleDir ++ "\"") ]

        Err (Content.Module.InvalidOutputPath pathStr) ->
            Output.Terminate ("Somehow the invalid output path \"" ++ pathStr ++ "\" has been generated")

        Err (Content.Module.DecoderError typePath decodeError) ->
            Output.Terminate ("Error decoding \"" ++ Content.Type.toString typePath ++ "\"\n" ++ Json.Decode.errorToString decodeError)


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
            let
                generatedModules : List (Output.Output Content.Module.Module)
                generatedModules =
                    List.map (\undecodedModule ->
                        moduleGenerationToOutput undecodedModule.dir (Content.Module.generate model.platform contentDecoder undecodedModule)
                    ) (Modules.modulesToList model.modulesContents)

            in
            case Output.sequence generatedModules of
                Output.Continue messages allFiles ->
                    ( { model
                        | fileEffectsPerformed = Set.fromList (List.map (Path.toString << .path) allFiles)
                        , outputFiles = List.map (\file -> { filePath = Path.toString file.path, fileContents = file.contents }) allFiles
                      }
                    , Cmd.batch
                        [ Ports.show (Output.encodeMessages messages)
                        , Cmd.batch (List.map (\file -> Ports.performEffect { filePath = Path.toString file.path, actions = file.actions }) allFiles)
                        ]
                    )

                Output.Ignore messages ->
                    ( model, Ports.show (Output.encodeMessages messages) )

                Output.Terminate message ->
                    ( model, Ports.terminate message )

        Add inputFile ->
            case functionPathResultToOutput (Content.Function.fromPath inputFile.filePath) of
                Output.Continue messages functionDetails ->
                    ( { model | modulesContents = Modules.newFunction contentModulePrefix functionDetails inputFile model.modulesContents }
                    , Ports.show (Output.encodeMessages messages)
                    )

                Output.Ignore messages ->
                    ( model
                    , Ports.show (Output.encodeMessages messages)
                    )

                Output.Terminate message ->
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
        decodeInputFile : Json.Decode.Decoder Modules.InputFile
        decodeInputFile =
            Json.Decode.map2 Modules.InputFile
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
