module Api exposing (errorToString, getHello, getMe, login, logout)

import Api.Types
    exposing
        ( AuthError
        , HelloResponse
        , LoginRequest
        , UserResponse
        , authErrorDecoder
        , helloResponseDecoder
        , loginRequestEncoder
        , resultDecoder
        , userResponseDecoder
        )
import Http


getHello : (Result Http.Error HelloResponse -> msg) -> Cmd msg
getHello toMsg =
    Http.get
        { url = "/api/v1/hello"
        , expect = Http.expectJson toMsg helloResponseDecoder
        }


login : LoginRequest -> (Result Http.Error (Result AuthError UserResponse) -> msg) -> Cmd msg
login request toMsg =
    Http.post
        { url = "/api/v1/auth/login"
        , body = Http.jsonBody (loginRequestEncoder request)
        , expect = Http.expectJson toMsg (resultDecoder authErrorDecoder userResponseDecoder)
        }


getMe : (Result Http.Error (Result AuthError UserResponse) -> msg) -> Cmd msg
getMe toMsg =
    Http.get
        { url = "/api/v1/auth/me"
        , expect = Http.expectJson toMsg (resultDecoder authErrorDecoder userResponseDecoder)
        }


logout : (Result Http.Error () -> msg) -> Cmd msg
logout toMsg =
    Http.post
        { url = "/api/v1/auth/logout"
        , body = Http.emptyBody
        , expect = Http.expectWhatever toMsg
        }


errorToString : Http.Error -> String
errorToString err =
    case err of
        Http.BadUrl url ->
            "Bad URL: " ++ url

        Http.Timeout ->
            "The request timed out."

        Http.NetworkError ->
            "A network error occurred."

        Http.BadStatus code ->
            "The server returned status " ++ String.fromInt code ++ "."

        Http.BadBody body ->
            "The response body did not match: " ++ body
