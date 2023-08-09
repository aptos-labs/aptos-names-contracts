module router::router {
    use aptos_framework::object::ExtendRef;
    use aptos_framework::object;
    use std::error;
    use std::option::{Self, Option};
    use std::signer::address_of;
    use std::string::{String};

    // == ROUTER MODE ENUMS ==

    // NOTE: New enums must update is_valid_mode(mode: u8)
    const MODE_V1: u8 = 0;
    const MODE_V1_AND_V2: u8 = 1;
    const MODE_V2: u8 = 2;
    // const MODE_NEXT: u8 = 3;

    // == ERROR CODES ==

    const ENOT_ADMIN: u64 = 0;
    const ENO_PENDING_ADMIN: u64 = 1;
    const ENOT_PENDING_ADMIN: u64 = 2;
    const EINVALID_MODE: u64 = 3;

    // == OTHER CONSTANTS ==

    const ROUTER_OBJECT_SEED: vector<u8>  = b"ANS ROUTER";

    // == STRUCTS ==

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct RouterConfig has key {
        pending_admin_addr: Option<address>,
        admin_addr: address,
        mode: u8,
        extend_ref: ExtendRef,
    }

    fun init_module(deployer: &signer) {
        let constructor_ref = object::create_named_object(deployer, ROUTER_OBJECT_SEED);
        let module_signer = object::generate_signer(&constructor_ref);
        move_to(&module_signer, RouterConfig {
            pending_admin_addr: option::none(),
            admin_addr: address_of(deployer),
            mode: MODE_V1,
            extend_ref: object::generate_extend_ref(&constructor_ref),
        });
    }

    // == ROUTER MANAGEMENT WRITE FUNCTIONS ==

    public entry fun set_pending_admin(
        router_admin: &signer,
        pending_admin_addr: address,
    ) acquires RouterConfig {
        let router_config = borrow_global_mut<RouterConfig>(router_config_addr());
        assert!(router_config.admin_addr == address_of(router_admin), error::permission_denied(ENOT_ADMIN));
        router_config.pending_admin_addr = option::some(pending_admin_addr);
    }

    public entry fun accept_pending_admin(pending_admin: &signer) acquires RouterConfig {
        let router_config = borrow_global_mut<RouterConfig>(router_config_addr());
        assert!(option::is_some(&router_config.pending_admin_addr), error::invalid_state(ENO_PENDING_ADMIN));
        let pending_admin_addr = address_of(pending_admin);
        assert!(
            option::extract(&mut router_config.pending_admin_addr) == pending_admin_addr,
            error::permission_denied(ENOT_PENDING_ADMIN)
        );
        router_config.admin_addr = pending_admin_addr;
        router_config.pending_admin_addr = option::none();
    }

    public entry fun set_mode(
        router_admin: &signer,
        mode: u8,
    ) acquires RouterConfig {
        assert!(is_valid_mode(mode), error::invalid_argument(EINVALID_MODE));
        let router_config = borrow_global_mut<RouterConfig>(router_config_addr());
        assert!(router_config.admin_addr == address_of(router_admin), error::permission_denied(ENOT_ADMIN));
        router_config.mode = mode;
    }

    // == ROUTER MANAGEMENT READ FUNCTIONS ==

    inline fun router_config_addr(): address {
        object::create_object_address(&@router, ROUTER_OBJECT_SEED)
    }

    inline fun is_valid_mode(mode: u8): bool {
        mode <= MODE_V2
    }

    public fun get_admin_addr(): address acquires RouterConfig {
        let router_config = borrow_global<RouterConfig>(router_config_addr());
        router_config.admin_addr
    }

    public fun get_pending_admin_addr(): Option<address> acquires RouterConfig {
        let router_config = borrow_global<RouterConfig>(router_config_addr());
        router_config.pending_admin_addr
    }

    public fun get_mode(): u8 acquires RouterConfig {
        let router_config = borrow_global<RouterConfig>(router_config_addr());
        router_config.mode
    }

    // == ROUTER WRITE FUNCTIONS ==

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

    // == ROUTER READ FUNCTIONS ==

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

    // == TEST ==

    #[test_only]
    public fun init_module_for_test(deployer: &signer) {
        init_module(deployer);
    }
}
