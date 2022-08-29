module Content.Internal exposing (FileName(..), node)

import Elm.Syntax.Node
import Elm.Syntax.Range



--


node : a -> Elm.Syntax.Node.Node a
node =
    Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange



--


type FileName
    = Hidden
    | Bracketed String
    | Normal String

