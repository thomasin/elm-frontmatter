module Utils exposing (writeTypeAnnotation, testDecoder)

import Content.Decode.Internal
import Content.Decode
import Elm.Syntax.Node
import Elm.Syntax.Import
import Elm.Syntax.Range
import Elm.Syntax.Expression
import Elm.Syntax.TypeAnnotation
import Elm.Writer
import Test
import Path.Platform
import Path
import Expect
import Json.Decode
import Json.Encode


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


testDecoder : String -> Content.Decode.Decoder value -> (Content.Decode.Internal.DecoderContext -> { typeAnnotation : Content.Decode.Internal.DecoderContext -> Elm.Syntax.TypeAnnotation.TypeAnnotation, imports : Content.Decode.Internal.DecoderContext -> List Elm.Syntax.Import.Import, jsonDecoder : Content.Decode.Internal.DecoderContext -> Json.Decode.Decoder value, asExpression : Content.Decode.Internal.DecoderContext -> value -> Elm.Syntax.Expression.Expression, actions : value -> List { with : String, args : Json.Encode.Value } } -> Expect.Expectation) -> Expect.Expectation
testDecoder str (Content.Decode.Internal.Decoder decoder) func =
    case Path.fromString Path.Platform.posix str of
        Ok path ->
            func { inputFilePath = path } decoder

        Err _ ->
            Expect.fail ""