module Icons exposing
    ( arrowRight
    , home
    , logOut
    , plus
    , roles
    , search
    , users
    )

import Html exposing (Html, node)
import Html.Attributes exposing (attribute, class)


{-| One Lucide icon, drawn by the Iconify web component from `index.html`. The
icon follows the current text color and sits at 18px. Pass a Lucide icon name.
-}
icon : String -> Html msg
icon name =
    node "iconify-icon"
        [ attribute "icon" ("lucide:" ++ name)
        , attribute "width" "16"
        , attribute "height" "16"
        , attribute "aria-hidden" "true"
        , class "shrink-0"
        ]
        []


home : Html msg
home =
    icon "house"


users : Html msg
users =
    icon "users"


roles : Html msg
roles =
    icon "shield"


plus : Html msg
plus =
    icon "plus"


logOut : Html msg
logOut =
    icon "log-out"


arrowRight : Html msg
arrowRight =
    icon "arrow-right"


search : Html msg
search =
    icon "search"
