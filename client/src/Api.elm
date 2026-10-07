module Api exposing
    ( assignRole
    , createRole
    , createUser
    , deleteRole
    , deleteUser
    , errorToString
    , getHello
    , getMe
    , getRolePermissions
    , getUserPermissions
    , getUserRolePermissions
    , getUserRoles
    , listPermissions
    , listRoles
    , listUsers
    , login
    , logout
    , removeRole
    , setRolePermissions
    , setUserPermissions
    , updateRole
    )

import Api.Types
    exposing
        ( AuthError
        , CreateRole
        , CreateUser
        , HelloResponse
        , LoginRequest
        , MeResponse
        , PermissionInfo
        , RoleBody
        , RoleResponse
        , UserResponse
        , authErrorDecoder
        , createRoleEncoder
        , createUserEncoder
        , helloResponseDecoder
        , loginRequestEncoder
        , meResponseDecoder
        , permissionInfoDecoder
        , permissionsBodyEncoder
        , resultDecoder
        , roleBodyEncoder
        , roleResponseDecoder
        , userResponseDecoder
        )
import Http
import I18n exposing (T)
import Json.Decode as Decode


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


getMe : (Result Http.Error (Result AuthError MeResponse) -> msg) -> Cmd msg
getMe toMsg =
    Http.get
        { url = "/api/v1/auth/me"
        , expect = Http.expectJson toMsg (resultDecoder authErrorDecoder meResponseDecoder)
        }


listUsers : (Result Http.Error (List UserResponse) -> msg) -> Cmd msg
listUsers toMsg =
    Http.get
        { url = "/api/v1/users"
        , expect = Http.expectJson toMsg (Decode.list userResponseDecoder)
        }


createUser : CreateUser -> (Result Http.Error UserResponse -> msg) -> Cmd msg
createUser body toMsg =
    Http.post
        { url = "/api/v1/users"
        , body = Http.jsonBody (createUserEncoder body)
        , expect = Http.expectJson toMsg userResponseDecoder
        }


deleteUser : String -> (Result Http.Error () -> msg) -> Cmd msg
deleteUser id toMsg =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = "/api/v1/users/" ++ id
        , body = Http.emptyBody
        , expect = Http.expectWhatever toMsg
        , timeout = Nothing
        , tracker = Nothing
        }


assignRole : String -> String -> (Result Http.Error () -> msg) -> Cmd msg
assignRole userId roleId toMsg =
    Http.post
        { url = "/api/v1/users/" ++ userId ++ "/roles"
        , body = Http.jsonBody (roleBodyEncoder { roleId = roleId })
        , expect = Http.expectWhatever toMsg
        }


removeRole : String -> String -> (Result Http.Error () -> msg) -> Cmd msg
removeRole userId roleId toMsg =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = "/api/v1/users/" ++ userId ++ "/roles"
        , body = Http.jsonBody (roleBodyEncoder { roleId = roleId })
        , expect = Http.expectWhatever toMsg
        , timeout = Nothing
        , tracker = Nothing
        }


getUserRoles : String -> (Result Http.Error (List RoleResponse) -> msg) -> Cmd msg
getUserRoles id toMsg =
    Http.get
        { url = "/api/v1/users/" ++ id ++ "/roles"
        , expect = Http.expectJson toMsg (Decode.list roleResponseDecoder)
        }


getUserPermissions : String -> (Result Http.Error (List String) -> msg) -> Cmd msg
getUserPermissions id toMsg =
    Http.get
        { url = "/api/v1/users/" ++ id ++ "/permissions"
        , expect = Http.expectJson toMsg (Decode.list Decode.string)
        }


getUserRolePermissions : String -> (Result Http.Error (List String) -> msg) -> Cmd msg
getUserRolePermissions id toMsg =
    Http.get
        { url = "/api/v1/users/" ++ id ++ "/roles/permissions"
        , expect = Http.expectJson toMsg (Decode.list Decode.string)
        }


listPermissions : (Result Http.Error (List PermissionInfo) -> msg) -> Cmd msg
listPermissions toMsg =
    Http.get
        { url = "/api/v1/rbac/permissions"
        , expect = Http.expectJson toMsg (Decode.list permissionInfoDecoder)
        }


listRoles : (Result Http.Error (List RoleResponse) -> msg) -> Cmd msg
listRoles toMsg =
    Http.get
        { url = "/api/v1/rbac/roles"
        , expect = Http.expectJson toMsg (Decode.list roleResponseDecoder)
        }


createRole : CreateRole -> (Result Http.Error RoleResponse -> msg) -> Cmd msg
createRole body toMsg =
    Http.post
        { url = "/api/v1/rbac/roles"
        , body = Http.jsonBody (createRoleEncoder body)
        , expect = Http.expectJson toMsg roleResponseDecoder
        }


deleteRole : String -> (Result Http.Error () -> msg) -> Cmd msg
deleteRole id toMsg =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = "/api/v1/rbac/roles/" ++ id
        , body = Http.emptyBody
        , expect = Http.expectWhatever toMsg
        , timeout = Nothing
        , tracker = Nothing
        }


updateRole : String -> CreateRole -> (Result Http.Error RoleResponse -> msg) -> Cmd msg
updateRole id body toMsg =
    Http.request
        { method = "PUT"
        , headers = []
        , url = "/api/v1/rbac/roles/" ++ id
        , body = Http.jsonBody (createRoleEncoder body)
        , expect = Http.expectJson toMsg roleResponseDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


getRolePermissions : String -> (Result Http.Error (List String) -> msg) -> Cmd msg
getRolePermissions id toMsg =
    Http.get
        { url = "/api/v1/rbac/roles/" ++ id ++ "/permissions"
        , expect = Http.expectJson toMsg (Decode.list Decode.string)
        }


setRolePermissions : String -> List String -> (Result Http.Error () -> msg) -> Cmd msg
setRolePermissions id permissions toMsg =
    Http.request
        { method = "PUT"
        , headers = []
        , url = "/api/v1/rbac/roles/" ++ id ++ "/permissions"
        , body = Http.jsonBody (permissionsBodyEncoder { permissions = permissions })
        , expect = Http.expectWhatever toMsg
        , timeout = Nothing
        , tracker = Nothing
        }


setUserPermissions : String -> List String -> (Result Http.Error () -> msg) -> Cmd msg
setUserPermissions id permissions toMsg =
    Http.request
        { method = "PUT"
        , headers = []
        , url = "/api/v1/users/" ++ id ++ "/permissions"
        , body = Http.jsonBody (permissionsBodyEncoder { permissions = permissions })
        , expect = Http.expectWhatever toMsg
        , timeout = Nothing
        , tracker = Nothing
        }


logout : (Result Http.Error () -> msg) -> Cmd msg
logout toMsg =
    Http.post
        { url = "/api/v1/auth/logout"
        , body = Http.emptyBody
        , expect = Http.expectWhatever toMsg
        }


errorToString : T -> Http.Error -> String
errorToString t err =
    case err of
        Http.BadUrl url ->
            t.errBadUrlPrefix ++ url

        Http.Timeout ->
            t.errTimeout

        Http.NetworkError ->
            t.errNetwork

        Http.BadStatus code ->
            t.errBadStatusPrefix ++ String.fromInt code ++ "."

        Http.BadBody body ->
            t.errBadBodyPrefix ++ body
