module Components.Button exposing (primary, secondary)

import Html exposing (Html, button)
import Html.Attributes exposing (class)


{-| A solid, near-black primary action, full width. Pass the button attributes,
for example `type_ "submit"`, `onClick`, or `disabled`.
-}
primary : List (Html.Attribute msg) -> List (Html msg) -> Html msg
primary attrs children =
    button (attrs ++ [ class (base ++ " bg-primary text-primary-foreground shadow-sm hover:bg-primary/90 active:bg-primary") ]) children


{-| A quiet, outlined action, full width.
-}
secondary : List (Html.Attribute msg) -> List (Html msg) -> Html msg
secondary attrs children =
    button (attrs ++ [ class (base ++ " border border-border bg-card text-muted-foreground hover:bg-accent") ]) children


base : String
base =
    "flex w-full items-center justify-center gap-2 rounded-lg px-4 py-2 text-sm font-medium tracking-tight transition-colors disabled:opacity-50"
