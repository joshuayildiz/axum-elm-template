module Components.Button exposing (primary, secondary)

import Html exposing (Html, button)
import Html.Attributes exposing (class)


{-| A solid, near-black primary action, full width. Pass the button attributes,
for example `type_ "submit"`, `onClick`, or `disabled`.
-}
primary : List (Html.Attribute msg) -> List (Html msg) -> Html msg
primary attrs children =
    button (attrs ++ [ class (base ++ " bg-zinc-900 text-white hover:bg-zinc-700") ]) children


{-| A quiet, outlined action, full width.
-}
secondary : List (Html.Attribute msg) -> List (Html msg) -> Html msg
secondary attrs children =
    button (attrs ++ [ class (base ++ " border border-zinc-200 bg-white text-zinc-700 hover:bg-zinc-50") ]) children


base : String
base =
    "w-full rounded-lg px-4 py-2.5 text-sm font-semibold transition-colors disabled:opacity-50"
