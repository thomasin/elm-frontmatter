module Content.Decode.File exposing (toFile)

import Content.Decode.Internal
import Content.File
import Content.Internal
import Content.Path
import Content.Type
import Content.Write
import Dict
import Json.Decode
import Json.Encode
import Result.Extra as Result


toDeclarations : String -> (Content.Type.Path -> Content.Decode.Internal.DeclarationResult) -> Content.Type.Path -> List ( String, Content.File.InputFile ) -> Content.Internal.Output Content.Write.Writer
toDeclarations pathSep declarationGenerator typePath functions =
    case declarationGenerator typePath of
        Content.Decode.Internal.Found (Content.Decode.Internal.Declaration frontmatterDecoder) ->
            let
                writerResult : Result Json.Decode.Error Content.Write.Writer
                writerResult =
                    Result.map Content.Write.concat <|
                        Result.combineMap
                            (\( functionName, inputFile ) ->
                                Content.Write.record
                                    { functionName = functionName
                                    , functionType = Content.Type.toTypeName typePath
                                    , inputFilePath = Content.Path.format inputFile.filePath
                                    , pathSep = pathSep
                                    , frontmatter = inputFile.fileFrontmatter
                                    , documentation = Just ("{-| Auto-generated from file " ++ Content.Path.format inputFile.filePath ++ "-}")
                                    , decoder = Content.Decode.Internal.Declaration frontmatterDecoder
                                    }
                            )
                            functions
            in
            case writerResult of
                Ok writer ->
                    Content.Internal.Continue [ Content.Internal.Success ("✨ Successfully decoded " ++ Content.Type.toString typePath) ]
                        writer

                -- There was a problem decoding the file contents
                Err decodeError ->
                    Content.Internal.Terminate
                        (Json.Decode.errorToString decodeError)

        -- No decoder found for this module
        Content.Decode.Internal.NotFound { throw } ->
            if throw then
                Content.Internal.Terminate
                    ("Couldn't find matching decoder for " ++ Content.Type.toString typePath)

            else
                Content.Internal.Ignore
                    [ Content.Internal.Info ("🌥  Ignoring " ++ Content.Type.toString typePath) ]


decodedDeclarations : String -> (Content.Type.Path -> Content.Decode.Internal.DeclarationResult) -> Content.File.FileDetails -> Content.Internal.Output Content.Write.Writer
decodedDeclarations pathSep declarationGenerator fileDetails =
    case fileDetails.content of
        Content.File.JustContent content ->
            toDeclarations pathSep
                declarationGenerator
                (Content.Type.Single (String.join "." fileDetails.moduleDir))
                [ content ]

        Content.File.JustListItems itemsDict ->
            toDeclarations pathSep
                declarationGenerator
                (Content.Type.Multiple (String.join "." fileDetails.moduleDir))
                (Dict.toList itemsDict)

        Content.File.Both content itemsDict ->
            let
                contentDeclarations : Content.Internal.Output Content.Write.Writer
                contentDeclarations =
                    toDeclarations pathSep
                        declarationGenerator
                        (Content.Type.Single (String.join "." fileDetails.moduleDir))
                        [ content ]

                itemsDeclarations : Content.Internal.Output Content.Write.Writer
                itemsDeclarations =
                    toDeclarations pathSep
                        declarationGenerator
                        (Content.Type.Multiple (String.join "." fileDetails.moduleDir))
                        (Dict.toList itemsDict)
            in
            case Content.Internal.sequence [ contentDeclarations, itemsDeclarations ] of
                Content.Internal.Continue messages (declarations1 :: declarations2 :: []) ->
                    Content.Internal.Continue messages
                        (Content.Write.concat [ declarations1, declarations2 ])

                Content.Internal.Continue messages (declarations1 :: []) ->
                    Content.Internal.Continue messages declarations1

                Content.Internal.Continue messages _ ->
                    Content.Internal.Ignore messages

                Content.Internal.Ignore messages ->
                    Content.Internal.Ignore messages

                Content.Internal.Terminate message ->
                    Content.Internal.Terminate message


toFile : String -> (Content.Type.Path -> Content.Decode.Internal.DeclarationResult) -> Content.File.FileDetails -> Content.Internal.Output { filePath : String, fileContents : String, actions : List { with : String, args : Json.Encode.Value } }
toFile pathSep declarationGenerator fileDetails =
    case decodedDeclarations pathSep declarationGenerator fileDetails of
        Content.Internal.Continue messages (Content.Write.Writer decoded) ->
            Content.Internal.Continue messages
                { filePath = String.join "/" fileDetails.moduleDir ++ ".elm"
                , fileContents =
                    Content.Write.toFileString
                        fileDetails.moduleDir
                        (Content.Write.Writer decoded)
                , actions = decoded.actions
                }

        Content.Internal.Ignore messages ->
            Content.Internal.Ignore messages

        Content.Internal.Terminate message ->
            Content.Internal.Terminate ("An error occured while decoding " ++ String.join "." fileDetails.moduleDir ++ ": " ++ message)
