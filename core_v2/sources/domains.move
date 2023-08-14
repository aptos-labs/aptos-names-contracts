module aptos_names_v2::domains {
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::aptos_account;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::timestamp;
    use aptos_names_v2::config;
    use aptos_names_v2::price_model;
    use aptos_names_v2::time_helper;
    use aptos_names_v2::token_helper;
    use aptos_names_v2::utf8_utils;
    use aptos_names_v2::verify;
    use aptos_token_objects::collection;
    use aptos_token_objects::token;
    use std::error;
    use std::option::{Self, Option};
    use std::signer;
    use std::signer::address_of;
    use std::string::{Self, String, utf8};

    const APP_SIGNER_CAPABILITY_SEED: vector<u8> = b"APP_SIGNER_CAPABILITY";
    const BURN_SIGNER_CAPABILITY_SEED: vector<u8> = b"BURN_SIGNER_CAPABILITY";
    const COLLECTION_DESCRIPTION: vector<u8> = b".apt names from Aptos Labs";
    const COLLECTION_URI: vector<u8> = b"https://aptosnames.com";
    /// current MAX_REMAINING_TIME_FOR_RENEWAL_SEC is 6 months
    const MAX_REMAINING_TIME_FOR_RENEWAL_SEC: u64 = 15552000;
    /// 2024/03/07 23:59:59
    const SECONDS_PER_YEAR: u64 = 60 * 60 * 24 * 365;

    /// enums for subdomain expiration policy. update validate_subdomain_expiration_policy() when adding more
    const SUBDOMAIN_POLICY_MANUAL_SET_EXPIRATION: u8 = 0;
    const SUBDOMAIN_POLICY_LOOKUP_DOMAIN_EXPIRATION: u8 = 1;
    // const SUBDOMAIN_POLICY_NEXT_ENUM = 2

    /// The Naming Service contract is not enabled
    const ENOT_ENABLED: u64 = 1;
    /// The caller is not authorized to perform this operation
    const ENOT_AUTHORIZED: u64 = 2;
    /// The name is not available, as it has already been registered
    const ENAME_NOT_AVAILABLE: u64 = 3;
    /// The number of years the caller attempted to register the domain or subdomain for is invalid
    const EINVALID_NUMBER_YEARS: u64 = 4;
    /// The domain does not exist- it is not registered
    const ENAME_NOT_EXIST: u64 = 5;
    /// The caller is not the owner of the domain, and is not authorized to perform the action
    const ENOT_OWNER_OF_DOMAIN: u64 = 6;
    /// The caller is not the owner of the name, and is not authorized to perform the action
    const ENOT_OWNER_OF_NAME: u64 = 9;
    /// The domain name is too long- it exceeds the configured maximum number of utf8 glyphs
    const ENAME_TOO_LONG: u64 = 10;
    /// The domain is too short.
    const ENAME_TOO_SHORT: u64 = 11;
    /// The domain name contains invalid characters: it is not a valid domain name
    const ENAME_HAS_INVALID_CHARACTERS: u64 = 12;
    /// The required `register_domain_signature` for `register_domain` is missing
    const EVALID_SIGNATURE_REQUIRED: u64 = 16;
    /// The name is not expired in 6 months, thus not eligible for renewal
    const EDOMAIN_NOT_AVAILABLE_TO_RENEW: u64 = 18;
    /// The subdomain is not eligible for renewal
    const ESUBDOMAIN_IS_AUTO_RENEW: u64 = 19;
    /// The name is expired
    const ENAME_EXPIRED: u64 = 20;
    /// The subdomain not exist
    const ESUBDOMAIN_NOT_EXIST: u64 = 21;
    /// The name is not a subdomain
    const ENOT_A_SUBDOMAIN: u64 = 22;
    /// The subdomain expiration can be set any date before the domain expiration
    const ESUBDOMAIN_EXPIRATION_PASS_DOMAIN_EXPIRATION: u64 = 24;
    /// The duration must be whole years
    const EDURATION_MUST_BE_WHOLE_YEARS: u64 = 25;
    /// The subdomain expiration policy is included in the enum SUBDOMAIN_POLICY_*
    const ESUBDOMAIN_EXPIRATION_POLICY_INVALID: u64 = 26;
    /// Caller must be the router
    const ENOT_ROUTER: u64 = 27;

    /// Tokens require a signer to create, so this is the signer for the collection
    struct CollectionCapability has key, drop {
        capability: SignerCapability,
        burn_signer_capability: SignerCapability,
    }

    /// Manager object refs
    struct Manager has key {
        /// The extend_ref of the manager object to get its signer
        extend_ref: object::ExtendRef,
    }

    struct SubdomainExt has store {
        subdomain_name: String,
        subdomain_expiration_policy: u8,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct NameRecord has key {
        domain_name: String,
        expiration_time_sec: u64,
        target_address: Option<address>,
        transfer_ref: object::TransferRef,
        // Currently unused, but may be used in the future to extend with more metadata
        extend_ref: object::ExtendRef,
        // Only present for subdomain
        subdomain_ext: Option<SubdomainExt>,
    }

    struct ReverseRecord has key {
        token_addr: Option<address>,
    }

    /// Holder for `SetReverseLookupEvent` events
    struct SetReverseLookupEvents has key, store {
        set_reverse_lookup_events: event::EventHandle<SetReverseLookupEvent>,
    }

    /// Holder for `SetTargetAddressEvent` events
    struct SetTargetAddressEvents has key, store {
        set_name_events: event::EventHandle<SetTargetAddressEvent>,
    }

    /// Holder for `RegisterNameEvent` events
    struct RegisterNameEvents has key, store {
        register_name_events: event::EventHandle<RegisterNameEvent>,
    }

    /// Holder for `RenewNameEvent` events
    struct RenewNameEvents has key, store {
        renew_name_events: event::EventHandle<RenewNameEvent>,
    }

    /// A name has been set as the reverse lookup for an address, or
    /// the reverse lookup has been cleared (in which case |target_address|
    /// will be none)
    struct SetReverseLookupEvent has drop, store {
        domain_name: String,
        subdomain_name: Option<String>,
        target_address: Option<address>,
    }

    /// A name (potentially subdomain) has had it's address changed
    /// This could be to a new address, or it could have been cleared
    struct SetTargetAddressEvent has drop, store {
        domain_name: String,
        subdomain_name: Option<String>,
        expiration_time_secs: u64,
        new_address: Option<address>,
    }

    /// A name (potentially subdomain) has been registered on chain
    /// Includes the the fee paid for the registration, and the expiration time
    struct RegisterNameEvent has drop, store {
        domain_name: String,
        subdomain_name: Option<String>,
        registration_fee_octas: u64,
        expiration_time_secs: u64,
    }

    /// A name (potentially subdomain) has been renewed on chain
    /// Includes the the fee paid for the registration, and the expiration time
    struct RenewNameEvent has drop, store {
        domain_name: String,
        subdomain_name: Option<String>,
        renewal_fee_octas: u64,
        expiration_time_secs: u64,
    }

    /// This is only callable during publishing
    fun init_module(account: &signer) {
        let funds_address: address = @aptos_names_funds;
        let admin_address: address = @aptos_names_admin;

        if (!account::exists_at(funds_address)) {
            aptos_account::create_account(funds_address);
        };

        if (!account::exists_at(admin_address)) {
            aptos_account::create_account(admin_address);
        };

        config::initialize_v1(account, admin_address, funds_address);

        move_to(account, SetTargetAddressEvents {
            set_name_events: account::new_event_handle<SetTargetAddressEvent>(account),
        });

        move_to(account, RegisterNameEvents {
            register_name_events: account::new_event_handle<RegisterNameEvent>(account),
        });

        move_to(account, RenewNameEvents {
            renew_name_events: account::new_event_handle<RenewNameEvent>(account),
        });

        // Create collection + token_resource
        let (token_resource, token_signer_cap) = account::create_resource_account(
            account,
            APP_SIGNER_CAPABILITY_SEED,
        );
        let (_, burn_signer_capability) = account::create_resource_account(
            account,
            BURN_SIGNER_CAPABILITY_SEED,
        );
        move_to(account, CollectionCapability {
            capability: token_signer_cap,
            burn_signer_capability,
        });
        collection::create_unlimited_collection(
            &token_resource,
            utf8(COLLECTION_DESCRIPTION),
            config::domain_collection_name_v1(),
            option::none(),
            utf8(COLLECTION_URI),
        );
        // TODO: figure out description for subdomain collection
        collection::create_unlimited_collection(
            &token_resource,
            utf8(COLLECTION_DESCRIPTION),
            config::subdomain_collection_name_v1(),
            option::none(),
            utf8(COLLECTION_URI),
        );

        move_to(account, SetReverseLookupEvents {
            set_reverse_lookup_events: account::new_event_handle<SetReverseLookupEvent>(account),
        });
    }

    inline fun is_subdomain(subdomain: Option<String>): bool {
        option::is_some(&subdomain)
    }

    public fun get_token_signer_address(): address acquires CollectionCapability {
        account::get_signer_capability_address(&borrow_global<CollectionCapability>(@aptos_names_v2).capability)
    }

    fun get_token_signer(): signer acquires CollectionCapability {
        account::create_signer_with_capability(&borrow_global<CollectionCapability>(@aptos_names_v2).capability)
    }

    public fun get_burn_signer_address(): address acquires CollectionCapability {
        account::get_signer_capability_address(
            &borrow_global<CollectionCapability>(@aptos_names_v2).burn_signer_capability
        )
    }

    fun get_burn_signer(): signer acquires CollectionCapability {
        account::create_signer_with_capability(
            &borrow_global<CollectionCapability>(@aptos_names_v2).burn_signer_capability
        )
    }

    inline fun token_addr_inline(
        domain_name: String,
        subdomain_name: Option<String>,
    ): address acquires CollectionCapability {
        token::create_token_address(
            &get_token_signer_address(),
            &get_collection_name(is_subdomain(subdomain_name)),
            &token_helper::get_fully_qualified_domain_name(subdomain_name, domain_name),
        )
    }

    public fun token_addr(
        domain_name: String,
        subdomain_name: Option<String>,
    ): address acquires CollectionCapability {
        token::create_token_address(
            &get_token_signer_address(),
            &get_collection_name(is_subdomain(subdomain_name)),
            &token_helper::get_fully_qualified_domain_name(subdomain_name, domain_name),
        )
    }

    public fun get_record_obj(
        domain_name: String,
        subdomain_name: Option<String>,
    ): Object<NameRecord> acquires CollectionCapability {
        object::address_to_object(token_addr_inline(domain_name, subdomain_name))
    }

    inline fun get_record(
        domain_name: String,
        subdomain_name: Option<String>,
    ): &NameRecord acquires CollectionCapability, NameRecord {
        borrow_global<NameRecord>(token_addr_inline(domain_name, subdomain_name))
    }

    inline fun get_record_mut(
        domain_name: String,
        subdomain_name: Option<String>,
    ): &mut NameRecord acquires CollectionCapability, NameRecord {
        borrow_global_mut<NameRecord>(token_addr_inline(domain_name, subdomain_name))
    }

    inline fun extract_subdomain_name(record: &NameRecord): Option<String> {
        if (option::is_some(&record.subdomain_ext)) {
            let subdomain_ext = option::borrow(&record.subdomain_ext);
            option::some(subdomain_ext.subdomain_name)
        } else {
            option::none<String>()
        }
    }

    inline fun get_collection_name(is_subdomain: bool): String {
        if (is_subdomain) {
            config::subdomain_collection_name_v1()
        } else {
            config::domain_collection_name_v1()
        }
    }

    /// Creates a token for the name.
    /// NOTE: This function performs no validation checks
    fun create_token(
        to_addr: address,
        domain_name: String,
        subdomain_name: Option<String>,
        expiration_time_sec: u64,
    ) acquires CollectionCapability {
        let name = token_helper::get_fully_qualified_domain_name(subdomain_name, domain_name);
        let description = config::tokendata_description();
        let uri: string::String = config::tokendata_url_prefix();
        string::append(&mut uri, name);

        let subdomain_ext: Option<SubdomainExt>;
        let constructor_ref = token::create_named_token(
            &get_token_signer(),
            get_collection_name(is_subdomain(subdomain_name)),
            description,
            name,
            option::none(),
            uri,
        );
        let token_signer = object::generate_signer(&constructor_ref);
        // creating subdomain
        if (is_subdomain(subdomain_name)) {
            subdomain_ext = option::some(SubdomainExt {
                subdomain_name: option::extract(&mut subdomain_name),
                subdomain_expiration_policy: SUBDOMAIN_POLICY_MANUAL_SET_EXPIRATION,
            });
        }
        // creating domain
        else {
            subdomain_ext = option::none<SubdomainExt>();
        };
        let record = NameRecord {
            domain_name,
            expiration_time_sec,
            target_address: option::none(),
            transfer_ref: object::generate_transfer_ref(&constructor_ref),
            extend_ref: object::generate_extend_ref(&constructor_ref),
            subdomain_ext,
        };
        move_to(&token_signer, record);
        let record_obj = object::object_from_constructor_ref<NameRecord>(&constructor_ref);
        object::transfer(&get_token_signer(), record_obj, to_addr);
    }

    fun register_domain_generic(
        sign: &signer,
        domain_name: String,
        registration_duration_secs: u64,
    ) acquires CollectionCapability, NameRecord, RegisterNameEvents, ReverseRecord, SetTargetAddressEvents, SetReverseLookupEvents {
        validate_registration_duration(registration_duration_secs);

        let subdomain_name = option::none<String>();

        assert!(name_is_registerable(subdomain_name, domain_name), error::invalid_state(ENAME_NOT_AVAILABLE));

        let length = validate_name_string(domain_name);

        let price = price_model::price_for_domain_v1(length, registration_duration_secs);
        coin::transfer<AptosCoin>(sign, config::fund_destination_address(), price);

        register_name_internal(sign, subdomain_name, domain_name, registration_duration_secs, price);

        // Automatically assign primary name if not exists. If exists, just assign target_addr
        let reverse_lookup_result = get_reverse_lookup(address_of(sign));
        if (option::is_none(&reverse_lookup_result)) {
            // If the user has no reverse lookup set, set the user's reverse lookup.
            set_reverse_lookup(sign, subdomain_name, domain_name);
        } else {
            // Automatically set the name to point to the sender's address
            set_target_address_internal(subdomain_name, domain_name, signer::address_of(sign));
        };
    }

    /// A wrapper around `register_name` as an entry function.
    /// Option<String> is not currently serializable, so we have these convenience methods
    public fun register_domain(
        router_signer: &signer,
        sign: &signer,
        domain_name: String,
        registration_duration_secs: u64,
    ) acquires CollectionCapability, NameRecord, RegisterNameEvents, ReverseRecord, SetTargetAddressEvents, SetReverseLookupEvents {
        assert!(address_of(router_signer) == @router_signer, error::permission_denied(ENOT_ROUTER));
        assert!(config::unrestricted_mint_enabled(), error::permission_denied(EVALID_SIGNATURE_REQUIRED));
        register_domain_generic(sign, domain_name, registration_duration_secs);
    }

    public fun register_domain_with_signature(
        router_signer: &signer,
        sign: &signer,
        domain_name: String,
        registration_duration_secs: u64,
        signature: vector<u8>
    ) acquires CollectionCapability, NameRecord, RegisterNameEvents, ReverseRecord, SetTargetAddressEvents, SetReverseLookupEvents {
        assert!(address_of(router_signer) == @router_signer, error::permission_denied(ENOT_ROUTER));
        let account_address = signer::address_of(sign);
        verify::assert_register_domain_signature_verifies(signature, account_address, domain_name);
        register_domain_generic(sign, domain_name, registration_duration_secs);
    }

    /// A wrapper around `register_name` as an entry function.
    /// Option<String> is not currently serializable, so we have these convenience method
    /// `expiration_time_sec` is the timestamp, in seconds, when the name expires
    public fun register_subdomain(
        router_signer: &signer,
        sign: &signer,
        domain_name: String,
        subdomain_name: String,
        expiration_time_sec: u64
    ) acquires CollectionCapability, NameRecord, RegisterNameEvents, ReverseRecord, SetTargetAddressEvents, SetReverseLookupEvents {
        assert!(address_of(router_signer) == @router_signer, error::permission_denied(ENOT_ROUTER));
        assert!(config::is_enabled(), error::unavailable(ENOT_ENABLED));

        assert!(
            name_is_registerable(option::some(subdomain_name), domain_name),
            error::invalid_state(ENAME_NOT_AVAILABLE)
        );

        // We are registering a subdomain name: this has no cost, but is only doable by the owner of the domain
        // TODO: Unit tests for trying to register invalid domains/subdomains
        validate_name_string(subdomain_name);

        // Ensure signer owns the domain we're registering a subdomain for
        let signer_addr = signer::address_of(sign);
        assert!(
            is_owner_of_name(signer_addr, option::none(), domain_name),
            error::permission_denied(ENOT_OWNER_OF_DOMAIN)
        );

        let registration_duration_secs = expiration_time_sec - timestamp::now_seconds();

        let price = price_model::price_for_subdomain_v1(registration_duration_secs);
        coin::transfer<AptosCoin>(sign, config::fund_destination_address(), price);

        register_name_internal(sign, option::some(subdomain_name), domain_name, registration_duration_secs, price);

        // Automatically assign primary name if not exists. If exists, just assign target_addr
        let reverse_lookup_result = get_reverse_lookup(address_of(sign));
        if (option::is_none(&reverse_lookup_result)) {
            // If the user has no reverse lookup set, set the user's reverse lookup.
            set_reverse_lookup(sign, option::some(subdomain_name), domain_name);
        } else {
            // TODO: Investigate why we don't do target_addr auto assignments for subdomains
            // Automatically set the name to point to the sender's address
            // set_target_address_internal(option::some(subdomain_name), domain_name, signer::address_of(sign));
        };
    }

    /// Router-only registration that does not take registration fees. Should only be used for v1=>v2 migrations.
    /// We skip checking registration duration because it is not necessarily a whole number year
    public fun register_name_with_router(
        router_signer: &signer,
        sign: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
        registration_duration_secs: u64,
    ) acquires CollectionCapability, NameRecord, RegisterNameEvents, ReverseRecord, SetReverseLookupEvents {
        assert!(address_of(router_signer) == @router_signer, error::permission_denied(ENOT_ROUTER));
        // For subdomains, this will check that the domain exists first
        assert!(name_is_registerable(subdomain_name, domain_name), error::invalid_state(ENAME_NOT_AVAILABLE));
        if (option::is_some(&subdomain_name)) {
            validate_name_string(*option::borrow(&subdomain_name));
        } else {
            validate_name_string(domain_name);
        };
        register_name_internal(sign, subdomain_name, domain_name, registration_duration_secs, 0);
        // No automatic assignment of primary name / target_addr. These are handled by the router
    }

    /// Register a name. Accepts an optional subdomain name, a required domain name, and a registration duration in seconds.
    /// For domains, the registration duration is only allowed to be in increments of 1 year, for now
    /// Since the owner of the domain is the only one that can create the subdomain, we allow them to decide how long they want the underlying registration to be
    /// The maximum subdomain registration duration is limited to the duration of its parent domain registration
    ///
    /// NOTE: Registration validation already done. This function does not perform any validation on whether `sign` is allowed to register this name
    fun register_name_internal(
        sign: &signer,
        subdomain_name: Option<String>,
        domain_name: String,
        registration_duration_secs: u64,
        price: u64
    ) acquires CollectionCapability, NameRecord, RegisterNameEvents, ReverseRecord, SetReverseLookupEvents {
        // If we're registering a name that exists but is expired, and the expired name is a primary name,
        // it should get removed from being a primary name.
        clear_reverse_lookup_for_name(subdomain_name, domain_name);

        let name_expiration_time_secs = timestamp::now_seconds() + registration_duration_secs;

        // if it is a subdomain, and it expires later than its domain, throw an error
        // This is done here so that any governance moderation activities must abide by the same invariant
        if (is_subdomain(subdomain_name)) {
            let domain_record = get_record(domain_name, option::none());
            assert!(
                name_expiration_time_secs <= domain_record.expiration_time_sec,
                error::out_of_range(ESUBDOMAIN_EXPIRATION_PASS_DOMAIN_EXPIRATION)
            );
        };

        // If the token already exists, transfer it to the signer
        // Else, create a new one and transfer it to the signer
        let account_addr = signer::address_of(sign);
        let token_addr = token_addr_inline(domain_name, subdomain_name);
        if (object::is_object(token_addr)) {
            let record = borrow_global_mut<NameRecord>(token_addr);
            record.expiration_time_sec = name_expiration_time_secs;
            record.target_address = option::none();
            object::transfer_with_ref(object::generate_linear_transfer_ref(&record.transfer_ref), account_addr);
        } else {
            create_token(
                account_addr,
                domain_name,
                subdomain_name,
                name_expiration_time_secs,
            );
        };

        event::emit_event<RegisterNameEvent>(
            &mut borrow_global_mut<RegisterNameEvents>(@aptos_names_v2).register_name_events,
            RegisterNameEvent {
                domain_name,
                subdomain_name,
                registration_fee_octas: price,
                expiration_time_secs: name_expiration_time_secs,
            },
        );
    }

    /// Disable or enable subdomain owner from transferring subdomain as domain owner
    public fun set_subdomain_transferability_as_domain_owner(
        router_signer: &signer,
        sign: &signer,
        domain_name: String,
        subdomain_name: String,
        transferrable: bool
    ) acquires CollectionCapability, NameRecord {
        assert!(address_of(router_signer) == @router_signer, error::permission_denied(ENOT_ROUTER));
        validate_subdomain_registered_and_domain_owned_by_signer(sign, domain_name, subdomain_name);
        let name_record_address = token_addr(domain_name, option::some(subdomain_name));
        let transfer_ref = &borrow_global_mut<NameRecord>(name_record_address).transfer_ref;
        if (transferrable) {
            object::enable_ungated_transfer(transfer_ref);
        } else {
            object::disable_ungated_transfer(transfer_ref);
        }
    }

    /// this is for domain owner to update subdomain expiration time
    public fun transfer_subdomain_as_domain_owner(
        router_signer: &signer,
        sign: &signer,
        domain_name: String,
        subdomain_name: String,
        to_addr: address,
    ) acquires CollectionCapability, NameRecord {
        assert!(address_of(router_signer) == @router_signer, error::permission_denied(ENOT_ROUTER));
        validate_subdomain_registered_and_domain_owned_by_signer(sign, domain_name, subdomain_name);
        let name_record_address = token_addr(domain_name, option::some(subdomain_name));
        let transfer_ref = &borrow_global_mut<NameRecord>(name_record_address).transfer_ref;
        object::transfer_with_ref(object::generate_linear_transfer_ref(transfer_ref), to_addr);
    }

    /// Forcefully set the name of a domain.
    /// This is a privileged operation, used via governance, to forcefully set a domain address
    /// This can be used, for example, to forcefully set the domain for a system address domain
    public entry fun force_set_domain_address(
        sign: &signer,
        domain_name: String,
        new_owner: address
    ) acquires CollectionCapability, NameRecord, ReverseRecord, SetTargetAddressEvents, SetReverseLookupEvents {
        force_set_target_address(sign, domain_name, option::none(), new_owner);
    }

    public entry fun force_set_subdomain_address(
        sign: &signer,
        domain_name: String,
        subdomain_name: String,
        new_owner: address
    ) acquires CollectionCapability, NameRecord, ReverseRecord, SetTargetAddressEvents, SetReverseLookupEvents {
        force_set_target_address(sign, domain_name,option::some(subdomain_name), new_owner);
    }

    fun force_set_target_address(
        sign: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
        new_owner: address
    ) acquires CollectionCapability, NameRecord, ReverseRecord, SetTargetAddressEvents, SetReverseLookupEvents {
        config::assert_signer_is_admin(sign);
        // If the domain name is a primary name, clear it.
        clear_reverse_lookup_for_name(subdomain_name, domain_name);
        set_target_address_internal(subdomain_name, domain_name, new_owner);
    }

    /// Forcefully create or seize a domain name. This is a privileged operation, used via governance.
    /// This can be used, for example, to forcefully create a domain for a system address domain, or to seize a domain from a malicious user.
    /// The `registration_duration_secs` parameter is the number of seconds to register the domain for, but is not limited to the maximum set in the config for domains registered normally.
    /// This allows, for example, to create a domain for the system address for 100 years so we don't need to worry about expiry
    /// Or for moderation purposes, it allows us to seize a racist/harassing domain for 100 years, and park it somewhere safe
    public entry fun force_create_or_seize_domain_name(
        sign: &signer,
        domain_name: String,
        registration_duration_secs: u64
    ) acquires CollectionCapability, NameRecord, RegisterNameEvents, ReverseRecord, SetReverseLookupEvents {
        force_create_or_seize_name(sign, domain_name, option::none(), registration_duration_secs);
    }

    public entry fun force_create_or_seize_subdomain_name(
        sign: &signer,
        domain_name: String,
        subdomain_name: String,
        registration_duration_secs: u64
    ) acquires CollectionCapability, NameRecord, RegisterNameEvents, ReverseRecord, SetReverseLookupEvents {
        force_create_or_seize_name(sign, domain_name, option::some(subdomain_name), registration_duration_secs);
    }

    public fun force_create_or_seize_name(
        sign: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
        registration_duration_secs: u64
    ) acquires CollectionCapability, NameRecord, RegisterNameEvents, ReverseRecord, SetReverseLookupEvents {
        config::assert_signer_is_admin(sign);
        // Register the name
        register_name_internal(sign, subdomain_name, domain_name, registration_duration_secs, 0);
    }

    #[legacy_entry_fun]
    /// This removes a name mapping from the registry; functionally this 'expires' it.
    /// This is a privileged operation, used via governance.
    public entry fun force_clear_registration(
        sign: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
    ) acquires CollectionCapability, NameRecord {
        config::assert_signer_is_admin(sign);
        let record = get_record_mut(domain_name, subdomain_name);
        object::transfer_with_ref(
            object::generate_linear_transfer_ref(&record.transfer_ref),
            get_token_signer_address(),
        );
        record.target_address = option::none();
    }

    public entry fun force_set_name_expiration(
        sign: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
        new_expiration_secs: u64
    ) acquires CollectionCapability, NameRecord {
        // check the signer eligibility
        config::assert_signer_is_admin(sign);

        let record = get_record_mut(domain_name, subdomain_name);
        record.expiration_time_sec = new_expiration_secs;
    }

    public entry fun renew_domain(
        sign: &signer,
        domain_name: String,
        registration_duration_secs: u64,
    ) acquires CollectionCapability, NameRecord, RenewNameEvents {
        // check the domain eligibility
        let length = validate_name_string(domain_name);

        validate_registration_duration(registration_duration_secs);
        assert!(is_domain_in_renewal_window(domain_name), error::invalid_state(EDOMAIN_NOT_AVAILABLE_TO_RENEW));
        let price = price_model::price_for_domain_v1(length, registration_duration_secs);
        // pay the price
        coin::transfer<AptosCoin>(sign, config::fund_destination_address(), price);
        renew_domain_internal(domain_name, registration_duration_secs, price);
    }

    fun renew_domain_internal(
        domain_name: String,
        registration_duration_secs: u64,
        price: u64,
    ) acquires CollectionCapability, NameRecord, RenewNameEvents {
        let record = get_record_mut(domain_name, option::none());
        record.expiration_time_sec = record.expiration_time_sec + registration_duration_secs;

        // log the event
        event::emit_event<RenewNameEvent>(
            &mut borrow_global_mut<RenewNameEvents>(@aptos_names_v2).renew_name_events,
            RenewNameEvent {
                domain_name,
                subdomain_name: option::none(),
                renewal_fee_octas: price,
                expiration_time_secs: record.expiration_time_sec,
            },
        );
    }

    fun validate_registration_duration(
        registration_duration_secs: u64,
    ) {
        assert!(
            registration_duration_secs % SECONDS_PER_YEAR == 0,
            error::invalid_argument(EDURATION_MUST_BE_WHOLE_YEARS)
        );

        let num_years = (time_helper::seconds_to_years(registration_duration_secs) as u8);
        assert!(
            num_years > 0 && num_years <= config::max_number_of_years_registered(),
            error::out_of_range(EINVALID_NUMBER_YEARS)
        );
    }

    public fun transfer_subdomain_owner(
        sign: &signer,
        domain_name: String,
        subdomain_name: String,
        new_owner_address: address,
        new_target_address: Option<address>,
    ) acquires CollectionCapability, NameRecord, ReverseRecord, SetReverseLookupEvents {
        // validate user own the domain
        let signer_addr = signer::address_of(sign);
        assert!(
            is_owner_of_name(signer_addr, option::none(), domain_name),
            error::permission_denied(ENOT_OWNER_OF_DOMAIN)
        );

        let token_addr = token_addr_inline(domain_name, option::some(subdomain_name));
        let record = borrow_global_mut<NameRecord>(token_addr);
        record.target_address = new_target_address;
        object::transfer_with_ref(object::generate_linear_transfer_ref(&record.transfer_ref), new_owner_address);
        // clear the primary name
        clear_reverse_lookup_for_name(option::some(subdomain_name), domain_name);
    }

    fun validate_name_string(
        name: String,
    ): u64 {
        let (is_valid, length) = utf8_utils::string_is_allowed(&name);
        assert!(is_valid, error::invalid_argument(ENAME_HAS_INVALID_CHARACTERS));
        assert!(length <= config::max_domain_length(), error::out_of_range(ENAME_TOO_LONG));
        assert!(length >= config::min_domain_length(), error::out_of_range(ENAME_TOO_SHORT));

        return length
    }

    public fun is_domain_in_renewal_window(
        domain_name: String,
    ): bool acquires CollectionCapability, NameRecord {
        // check if the domain is registered
        assert!(name_is_registered(option::none(), domain_name), error::not_found(ENAME_NOT_EXIST));
        // check if the domain is expired already
        assert!(!name_is_expired(option::none(), domain_name), error::invalid_state(ENAME_EXPIRED));
        let record = get_record_mut(domain_name, option::none());

        record.expiration_time_sec <= timestamp::now_seconds() + MAX_REMAINING_TIME_FOR_RENEWAL_SEC
    }

    /// this is for domain owner to update subdomain expiration time
    public fun set_subdomain_expiration_as_domain_owner(
        sign: &signer,
        domain_name: String,
        subdomain_name: String,
        expiration_time_sec: u64,
    ) acquires CollectionCapability, NameRecord {
        validate_subdomain_registered_and_domain_owned_by_signer(sign, domain_name, subdomain_name);
        // check if the expiration time is valid
        let domain_record = get_record(domain_name, option::none());
        assert!(
            domain_record.expiration_time_sec >= expiration_time_sec,
            error::invalid_state(ESUBDOMAIN_EXPIRATION_PASS_DOMAIN_EXPIRATION)
        );

        // check the auto-renew flag
        let record = get_record_mut(domain_name, option::some(subdomain_name));
        assert!(option::is_some(&record.subdomain_ext), error::invalid_state(ENOT_A_SUBDOMAIN));
            let subdomain_ext = option::borrow(&record.subdomain_ext);
            if (subdomain_ext.subdomain_expiration_policy == SUBDOMAIN_POLICY_LOOKUP_DOMAIN_EXPIRATION) {
                assert!(false, error::invalid_state(ESUBDOMAIN_IS_AUTO_RENEW));
            };

        // manually set the expiration date
        record.expiration_time_sec = expiration_time_sec;
    }

    public fun set_subdomain_renewal_policy(
        sign: &signer,
        domain_name: String,
        subdomain_name: String,
        subdomain_expiration_policy: u8,
    ) acquires CollectionCapability, NameRecord {
        validate_subdomain_registered_and_domain_owned_by_signer(sign, domain_name, subdomain_name);
        validate_subdomain_expiration_policy(subdomain_expiration_policy);
        // if manually set the expiration date
        let record = get_record_mut(domain_name, option::some(subdomain_name));
        // check the auto-renew flag
        if (option::is_none(&record.subdomain_ext)) {
            assert!(false, error::invalid_state(ENOT_A_SUBDOMAIN));
        };
        let subdomain_ext = option::borrow_mut(&mut record.subdomain_ext);
        subdomain_ext.subdomain_expiration_policy = subdomain_expiration_policy;
    }

    public fun get_subdomain_renewal_policy(
        domain_name: String,
        subdomain_name: String,
    ): u8 acquires CollectionCapability, NameRecord {
        let record = get_record_mut(domain_name, option::some(subdomain_name));
        // check the auto-renew flag
        if (!option::is_some(&record.subdomain_ext)) {
            assert!(false, error::invalid_state(ESUBDOMAIN_NOT_EXIST));
        };
        let subdomain_ext = option::borrow_mut(&mut record.subdomain_ext);
        subdomain_ext.subdomain_expiration_policy
    }

    fun validate_subdomain_expiration_policy(
        subdomain_expiration_policy: u8,
    ) {
        // revise the function when adding more policies
        // SUBDOMAIN_POLICY_NEXT_ENUM = 2
        assert!(
            subdomain_expiration_policy == SUBDOMAIN_POLICY_LOOKUP_DOMAIN_EXPIRATION
                || subdomain_expiration_policy == SUBDOMAIN_POLICY_MANUAL_SET_EXPIRATION,
            error::invalid_argument(ESUBDOMAIN_EXPIRATION_POLICY_INVALID)
        );
    }

    fun validate_subdomain_registered_and_domain_owned_by_signer(
        sign: &signer,
        domain_name: String,
        subdomain_name: String,
    ) acquires CollectionCapability, NameRecord {
        assert!(name_is_registered(option::some(subdomain_name), domain_name), error::not_found(ESUBDOMAIN_NOT_EXIST));
        // Ensure signer owns the domain we're registering a subdomain for
        let signer_addr = signer::address_of(sign);
        assert!(
            is_owner_of_name(signer_addr, option::none(), domain_name),
            error::permission_denied(ENOT_OWNER_OF_DOMAIN)
        );
    }

    /// Checks for the name not existing, or being expired
    /// Returns true if the name is available for registration
    /// if this is a subdomain, and the domain doesn't exist, returns false
    /// Doesn't use the `name_is_expired` or `name_is_registered` internally to share the borrow
    public fun name_is_registerable(
        subdomain_name: Option<String>,
        domain_name: String
    ): bool acquires CollectionCapability, NameRecord {
        // If this is a subdomain, ensure the domain also exists, and is not expired: i.e not registerable
        // So if the domain name is registerable, we return false, as the subdomain is not registerable
        if (is_subdomain(subdomain_name) && name_is_registerable(option::none(), domain_name)) {
            return false
        };
        // Check to see if the domain expired
        name_is_expired(subdomain_name, domain_name)
    }

    /// Returns true if the is not registered OR (name is registered AND is expired)
    public fun name_is_expired(
        subdomain_name: Option<String>,
        domain_name: String
    ): bool acquires CollectionCapability, NameRecord {
        if (!name_is_registered(subdomain_name, domain_name)) {
            true
        } else {
            let record = get_record(domain_name, subdomain_name);
            // check the auto-renew flag
            if (option::is_some(&record.subdomain_ext)) {
                let subdomain_ext = option::borrow(&record.subdomain_ext);
                if (subdomain_ext.subdomain_expiration_policy == SUBDOMAIN_POLICY_LOOKUP_DOMAIN_EXPIRATION) {
                    // refer to the expiration date of the domain
                    let domain_record = get_record(domain_name, option::none());
                    return time_is_expired(domain_record.expiration_time_sec)
                }
            };
            time_is_expired(record.expiration_time_sec)
        }
    }

    /// Returns true if the object exists AND the owner is not the `token_resource` account
    public fun name_is_registered(
        subdomain_name: Option<String>,
        domain_name: String
    ): bool acquires CollectionCapability {
        object::is_object(token_addr_inline(domain_name, subdomain_name)) &&
            !object::is_owner(get_record_obj(domain_name, subdomain_name), get_token_signer_address())
    }

    /// Check if the address is the owner of the given aptos_name
    /// If the name does not exist or owner owns an expired name, returns false
    public fun is_owner_of_name(
        owner_addr: address,
        subdomain_name: Option<String>,
        domain_name: String
    ): bool acquires CollectionCapability, NameRecord {
        if (!name_is_registered(subdomain_name, domain_name) || name_is_expired(
            subdomain_name,
            domain_name
        )) return false;
        let record_obj = object::address_to_object<NameRecord>(token_addr_inline(domain_name, subdomain_name));
        object::owns(record_obj, owner_addr)
    }

    /// Returns a name's owner address. Returns option::none() if there is no owner.
    public fun name_owner_addr(
        subdomain_name: Option<String>,
        domain_name: String,
    ): Option<address> acquires CollectionCapability, NameRecord {
        // check if the name is registered
        if (!name_is_registered(subdomain_name, domain_name) || name_is_expired(
            subdomain_name,
            domain_name
        )) return option::none();
        let record_obj = object::address_to_object<NameRecord>(token_addr_inline(domain_name, subdomain_name));
        option::some(object::owner(record_obj))
    }

    /// gets the address pointed to by a given name
    /// Is `Option<address>` because the name may not be registered, or it may not have an address associated with it
    public fun name_resolved_address(
        subdomain_name: Option<String>,
        domain_name: String
    ): Option<address> acquires CollectionCapability, NameRecord {
        // TODO: Why does this not check expiration?
        if (!name_is_registered(subdomain_name, domain_name)) {
            option::none()
        } else {
            let record = get_record(domain_name, subdomain_name);
            return record.target_address
        }
    }

    public entry fun set_domain_address(
        sign: &signer,
        domain_name: String,
        new_address: address
    ) acquires CollectionCapability, NameRecord, ReverseRecord, SetTargetAddressEvents, SetReverseLookupEvents {
        set_target_address(sign, option::none(), domain_name, new_address);
    }

    public entry fun set_subdomain_address(
        sign: &signer,
        subdomain_name: String,
        domain_name: String,
        new_address: address
    ) acquires CollectionCapability, NameRecord, ReverseRecord, SetTargetAddressEvents, SetReverseLookupEvents {
        set_target_address(sign, option::some(subdomain_name), domain_name, new_address);
    }

    public fun set_target_address(
        sign: &signer,
        subdomain_name: Option<String>,
        domain_name: String,
        new_address: address
    ) acquires CollectionCapability, NameRecord, ReverseRecord, SetTargetAddressEvents, SetReverseLookupEvents {
        // If the domain name is a primary name, clear it.
        clear_reverse_lookup_for_name(subdomain_name, domain_name);

        let signer_addr = signer::address_of(sign);
        assert!(
            is_owner_of_name(signer_addr, subdomain_name, domain_name),
            error::permission_denied(ENOT_OWNER_OF_NAME)
        );

        set_target_address_internal(subdomain_name, domain_name, new_address);

        // If the signer's reverse lookup is the domain, and the new address is not the signer, clear the signer's reverse lookup.
        // Example:
        // The current state is bob.apt points to @a and the reverse lookup of @a points to bob.apt.
        // The owner wants to set bob.apt to point to @b.
        // The new state should be bob.apt points to @b, and the reverse lookup of @a should be none.
        // if current state is true, then we must clear
        let maybe_reverse_lookup = get_reverse_lookup(signer_addr);
        if (option::is_none(&maybe_reverse_lookup)) {
            return
        };
        let reverse_name_record = borrow_global<NameRecord>(*option::borrow(&maybe_reverse_lookup));
        let reverse_name_record_subdomain = extract_subdomain_name(reverse_name_record);
        if (reverse_name_record.domain_name == domain_name &&
            reverse_name_record_subdomain == subdomain_name &&
            signer_addr != new_address
        ) {
            clear_reverse_lookup(sign);
        };
    }

    fun set_target_address_internal(
        subdomain_name: Option<String>,
        domain_name: String,
        new_address: address
    ) acquires CollectionCapability, NameRecord, SetTargetAddressEvents {
        assert!(name_is_registered(subdomain_name, domain_name), error::not_found(ENAME_NOT_EXIST));
        let record = get_record_mut(domain_name, subdomain_name);
        record.target_address = option::some(new_address);
        emit_set_target_address_event_v1(
            subdomain_name,
            domain_name,
            record.expiration_time_sec,
            record.target_address,
        );
    }

    public entry fun clear_domain_address(
        sign: &signer,
        domain_name: String
    ) acquires CollectionCapability, NameRecord, ReverseRecord, SetTargetAddressEvents, SetReverseLookupEvents {
        clear_target_address(sign, option::none(), domain_name);
    }

    public entry fun clear_subdomain_address(
        sign: &signer,
        subdomain_name: String,
        domain_name: String
    ) acquires CollectionCapability, NameRecord, ReverseRecord, SetTargetAddressEvents, SetReverseLookupEvents {
        clear_target_address(sign, option::some(subdomain_name), domain_name);
    }

    /// This is a shared entry point for clearing the address of a domain or subdomain
    /// It enforces owner permissions
    fun clear_target_address(
        sign: &signer,
        subdomain_name: Option<String>,
        domain_name: String
    ) acquires CollectionCapability, NameRecord, ReverseRecord, SetTargetAddressEvents, SetReverseLookupEvents {
        assert!(name_is_registered(subdomain_name, domain_name), error::not_found(ENAME_NOT_EXIST));

        let signer_addr = signer::address_of(sign);

        // Clear the reverse lookup if this name is the signer's reverse lookup
        let maybe_reverse_lookup = get_reverse_lookup(signer_addr);
        if (option::is_some(&maybe_reverse_lookup)) {
            let reverse_lookup = option::borrow(&maybe_reverse_lookup);
            if (token_addr_inline(domain_name, subdomain_name) == *reverse_lookup) {
                clear_reverse_lookup_internal(signer_addr);
            };
        };

        // Only the owner or the registered address can clear the address
        let is_owner = is_owner_of_name(signer_addr, subdomain_name, domain_name);
        let is_name_resolved_address = name_resolved_address(subdomain_name, domain_name) == option::some<address>(
            signer_addr
        );

        assert!(is_owner || is_name_resolved_address, error::permission_denied(ENOT_AUTHORIZED));

        let record = get_record_mut(domain_name, subdomain_name);
        record.target_address = option::none();
        emit_set_target_address_event_v1(
            subdomain_name,
            domain_name,
            record.expiration_time_sec,
            record.target_address,
        );
    }

    /// Sets the |account|'s reverse lookup, aka "primary name". This allows a user to specify which of their Aptos Names
    /// is their "primary", so that dapps can display the user's primary name rather than their address.
    public entry fun set_reverse_lookup(
        account: &signer,
        subdomain_name: Option<String>,
        domain_name: String
    ) acquires CollectionCapability, NameRecord, ReverseRecord, SetTargetAddressEvents, SetReverseLookupEvents {
        // Name must be registered before assigning reverse lookup
        if (!name_is_registered(subdomain_name, domain_name)) {
            return
        };
        let token_addr = token_addr_inline(domain_name, subdomain_name);
        set_target_address(account, subdomain_name, domain_name, address_of(account));
        set_reverse_lookup_internal(account, token_addr);
    }

    /// Entry function for clearing reverse lookup.
    public entry fun clear_reverse_lookup_entry(
        account: &signer
    ) acquires NameRecord, ReverseRecord, SetReverseLookupEvents {
        clear_reverse_lookup(account);
    }

    /// Clears the user's reverse lookup.
    public fun clear_reverse_lookup(
        account: &signer
    ) acquires NameRecord, ReverseRecord, SetReverseLookupEvents {
        let account_addr = signer::address_of(account);
        clear_reverse_lookup_internal(account_addr);
    }

    /// Returns the reverse lookup (the token addr) for an address if any.
    public fun get_reverse_lookup(
        account_addr: address
    ): Option<address> acquires ReverseRecord {
        if (exists<ReverseRecord>(account_addr)) {
            let reverse_record = borrow_global<ReverseRecord>(account_addr);
            reverse_record.token_addr
        } else {
            option::none()
        }
    }

    /// Returns whether a ReverseRecord exists at `account_addr`
    public fun reverse_record_exists(account_addr: address): bool {
        exists<ReverseRecord>(account_addr)
    }

    fun set_reverse_lookup_internal(
        account: &signer,
        token_addr: address,
    ) acquires NameRecord, ReverseRecord, SetReverseLookupEvents {
        let account_addr = signer::address_of(account);
        let record = borrow_global<NameRecord>(token_addr);
        let record_obj = object::address_to_object<NameRecord>(token_addr);
        assert!(object::owns(record_obj, account_addr), error::permission_denied(ENOT_AUTHORIZED));

        if (!exists<ReverseRecord>(account_addr)) {
            move_to(account, ReverseRecord {
                token_addr: option::some(token_addr)
            })
        } else {
            let reverse_record = borrow_global_mut<ReverseRecord>(account_addr);
            reverse_record.token_addr = option::some(token_addr);
        };

        emit_set_reverse_lookup_event_v1(
            extract_subdomain_name(record),
            record.domain_name,
            option::some(account_addr)
        );
    }

    fun clear_reverse_lookup_internal(
        account_addr: address
    ) acquires NameRecord, ReverseRecord, SetReverseLookupEvents {
        let maybe_reverse_lookup = get_reverse_lookup(account_addr);
        if (option::is_none(&maybe_reverse_lookup)) {
            return
        };
        let token_addr = *option::borrow(&maybe_reverse_lookup);
        let record = borrow_global<NameRecord>(token_addr);
        let reverse_record = borrow_global_mut<ReverseRecord>(account_addr);
        reverse_record.token_addr = option::none();
        emit_set_reverse_lookup_event_v1(
            extract_subdomain_name(record),
            record.domain_name,
            option::none()
        );
    }

    fun clear_reverse_lookup_for_name(
        subdomain_name: Option<String>,
        domain_name: String
    ) acquires CollectionCapability, NameRecord, ReverseRecord, SetReverseLookupEvents {
        if (!name_is_registered(subdomain_name, domain_name)) return;

        // If the name is a primary name, clear it
        let record = get_record(domain_name, subdomain_name);
        if (option::is_none(&record.target_address)) return;
        let target_address = *option::borrow(&record.target_address);
        let reverse_token_addr = get_reverse_lookup(target_address);
        if (option::is_none(&reverse_token_addr)) return;
        let reverse_record = borrow_global<NameRecord>(*option::borrow(&reverse_token_addr));
        let reverse_record_subdomain_name = extract_subdomain_name(reverse_record);
        if (reverse_record_subdomain_name == subdomain_name && reverse_record.domain_name == domain_name) {
            clear_reverse_lookup_internal(target_address);
        };
    }

    fun emit_set_target_address_event_v1(
        subdomain_name: Option<String>,
        domain_name: String,
        expiration_time_secs: u64,
        new_address: Option<address>
    ) acquires SetTargetAddressEvents {
        let event = SetTargetAddressEvent {
            domain_name,
            subdomain_name,
            expiration_time_secs,
            new_address,
        };

        event::emit_event<SetTargetAddressEvent>(
            &mut borrow_global_mut<SetTargetAddressEvents>(@aptos_names_v2).set_name_events,
            event,
        );
    }

    fun emit_set_reverse_lookup_event_v1(
        subdomain_name: Option<String>,
        domain_name: String,
        target_address: Option<address>
    ) acquires SetReverseLookupEvents {
        let event = SetReverseLookupEvent {
            domain_name,
            subdomain_name,
            target_address,
        };

        event::emit_event<SetReverseLookupEvent>(
            &mut borrow_global_mut<SetReverseLookupEvents>(@aptos_names_v2).set_reverse_lookup_events,
            event,
        );
    }

    public fun get_name_record_v1_props_for_name(
        subdomain: Option<String>,
        domain: String,
    ): (u64, Option<address>) acquires CollectionCapability, NameRecord {
        let record = get_record(domain, subdomain);
        (record.expiration_time_sec, record.target_address)
    }

    public fun get_record_props_from_token_addr(
        token_addr: address
    ): (Option<String>, String) acquires NameRecord {
        let record = borrow_global<NameRecord>(token_addr);
        (extract_subdomain_name(record), record.domain_name)
    }

    /// Given a time, returns true if that time is in the past, false otherwise
    public fun time_is_expired(expiration_time_sec: u64): bool {
        timestamp::now_seconds() >= expiration_time_sec
    }

    #[test_only]
    public fun init_module_for_test(account: &signer) {
        init_module(account);
    }

    #[test_only]
    public fun get_set_target_address_event_v1_count(): u64 acquires SetTargetAddressEvents {
        event::counter(&borrow_global<SetTargetAddressEvents>(@aptos_names_v2).set_name_events)
    }

    #[test_only]
    public fun get_register_name_event_v1_count(): u64 acquires RegisterNameEvents {
        event::counter(&borrow_global<RegisterNameEvents>(@aptos_names_v2).register_name_events)
    }

    #[test_only]
    public fun get_set_reverse_lookup_event_v1_count(): u64 acquires SetReverseLookupEvents {
        event::counter(&borrow_global<SetReverseLookupEvents>(@aptos_names_v2).set_reverse_lookup_events)
    }

    #[test(aptos = @0x1)]
    fun test_time_is_expired(aptos: &signer) {
        timestamp::set_time_has_started_for_testing(aptos);
        // Set the time to a nonzero value to avoid subtraction overflow.
        timestamp::update_global_time_for_test_secs(100);

        // If the expiration time is after the current time, we should return not expired
        assert!(!time_is_expired(timestamp::now_seconds() + 1), 1);

        // If the current time is equal to expiration time, consider it expired
        assert!(time_is_expired(timestamp::now_seconds()), 2);

        // If the expiration time is earlier than the current time, we should return expired
        assert!(time_is_expired(timestamp::now_seconds() - 1), 3);
    }
}
