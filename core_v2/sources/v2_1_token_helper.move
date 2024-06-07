module aptos_names_v2_1::v2_1_token_helper {
    friend aptos_names_v2_1::v2_1_domains;

    use aptos_names_v2_1::v2_1_string_validator;
    use std::error;
    use std::option::{Self, Option};
    use std::string::{Self, String};

    const DOMAIN_DELIMITER: vector<u8> = b".";
    const DOMAIN_SUFFIX: vector<u8> = b".apt";

    /// The collection does not exist. This should never happen.
    const ECOLLECTION_NOT_EXISTS: u64 = 1;
    /// The domain name is not a valid name
    const EDOMAIN_NAME_INVALID: u64 = 2;
    /// The subdomain name is not a valid name
    const ESUBDOMAIN_NAME_INVALID: u64 = 3;

    public(friend) fun get_fully_qualified_domain_name(
        subdomain_name: Option<String>, domain_name: String
    ): String {
        let (domain_is_allowed, _length) = v2_1_string_validator::string_is_allowed(&domain_name);
        assert!(domain_is_allowed, error::invalid_argument(EDOMAIN_NAME_INVALID));
        let subdomain_is_allowed =
            if (option::is_some(&subdomain_name)) {
                let (subdomain_is_allowed, _length) =
                    v2_1_string_validator::string_is_allowed(option::borrow(&subdomain_name));
                subdomain_is_allowed
            } else { true };
        assert!(subdomain_is_allowed, error::invalid_argument(ESUBDOMAIN_NAME_INVALID));
        let combined = combine_sub_and_domain_str(subdomain_name, domain_name);
        string::append_utf8(&mut combined, DOMAIN_SUFFIX);
        combined
    }

    /// Combines a subdomain and domain into a new string, separated by a `.`
    /// Used for building fully qualified domain names (Ex: `{subdomain_name}.{domain_name}.apt`)
    /// If there is no subdomain, just returns the domain name
    public(friend) fun combine_sub_and_domain_str(
        subdomain_name: Option<String>, domain_name: String
    ): String {
        if (option::is_none(&subdomain_name)) {
            return domain_name
        };

        let combined = option::borrow_mut(&mut subdomain_name);
        string::append_utf8(combined, DOMAIN_DELIMITER);
        string::append(combined, domain_name);
        *combined
    }

    #[test]
    fun test_get_fully_qualified_domain_name() {
        assert!(get_fully_qualified_domain_name(option::none(), string::utf8(b"test"))
            == string::utf8(b"test.apt"),
            1);
        assert!(get_fully_qualified_domain_name(option::none(),
                string::utf8(b"wowthisislong"))
            == string::utf8(b"wowthisislong.apt"),
            2);
        assert!(get_fully_qualified_domain_name(option::none(), string::utf8(b"123"))
            == string::utf8(b"123.apt"),
            2);
        assert!(get_fully_qualified_domain_name(option::some(string::utf8(b"sub")),
                string::utf8(b"test"))
            == string::utf8(b"sub.test.apt"),
            2);
    }

    #[test]
    fun test_combine_sub_and_domain_str() {
        let subdomain_name = string::utf8(b"sub");
        let domain_name = string::utf8(b"dom");
        let combined =
            combine_sub_and_domain_str(option::some(subdomain_name), domain_name);
        assert!(combined == string::utf8(b"sub.dom"), 1);
    }

    #[test]
    fun test_combine_sub_and_domain_str_dom_only() {
        let domain_name = string::utf8(b"dom");
        let combined = combine_sub_and_domain_str(option::none(), domain_name);
        assert!(combined == string::utf8(b"dom"), 1);
    }
}
