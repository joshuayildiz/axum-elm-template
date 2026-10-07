port module Main exposing (main)

import Api
import Api.Types exposing (AuthError, MeResponse)
import Browser
import Browser.Navigation as Nav
import Components.LangSwitcher as LangSwitcher
import Components.Sidebar as Sidebar
import Html exposing (Html, a, div, h1, p, text)
import Html.Attributes exposing (class, href)
import Http
import I18n exposing (Lang, T)
import Pages.Login as Login
import Pages.Roles as Roles
import Pages.Root as RootPage
import Pages.Users as Users
import Time
import Url exposing (Url)
import Url.Parser as Parser exposing (Parser)


{-| Persist the chosen language in the browser. `index.html` subscribes and
writes it to `localStorage`.
-}
port setLanguage : String -> Cmd msg


{-| The values `index.html` passes in at startup. `language` is the stored choice
or the browser language.
-}
type alias Flags =
    { language : String }


type Route
    = Root
    | Login
    | Users
    | Roles
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
    , users : Users.Model
    , roles : Roles.Model
    , userMenuOpen : Bool
    }


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url
    | GotMe (Result Http.Error (Result AuthError MeResponse))
    | LoginMsg Login.Msg
    | UsersMsg Users.Msg
    | RolesMsg Roles.Msg
    | SetLang Lang
    | ToggleUserMenu
    | Logout
    | LoggedOut (Result Http.Error ())
    | Tick


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
      , users = Users.init
      , roles = Roles.init
      , userMenuOpen = False
      }
    , Api.getMe GotMe
    )


routeParser : Parser (Route -> a) a
routeParser =
    Parser.oneOf
        [ Parser.map Root Parser.top
        , Parser.map Login (Parser.s "login")
        , Parser.map Users (Parser.s "users")
        , Parser.map Roles (Parser.s "roles")
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

        Login ->
            "/login"

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

                _ ->
                    Nav.replaceUrl model.key "/login"

        SignedIn me ->
            case model.route of
                Login ->
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

                next =
                    { model | session = session }
            in
            ( next, Cmd.batch [ guard next, enter next ] )

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

        SetLang lang ->
            ( { model | lang = lang }, setLanguage (I18n.toString lang) )

        ToggleUserMenu ->
            ( { model | userMenuOpen = not model.userMenuOpen }, Cmd.none )

        Logout ->
            ( model, Api.logout LoggedOut )

        LoggedOut _ ->
            -- End the session on the client even if the request failed. The
            -- cookie is short lived, so a lost call still ends the session soon.
            let
                next =
                    { model | session = Anonymous, userMenuOpen = False }
            in
            ( next, guard next )

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

        Tick ->
            ( model, Api.getMe GotMe )


{-| While signed in, re-check the session every thirty seconds. Each check
renews the token, so an open tab stays signed in past the one-minute token life.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    case model.session of
        SignedIn _ ->
            Time.every 30000 (\_ -> Tick)

        _ ->
            Sub.none


pageTitle : T -> Route -> String
pageTitle t route =
    case route of
        Root ->
            t.home

        Login ->
            t.signIn

        Users ->
            t.users

        Roles ->
            t.roles

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
                        Html.map LoginMsg (Login.view t model.login)

                    _ ->
                        viewLoading t
                ]

        SignedIn me ->
            case model.route of
                Login ->
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
    div [ class "flex h-dvh overflow-hidden bg-zinc-50 text-zinc-900" ]
        [ Sidebar.view
            { t = t
            , permissions = me.permissions
            , activePath = pathFor model.route
            , name = me.name
            , email = me.email
            , menuOpen = model.userMenuOpen
            , onToggleMenu = ToggleUserMenu
            , onLogout = Logout
            }
        , div [ class "flex flex-1 flex-col items-center gap-5 overflow-y-auto p-6" ]
            [ div [ class "flex w-full justify-end" ] [ langSwitcher model.lang ]
            , viewPage t model me
            ]
        ]


viewPage : T -> Model -> MeResponse -> Html Msg
viewPage t model me =
    case model.route of
        Root ->
            RootPage.view t

        Users ->
            Html.map UsersMsg
                (Users.view t
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
