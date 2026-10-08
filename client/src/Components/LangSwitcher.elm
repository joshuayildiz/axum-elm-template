module Components.LangSwitcher exposing (view)

{-| A compact language selector. It holds no state. It reads the current language
and reports a new one through `onSelect`.
-}

import Html exposing (Html, option, select, text)
import Html.Attributes exposing (class, selected, value)
import Html.Events exposing (on, targetValue)
import I18n exposing (Lang)
import Json.Decode as Decode


view : Lang -> (Lang -> msg) -> Html msg
view current onSelect =
    select
        [ on "change" (Decode.map (I18n.fromString >> onSelect) targetValue)
        , class "cursor-pointer rounded-lg border border-border bg-card px-2 py-1 text-[12px] font-medium text-muted-foreground transition-colors hover:border-ring focus:border-ring focus:outline-none"
        ]
        (List.map (viewOption current) I18n.all)


viewOption : Lang -> Lang -> Html msg
viewOption current lang =
    option
        [ value (I18n.toString lang)
        , selected (lang == current)
        ]
        [ text (I18n.label lang) ]
