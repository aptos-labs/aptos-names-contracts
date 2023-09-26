module router::router {
    use aptos_framework::account::SignerCapability;
    use aptos_framework::account;
    use aptos_framework::object;
    use aptos_framework::timestamp;
    use aptos_names::domains;
    use aptos_names_v2_1::v2_1_domains;
    use std::error;
    use std::option::{Self, Option};
    use std::signer;
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
    /// Name already expired and past grace period so is not eligible for migration
    const EMIGRATION_ALREADY_EXPIRED: u64 = 7;
    /// User is not owner of the name
    const ENOT_NAME_OWNER: u64 = 8;
    /// Subdomain has not been migrated
    const ESUBDOMAIN_NOT_MIGRATED: u64 = 9;
    /// Cannot migrate subdomain before migrate domain
    const ECANNOT_MIGRATE_SUBDOMAIN_BEFORE_MIGRATE_DOMAIN: u64 = 10;
    /// Name is already migrated
    const ENAME_ALREADY_MIGRATED: u64 = 11;

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
            admin_addr: signer::address_of(deployer),
            mode: MODE_V1,
            signer_cap,
        });
    }

    // == ROUTER MANAGEMENT WRITE FUNCTIONS ==

    /// Sets the pending admin address. Caller must be the admin
    public entry fun set_pending_admin(
        router_admin: &signer,
        pending_admin_addr: address,
    ) acquires RouterConfig {
        let router_config = borrow_global_mut<RouterConfig>(@router);
        assert!(router_config.admin_addr == signer::address_of(router_admin), error::permission_denied(ENOT_ADMIN));
        router_config.pending_admin_addr = option::some(pending_admin_addr);
    }

    /// Accept to become admin. Caller must be the pending admin
    public entry fun accept_pending_admin(pending_admin: &signer) acquires RouterConfig {
        let router_config = borrow_global_mut<RouterConfig>(@router);
        assert!(
            router_config.pending_admin_addr == option::some(signer::address_of(pending_admin)),
            error::permission_denied(ENOT_PENDING_ADMIN)
        );
        router_config.admin_addr = *option::borrow(&router_config.pending_admin_addr);
        router_config.pending_admin_addr = option::none();
    }

    /// Change the router mode. See ROUTER MODE ENUMS
    public entry fun set_mode(
        router_admin: &signer,
        mode: u8,
    ) acquires RouterConfig {
        assert!(is_valid_mode(mode), error::invalid_argument(EINVALID_MODE));
        let router_config = borrow_global_mut<RouterConfig>(@router);
        assert!(router_config.admin_addr == signer::address_of(router_admin), error::permission_denied(ENOT_ADMIN));
        router_config.mode = mode;
    }

    // == ROUTER MANAGEMENT READ FUNCTIONS ==

    inline fun get_router_signer(): &signer acquires RouterConfig {
        &account::create_signer_with_capability(&borrow_global<RouterConfig>(@router).signer_cap)
    }

    inline fun router_signer_addr(): address acquires RouterConfig {
        signer::address_of(get_router_signer())
    }

    inline fun is_valid_mode(mode: u8): bool {
        mode <= MODE_V1_AND_V2
    }

    #[view]
    public fun get_admin_addr(): address acquires RouterConfig {
        borrow_global<RouterConfig>(@router).admin_addr
    }

    #[view]
    public fun get_pending_admin_addr(): Option<address> acquires RouterConfig {
        borrow_global<RouterConfig>(@router).pending_admin_addr
    }

    #[view]
    public fun get_mode(): u8 acquires RouterConfig {
        borrow_global<RouterConfig>(@router).mode
    }

    // == ROUTER WRITE FUNCTIONS ==

    // ==== REGISTRATION ====

    /// If the name is registerable in v1, the name can only be registered if it is also available in v2.
    /// Else the name is registered and active in v1, then the name can only be registered if we have burned the token
    /// (sent it to the router_signer)
    fun can_register_in_v2(domain_name: String, subdomain_name: Option<String>): bool acquires RouterConfig {
        let registerable_in_v1 = domains::name_is_expired_past_grace(subdomain_name, domain_name);
        if (registerable_in_v1) {
            v2_1_domains::is_name_registerable(domain_name, subdomain_name)
        } else {
            let (is_burned, _token_id) = domains::is_token_owner(
                router_signer_addr(),
                subdomain_name,
                domain_name
            );
            is_burned
        }
    }

    #[view]
    public fun can_register(domain_name: String, subdomain_name: Option<String>): bool acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            domains::name_is_expired_past_grace(subdomain_name, domain_name)
        } else if (mode == MODE_V1_AND_V2) {
            can_register_in_v2(domain_name, subdomain_name)
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    /// @notice Registers a domain name
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
            domains::register_domain(
                user,
                domain_name,
                ((registration_duration_secs / SECONDS_PER_YEAR) as u8)
            );
        } else if (mode == MODE_V1_AND_V2) {
            assert!(can_register_in_v2(domain_name, option::none()), error::unavailable(ENAME_NOT_AVAILABLE));
            v2_1_domains::register_domain(
                get_router_signer(),
                user,
                domain_name,
                registration_duration_secs,
            );
            // Clear the name in v1
            domains::force_clear_registration(get_router_signer(), option::none(), domain_name)
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        };

        // Common operations that handle modes via the router
        let target_addr_with_default = if (option::is_some(&target_addr)) {
            *option::borrow(&target_addr)
        } else {
            signer::address_of(user)
        };
        set_target_addr(
            user,
            domain_name,
            option::none(),
            target_addr_with_default
        );
        if (option::is_some(&to_addr)) {
            transfer_name(user, domain_name, option::none(), *option::borrow(&to_addr));
        };

        // This will set primary name and target address
        set_primary_name_when_register(
            user,
            target_addr,
            to_addr,
            domain_name,
            option::none(),
        );
    }

    fun set_primary_name_when_register(
        user: &signer,
        target_addr: Option<address>,
        to_addr: Option<address>,
        domain_name: String,
        subdomain_name: Option<String>,
    ) acquires RouterConfig {
        let owner_addr = signer::address_of(user);

        // if the owner address is not the buyer address
        if (option::is_some(&to_addr) && to_addr != option::some(owner_addr)) {
            return
        };

        // if the target address is not the buyer address
        if (option::is_some(&target_addr) && target_addr != option::some(owner_addr)) {
            return
        };

        if (!has_primary_name(user)) {
            set_primary_name(user, domain_name, subdomain_name);
        };
    }

    /// @notice Registers a subdomain name
    /// @param user The user who is paying for the registration
    /// @param domain_name The domain name to register
    /// @param subdomain_name The subdomain name to register
    /// @param expiration_time_sec The expiration time of the registration in seconds
    /// @param transferrable Whether this subdomain can be transferred by the owner
    /// @param _expiration_policy The expiration policy of the registration. Unused in MODE_V1
    /// @param target_addr The address the registered name will point to
    /// @param to_addr The address to send the token to. If none, then the user will be the owner. In MODE_V1, receiver must have already opted in to direct_transfer via token::opt_in_direct_transfer
    public entry fun register_subdomain(
        user: &signer,
        domain_name: String,
        subdomain_name: String,
        expiration_time_sec: u64,
        expiration_policy: u8,
        transferrable: bool,
        target_addr: Option<address>,
        to_addr: Option<address>,
    ) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            domains::register_subdomain(user, subdomain_name, domain_name, expiration_time_sec);
        } else if (mode == MODE_V1_AND_V2) {
            assert!(
                can_register_in_v2(domain_name, option::some(subdomain_name)),
                error::unavailable(ENAME_NOT_AVAILABLE)
            );
            v2_1_domains::register_subdomain(
                get_router_signer(),
                user,
                domain_name,
                subdomain_name,
                expiration_time_sec,
            );
            v2_1_domains::set_subdomain_expiration_policy(
                user,
                domain_name,
                subdomain_name,
                expiration_policy,
            );
            domains::force_clear_registration(get_router_signer(), option::some(subdomain_name), domain_name)
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        };

        // Common operations that handle modes via the router
        let target_addr_with_default = if (option::is_some(&target_addr)) {
            *option::borrow(&target_addr)
        } else {
            signer::address_of(user)
        };
        set_target_addr(
            user,
            domain_name,
            option::some(subdomain_name),
            target_addr_with_default
        );
        if (option::is_some(&to_addr)) {
            transfer_name(user, domain_name, option::some(subdomain_name), *option::borrow(&to_addr));
        };
        if (mode == MODE_V1_AND_V2) {
            v2_1_domains::set_subdomain_transferability_as_domain_owner(
                get_router_signer(),
                user,
                domain_name,
                subdomain_name,
                transferrable
            );
        };

        // This will set primary name and target address
        set_primary_name_when_register(
            user,
            target_addr,
            to_addr,
            domain_name,
            option::some(subdomain_name),
        );
    }

    // ==== MIGRATION ====

    /// @notice Migrates a name to the current router mode
    public entry fun migrate_name(
        user: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
    ) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        } else if (mode == MODE_V1_AND_V2) {
            let user_addr = signer::address_of(user);
            // Check name is not already migrated
            assert!(
                !exists_in_v2(domain_name, subdomain_name),
                error::invalid_state(ENAME_ALREADY_MIGRATED)
            );

            let (is_v1_owner, _token_id) = domains::is_token_owner(
                user_addr,
                subdomain_name,
                domain_name,
            );
            assert!(is_v1_owner, error::permission_denied(ENOT_NAME_OWNER));
            assert!(
                !domains::name_is_expired_past_grace(subdomain_name, domain_name),
                error::invalid_state(EMIGRATION_ALREADY_EXPIRED)
            );

            // Check primary name status
            let maybe_primary_name = domains::get_reverse_lookup(user_addr);
            let is_primary_name = if (option::is_some(&maybe_primary_name)) {
                let (primary_subdomain_name, primary_domain_name) = domains::get_name_record_key_v1_props(
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
            ) = domains::get_name_record_v1_props_for_name(
                subdomain_name,
                domain_name,
            );
            let tokendata_id = aptos_names::token_helper::build_tokendata_id(
                aptos_names::token_helper::get_token_signer_address(),
                subdomain_name,
                domain_name,
            );
            let token_id = aptos_names::token_helper::latest_token_id(&tokendata_id);

            // Domain must migrate before subdomain, throw error if this is a subdomain but domain has not been migrated
            if (option::is_some(&subdomain_name)) {
                assert!(
                    exists_in_v2(domain_name, option::none()),
                    error::invalid_state(ECANNOT_MIGRATE_SUBDOMAIN_BEFORE_MIGRATE_DOMAIN)
                )
            };

            // Burn by sending to `router_signer`
            let router_signer = get_router_signer();
            aptos_token::token::direct_transfer(
                user,
                router_signer,
                token_id,
                1,
            );

            // Calculate new expiration. Cases:
            // 1. Name is a subdomain. Migrate the name with the same expiration
            // 2. Name is a domain
            //   a. it expires before AUTO_RENEWAL_EXPIRATION_CUTOFF_SEC. Migrate the name with an extra year to its existing expiration
            //   b. it expires after AUTO_RENEWAL_EXPIRATION_CUTOFF_SEC. Migrate the name with the same expiration
            let now = timestamp::now_seconds();
            let new_expiration_time_sec = if (option::is_some(&subdomain_name)) {
                expiration_time_sec
            } else {
                if (expiration_time_sec <= AUTO_RENEWAL_EXPIRATION_CUTOFF_SEC) {
                    expiration_time_sec + SECONDS_PER_YEAR
                } else {
                    expiration_time_sec
                }
            };

            // Mint token in v2
            v2_1_domains::register_name_with_router(
                router_signer,
                user,
                domain_name,
                subdomain_name,
                new_expiration_time_sec - now
            );

            // If the name was a primary name, carry it over (`target_addr` gets automatically carried over too)
            // Else, if there was a target_addr in v1, just carry over the target_addr
            if (is_primary_name) {
                v2_1_domains::set_reverse_lookup(user, subdomain_name, domain_name)
            } else if (option::is_some(&target_addr)) {
                v2_1_domains::set_target_address(
                    user,
                    domain_name,
                    subdomain_name,
                    *option::borrow(&target_addr)
                );
            };

            // Clear the name in v1. Will also clear the primary name if it was a primary name
            domains::force_clear_registration(router_signer, subdomain_name, domain_name)
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    // ==== EXPIRATION ====

    /// @notice Renews the domain. NOTE 1: Not available in MODE_V1. NOTE 2: Will attempt to migrate the domain. For subdomains, the call may fail unless `migrate_name` is called directly on the subdomain first
    public entry fun renew_domain(
        user: &signer,
        domain_name: String,
        renewal_duration_secs: u64,
    ) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            // Will not be implemented in v1
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        } else if (mode == MODE_V1_AND_V2) {
            migrate_if_eligible(user, domain_name, option::none());
            v2_1_domains::renew_domain(user, domain_name, renewal_duration_secs)
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    fun migrate_if_eligible(
        user: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
    ) acquires RouterConfig {
        // Migrate if the name is still in v1 and is a domain.
        // We do not migrate the subdomain because it might fail due to domain hasn't been migrated
        if (!exists_in_v2(domain_name, subdomain_name) && is_v1_name_owner(
            signer::address_of(user),
            domain_name,
            subdomain_name
        )) {
            if (option::is_none(&subdomain_name)) {
                migrate_name(user, domain_name, subdomain_name);
            } else {
                abort error::invalid_argument(ESUBDOMAIN_NOT_MIGRATED)
            };
        };
    }

    // ==== REVERSE REGISTRATION ====

    fun has_primary_name(
        user: &signer,
    ): bool acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            let reverse_lookup_result = domains::get_reverse_lookup(signer::address_of(user));
            return (option::is_some(&reverse_lookup_result))
        } else if (mode == MODE_V1_AND_V2) {
            // Returns true if the user has a primary name in v1 or v2. We are essentially accepting that a v1 primary name is valid while in MODE_V1_AND_V2.
            // That said, as long as v1 is read-only and changes to v2 names will clear the v1 name, this is acceptable
            return (option::is_some(&domains::get_reverse_lookup(signer::address_of(user))) || option::is_some(&v2_1_domains::get_reverse_lookup(signer::address_of(user))))
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    /// @notice Updates a user's primary name. NOTE: Will attempt to migrate the domain. For subdomains, the call may fail unless `migrate_name` is called directly on the subdomain first
    public entry fun set_primary_name(
        user: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
    ) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            let record = domains::create_name_record_key_v1(
                subdomain_name,
                domain_name,
            );
            domains::set_reverse_lookup(user, &record);
        } else if (mode == MODE_V1_AND_V2) {
            migrate_if_eligible(user, domain_name, subdomain_name);
            // Clear primary name in v1 if exists so we do not have primary name in both v1 and v2
            let user_addr = signer::address_of(user);
            let (_, v1_primary_domain_name) = get_v1_primary_name(user_addr);
            if (option::is_some(&v1_primary_domain_name)) {
                domains::force_clear_reverse_lookup(get_router_signer(), user_addr);
            };
            v2_1_domains::set_reverse_lookup(
                user,
                subdomain_name,
                domain_name,
            );
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    /// @notice Clears a user's primary name. NOTE: Will attempt to migrate the domain. For subdomains, the call may fail unless `migrate_name` is called directly on the subdomain first
    public entry fun clear_primary_name(user: &signer) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            domains::clear_reverse_lookup(user);
        } else if (mode == MODE_V1_AND_V2) {
            // Clear primary name in v1 if exists so we do not have primary name in both v1 and v2
            let (v1_primary_subdomain_name, v1_primary_domain_name) = get_v1_primary_name(signer::address_of(user));
            if (option::is_some(&v1_primary_domain_name)) {
                // If v1 primary name is a domain, migrate it to v2, this will automatically clear it as primary name in v1 and set again in v2
                if (option::is_none(&v1_primary_subdomain_name)) {
                    migrate_name(user, *option::borrow(&v1_primary_domain_name), v1_primary_subdomain_name);
                } else {
                    // else v1 primary name is a subdomain, we only clear it but not migrate it, as migration could fail if its domain has not been migrated
                    domains::clear_reverse_lookup(user);
                };
            };
            v2_1_domains::clear_reverse_lookup(user);
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    // ==== METADATA ====

    /// @notice Update a name's target address. NOTE: Will attempt to migrate the domain. For subdomains, the call may fail unless `migrate_name` is called directly on the subdomain first
    public entry fun set_target_addr(
        user: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
        target_addr: address,
    ) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            domains::set_name_address(
                user,
                subdomain_name,
                domain_name,
                target_addr,
            )
        } else if (mode == MODE_V1_AND_V2) {
            migrate_if_eligible(user, domain_name, subdomain_name);
            v2_1_domains::set_target_address(
                user,
                domain_name,
                subdomain_name,
                target_addr,
            )
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    /// @notice Clear a name's target address. NOTE: Will attempt to migrate the domain. For subdomains, the call may fail unless `migrate_name` is called directly on the subdomain first
    public entry fun clear_target_addr(
        user: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
    ) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            domains::clear_name_address(
                user,
                subdomain_name,
                domain_name,
            )
        } else if (mode == MODE_V1_AND_V2) {
            migrate_if_eligible(user, domain_name, subdomain_name);
            v2_1_domains::clear_target_address(
                user,
                subdomain_name,
                domain_name,
            )
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }


    // ==== DOMAIN ADMIN ====

    /// @notice Transfer a subdomain as the domain admin. NOTE: Not available in MODE_V1
    public entry fun domain_admin_transfer_subdomain(
        domain_admin: &signer,
        domain_name: String,
        subdomain_name: String,
        to_addr: address,
        target_addr: Option<address>,
    ) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        } else if (mode == MODE_V1_AND_V2) {
            v2_1_domains::transfer_subdomain_owner(
                domain_admin,
                domain_name,
                subdomain_name,
                to_addr,
                target_addr,
            )
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    /// @notice Toggle subdomain transferrability as the domain admin. NOTE: Not available in MODE_V1
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
            v2_1_domains::set_subdomain_transferability_as_domain_owner(
                get_router_signer(),
                domain_admin,
                domain_name,
                subdomain_name,
                transferable
            )
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    /// @notice Update subdomain expiration policy as the domain admin. NOTE: Not available in MODE_V1
    public entry fun domain_admin_set_subdomain_expiration_policy(
        domain_admin: &signer,
        domain_name: String,
        subdomain_name: String,
        expiration_policy: u8,
    ) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            // Will not be implemented in v1
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        } else if (mode == MODE_V1_AND_V2) {
            v2_1_domains::set_subdomain_expiration_policy(
                domain_admin,
                domain_name,
                subdomain_name,
                expiration_policy,
            )
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    /// @notice Update subdomain expiration as the domain admin. NOTE: Not available in MODE_V1
    public entry fun domain_admin_set_subdomain_expiration(
        domain_admin: &signer,
        domain_name: String,
        subdomain_name: String,
        expiration_time_sec: u64,
    ) acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            // Will not be implemented in v1
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        } else if (mode == MODE_V1_AND_V2) {
            v2_1_domains::set_subdomain_expiration(
                domain_admin,
                domain_name,
                subdomain_name,
                expiration_time_sec,
            )
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    // == ROUTER READ FUNCTIONS ==

    /// Returns true if the name is tracked in v2
    inline fun exists_in_v2(domain_name: String, subdomain_name: Option<String>): bool {
        object::is_object(v2_1_domains::get_token_addr(domain_name, subdomain_name))
    }

    inline fun get_v1_target_addr(
        domain_name: String,
        subdomain_name: Option<String>
    ): Option<address> {
        if (!aptos_names::domains::name_is_registered(subdomain_name, domain_name)) {
            option::none()
        } else {
            let (_property_version, _expiration_time_sec, target_addr) = aptos_names::domains::get_name_record_v1_props_for_name(
                subdomain_name,
                domain_name,
            );
            target_addr
        }
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
                let target_addr = v2_1_domains::get_target_address(
                    domain_name,
                    subdomain_name,
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
        let (is_owner, _token_id) = domains::is_token_owner(owner_addr, subdomain_name, domain_name);
        is_owner && !domains::name_is_expired(subdomain_name, domain_name)
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
                v2_1_domains::is_token_owner(owner_addr, domain_name, subdomain_name) && !v2_1_domains::is_name_expired(
                    domain_name,
                    subdomain_name
                )
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
            v2_1_domains::get_name_owner_addr(subdomain_name, domain_name)
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    inline fun get_v1_expiration(
        domain_name: String,
        subdomain_name: Option<String>
    ): u64 {
        let (_property_version, expiration_time_sec, _target_addr) = domains::get_name_record_v1_props_for_name(
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
                let expiration_time_sec = v2_1_domains::get_expiration(
                    domain_name,
                    subdomain_name,
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
        domain_name: String,
        subdomain_name: String,
    ): u8 acquires RouterConfig {
        let mode = get_mode();
        if (mode == MODE_V1) {
            // Cannot be implemented with token v1
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        } else if (mode == MODE_V1_AND_V2) {
            v2_1_domains::get_subdomain_renewal_policy(domain_name, subdomain_name)
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    inline fun get_v1_primary_name(
        user_addr: address
    ): (Option<String>, Option<String>) {
        let record = domains::get_reverse_lookup(user_addr);
        if (option::is_none(&record)) {
            (option::none(), option::none())
        } else {
            let (subdomain_name, domain_name) = domains::get_name_record_key_v1_props(
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
            if (!v2_1_domains::reverse_record_exists(user_addr)) {
                get_v1_primary_name(user_addr)
            } else {
                let token_addr = v2_1_domains::get_reverse_lookup(user_addr);
                if (option::is_none(&token_addr)) {
                    (option::none(), option::none())
                } else {
                    let (subdomain_name, domain_name) = v2_1_domains::get_name_props_from_token_addr(
                        *option::borrow(&token_addr)
                    );
                    (subdomain_name, option::some(domain_name))
                }
            }
        } else {
            abort error::not_implemented(ENOT_IMPLEMENTED_IN_MODE)
        }
    }

    // == Transfer helper ==
    fun transfer_name(
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
            ) = domains::get_name_record_v1_props_for_name(
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
            let token_addr = v2_1_domains::get_token_addr(domain_name, subdomain_name);
            object::transfer(
                user,
                object::address_to_object<v2_1_domains::NameRecord>(token_addr),
                to_addr,
            );
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
