module Api exposing (errorToString, getHello)

import Api.Types exposing (HelloResponse, helloResponseDecoder)
import Http


getHello : (Result Http.Error HelloResponse -> msg) -> Cmd msg
getHello toMsg =
    Http.get
        { url = "/api/v1/hello"
        , expect = Http.expectJson toMsg helloResponseDecoder
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
