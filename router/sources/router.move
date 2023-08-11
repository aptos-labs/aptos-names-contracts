module router::router {
    use aptos_framework::account::SignerCapability;
    use aptos_framework::account;
    use aptos_framework::object;
    use aptos_framework::timestamp;
    use std::error;
    use std::option::{Self, Option};
    use std::signer::address_of;
    use std::string::{String};

    // == ROUTER MODE ENUMS ==

    // NOTE: New enums must update is_valid_mode(mode: u8)
    const MODE_V1: u8 = 0;
    const MODE_V1_AND_V2: u8 = 1;
    // const MODE_NEXT: u8 = 2;

    // == ERROR CODES ==

    /// Caller is not the admin
    const ENOT_ADMIN: u64 = 0;
    /// There is no pending admin
    const ENO_PENDING_ADMIN: u64 = 1;
    /// Caller is not the pending admin
    const ENOT_PENDING_ADMIN: u64 = 2;
    /// Provided mode is not supported
    const EINVALID_MODE: u64 = 3;
    /// Function is not implemented in the current mode
    const ENOT_IMPLEMENTED_IN_MODE: u64 = 4;
    /// Seconds is not a multiple of `SECONDS_PER_YEAR`
    const ENOT_MULTIPLE_OF_SECONDS_PER_YEAR: u64 = 5;
    /// Name is not available for registration
    const ENAME_NOT_AVAILABLE: u64 = 6;
    /// Name already expired and is not eligible for migration
    const EMIGRATION_ALREADY_EXPIRED: u64 = 7;
    /// User is not owner of the name
    const ENOT_NAME_OWNER: u64 = 8;

    // == OTHER CONSTANTS ==

    const ROUTER_SIGNER_SEED: vector<u8> = b"ANS ROUTER";
    const SECONDS_PER_YEAR: u64 = 60 * 60 * 24 * 365;
    /// 2024/03/07 23:59:59
    const AUTO_RENEWAL_EXPIRATION_CUTOFF_SEC: u64 = 1709855999;

    // == STRUCTS ==

    struct RouterConfig has key {
        pending_admin_addr: Option<address>,
        admin_addr: address,
        mode: u8,
        signer_cap: SignerCapability,
    }

    fun init_module(deployer: &signer) {
        let (_, signer_cap) = account::create_resource_account(
            deployer,
            ROUTER_SIGNER_SEED,
        );
        move_to(deployer, RouterConfig {
            pending_admin_addr: option::none(),
            admin_addr: address_of(deployer),
            mode: MODE_V1,
            signer_cap,
        });
    }

    // == ROUTER MANAGEMENT WRITE FUNCTIONS ==

    public entry fun set_pending_admin(
        router_admin: &signer,
        pending_admin_addr: address,
    ) acquires RouterConfig {
        let router_config = borrow_global_mut<RouterConfig>(@router);
        assert!(router_config.admin_addr == address_of(router_admin), error::permission_denied(ENOT_ADMIN));
        router_config.pending_admin_addr = option::some(pending_admin_addr);
    }

    public entry fun accept_pending_admin(pending_admin: &signer) acquires RouterConfig {
        let router_config = borrow_global_mut<RouterConfig>(@router);
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
        let router_config = borrow_global_mut<RouterConfig>(@router);
        assert!(router_config.admin_addr == address_of(router_admin), error::permission_denied(ENOT_ADMIN));
        router_config.mode = mode;
    }

    // == ROUTER MANAGEMENT READ FUNCTIONS ==

    inline fun get_router_signer(): signer acquires RouterConfig {
        let router_config = borrow_global<RouterConfig>(@router);
        account::create_signer_with_capability(&router_config.signer_cap)
    }

    inline fun router_signer_addr(): address acquires RouterConfig {
        let router_config = borrow_global<RouterConfig>(@router);
        account::get_signer_capability_address(&router_config.signer_cap)
    }

    inline fun is_valid_mode(mode: u8): bool {
        mode <= MODE_V1_AND_V2
    }

    #[view]
    public fun get_admin_addr(): address acquires RouterConfig {
        let router_config = borrow_global<RouterConfig>(@router);
        router_config.admin_addr
    }

    #[view]
    public fun get_pending_admin_addr(): Option<address> acquires RouterConfig {
        let router_config = borrow_global<RouterConfig>(@router);
        router_config.pending_admin_addr
    }

    #[view]
    public fun get_mode(): u8 acquires RouterConfig {
        let router_config = borrow_global<RouterConfig>(@router);
        router_config.mode
    }

    // == ROUTER WRITE FUNCTIONS ==

    // ==== REGISTRATION ====

    /// If the name is registered and active in v1, then the name can only be registered if we have burned the token (sent it to the router_signer)
    /// Else, the name can only be registered if it is available in v2 (we double check availablity for safety)
    inline fun can_register_in_v2(domain_name: String, subdomain_name: Option<String>): bool {
        if (aptos_names::domains::name_is_registered(
            subdomain_name,
            domain_name
        ) && !aptos_names::domains::name_is_expired(subdomain_name, domain_name)) {
            let (is_burned, _token_id) = aptos_names::domains::is_owner_of_name(
                router_signer_addr(),
                subdomain_name,
                domain_name
            );
            is_burned
        } else {
            aptos_names_v2::domains::name_is_registerable(subdomain_name, domain_name)
        }
    }

    /// @param user The user who is paying for the registration
    /// @param domain_name The domain name to register
    /// @param registration_duration_secs The duration of the registration in seconds
    /// @param target_addr The address the registered name will point to
    /// @param to_addr The address to send the token to. If none, then the user will be the owner. In MODE_V1, receiver must have already opted in to direct_transfer via token::opt_in_direct_transfer
    public entry fun register_domain(
        user: &signer,
        domain_name: String,
        registration_duration_secs: u64,
        target_addr: Option<address>,
        to_addr: Option<address>,
    ) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            assert!(
                registration_duration_secs % SECONDS_PER_YEAR == 0,
                error::invalid_argument(ENOT_MULTIPLE_OF_SECONDS_PER_YEAR)
            );
            aptos_names::domains::register_domain(
                user,
                domain_name,
                ((registration_duration_secs / SECONDS_PER_YEAR) as u8)
            );
        } else if (mode == MODE_V1_AND_V2) {
            assert!(can_register_in_v2(domain_name, option::none()), error::unavailable(ENAME_NOT_AVAILABLE));
            aptos_names_v2::domains::register_domain(
                &get_router_signer(),
                user,
                domain_name,
                registration_duration_secs,
            );
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        };

        // Common operations that handle modes via the router
        if (option::is_some(&target_addr)) {
            set_target_addr(
                user,
                domain_name,
                option::none(),
                *option::borrow(&target_addr)
            );
        };
        if (option::is_some(&to_addr)) {
            transfer_name(user, domain_name, option::none(), *option::borrow(&to_addr));
        };
    }

    /// @param user The user who is paying for the registration
    /// @param domain_name The domain name to register
    /// @param subdomain_name The subdomain name to register
    /// @param expiration_time_sec The expiration time of the registration in seconds
    /// @param _transferrable Whether this subdomain can be transferred by the owner
    /// @param _expiration_policy The expiration policy of the registration. Unused in MODE_V1
    /// @param target_addr The address the registered name will point to
    /// @param to_addr The address to send the token to. If none, then the user will be the owner. In MODE_V1, receiver must have already opted in to direct_transfer via token::opt_in_direct_transfer
    /// @param disable_owner_transfer If set to true, subdomain owner cannot transfer subdomain anymore
    public entry fun register_subdomain(
        user: &signer,
        domain_name: String,
        subdomain_name: String,
        expiration_time_sec: u64,
        _expiration_policy: u8,
        transferrable: bool,
        target_addr: Option<address>,
        to_addr: Option<address>,
    ) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            aptos_names::domains::register_subdomain(user, subdomain_name, domain_name, expiration_time_sec);
        } else if (mode == MODE_V1_AND_V2) {
            assert!(
                can_register_in_v2(domain_name, option::some(subdomain_name)),
                error::unavailable(ENAME_NOT_AVAILABLE)
            );
            aptos_names_v2::domains::register_subdomain(
                &get_router_signer(),
                user,
                domain_name,
                subdomain_name,
                expiration_time_sec,
            )
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        };

        // Common operations that handle modes via the router
        if (option::is_some(&target_addr)) {
            set_target_addr(
                user,
                domain_name,
                option::some(subdomain_name),
                *option::borrow(&target_addr)
            );
        };
        if (option::is_some(&to_addr)) {
            transfer_name(user, domain_name, option::some(subdomain_name), *option::borrow(&to_addr));
        };
        if (mode == MODE_V1_AND_V2) {
            aptos_names_v2::domains::set_subdomain_transferability_as_domain_owner(
                &get_router_signer(),
                user,
                domain_name,
                subdomain_name,
                transferrable
            )
        }
    }

    // ==== MIGRATION ====

    public entry fun migrate_name(
        user: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
    ) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        } else if (mode == MODE_V1_AND_V2) {
            let user_addr = address_of(user);
            let (is_v1_owner, _token_id) = aptos_names::domains::is_owner_of_name(
                user_addr,
                subdomain_name,
                domain_name,
            );
            assert!(is_v1_owner, error::permission_denied(ENOT_NAME_OWNER));

            // Check primary name status
            let maybe_primary_name = aptos_names::domains::get_reverse_lookup(user_addr);
            let is_primary_name = if (option::is_some(&maybe_primary_name)) {
                let (primary_subdomain_name, primary_domain_name) = aptos_names::domains::get_name_record_key_v1_props(
                    &option::extract(&mut maybe_primary_name)
                );
                subdomain_name == primary_subdomain_name && domain_name == primary_domain_name
            } else {
                false
            };

            // Get the v1 token info
            let (
                _property_version,
                expiration_time_sec,
                target_addr
            ) = aptos_names::domains::get_name_record_v1_props_for_name(
                subdomain_name,
                domain_name,
            );
            let tokendata_id = aptos_names::token_helper::build_tokendata_id(
                aptos_names::token_helper::get_token_signer_address(),
                subdomain_name,
                domain_name,
            );
            let token_id = aptos_names::token_helper::latest_token_id(&tokendata_id);

            // Clear the target_addr in v1
            if (option::is_some(&subdomain_name)) {
                aptos_names::domains::clear_subdomain_address(user, *option::borrow(&subdomain_name), domain_name);
            } else {
                aptos_names::domains::clear_domain_address(user, domain_name);
            };

            // Burn by sending to `router_signer`
            let router_signer = get_router_signer();
            aptos_token::token::direct_transfer(
                user,
                &router_signer,
                token_id,
                1,
            );

            // Calculate new expiration
            let now = timestamp::now_seconds();
            assert!(expiration_time_sec >= now, error::invalid_state(EMIGRATION_ALREADY_EXPIRED));
            let new_expiration_time_sec = if (option::is_none(
                &subdomain_name
            ) && expiration_time_sec <= AUTO_RENEWAL_EXPIRATION_CUTOFF_SEC) {
                expiration_time_sec + SECONDS_PER_YEAR
            } else {
                expiration_time_sec
            };

            // Mint token in v2
            aptos_names_v2::domains::register_name_with_router(
                &router_signer,
                user,
                domain_name,
                subdomain_name,
                new_expiration_time_sec - now
            );

            // If the name was a primary name, carry it over (`target_addr` gets automatically carried over too)
            // Else, if there was a target_addr in v1, just carry over the target_addr
            if (is_primary_name) {
                aptos_names_v2::domains::set_reverse_lookup(user, subdomain_name, domain_name)
            } else if (option::is_some(&target_addr)) {
                aptos_names_v2::domains::set_target_address(
                    user,
                    subdomain_name,
                    domain_name,
                    *option::borrow(&target_addr)
                );
            };

            // Carry over the primary name
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    // ==== TRANSFER ====

    public entry fun transfer_name(
        user: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
        to_addr: address
    ) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            // Get the v1 token info
            let (
                _property_version,
                _expiration_time_sec,
                _target_addr
            ) = aptos_names::domains::get_name_record_v1_props_for_name(
                subdomain_name,
                domain_name,
            );
            let tokendata_id = aptos_names::token_helper::build_tokendata_id(
                aptos_names::token_helper::get_token_signer_address(),
                subdomain_name,
                domain_name,
            );
            let token_id = aptos_names::token_helper::latest_token_id(&tokendata_id);
            aptos_token::token::transfer(
                user,
                token_id,
                to_addr,
                1,
            );

            // TODO: Probably good idea to clear entries in v1
        } else if (mode == MODE_V1_AND_V2) {
            let token_addr = aptos_names_v2::domains::token_addr(domain_name, subdomain_name);
            object::transfer(
                user,
                object::address_to_object<aptos_names_v2::domains::NameRecord>(token_addr),
                to_addr,
            );
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    // ==== EXPIRATION ====

    // Not available in MODE_V1
    public entry fun renew_domain(
        _user: &signer,
        _domain_name: String
    ) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            // Will not be implemented in v1
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        } else if (mode == MODE_V1_AND_V2) {
            // TODO: Implement
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    // Not available in MODE_V1
    // ==== REVERSE REGISTRATION ====

    public entry fun set_primary_name(
        user: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
    ) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            let record = aptos_names::domains::create_name_record_key_v1(
                subdomain_name,
                domain_name,
            );
            aptos_names::domains::set_reverse_lookup(user, &record);
        } else if (mode == MODE_V1_AND_V2) {
            aptos_names_v2::domains::set_reverse_lookup(
                user,
                subdomain_name,
                domain_name,
            );
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    public entry fun clear_primary_name(user: &signer) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            aptos_names::domains::clear_reverse_lookup(user);
        } else if (mode == MODE_V1_AND_V2) {
            aptos_names_v2::domains::clear_reverse_lookup(user);
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    // ==== METADATA ====

    public entry fun set_target_addr(
        user: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
        target_addr: address,
    ) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            aptos_names::domains::set_name_address(
                user,
                subdomain_name,
                domain_name,
                target_addr,
            )
        } else if (mode == MODE_V1_AND_V2) {
            aptos_names_v2::domains::set_target_address(
                user,
                subdomain_name,
                domain_name,
                target_addr,
            )
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }


    // ==== DOMAIN ADMIN ====

    /// Not available in MODE_V1
    public entry fun domain_admin_transfer_subdomain(
        domain_admin: &signer,
        domain_name: String,
        subdomain_name: String,
        to_addr: address,
    ) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        } else if (mode == MODE_V1_AND_V2) {
            aptos_names_v2::domains::transfer_subdomain_as_domain_owner(
                &get_router_signer(),
                domain_admin,
                domain_name,
                subdomain_name,
                to_addr,
            )
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    /// Not available in MODE_V1
    public entry fun domain_admin_set_subdomain_transferability(
        domain_admin: &signer,
        domain_name: String,
        subdomain_name: String,
        transferable: bool,
    ) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        } else if (mode == MODE_V1_AND_V2) {
            aptos_names_v2::domains::set_subdomain_transferability_as_domain_owner(
                &get_router_signer(),
                domain_admin,
                domain_name,
                subdomain_name,
                transferable
            )
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    public entry fun domain_admin_set_subdomain_expiration_policy(
        _domain_admin: &signer,
        _domain_name: String,
        _subdomain_name: String,
        _expiration_policy: u8,
    ) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            // Will not be implemented in v1
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        } else if (mode == MODE_V1_AND_V2) {
            // TODO: Implement
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    public entry fun domain_admin_set_subdomain_expiration(
        _domain_admin: &signer,
        _domain_name: String,
        _subdomain_name: String,
        _expiration_time_sec: u64,
    ) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            // Will not be implemented in v1
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        } else if (mode == MODE_V1_AND_V2) {
            // TODO: Implement
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    // == ROUTER READ FUNCTIONS ==

    /// Returns true if the name is tracked in v2
    inline fun exists_in_v2(domain_name: String, subdomain_name: Option<String>): bool {
        object::is_object(aptos_names_v2::domains::token_addr(domain_name, subdomain_name))
    }

    inline fun get_v1_target_addr(
        domain_name: String,
        subdomain_name: Option<String>
    ): Option<address> {
        let (_property_version, _expiration_time_sec, target_addr) = aptos_names::domains::get_name_record_v1_props_for_name(
            subdomain_name,
            domain_name,
        );
        target_addr
    }

    #[view]
    public fun get_target_addr(
        domain_name: String,
        subdomain_name: Option<String>
    ): Option<address> acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            get_v1_target_addr(domain_name, subdomain_name)
        } else if (mode == MODE_V1_AND_V2) {
            if (!exists_in_v2(domain_name, subdomain_name)) {
                get_v1_target_addr(domain_name, subdomain_name)
            } else {
                let (_expiration_time_sec, target_addr) = aptos_names_v2::domains::get_name_record_v1_props_for_name(
                    subdomain_name,
                    domain_name
                );
                target_addr
            }
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    inline fun is_v1_name_owner(
        owner_addr: address,
        domain_name: String,
        subdomain_name: Option<String>,
    ): bool {
        let (is_owner, _token_id) = aptos_names::domains::is_owner_of_name(owner_addr, subdomain_name, domain_name);
        is_owner
    }

    #[view]
    public fun is_name_owner(
        owner_addr: address,
        domain_name: String,
        subdomain_name: Option<String>,
    ): bool acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            is_v1_name_owner(owner_addr, domain_name, subdomain_name)
        } else if (mode == MODE_V1_AND_V2) {
            if (!exists_in_v2(domain_name, subdomain_name)) {
                is_v1_name_owner(owner_addr, domain_name, subdomain_name)
            } else {
                aptos_names_v2::domains::is_owner_of_name(owner_addr, subdomain_name, domain_name)
            }
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    #[view]
    /// Returns a name's owner address. Returns option::none() if there is no owner.
    /// Not available in MODE_v1
    public fun get_owner_addr(
        domain_name: String,
        subdomain_name: Option<String>,
    ): Option<address> acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            // Cannot be implemented with token v1
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        } else if (mode == MODE_V1_AND_V2) {
            aptos_names_v2::domains::name_owner_addr(subdomain_name, domain_name)
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    inline fun get_v1_expiration(
        domain_name: String,
        subdomain_name: Option<String>
    ): u64 {
        let (_property_version, expiration_time_sec, _target_addr) = aptos_names::domains::get_name_record_v1_props_for_name(
            subdomain_name,
            domain_name,
        );
        expiration_time_sec
    }

    #[view]
    public fun get_expiration(
        domain_name: String,
        subdomain_name: Option<String>
    ): u64 acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            get_v1_expiration(domain_name, subdomain_name)
        } else if (mode == MODE_V1_AND_V2) {
            if (!exists_in_v2(domain_name, subdomain_name)) {
                get_v1_expiration(domain_name, subdomain_name)
            } else {
                let (expiration_time_sec, _target_addr) = aptos_names_v2::domains::get_name_record_v1_props_for_name(
                    subdomain_name,
                    domain_name,
                );
                expiration_time_sec
            }
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    #[view]
    /// Not available in MODE_v1
    public fun get_subdomain_expiration_policy(
        _domain_name: String,
        _subdomain_name: Option<String>
    ): u8 acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            // Cannot be implemented with token v1
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        } else if (mode == MODE_V1_AND_V2) {
            // TODO
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    inline fun get_v1_primary_name(
        user_addr: address
    ): (Option<String>, Option<String>) {
        let record = aptos_names::domains::get_reverse_lookup(user_addr);
        if (option::is_none(&record)) {
            (option::none(), option::none())
        } else {
            let (subdomain_name, domain_name) = aptos_names::domains::get_name_record_key_v1_props(
                option::borrow(&record)
            );
            (subdomain_name, option::some(domain_name))
        }
    }

    #[view]
    /// @returns a tuple of (subdomain, domain). If user_addr has no primary name, two `option::none()` will be returned
    public fun get_primary_name(user_addr: address): (Option<String>, Option<String>) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            get_v1_primary_name(user_addr)
        } else if (mode == MODE_V1_AND_V2) {
            if (!aptos_names_v2::domains::reverse_record_exists(user_addr)) {
                get_v1_primary_name(user_addr)
            } else {
                let token_addr = aptos_names_v2::domains::get_reverse_lookup(user_addr);
                if (option::is_none(&token_addr)) {
                    (option::none(), option::none())
                } else {
                    let (subdomain_name, domain_name) = aptos_names_v2::domains::get_record_props_from_token_addr(
                        *option::borrow(&token_addr)
                    );
                    (subdomain_name, option::some(domain_name))
                }
            }
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    // == TEST ==

    #[test_only]
    public fun init_module_for_test(deployer: &signer) {
        init_module(deployer);
    }
}
