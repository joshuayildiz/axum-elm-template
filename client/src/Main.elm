port module Main exposing (main)

import Api
import Api.Types exposing (AuthError, MeResponse, PublicConfig, ServerMessage(..), clientMessageEncoder, serverMessageDecoder)
import Browser
import Browser.Navigation as Nav
import Components.Account as Account
import Components.LangSwitcher as LangSwitcher
import Components.Sidebar as Sidebar
import Html exposing (Html, a, div, h1, p, text)
import Html.Attributes exposing (class, href)
import Http
import I18n exposing (Lang, T)
import Json.Decode as Decode
import Json.Encode as Encode
import Pages.Login as Login
import Pages.Register as Register
import Pages.Roles as Roles
import Pages.Root as RootPage
import Pages.Settings as Settings
import Pages.Users as Users
import Set exposing (Set)
import Time
import Url exposing (Url)
import Url.Parser as Parser exposing (Parser)


{-| Persist the chosen language in the browser. `index.html` subscribes and
writes it to `localStorage`.
-}
port setLanguage : String -> Cmd msg


{-| Open the websocket. `index.html` holds the socket and reconnects it. Called
once the session is known to be signed in, because the upgrade needs the cookie.
-}
port connectSocket : () -> Cmd msg


{-| Close the websocket and stop reconnecting. Called on sign-out.
-}
port disconnectSocket : () -> Cmd msg


{-| Send one encoded `ClientMessage` up the socket.
-}
port sendSocket : String -> Cmd msg


{-| Receive one raw `ServerMessage` JSON string from the socket.
-}
port socketMessage : (String -> msg) -> Sub msg


{-| The values `index.html` passes in at startup. `language` is the stored choice
or the browser language.
-}
type alias Flags =
    { language : String }


{-| One broadcast line, as shown in the home-page log.
-}
type alias ChatLine =
    { from : String, text : String }


type Route
    = Root
    | Login
    | Register
    | Users
    | Roles
    | Settings
    | NotFound


type Session
    = Checking
    | Anonymous
    | SignedIn MeResponse


type alias Model =
    { key : Nav.Key
    , route : Route
    , session : Session
    , lang : Lang
    , login : Login.Model
    , register : Register.Model
    , users : Users.Model
    , roles : Roles.Model
    , settings : Settings.Model
    , userMenuOpen : Bool
    , account : Maybe Account.Model
    , online : Set String
    , draft : String
    , messages : List ChatLine
    , companyName : String
    , registrationEnabled : Bool
    }


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url
    | GotMe (Result Http.Error (Result AuthError MeResponse))
    | GotConfig (Result Http.Error PublicConfig)
    | LoginMsg Login.Msg
    | RegisterMsg Register.Msg
    | UsersMsg Users.Msg
    | RolesMsg Roles.Msg
    | SettingsMsg Settings.Msg
    | SetLang Lang
    | ToggleUserMenu
    | OpenAccount Account.Tab
    | AccountMsg Account.Msg
    | Logout
    | LoggedOut (Result Http.Error ())
    | Tick
    | SocketMessage String
    | DraftChanged String
    | SendBroadcast


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        , onUrlRequest = LinkClicked
        , onUrlChange = UrlChanged
        }


init : Flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    ( { key = key
      , route = toRoute url
      , session = Checking
      , lang = I18n.fromString flags.language
      , login = Login.init
      , register = Register.init
      , users = Users.init
      , roles = Roles.init
      , settings = Settings.init
      , userMenuOpen = False
      , account = Nothing
      , online = Set.empty
      , draft = ""
      , messages = []
      , companyName = ""
      , registrationEnabled = False
      }
    , Cmd.batch [ Api.getMe GotMe, Api.getConfig GotConfig ]
    )


routeParser : Parser (Route -> a) a
routeParser =
    Parser.oneOf
        [ Parser.map Root Parser.top
        , Parser.map Login (Parser.s "login")
        , Parser.map Register (Parser.s "register")
        , Parser.map Users (Parser.s "users")
        , Parser.map Roles (Parser.s "roles")
        , Parser.map Settings (Parser.s "settings")
        ]


toRoute : Url -> Route
toRoute url =
    Maybe.withDefault NotFound (Parser.parse routeParser url)


{-| The path a route lives at, used to mark the active sidebar tab.
-}
pathFor : Route -> String
pathFor route =
    case route of
        Root ->
            "/"

        Users ->
            "/users"

        Roles ->
            "/roles"

        Settings ->
            "/settings"

        Login ->
            "/login"

        Register ->
            "/register"

        NotFound ->
            ""


{-| The permission a route needs. `Nothing` means any signed-in user may see it.
-}
routeRequirement : Route -> Maybe String
routeRequirement route =
    case route of
        Users ->
            Just "users.read"

        Roles ->
            Just "roles.read"

        Settings ->
            Just "settings.read"

        _ ->
            Nothing


{-| Send a visitor away from a page the current session is not allowed to see.
An anonymous visitor on a protected page goes to the login page. A signed-in
visitor on the login page goes to the root, and one who lacks the permission for
a page goes to the root. While the session is unknown, wait.
-}
guard : Model -> Cmd Msg
guard model =
    case model.session of
        Checking ->
            Cmd.none

        Anonymous ->
            case model.route of
                Login ->
                    Cmd.none

                Register ->
                    Cmd.none

                _ ->
                    Nav.replaceUrl model.key "/login"

        SignedIn me ->
            case model.route of
                Login ->
                    Nav.replaceUrl model.key "/"

                Register ->
                    Nav.replaceUrl model.key "/"

                _ ->
                    case routeRequirement model.route of
                        Just permission ->
                            if List.member permission me.permissions then
                                Cmd.none

                            else
                                Nav.replaceUrl model.key "/"

                        Nothing ->
                            Cmd.none


{-| The data a page needs when it opens. It runs only for a signed-in user who
is allowed on the page, so a fetch never fires for a page the guard sends away.
-}
enter : Model -> Cmd Msg
enter model =
    case model.session of
        SignedIn me ->
            case ( model.route, routeRequirement model.route ) of
                ( Users, Just permission ) ->
                    if List.member permission me.permissions then
                        Cmd.map UsersMsg Users.load

                    else
                        Cmd.none

                ( Roles, Just permission ) ->
                    if List.member permission me.permissions then
                        Cmd.map RolesMsg Roles.load

                    else
                        Cmd.none

                ( Settings, Just permission ) ->
                    if List.member permission me.permissions then
                        Cmd.map SettingsMsg Settings.load

                    else
                        Cmd.none

                _ ->
                    Cmd.none

        _ ->
            Cmd.none


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked (Browser.Internal url) ->
            ( model, Nav.pushUrl model.key (Url.toString url) )

        LinkClicked (Browser.External url) ->
            ( model, Nav.load url )

        UrlChanged url ->
            let
                next =
                    { model | route = toRoute url }
            in
            ( next, Cmd.batch [ guard next, enter next ] )

        GotMe result ->
            let
                session =
                    case result of
                        Ok (Ok me) ->
                            SignedIn me

                        _ ->
                            Anonymous

                -- Open the socket when the session becomes signed in, and close
                -- it when it ends. The me poll runs every 30 seconds, so compare
                -- against the old session to act only on a real change.
                socketCmd =
                    case ( model.session, session ) of
                        ( SignedIn _, SignedIn _ ) ->
                            Cmd.none

                        ( _, SignedIn _ ) ->
                            connectSocket ()

                        ( SignedIn _, _ ) ->
                            disconnectSocket ()

                        _ ->
                            Cmd.none

                next =
                    case session of
                        SignedIn _ ->
                            { model | session = session }

                        _ ->
                            { model | session = session, account = Nothing, online = Set.empty, messages = [] }
            in
            ( next, Cmd.batch [ guard next, enter next, socketCmd ] )

        GotConfig (Ok config) ->
            ( { model | companyName = config.companyName, registrationEnabled = config.registrationEnabled }, Cmd.none )

        GotConfig (Err _) ->
            ( model, Cmd.none )

        LoginMsg subMsg ->
            let
                ( login, cmd, event ) =
                    Login.update subMsg model.login

                -- On a fresh login, load the full session (with permissions)
                -- from the me endpoint before showing the app.
                ( session, afterLogin ) =
                    case event of
                        Login.LoggedIn _ ->
                            ( Checking, Api.getMe GotMe )

                        Login.NoEvent ->
                            ( model.session, Cmd.none )

                next =
                    { model | login = login, session = session }
            in
            ( next, Cmd.batch [ Cmd.map LoginMsg cmd, afterLogin, guard next ] )

        RegisterMsg subMsg ->
            let
                ( register, cmd, event ) =
                    Register.update subMsg model.register

                ( session, afterRegister ) =
                    case event of
                        Register.Registered _ ->
                            ( Checking, Api.getMe GotMe )

                        Register.NoEvent ->
                            ( model.session, Cmd.none )

                next =
                    { model | register = register, session = session }
            in
            ( next, Cmd.batch [ Cmd.map RegisterMsg cmd, afterRegister, guard next ] )

        SetLang lang ->
            ( { model | lang = lang }, setLanguage (I18n.toString lang) )

        ToggleUserMenu ->
            ( { model | userMenuOpen = not model.userMenuOpen }, Cmd.none )

        OpenAccount tab ->
            case model.session of
                SignedIn me ->
                    ( { model | account = Just (Account.init tab me.totpEnabled), userMenuOpen = False }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        AccountMsg subMsg ->
            case model.account of
                Just account ->
                    let
                        ( updated, cmd, event ) =
                            Account.update subMsg account

                        ( nextAccount, extra ) =
                            case event of
                                Account.NoEvent ->
                                    ( Just updated, Cmd.none )

                                Account.Close ->
                                    ( Nothing, Cmd.none )

                                Account.TotpChanged _ ->
                                    ( Just updated, Api.getMe GotMe )
                    in
                    ( { model | account = nextAccount }
                    , Cmd.batch [ Cmd.map AccountMsg cmd, extra ]
                    )

                Nothing ->
                    ( model, Cmd.none )

        Logout ->
            ( model, Api.logout LoggedOut )

        LoggedOut _ ->
            -- End the session on the client even if the request failed. The
            -- cookie is short lived, so a lost call still ends the session soon.
            let
                next =
                    { model | session = Anonymous, userMenuOpen = False, account = Nothing, online = Set.empty, messages = [] }
            in
            ( next, Cmd.batch [ guard next, disconnectSocket () ] )

        UsersMsg subMsg ->
            let
                ( users, cmd ) =
                    Users.update subMsg model.users
            in
            ( { model | users = users }, Cmd.map UsersMsg cmd )

        RolesMsg subMsg ->
            let
                ( roles, cmd ) =
                    Roles.update subMsg model.roles
            in
            ( { model | roles = roles }, Cmd.map RolesMsg cmd )

        SettingsMsg subMsg ->
            let
                ( settings, cmd, event ) =
                    Settings.update subMsg model.settings

                refresh =
                    case event of
                        Settings.SettingsSaved ->
                            Cmd.batch [ Api.getMe GotMe, Api.getConfig GotConfig ]

                        Settings.NoEvent ->
                            Cmd.none
            in
            ( { model | settings = settings }, Cmd.batch [ Cmd.map SettingsMsg cmd, refresh ] )

        Tick ->
            ( model, Api.getMe GotMe )

        SocketMessage raw ->
            case Decode.decodeString serverMessageDecoder raw of
                Ok (Snapshot { online }) ->
                    ( { model | online = Set.fromList online }, Cmd.none )

                Ok (Online { userId }) ->
                    ( { model | online = Set.insert userId model.online }, Cmd.none )

                Ok (Offline { userId }) ->
                    ( { model | online = Set.remove userId model.online }, Cmd.none )

                Ok (Broadcast { from, text }) ->
                    -- Newest first, and capped so the log cannot grow forever.
                    ( { model | messages = List.take 50 ({ from = from, text = text } :: model.messages) }
                    , Cmd.none
                    )

                Err _ ->
                    ( model, Cmd.none )

        DraftChanged text ->
            ( { model | draft = text }, Cmd.none )

        SendBroadcast ->
            if String.trim model.draft == "" then
                ( model, Cmd.none )

            else
                ( { model | draft = "" }
                , sendSocket (Encode.encode 0 (clientMessageEncoder (Api.Types.SendBroadcast { text = model.draft })))
                )


{-| While signed in, re-check the session every thirty seconds. Each check
renews the token, so an open tab stays signed in past the one-minute token life.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    case model.session of
        SignedIn _ ->
            Sub.batch
                [ Time.every 30000 (\_ -> Tick)
                , socketMessage SocketMessage
                ]

        _ ->
            Sub.none


pageTitle : T -> Route -> String
pageTitle t route =
    case route of
        Root ->
            t.home

        Login ->
            t.signIn

        Register ->
            t.createAccount

        Users ->
            t.users

        Roles ->
            t.roles

        Settings ->
            t.settings

        NotFound ->
            t.notFound


view : Model -> Browser.Document Msg
view model =
    let
        t =
            I18n.translations model.lang
    in
    { title = pageTitle t model.route
    , body = [ viewShell t model ]
    }


{-| Pick the outer frame. Signed-in pages sit beside the sidebar. Every other
state is centered on its own.
-}
viewShell : T -> Model -> Html Msg
viewShell t model =
    case model.session of
        Checking ->
            centered model.lang [ viewLoading t ]

        Anonymous ->
            centered model.lang
                [ case model.route of
                    Login ->
                        Html.map LoginMsg (Login.view t model.companyName model.registrationEnabled model.login)

                    Register ->
                        Html.map RegisterMsg (Register.view t model.companyName model.register)

                    _ ->
                        viewLoading t
                ]

        SignedIn me ->
            case model.route of
                Login ->
                    centered model.lang [ viewLoading t ]

                Register ->
                    centered model.lang [ viewLoading t ]

                _ ->
                    viewSignedIn t model me


langSwitcher : Lang -> Html Msg
langSwitcher lang =
    LangSwitcher.view lang SetLang


centered : Lang -> List (Html Msg) -> Html Msg
centered lang children =
    div
        [ class "relative flex min-h-dvh flex-col items-center justify-center gap-6 bg-zinc-50 px-4 text-zinc-900" ]
        (div [ class "absolute right-4 top-4" ] [ langSwitcher lang ] :: children)


{-| The sidebar beside the page content. The sidebar shows only the tabs the
permissions allow, so the guard and the sidebar agree on what a user can reach.
-}
viewSignedIn : T -> Model -> MeResponse -> Html Msg
viewSignedIn t model me =
    div []
        [ div [ class "flex h-dvh overflow-hidden bg-zinc-50 text-zinc-900" ]
            [ Sidebar.view
                { t = t
                , companyName = me.companyName
                , permissions = me.permissions
                , activePath = pathFor model.route
                , name = me.name
                , email = me.email
                , menuOpen = model.userMenuOpen
                , onToggleMenu = ToggleUserMenu
                , onLogout = Logout
                , onSecurity = OpenAccount Account.PasswordTab
                }
            , div [ class "flex flex-1 flex-col items-center gap-5 overflow-y-auto p-6" ]
                [ div [ class "flex w-full justify-end" ] [ langSwitcher model.lang ]
                , viewPage t model me
                ]
            ]
        , case model.account of
            Just account ->
                Html.map AccountMsg (Account.view t account)

            Nothing ->
                text ""
        ]


viewPage : T -> Model -> MeResponse -> Html Msg
viewPage t model me =
    case model.route of
        Root ->
            RootPage.view t model.draft model.messages DraftChanged SendBroadcast

        Users ->
            Html.map UsersMsg
                (Users.view t
                    model.online
                    { canCreate = List.member "users.create" me.permissions
                    , canDelete = List.member "users.delete" me.permissions
                    , canReadRoles = List.member "users.roles.read" me.permissions
                    , canAssignRoles = List.member "users.roles.assign" me.permissions
                    , canReadPermissions = List.member "users.permissions.read" me.permissions
                    , canGrant = List.member "users.permissions.grant" me.permissions
                    }
                    model.users
                )

        Roles ->
            Html.map RolesMsg
                (Roles.view t
                    { canCreate = List.member "roles.create" me.permissions
                    , canUpdate = List.member "roles.update" me.permissions
                    , canDelete = List.member "roles.delete" me.permissions
                    , canReadPermissions = List.member "roles.permissions.read" me.permissions
                    , canGrant = List.member "roles.permissions.grant" me.permissions
                    }
                    model.roles
                )

        Settings ->
            Html.map SettingsMsg (Settings.view t model.settings)

        _ ->
            viewNotFound t


viewLoading : T -> Html Msg
viewLoading t =
    p [ class "text-sm text-zinc-500" ] [ text t.loading ]


viewNotFound : T -> Html Msg
viewNotFound t =
    div [ class "flex flex-col items-center gap-3" ]
        [ h1 [ class "text-lg font-semibold tracking-tight text-zinc-900" ] [ text t.notFound ]
        , a
            [ href "/"
            , class "text-sm font-medium text-zinc-900 underline underline-offset-4 hover:text-zinc-600"
            ]
            [ text t.goHome ]
        ]
