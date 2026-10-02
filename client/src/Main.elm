module Main exposing (main)

import Browser
import Html exposing (Html, text)


main : Program () () msg
main =
    Browser.sandbox
        { init = ()
        , update = \_ model -> model
        , view = view
        }


view : () -> Html msg
view _ =
    text "Hello, world!"
