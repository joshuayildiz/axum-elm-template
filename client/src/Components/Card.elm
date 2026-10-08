module Components.Card exposing (view)

import Html exposing (Html, div)
import Html.Attributes exposing (class)


{-| A centered white panel with a soft border and shadow, in the quiet style of
the reference pages.
-}
view : List (Html msg) -> Html msg
view children =
    div [ class "w-full max-w-sm rounded-2xl border border-border bg-card p-6 shadow-sm" ] children
