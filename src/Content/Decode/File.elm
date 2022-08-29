module Content.Decode.File exposing (InputFile, OutputModule, toFile)

import Content.Decode.Internal
import Content.Function
import Content.Output
import Content.Internal
import Path
import Content.Type
import Content.Write
import Dict
import Json.Decode
import Json.Encode
import Result.Extra as Result


type alias OutputModule =
    { dir : List String
    , functions : Dict.Dict String { type_ : Content.Function.FunctionType, inputFile : InputFile }
    }


type alias InputFile =
    { filePath : Path.Path
    , fileFrontmatter : Json.Decode.Value
    }


--decodedDeclarations : List String -> Dict.Dict String InputFile -> (Content.Type.Path -> Content.Decode.Internal.DeclarationResult) -> Content.Internal.Output Content.Write.Writer
--decodedDeclarations moduleDir fileDetails declarationGenerator =
--    toDeclarations
--        (Content.Type.Multiple (String.join "." moduleDir))
--        (Dict.toList fileDetails)
--        declarationGenerator

    --case fileDetails.content of
    --    Content.File.JustContent content ->
    --        toDeclarations
    --            declarationGenerator
    --            (Content.Type.Single (String.join "." fileDetails.moduleDir))
    --            [ content ]

    --    Content.File.JustListItems itemsDict ->
    --        toDeclarations
    --            declarationGenerator
    --            (Content.Type.Multiple (String.join "." fileDetails.moduleDir))
    --            (Dict.toList itemsDict)

        --Content.File.Both content itemsDict ->
        --    let
        --        contentDeclarations : Content.Internal.Output Content.Write.Writer
        --        contentDeclarations =
        --            toDeclarations
        --                declarationGenerator
        --                (Content.Type.Single (String.join "." fileDetails.moduleDir))
        --                [ content ]

        --        itemsDeclarations : Content.Internal.Output Content.Write.Writer
        --        itemsDeclarations =
        --            toDeclarations
        --                declarationGenerator
        --                (Content.Type.Multiple (String.join "." fileDetails.moduleDir))
        --                (Dict.toList itemsDict)
        --    in
        --    case Content.Internal.sequence [ contentDeclarations, itemsDeclarations ] of
        --        Content.Internal.Continue messages (declarations1 :: declarations2 :: []) ->
        --            Content.Internal.Continue messages
        --                (Content.Write.concat [ declarations1, declarations2 ])

        --        Content.Internal.Continue messages (declarations1 :: []) ->
        --            Content.Internal.Continue messages declarations1

        --        Content.Internal.Continue messages _ ->
        --            Content.Internal.Ignore messages

        --        Content.Internal.Ignore messages ->
        --            Content.Internal.Ignore messages

        --        Content.Internal.Terminate message ->
        --            Content.Internal.Terminate message



            --case declarationGenerator typePath of
            --    Content.Decode.Internal.Found (Content.Decode.Internal.Declaration frontmatterDecoder) ->
            --        let
            --            writerResult : Result Json.Decode.Error Content.Write.Writer
            --            writerResult =
            --                Result.map Content.Write.concat <|
            --                    Result.combineMap
            --                        (\( functionName, inputFile ) ->
            --                            Content.Write.record
            --                                { functionName = functionName
            --                                , functionType = Content.Type.toTypeName typePath
            --                                , inputFilePath = inputFile.filePath
            --                                , frontmatter = inputFile.fileFrontmatter
            --                                , documentation = Just ("{-| Auto-generated from file " ++ Content.Path.toString inputFile.filePath ++ "-}")
            --                                , decoder = Content.Decode.Internal.Declaration frontmatterDecoder
            --                                }
            --                        )
            --                        functions
            --        in
            --        case writerResult of
            --            Ok writer ->
            --                Content.Output.Continue [ Content.Output.Success ("✨ Successfully decoded " ++ Content.Type.toString typePath) ]
            --                    writer

            --            -- There was a problem decoding the file contents
            --            Err decodeError ->
            --                Content.Output.Terminate
            --                    (Json.Decode.errorToString decodeError)

            --    -- No decoder found for this module
            --    Content.Decode.Internal.NotFound { throw } ->
            --        if throw then
            --            Content.Output.Terminate
            --                ("Couldn't find matching decoder for " ++ Content.Type.toString typePath)

            --        else
            --            Content.Output.Ignore
            --                [ Content.Output.Info ("🌥  Ignoring " ++ Content.Type.toString typePath) ]


toFile : (Content.Type.Path -> Content.Decode.Internal.DeclarationResult) -> OutputModule -> Content.Output.Output { filePath : String, fileContents : String, actions : List { with : String, args : Json.Encode.Value } }
toFile declarationGenerator outputModule =
    let
        toDeclarations : List ( String, { type_ : Content.Function.FunctionType, inputFile : InputFile } ) -> Content.Output.Output Content.Write.Writer
        toDeclarations functions =
            Content.Output.map Content.Write.concat <| Content.Output.sequence <| List.map
                (\( functionName, functionDetails ) ->
                    let
                        typePath : Content.Type.Path
                        typePath =
                            Content.Type.fromFunctionType functionDetails.type_ outputModule.dir

                    in
                    case declarationGenerator typePath of
                        Content.Decode.Internal.Found (Content.Decode.Internal.Declaration frontmatterDecoder) ->
                            let
                                writerResult : Result Json.Decode.Error Content.Write.Writer
                                writerResult =
                                    Content.Write.record
                                        { functionName = functionName
                                        , functionType = Content.Type.toTypeName typePath
                                        , inputFilePath = functionDetails.inputFile.filePath
                                        , frontmatter = functionDetails.inputFile.fileFrontmatter
                                        , documentation = Just ("{-| Auto-generated from file " ++ Path.toString functionDetails.inputFile.filePath ++ "-}")
                                        , decoder = Content.Decode.Internal.Declaration frontmatterDecoder
                                        }
                            in
                            case writerResult of
                                Ok writer ->
                                    Content.Output.Continue
                                        [ Content.Output.Success ("✨ Successfully decoded " ++ Content.Type.toString typePath) ]
                                        writer

                                -- There was a problem decoding the file contents
                                Err decodeError ->
                                    Content.Output.Terminate
                                        (Json.Decode.errorToString decodeError)

                        -- No decoder found for this module
                        Content.Decode.Internal.NotFound { throw } ->
                            if throw then
                                Content.Output.Terminate
                                    ("Couldn't find matching decoder for " ++ Content.Type.toString typePath)

                            else
                                Content.Output.Ignore
                                    [ Content.Output.Info ("🌥  Ignoring " ++ Content.Type.toString typePath) ]
                )
                functions
            
    in
    case toDeclarations (Dict.toList outputModule.functions) of
        Content.Output.Continue messages (Content.Write.Writer decoded) ->
            Content.Output.Continue messages
                { filePath = String.join "/" outputModule.dir ++ ".elm"
                , fileContents =
                    Content.Write.toFileString
                        outputModule.dir
                        (Content.Write.Writer decoded)
                , actions = decoded.actions
                }

        Content.Output.Ignore messages ->
            Content.Output.Ignore messages

        Content.Output.Terminate message ->
            Content.Output.Terminate ("An error occured while decoding " ++ String.join "." outputModule.dir ++ ": " ++ message)
