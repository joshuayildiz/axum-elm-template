module Api exposing
    ( assignRole
    , changePassword
    , createRole
    , createUser
    , deleteRole
    , deleteUser
    , errorToString
    , getConfig
    , getHello
    , getMe
    , getRolePermissions
    , getUserPermissions
    , getUserRolePermissions
    , getUserRoles
    , listPermissions
    , listRoles
    , listSettings
    , listUsers
    , login
    , loginTotp
    , logout
    , register
    , removeRole
    , setRolePermissions
    , setUserPermissions
    , totpDisable
    , totpEnable
    , totpSetup
    , updateRole
    , updateSettings
    )

import Api.Types
    exposing
        ( AuthError
        , ChangePassword
        , CreateRole
        , CreateUser
        , HelloResponse
        , LoginRequest
        , LoginResponse
        , MeResponse
        , PasswordError
        , PermissionInfo
        , PublicConfig
        , RegisterRequest
        , RegistrationError
        , RoleBody
        , RoleResponse
        , SettingInfo
        , SettingsBody
        , TotpConfirm
        , TotpDisable
        , TotpSetup
        , UserResponse
        , authErrorDecoder
        , changePasswordEncoder
        , createRoleEncoder
        , createUserEncoder
        , helloResponseDecoder
        , loginRequestEncoder
        , loginResponseDecoder
        , meResponseDecoder
        , passwordErrorDecoder
        , permissionInfoDecoder
        , permissionsBodyEncoder
        , publicConfigDecoder
        , registerRequestEncoder
        , registrationErrorDecoder
        , resultDecoder
        , roleBodyEncoder
        , roleResponseDecoder
        , settingInfoDecoder
        , settingsBodyEncoder
        , totpCodeEncoder
        , totpConfirmEncoder
        , totpDisableEncoder
        , totpSetupDecoder
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


getConfig : (Result Http.Error PublicConfig -> msg) -> Cmd msg
getConfig toMsg =
    Http.get
        { url = "/api/v1/config"
        , expect = Http.expectJson toMsg publicConfigDecoder
        }


login : LoginRequest -> (Result Http.Error (Result AuthError LoginResponse) -> msg) -> Cmd msg
login request toMsg =
    Http.post
        { url = "/api/v1/auth/login"
        , body = Http.jsonBody (loginRequestEncoder request)
        , expect = Http.expectJson toMsg (resultDecoder authErrorDecoder loginResponseDecoder)
        }


register : RegisterRequest -> (Result Http.Error (Result RegistrationError UserResponse) -> msg) -> Cmd msg
register body toMsg =
    Http.post
        { url = "/api/v1/auth/register"
        , body = Http.jsonBody (registerRequestEncoder body)
        , expect = Http.expectJson toMsg (resultDecoder registrationErrorDecoder userResponseDecoder)
        }


loginTotp : String -> (Result Http.Error (Result AuthError LoginResponse) -> msg) -> Cmd msg
loginTotp code toMsg =
    Http.post
        { url = "/api/v1/auth/login/totp"
        , body = Http.jsonBody (totpCodeEncoder { code = code })
        , expect = Http.expectJson toMsg (resultDecoder authErrorDecoder loginResponseDecoder)
        }


changePassword : ChangePassword -> (Result Http.Error (Result PasswordError ()) -> msg) -> Cmd msg
changePassword body toMsg =
    Http.post
        { url = "/api/v1/auth/password"
        , body = Http.jsonBody (changePasswordEncoder body)
        , expect = Http.expectJson toMsg (resultDecoder passwordErrorDecoder (Decode.null ()))
        }


totpSetup : (Result Http.Error TotpSetup -> msg) -> Cmd msg
totpSetup toMsg =
    Http.post
        { url = "/api/v1/auth/totp/setup"
        , body = Http.emptyBody
        , expect = Http.expectJson toMsg totpSetupDecoder
        }


totpEnable : TotpConfirm -> (Result Http.Error (Result AuthError ()) -> msg) -> Cmd msg
totpEnable body toMsg =
    Http.post
        { url = "/api/v1/auth/totp/enable"
        , body = Http.jsonBody (totpConfirmEncoder body)
        , expect = Http.expectJson toMsg (resultDecoder authErrorDecoder (Decode.null ()))
        }


totpDisable : TotpDisable -> (Result Http.Error (Result PasswordError ()) -> msg) -> Cmd msg
totpDisable body toMsg =
    Http.post
        { url = "/api/v1/auth/totp/disable"
        , body = Http.jsonBody (totpDisableEncoder body)
        , expect = Http.expectJson toMsg (resultDecoder passwordErrorDecoder (Decode.null ()))
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


listSettings : (Result Http.Error (List SettingInfo) -> msg) -> Cmd msg
listSettings toMsg =
    Http.get
        { url = "/api/v1/settings"
        , expect = Http.expectJson toMsg (Decode.list settingInfoDecoder)
        }


updateSettings : SettingsBody -> (Result Http.Error () -> msg) -> Cmd msg
updateSettings body toMsg =
    Http.request
        { method = "PUT"
        , headers = []
        , url = "/api/v1/settings"
        , body = Http.jsonBody (settingsBodyEncoder body)
        , expect = Http.expectWhatever toMsg
        , timeout = Nothing
        , tracker = Nothing
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
