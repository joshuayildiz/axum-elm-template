module Components.Sidebar exposing (view)

import Html exposing (Html, a, aside, div, nav, span, text)
import Html.Attributes exposing (class, href)
import Icons


{-| One sidebar entry. `permission` is the permission name the user must hold for
the tab to show. `Nothing` means the tab is open to every signed-in user.
-}
type alias Tab msg =
    { label : String
    , path : String
    , permission : Maybe String
    , icon : Html msg
    }


tabs : List (Tab msg)
tabs =
    [ { label = "Home", path = "/", permission = Nothing, icon = Icons.home }
    , { label = "Users", path = "/users", permission = Just "users.read", icon = Icons.users }
    , { label = "Roles", path = "/roles", permission = Just "roles.read", icon = Icons.roles }
    ]


{-| Render the sidebar. It shows only the tabs the user is allowed to see, and
marks the tab for the current path as active.
-}
view : { permissions : List String, activePath : String, name : Maybe String, email : String } -> Html msg
view { permissions, activePath, name, email } =
    aside [ class "flex w-52 shrink-0 flex-col gap-5 border-r border-zinc-200/70 bg-white/60 p-3" ]
        [ brand
        , nav [ class "flex flex-1 flex-col gap-0.5 overflow-y-auto" ]
            (caption "Menu" :: List.filterMap (viewTab permissions activePath) tabs)
        , viewUser name email
        ]


viewUser : Maybe String -> String -> Html msg
viewUser name email =
    div [ class "mt-auto flex flex-col gap-0.5 border-t border-zinc-200/70 px-2 pt-3" ]
        [ span [ class "text-[10px] font-medium uppercase tracking-[0.16em] text-zinc-400" ]
            [ text "Signed in as" ]
        , span [ class "truncate text-[13px] font-medium text-zinc-800" ]
            [ text (Maybe.withDefault email name) ]
        , case name of
            Just _ ->
                span [ class "truncate text-[11px] text-zinc-400" ] [ text email ]

            Nothing ->
                text ""
        ]


brand : Html msg
brand =
    div [ class "flex items-center gap-2 px-2 pt-1" ]
        [ div [ class "flex h-6 w-6 items-center justify-center rounded-md bg-zinc-900 text-[11px] font-bold text-white" ]
            [ text "A" ]
        , span [ class "text-sm font-semibold tracking-tight text-zinc-900" ] [ text "Console" ]
        ]


caption : String -> Html msg
caption label =
    span [ class "px-2.5 pb-1 text-[10px] font-medium uppercase tracking-[0.16em] text-zinc-400" ]
        [ text label ]


viewTab : List String -> String -> Tab msg -> Maybe (Html msg)
viewTab permissions activePath tab =
    if allowed permissions tab then
        Just (link activePath tab)

    else
        Nothing


allowed : List String -> Tab msg -> Bool
allowed permissions tab =
    case tab.permission of
        Nothing ->
            True

        Just permission ->
            List.member permission permissions


link : String -> Tab msg -> Html msg
link activePath tab =
    a
        [ href tab.path
        , class
            (if tab.path == activePath then
                "flex items-center gap-2.5 rounded-lg bg-zinc-900 px-2.5 py-1.5 text-[13px] font-medium text-white"

             else
                "flex items-center gap-2.5 rounded-lg px-2.5 py-1.5 text-[13px] font-medium text-zinc-500 transition-colors hover:bg-zinc-100 hover:text-zinc-900"
            )
        ]
        [ tab.icon
        , span [] [ text tab.label ]
        ]
