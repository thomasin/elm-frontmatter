module Content.Decode.Internal exposing (Attribute(..), Declaration(..), DeclarationResult(..), DecodedAttribute, Decoder(..))

import Elm.Syntax.Expression
import Elm.Syntax.Import
import Elm.Syntax.TypeAnnotation
import Json.Decode
import Json.Encode


type Declaration
    = Declaration
        { typeAnnotation : Elm.Syntax.TypeAnnotation.RecordDefinition
        , imports : List Elm.Syntax.Import.Import
        , jsonDecoder : { pathSep : String, inputFilePath : String } -> Json.Decode.Decoder (List { keyName : String, expression : Elm.Syntax.Expression.Expression, actions : List { with : String, args : Json.Encode.Value } })
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
        { typeAnnotation : Elm.Syntax.TypeAnnotation.RecordField
        , imports : List Elm.Syntax.Import.Import
        , jsonDecoder : { pathSep : String, inputFilePath : String } -> Json.Decode.Decoder DecodedAttribute
        }


type Decoder a
    = Decoder
        { typeAnnotation : Elm.Syntax.TypeAnnotation.TypeAnnotation
        , imports : List Elm.Syntax.Import.Import
        , jsonDecoder : { pathSep : String, inputFilePath : String } -> Json.Decode.Decoder a
        , asExpression : a -> Elm.Syntax.Expression.Expression
        , actions : a -> List { with : String, args : Json.Encode.Value }
        }
