module Pages.Root exposing (view)

import Api.Types exposing (MeResponse)
import Html exposing (Html, code, div, h1, p, span, text)
import Html.Attributes exposing (class)


view : MeResponse -> Html msg
view _ =
    div [ class "relative flex w-full flex-1 flex-col items-center justify-center gap-6 text-center" ]
        [ div [ class "pointer-events-none absolute -top-16 h-64 w-64 rounded-full bg-emerald-200/40 blur-3xl" ] []
        , div [ class "relative flex flex-col items-center gap-6" ]
            [ span [ class "inline-flex items-center gap-1.5 rounded-full border border-zinc-200 bg-white/70 px-3 py-1 text-[11px] font-medium text-zinc-500" ]
                [ span [ class "h-1.5 w-1.5 rounded-full bg-emerald-500" ] []
                , text "Running"
                ]
            , div [ class "flex flex-col gap-3" ]
                [ h1 [ class "text-4xl font-semibold tracking-tight text-zinc-900" ]
                    [ text "Axum + Elm" ]
                , p [ class "text-base text-zinc-500" ]
                    [ text "Typed, calm, and ready." ]
                ]
            , p [ class "max-w-sm text-sm leading-relaxed text-zinc-400" ]
                [ text "This is the home page. The server is running and you are signed in. Build your own screens from here." ]
            , p [ class "text-[13px] text-zinc-400" ]
                [ text "Edit "
                , code [ class "rounded-md bg-zinc-100 px-1.5 py-0.5 font-mono text-[12px] text-zinc-600" ]
                    [ text "client/src/Pages/Root.elm" ]
                , text " to change this page."
                ]
            ]
        ]
