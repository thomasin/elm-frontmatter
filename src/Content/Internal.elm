module Content.Internal exposing (Message(..), Output(..), encodeMessages, node, sequence)

import Elm.Syntax.Node
import Elm.Syntax.Range



--


node : a -> Elm.Syntax.Node.Node a
node =
    Elm.Syntax.Node.Node Elm.Syntax.Range.emptyRange



--


type Output a
    = Continue (List Message) a
    | Ignore (List Message)
    | Terminate String


type Message
    = Success String
    | Info String


sequence : List (Output a) -> Output (List a)
sequence outputs =
    let
        check : List (Output a) -> List Message -> List a -> Output (List a)
        check outputs_ messages items =
            case outputs_ of
                [] ->
                    Continue messages items

                o :: os ->
                    case o of
                        Continue messages_ item ->
                            check os (List.append messages_ messages) (item :: items)

                        Ignore messages_ ->
                            check os (List.append messages_ messages) items

                        Terminate message ->
                            Terminate message
    in
    check outputs [] []


encodeMessages : List Message -> List { level : String, message : String }
encodeMessages messages =
    List.map
        (\message ->
            case message of
                Success str ->
                    { level = "success", message = str }

                Info str ->
                    { level = "info", message = str }
        )
        messages
