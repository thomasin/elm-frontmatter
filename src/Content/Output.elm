module Content.Output exposing (Output(..), Message(..), encodeMessages, map, sequence)


type Message
    = Success String
    | Info String


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


type Output a
    = Continue (List Message) a
    | Ignore (List Message)
    | Terminate String


map : (a -> b) -> Output a -> Output b
map func output =
    case output of
        Continue messages a ->
            Continue messages (func a)

        Ignore messages ->
            Ignore messages
    
        Terminate str ->
            Terminate str


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