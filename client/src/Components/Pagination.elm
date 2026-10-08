module Components.Pagination exposing (view)

import Html exposing (Html, button, div, span, text)
import Html.Attributes exposing (class, disabled)
import Html.Events exposing (onClick)
import I18n exposing (T)


view : T -> { page : Int, perPage : Int, total : Int, onPrev : msg, onNext : msg } -> Html msg
view t cfg =
    let
        totalPages =
            max 1 (ceiling (toFloat cfg.total / toFloat cfg.perPage))
    in
    if cfg.total == 0 then
        text ""

    else
        div [ class "flex items-center justify-between pt-1" ]
            [ span [ class "text-[13px] text-muted-foreground" ]
                [ text (t.pageWord ++ " " ++ String.fromInt cfg.page ++ " " ++ t.ofWord ++ " " ++ String.fromInt totalPages) ]
            , div [ class "flex items-center gap-2" ]
                [ button
                    [ onClick cfg.onPrev
                    , disabled (cfg.page <= 1)
                    , class buttonClass
                    ]
                    [ text t.previous ]
                , button
                    [ onClick cfg.onNext
                    , disabled (cfg.page >= totalPages)
                    , class buttonClass
                    ]
                    [ text t.next ]
                ]
            ]


buttonClass : String
buttonClass =
    "rounded-lg border border-border px-2.5 py-1.5 text-[13px] font-medium text-muted-foreground transition-colors hover:bg-accent disabled:cursor-not-allowed disabled:opacity-40"
