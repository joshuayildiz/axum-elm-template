module Pages.Root exposing (view)

import Html exposing (Html, button, code, div, form, h1, h2, input, p, span, text)
import Html.Attributes exposing (class, placeholder, type_, value)
import Html.Events exposing (onInput, onSubmit)
import I18n exposing (T)


{-| The home page. Below the hero sits the live broadcast demo. The draft text,
the message log, and the two handlers come from `Main`, which owns the socket, so
the log survives navigation between pages.
-}
view : T -> String -> List { from : String, text : String } -> (String -> msg) -> msg -> Html msg
view t draft messages onInput_ onSend =
    div [ class "relative flex w-full flex-1 flex-col items-center justify-center gap-10 text-center" ]
        [ div [ class "pointer-events-none absolute -top-16 h-64 w-64 rounded-full bg-success/30 blur-3xl" ] []
        , div [ class "relative flex flex-col items-center gap-6" ]
            [ span [ class "inline-flex items-center gap-1.5 rounded-full border border-border bg-card/70 px-3 py-1 text-[11px] font-medium text-muted-foreground" ]
                [ span [ class "h-1.5 w-1.5 rounded-full bg-success" ] []
                , text t.rootBadge
                ]
            , div [ class "flex flex-col gap-3" ]
                [ h1 [ class "text-4xl font-semibold tracking-tight text-foreground" ]
                    [ text "Axum + Elm" ]
                , p [ class "text-base text-muted-foreground" ]
                    [ text t.rootTagline ]
                ]
            , p [ class "max-w-sm text-sm leading-relaxed text-muted-foreground" ]
                [ text t.rootBody ]
            , p [ class "text-[13px] text-muted-foreground" ]
                [ text t.rootEditPrefix
                , code [ class "rounded-md bg-secondary px-1.5 py-0.5 font-mono text-[12px] text-muted-foreground" ]
                    [ text "client/src/Pages/Root.elm" ]
                , text t.rootEditSuffix
                ]
            ]
        , viewBroadcast t draft messages onInput_ onSend
        ]


viewBroadcast : T -> String -> List { from : String, text : String } -> (String -> msg) -> msg -> Html msg
viewBroadcast t draft messages onInput_ onSend =
    div [ class "relative flex w-full max-w-sm flex-col gap-3 rounded-xl border border-border bg-card p-5 text-left shadow-sm" ]
        [ h2 [ class "text-[10px] font-semibold uppercase tracking-[0.16em] text-muted-foreground" ]
            [ text t.broadcastTitle ]
        , form [ class "flex items-center gap-2", onSubmit onSend ]
            [ input
                [ type_ "text"
                , placeholder t.broadcastPlaceholder
                , value draft
                , onInput onInput_
                , class "min-w-0 flex-1 rounded-lg border border-border bg-card px-2.5 py-1.5 text-[13px] text-foreground transition-colors placeholder:text-muted-foreground focus:border-ring focus:outline-none"
                ]
                []
            , button
                [ type_ "submit"
                , class "shrink-0 rounded-lg bg-primary px-2.5 py-1.5 text-[13px] font-medium text-primary-foreground transition-colors hover:bg-primary/90"
                ]
                [ text t.broadcastSend ]
            ]
        , if List.isEmpty messages then
            p [ class "text-[13px] text-muted-foreground" ] [ text t.broadcastEmpty ]

          else
            div [ class "flex flex-col gap-1.5" ] (List.map viewLine messages)
        ]


viewLine : { from : String, text : String } -> Html msg
viewLine line =
    p [ class "text-[13px] text-muted-foreground" ]
        [ span [ class "font-medium text-foreground" ] [ text line.from ]
        , text ": "
        , text line.text
        ]
