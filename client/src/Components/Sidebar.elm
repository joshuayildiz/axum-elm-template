module Components.Sidebar exposing (Config, view)

import Html exposing (Html, a, aside, button, div, nav, span, text)
import Html.Attributes exposing (class, href)
import Html.Events exposing (onClick)
import I18n exposing (T)
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


tabs : T -> List (Tab msg)
tabs t =
    [ { label = t.home, path = "/", permission = Nothing, icon = Icons.home }
    , { label = t.users, path = "/users", permission = Just "users.read", icon = Icons.users }
    , { label = t.roles, path = "/roles", permission = Just "roles.read", icon = Icons.roles }
    , { label = t.settings, path = "/settings", permission = Just "settings.read", icon = Icons.settings }
    ]


{-| Render the sidebar. It shows only the tabs the user is allowed to see, and
marks the tab for the current path as active.
-}
type alias Config msg =
    { t : T
    , companyName : String
    , permissions : List String
    , activePath : String
    , name : Maybe String
    , email : String
    , menuOpen : Bool
    , onToggleMenu : msg
    , onLogout : msg
    , onSecurity : msg
    , langSwitcher : Html msg
    }


view : Config msg -> Html msg
view config =
    aside [ class "flex w-52 shrink-0 flex-col gap-5 border-r border-zinc-200/70 bg-white/60 p-3" ]
        [ brand config.companyName
        , nav [ class "flex flex-1 flex-col gap-0.5 overflow-y-auto" ]
            (caption config.t.menu :: List.filterMap (viewTab config.permissions config.activePath) (tabs config.t))
        , div [ class "px-2" ] [ config.langSwitcher ]
        , viewUser config
        ]


viewUser : Config msg -> Html msg
viewUser config =
    div [ class "relative mt-auto border-t border-zinc-200/70 pt-3" ]
        [ button
            [ onClick config.onToggleMenu
            , class "flex w-full flex-col gap-0.5 rounded-lg px-2 py-1 text-left transition-colors hover:bg-zinc-100"
            ]
            [ span [ class "text-[10px] font-medium uppercase tracking-[0.16em] text-zinc-400" ]
                [ text config.t.signedInAs ]
            , span [ class "truncate text-[13px] font-medium text-zinc-800" ]
                [ text (Maybe.withDefault config.email config.name) ]
            , case config.name of
                Just _ ->
                    span [ class "truncate text-[11px] text-zinc-400" ] [ text config.email ]

                Nothing ->
                    text ""
            ]
        , if config.menuOpen then
            viewMenu config

          else
            text ""
        ]


viewMenu : Config msg -> Html msg
viewMenu config =
    div []
        [ div [ class "fixed inset-0 z-40", onClick config.onToggleMenu ] []
        , div [ class "absolute bottom-full left-0 z-50 mb-1 w-full rounded-lg border border-zinc-200 bg-white p-1 shadow-lg" ]
            [ menuItemWithIcon config.onSecurity Icons.security config.t.security
            , div [ class "my-1 border-t border-zinc-100" ] []
            , menuItemWithIcon config.onLogout Icons.logOut config.t.logOut
            ]
        ]


menuItemWithIcon : msg -> Html msg -> String -> Html msg
menuItemWithIcon onSelect icon label =
    button
        [ onClick onSelect
        , class "flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-[13px] font-medium text-zinc-700 transition-colors hover:bg-zinc-100"
        ]
        [ icon, text label ]


brand : String -> Html msg
brand name =
    div [ class "flex items-center gap-2 px-2 pt-1" ]
        [ div [ class "flex h-6 w-6 items-center justify-center rounded-md bg-zinc-900 text-[11px] font-bold text-white" ]
            [ text (String.toUpper (String.left 1 name)) ]
        , span [ class "text-sm font-semibold tracking-tight text-zinc-900" ] [ text name ]
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
