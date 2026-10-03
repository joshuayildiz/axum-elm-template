module Main exposing (main)

import Api
import Api.Types exposing (AuthError, UserResponse)
import Browser
import Browser.Navigation as Nav
import Html exposing (Html, a, div, h1, p, text)
import Html.Attributes exposing (class, href)
import Http
import Pages.Login as Login
import Pages.Root as RootPage
import Time
import Url exposing (Url)
import Url.Parser as Parser exposing (Parser)


type Route
    = Root
    | Login
    | NotFound


type Session
    = Checking
    | Anonymous
    | SignedIn UserResponse


type alias LoginModel =
    Login.Model


type alias Model =
    { key : Nav.Key
    , route : Route
    , session : Session
    , login : LoginModel
    }


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url
    | GotMe (Result Http.Error (Result AuthError UserResponse))
    | LoginMsg Login.Msg
    | RootMsg RootPage.Msg
    | Tick


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        , onUrlRequest = LinkClicked
        , onUrlChange = UrlChanged
        }


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    ( { key = key
      , route = toRoute url
      , session = Checking
      , login = Login.init
      }
    , Api.getMe GotMe
    )


routeParser : Parser (Route -> a) a
routeParser =
    Parser.oneOf
        [ Parser.map Root Parser.top
        , Parser.map Login (Parser.s "login")
        ]


toRoute : Url -> Route
toRoute url =
    Maybe.withDefault NotFound (Parser.parse routeParser url)


{-| Send a visitor away from a page the current session is not allowed to see.
An anonymous visitor on a protected page goes to the login page, and a signed-in
visitor on the login page goes to the root. While the session is unknown, wait.
-}
guard : Model -> Cmd Msg
guard model =
    case ( model.route, model.session ) of
        ( Root, Anonymous ) ->
            Nav.replaceUrl model.key "/login"

        ( Login, SignedIn _ ) ->
            Nav.replaceUrl model.key "/"

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
            ( next, guard next )

        GotMe result ->
            let
                session =
                    case result of
                        Ok (Ok user) ->
                            SignedIn user

                        _ ->
                            Anonymous

                next =
                    { model | session = session }
            in
            ( next, guard next )

        LoginMsg subMsg ->
            let
                ( login, cmd, event ) =
                    Login.update subMsg model.login

                next =
                    case event of
                        Login.LoggedIn user ->
                            { model | login = login, session = SignedIn user }

                        Login.NoEvent ->
                            { model | login = login }
            in
            ( next, Cmd.batch [ Cmd.map LoginMsg cmd, guard next ] )

        RootMsg subMsg ->
            let
                ( cmd, event ) =
                    RootPage.update subMsg

                next =
                    case event of
                        RootPage.LoggedOut ->
                            { model | session = Anonymous }

                        RootPage.NoEvent ->
                            model
            in
            ( next, Cmd.batch [ Cmd.map RootMsg cmd, guard next ] )

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


pageTitle : Route -> String
pageTitle route =
    case route of
        Root ->
            "Home"

        Login ->
            "Sign in"

        NotFound ->
            "Not found"


view : Model -> Browser.Document Msg
view model =
    { title = pageTitle model.route
    , body =
        [ div [ class "flex min-h-dvh flex-col items-center justify-center gap-6 bg-zinc-50 px-4 text-zinc-900" ]
            [ viewPage model ]
        ]
    }


{-| Pick the page for the route. The guard has already redirected any session
that is not allowed here, so each page only needs to handle its own session.
-}
viewPage : Model -> Html Msg
viewPage model =
    case model.route of
        NotFound ->
            viewNotFound

        Login ->
            case model.session of
                SignedIn _ ->
                    viewLoading

                _ ->
                    Html.map LoginMsg (Login.view model.login)

        Root ->
            case model.session of
                SignedIn user ->
                    Html.map RootMsg (RootPage.view user)

                _ ->
                    viewLoading


viewLoading : Html Msg
viewLoading =
    p [ class "text-sm text-zinc-500" ] [ text "Loading..." ]


viewNotFound : Html Msg
viewNotFound =
    div [ class "flex flex-col items-center gap-3" ]
        [ h1 [ class "text-lg font-semibold tracking-tight text-zinc-900" ] [ text "Not found" ]
        , a
            [ href "/"
            , class "text-sm font-medium text-zinc-900 underline underline-offset-4 hover:text-zinc-600"
            ]
            [ text "Go home" ]
        ]
