module Content.Decode.Internal exposing (DecoderContext, Attribute(..), Declaration(..), DeclarationResult(..), DecodedAttribute, Decoder(..), decoderToSyntax, escapedString)

import Elm.Syntax.Expression
import Elm.Syntax.Import
import Elm.Syntax.TypeAnnotation
import Json.Decode
import Json.Encode
import Path


type Declaration
    = Declaration
        { typeAnnotation : DecoderContext -> Elm.Syntax.TypeAnnotation.RecordDefinition
        , imports : DecoderContext -> List Elm.Syntax.Import.Import
        , jsonDecoder : DecoderContext -> Json.Decode.Decoder (List { keyName : String, expression : Elm.Syntax.Expression.Expression, actions : List { with : String, args : Json.Encode.Value } })
        }


type DeclarationResult
    = Found Declaration
    | NotFound { throw : Bool }


type alias DecodedAttribute =
    { keyName : String
    , expression : Elm.Syntax.Expression.Expression
    , actions : List { with : String, args : Json.Encode.Value }
    }


type Attribute
    = Attribute
        { typeAnnotation : DecoderContext -> Elm.Syntax.TypeAnnotation.RecordField
        , imports : DecoderContext -> List Elm.Syntax.Import.Import
        , jsonDecoder : DecoderContext -> Json.Decode.Decoder DecodedAttribute
        }


type Decoder a
    = Decoder
        { typeAnnotation : DecoderContext -> Elm.Syntax.TypeAnnotation.TypeAnnotation
        , imports : DecoderContext -> List Elm.Syntax.Import.Import
        , jsonDecoder : DecoderContext -> Json.Decode.Decoder a
        , asExpression : DecoderContext -> a -> Elm.Syntax.Expression.Expression
        , actions : a -> List { with : String, args : Json.Encode.Value }
        }


type alias DecoderContext =
    { inputFilePath : Path.Path
    }


escapedString : String -> String
escapedString value =
    (String.replace "\"" "\\\"" (String.replace "\\" "\\\\" value))


decoderToSyntax : Decoder value -> { typeAnnotation : DecoderContext -> Elm.Syntax.TypeAnnotation.TypeAnnotation, imports : DecoderContext -> List Elm.Syntax.Import.Import, expression : DecoderContext -> value -> Elm.Syntax.Expression.Expression }
decoderToSyntax (Decoder decoder) =
    { typeAnnotation = decoder.typeAnnotation
    , imports = decoder.imports
    , expression = decoder.asExpression
    }

