module router::router {
    use std::error;
    use std::option::{Self, Option};
    use std::string::{String};

    // == WRITE ==

    // ==== REGISTRATION ====

    public entry fun register_name(
        _user: &signer,
        _domain_name: String,
        _subdomain_name: Option<String>,
    ) {}

    // ==== MIGRATION ====

    public entry fun migrate_name(
        _user: &signer,
        _domain_name: String,
        _subdomain_name: Option<String>,
    ) {}

    // ==== TRANSFER ====

    public entry fun transfer_name(
        _user: &signer,
        _domain_name: String,
        _subdomain_name: Option<String>,
        _to_addr: address
    ) {}

    // ==== EXPIRATION ====

    public entry fun renew_domain(
        _user: &signer,
        _domain_name: String
    ) {}

    public entry fun set_subdomain_expiration_policy(
        _user: &signer,
        _domain_name: String,
        _subdomain_name: String,
    ) {}

    public entry fun set_subdomain_expiration(
        _user: &signer,
        _subdomain_name: String,
        _domain_name: String,
    ) {}

    // ==== REVERSE REGISTRATION ====

    public entry fun set_primary_name(
        _user: &signer,
        _domain_name: String,
        _subdomain_name: Option<String>,
    ) {}

    public entry fun clear_primary_name(_user: &signer) {}

    // ==== METADATA ====

    public entry fun set_target_addr(
        _user: &signer,
        _domain_name: String,
        _subdomain_name: Option<String>,
    ) {}

    // ==== DOMAIN ADMIN ====

    public entry fun domain_admin_transfer_subdomain(
        _domain_admin: &signer,
        _domain_name: String,
        _subdomain_name: String,
    ) {}

    // ==== READ ====

    public fun get_target_addr(
        _domain_name: String,
        _subdomain_name: Option<String>
    ): Option<address> {
        assert!(true, error::not_implemented(0));
        option::some(@0)
    }

    public fun get_owner_addr(
        _domain_name: String,
        _subdomain_name: Option<String>
    ): Option<address> {
        assert!(true, error::not_implemented(0));
        option::some(@0)
    }

    public fun get_expiration(
        _domain_name: String,
        _subdomain_name: Option<String>
    ): u64 {
        assert!(true, error::not_implemented(0));
        0
    }

    public fun get_subdomain_expiration_policy(
        _domain_name: String,
        _subdomain_name: Option<String>
    ): u8 {
        assert!(true, error::not_implemented(0));
        0
    }

    /// @returns a tuple of (domain, subdomain). If user_addr has no primary name, two `option::none()` will be returned
    public fun get_primary_name(_user_addr: address): (Option<String>, Option<String>) {
        assert!(true, error::not_implemented(0));
        (option::none(), option::none())
    }
}
