#[derive(Debug, Clone, Copy)]
pub(crate) struct Perm {
    pub(crate) name: &'static str,
    pub(crate) segment: &'static str,
    pub(crate) children: &'static [&'static Perm],
}

impl Perm {
    pub(crate) fn for_each(&'static self, f: &mut impl FnMut(&'static Perm)) {
        f(self);
        for child in self.children {
            child.for_each(f);
        }
    }
}

pub(crate) fn all() -> Vec<&'static Perm> {
    let mut out = Vec::new();
    for root in crate::rbac::ROOT {
        root.for_each(&mut |node| out.push(node));
    }
    out
}

pub(crate) fn find(name: &str) -> Option<&'static Perm> {
    fn search(node: &'static Perm, name: &str) -> Option<&'static Perm> {
        if node.name == name {
            return Some(node);
        }
        for child in node.children {
            if let Some(found) = search(child, name) {
                return Some(found);
            }
        }
        None
    }
    crate::rbac::ROOT
        .iter()
        .copied()
        .find_map(|root| search(root, name))
}

#[macro_export]
macro_rules! __perm_children {
    ( @acc [ $($acc:tt)* ] ; ) => {
        &[ $($acc)* ]
    };
    ( @acc [ $($acc:tt)* ] ; , $($rest:tt)* ) => {
        $crate::__perm_children!( @acc [ $($acc)* ] ; $($rest)* )
    };
    ( @acc [ $($acc:tt)* ] ; $seg:ident { $($children:tt)* } $($rest:tt)* ) => {
        $crate::__perm_children!( @acc [ $($acc)* &$seg::NODE, ] ; $($rest)* )
    };
    ( @acc [ $($acc:tt)* ] ; $seg:ident $($rest:tt)* ) => {
        $crate::__perm_children!( @acc [ $($acc)* &$seg::NODE, ] ; $($rest)* )
    };
}

#[macro_export]
macro_rules! __perm_defs {
    ( [ $($anc:ident)* ] ) => {};

    ( [ $($anc:ident)* ] , $($rest:tt)* ) => {
        $crate::__perm_defs!( [ $($anc)* ] $($rest)* );
    };

    ( [ $($anc:ident)* ] $seg:ident { $($children:tt)* } $($rest:tt)* ) => {
        pub(crate) mod $seg {
            pub(crate) const NAME: &str =
                concat!( $( stringify!($anc), ".", )* stringify!($seg) );
            pub(crate) static NODE: $crate::rbac::permission::Perm = $crate::rbac::permission::Perm {
                name: NAME,
                segment: stringify!($seg),
                children: $crate::__perm_children!( @acc [] ; $($children)* ),
            };
            $crate::__perm_defs!( [ $($anc)* $seg ] $($children)* );
        }
        $crate::__perm_defs!( [ $($anc)* ] $($rest)* );
    };

    ( [ $($anc:ident)* ] $seg:ident $($rest:tt)* ) => {
        pub(crate) mod $seg {
            pub(crate) const NAME: &str =
                concat!( $( stringify!($anc), ".", )* stringify!($seg) );
            pub(crate) static NODE: $crate::rbac::permission::Perm = $crate::rbac::permission::Perm {
                name: NAME,
                segment: stringify!($seg),
                children: &[],
            };
        }
        $crate::__perm_defs!( [ $($anc)* ] $($rest)* );
    };
}

#[macro_export]
macro_rules! permissions {
    ( $($body:tt)* ) => {
        pub(crate) static ROOT: &[&$crate::rbac::permission::Perm] =
            $crate::__perm_children!( @acc [] ; $($body)* );
        $crate::__perm_defs!( [] $($body)* );
    };
}
