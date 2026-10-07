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
        , class "cursor-pointer rounded-lg border border-zinc-200 bg-white px-2 py-1 text-[12px] font-medium text-zinc-600 transition-colors hover:border-zinc-300 focus:border-zinc-400 focus:outline-none"
        ]
        (List.map (viewOption current) I18n.all)


viewOption : Lang -> Lang -> Html msg
viewOption current lang =
    option
        [ value (I18n.toString lang)
        , selected (lang == current)
        ]
        [ text (I18n.label lang) ]
