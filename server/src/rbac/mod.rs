pub(crate) mod check;
pub(crate) mod permission;

crate::permissions! {
    users {
        read,
        create,
        update,
        delete,
        roles {
            read,
            assign,
        },
        permissions {
            read,
            grant,
        }
    },
    roles {
        read,
        create,
        update,
        delete,
        permissions {
            read,
            grant,
        }
    },
    settings {
        read,
        update,
    },
}
