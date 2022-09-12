module Utils exposing (testDeclaration, testDecoder, writeExpression, writeTypeAnnotation)

import Content.Decode
import Content.Decode.Internal
import Content.Function
import Elm.Syntax.Expression
import Elm.Syntax.Import
import Elm.Syntax.Node
import Elm.Syntax.Range
import Elm.Syntax.TypeAnnotation
import Elm.Writer
import Expect
import Json.Decode
import Json.Encode
import Path
import Path.Platform


writeExpression : Elm.Syntax.Expression.Expression -> String
writeExpression =
    Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange
        >> Elm.Writer.writeExpression
        >> Elm.Writer.write


writeTypeAnnotation : Elm.Syntax.TypeAnnotation.TypeAnnotation -> String
writeTypeAnnotation =
    Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange
        >> Elm.Writer.writeTypeAnnotation
        >> Elm.Writer.write


testDecoder : String -> Maybe (List String) -> Content.Decode.Decoder value -> (Content.Decode.Internal.DecoderContext -> { typeAnnotation : Content.Decode.Internal.DecoderContext -> Elm.Syntax.TypeAnnotation.TypeAnnotation, imports : Content.Decode.Internal.DecoderContext -> List Elm.Syntax.Import.Import, jsonDecoder : Content.Decode.Internal.DecoderContext -> Json.Decode.Decoder value, asExpression : Content.Decode.Internal.DecoderContext -> value -> Elm.Syntax.Expression.Expression, actions : value -> List { with : String, args : Json.Encode.Value } } -> Expect.Expectation) -> Expect.Expectation
testDecoder str maybeModuleDir (Content.Decode.Internal.Decoder decoder) func =
    case Path.fromString Path.Platform.posix str of
        Ok path ->
            case maybeModuleDir of
                Just moduleDir ->
                    func (Content.Decode.Internal.DecoderContext { inputFilePath = path, moduleDir = moduleDir }) decoder

                Nothing ->
                    case Content.Function.fromPath path of
                        Ok function ->
                            func (Content.Decode.Internal.DecoderContext { inputFilePath = path, moduleDir = function.moduleDir }) decoder

                        Err _ ->
                            Expect.fail "Invalid function"

        Err _ ->
            Expect.fail "Invalid path"


testDeclaration : String -> Content.Decode.QueryResult -> (Content.Decode.Internal.DecoderContext -> Content.Decode.Internal.Declaration -> Expect.Expectation) -> Expect.Expectation
testDeclaration str queryResult func =
    case queryResult of
        Content.Decode.Internal.Found declaration ->
            case Path.fromString Path.Platform.posix str of
                Ok path ->
                    case Content.Function.fromPath path of
                        Ok function ->
                            func (Content.Decode.Internal.DecoderContext { inputFilePath = path, moduleDir = function.moduleDir }) declaration

                        Err _ ->
                            Expect.fail "Invalid function"

                Err _ ->
                    Expect.fail "Invalid path"

        _ ->
            Expect.fail "Declaration not found"
