module aptos_names_v2_1::v2_1_domains {
    use aptos_framework::account;
    use aptos_framework::aptos_account;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::object::{Self, Object, ExtendRef, TransferRef};
    use aptos_framework::timestamp;
    use aptos_names_v2_1::v2_1_config;
    use aptos_names_v2_1::v2_1_price_model;
    use aptos_names_v2_1::v2_1_token_helper;
    use aptos_names_v2_1::v2_1_string_validator;
    use aptos_token_objects::collection;
    use aptos_token_objects::token;
    use std::error;
    use std::option::{Self, Option};
    use std::signer::address_of;
    use std::signer;
    use std::string::{Self, String, utf8};

    const APP_OBJECT_SEED: vector<u8> = b"ANS v2";
    const COLLECTION_DESCRIPTION: vector<u8> = b".apt names from Aptos Labs";
    const SUBDOMAIN_COLLECTION_DESCRIPTION: vector<u8> = b"subdomain of .apt names from Aptos Labs";
    const COLLECTION_URI: vector<u8> = b"https://aptosnames.com";
    /// current MAX_REMAINING_TIME_FOR_RENEWAL_SEC is 6 months
    const MAX_REMAINING_TIME_FOR_RENEWAL_SEC: u64 = 15552000;
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
    /// Cannot register subdomain while its domain has expired
    const ECANNOT_REGISTER_SUBDOMAIN_WHILE_DOMAIN_HAS_EXPIRED: u64 = 28;
    /// Cannot transfer subdomain while its domain has expired
    const ECANNOT_TRANSFER_SUBDOMAIN_WHILE_DOMAIN_HAS_EXPIRED: u64 = 29;
    /// The domain is expired
    const EDOMAIN_EXPIRED: u64 = 30;
    /// Name is expired and out of grace period
    const ECANNOT_RENEW_NAME_THAT_IS_EXPIRED_AND_PAST_GRACE_PERIOD: u64 = 31;

    #[resource_group(scope = global)]
    struct ObjectGroup { }

    /// Tokens require a signer to create and we want to store global resources. We use object to achieve both
    struct DomainObject has key {
        extend_ref: ExtendRef,
    }

    #[resource_group_member(group = aptos_names_v2_1::v2_1_domains::ObjectGroup)]
    struct NameRecord has key {
        domain_name: String,
        expiration_time_sec: u64,
        target_address: Option<address>,
        transfer_ref: TransferRef,
        registration_time_sec: u64,
        // Currently unused, but may be used in the future to extend with more metadata
        extend_ref: ExtendRef,
    }

    #[resource_group_member(group = aptos_names_v2_1::v2_1_domains::ObjectGroup)]
    /// This is a subdomain extension that is only used for subdomains
    struct SubdomainExt has key {
        subdomain_name: String,
        subdomain_expiration_policy: u8,
    }

    struct ReverseRecord has key {
        token_addr: Option<address>,
    }

    #[resource_group_member(group = aptos_names_v2_1::v2_1_domains::ObjectGroup)]
    /// Holder for `SetReverseLookupEvent` events
    struct SetReverseLookupEvents has key {
        set_reverse_lookup_events: event::EventHandle<SetReverseLookupEvent>,
    }

    #[resource_group_member(group = aptos_names_v2_1::v2_1_domains::ObjectGroup)]
    /// Holder for `SetTargetAddressEvent` events
    struct SetTargetAddressEvents has key {
        set_name_events: event::EventHandle<SetTargetAddressEvent>,
    }

    #[resource_group_member(group = aptos_names_v2_1::v2_1_domains::ObjectGroup)]
    /// Holder for `RegisterNameEvent` events
    struct RegisterNameEvents has key {
        register_name_events: event::EventHandle<RegisterNameEvent>,
    }

    #[resource_group_member(group = aptos_names_v2_1::v2_1_domains::ObjectGroup)]
    /// Holder for `RenewNameEvent` events
    struct RenewNameEvents has key {
        renew_name_events: event::EventHandle<RenewNameEvent>,
    }

    /// A name has been set as the reverse lookup for an address, or
    /// the reverse lookup has been cleared (in which case |target_address|
    /// will be none)
    struct SetReverseLookupEvent has drop, store {
        /// The address this reverse lookup belongs to
        account_addr: address,

        /// Indexer needs knowledge of previous state
        prev_domain_name: Option<String>,
        prev_subdomain_name: Option<String>,
        prev_expiration_time_secs: Option<u64>,

        curr_domain_name: Option<String>,
        curr_subdomain_name: Option<String>,
        curr_expiration_time_secs: Option<u64>,
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

        // Extras for indexing
        target_address: Option<address>,
        is_primary_name: bool,
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

        v2_1_config::initialize_config(account, admin_address, funds_address);

        // Create collection + token_resource
        let constructor_ref = object::create_named_object(
            account,
            APP_OBJECT_SEED,
        );
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let app_signer = &object::generate_signer(&constructor_ref);
        collection::create_unlimited_collection(
            app_signer,
            utf8(COLLECTION_DESCRIPTION),
            v2_1_config::domain_collection_name(),
            option::none(),
            utf8(COLLECTION_URI),
        );
        collection::create_unlimited_collection(
            app_signer,
            utf8(SUBDOMAIN_COLLECTION_DESCRIPTION),
            v2_1_config::subdomain_collection_name(),
            option::none(),
            utf8(COLLECTION_URI),
        );
        aptos_account::create_account(signer::address_of(app_signer));
        move_to(app_signer, SetTargetAddressEvents {
            set_name_events: account::new_event_handle<SetTargetAddressEvent>(app_signer),
        });
        move_to(app_signer, RegisterNameEvents {
            register_name_events: account::new_event_handle<RegisterNameEvent>(app_signer),
        });
        move_to(app_signer, RenewNameEvents {
            renew_name_events: account::new_event_handle<RenewNameEvent>(app_signer),
        });
        move_to(app_signer, SetReverseLookupEvents {
            set_reverse_lookup_events: account::new_event_handle<SetReverseLookupEvent>(app_signer),
        });
        move_to(app_signer, DomainObject {
            extend_ref,
        });
    }

    /// Creates a token for the name.
    /// NOTE: This function performs no validation checks
    fun create_token(
        to_addr: address,
        domain_name: String,
        subdomain_name: Option<String>,
        expiration_time_sec: u64,
    ) acquires DomainObject {
        let name = v2_1_token_helper::get_fully_qualified_domain_name(subdomain_name, domain_name);
        let description = v2_1_config::tokendata_description();
        let uri = v2_1_config::tokendata_url_prefix();
        string::append(&mut uri, name);

        let constructor_ref = token::create_named_token(
            &get_app_signer(),
            get_collection_name(is_subdomain(subdomain_name)),
            description,
            name,
            option::none(),
            uri,
        );
        let token_signer = object::generate_signer(&constructor_ref);
        // creating subdomain
        let record = NameRecord {
            domain_name,
            expiration_time_sec,
            target_address: option::none(),
            transfer_ref: object::generate_transfer_ref(&constructor_ref),
            registration_time_sec: timestamp::now_seconds(),
            extend_ref: object::generate_extend_ref(&constructor_ref),
        };
        move_to(&token_signer, record);
        if (option::is_some(&subdomain_name)) {
            let subdomain_ext = SubdomainExt {
                subdomain_name: *option::borrow(&subdomain_name),
                subdomain_expiration_policy: SUBDOMAIN_POLICY_MANUAL_SET_EXPIRATION,
            };
            move_to(&token_signer, subdomain_ext);
        };
        let record_obj = object::object_from_constructor_ref<NameRecord>(&constructor_ref);
        object::transfer(&get_app_signer(), record_obj, to_addr);
    }

    // === REGISTER NAME ===

    /// A wrapper around `register_name` as an entry function.
    /// Option<String> is not currently serializable, so we have these convenience methods
    public fun register_domain(
        router_signer: &signer,
        sign: &signer,
        domain_name: String,
        registration_duration_secs: u64,
    ) acquires DomainObject, NameRecord, SubdomainExt, RegisterNameEvents, ReverseRecord, SetReverseLookupEvents {
        assert!(address_of(router_signer) == @router_signer, error::permission_denied(ENOT_ROUTER));

        validate_registration_duration(registration_duration_secs);

        let subdomain_name = option::none<String>();

        assert!(is_name_registerable(domain_name, subdomain_name), error::invalid_state(ENAME_NOT_AVAILABLE));

        let length = validate_name_string(domain_name);

        let price = v2_1_price_model::price_for_domain(length, registration_duration_secs);
        coin::transfer<AptosCoin>(sign, v2_1_config::fund_destination_address(), price);

        register_name_internal(sign, subdomain_name, domain_name, registration_duration_secs, price);
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
    ) acquires DomainObject, NameRecord, SubdomainExt, RegisterNameEvents, ReverseRecord, SetReverseLookupEvents {
        assert!(address_of(router_signer) == @router_signer, error::permission_denied(ENOT_ROUTER));
        assert!(v2_1_config::is_enabled(), error::unavailable(ENOT_ENABLED));

        assert!(
            is_name_registerable(domain_name, option::some(subdomain_name)),
            error::invalid_state(ENAME_NOT_AVAILABLE)
        );

        // We are registering a subdomain name: this has no cost, but is only doable by the owner of the domain
        validate_name_string(subdomain_name);

        // Ensure signer owns the domain we're registering a subdomain for
        let signer_addr = signer::address_of(sign);
        assert!(
            is_token_owner(signer_addr, domain_name, option::none()),
            error::permission_denied(ENOT_OWNER_OF_DOMAIN)
        );
        assert!(
            !is_name_expired(domain_name, option::none()),
            error::permission_denied(ECANNOT_REGISTER_SUBDOMAIN_WHILE_DOMAIN_HAS_EXPIRED)
        );

        let registration_duration_secs = expiration_time_sec - timestamp::now_seconds();

        let price = v2_1_price_model::price_for_subdomain(registration_duration_secs);
        coin::transfer<AptosCoin>(sign, v2_1_config::fund_destination_address(), price);

        register_name_internal(sign, option::some(subdomain_name), domain_name, registration_duration_secs, price);
    }

    /// Router-only registration that does not take registration fees. Should only be used for v1=>v2 migrations.
    /// We skip checking registration duration because it is not necessarily a whole number year
    public fun register_name_with_router(
        router_signer: &signer,
        sign: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
        registration_duration_secs: u64,
    ) acquires DomainObject, NameRecord, SubdomainExt, RegisterNameEvents, ReverseRecord, SetReverseLookupEvents {
        assert!(address_of(router_signer) == @router_signer, error::permission_denied(ENOT_ROUTER));
        // For subdomains, this will check that the domain exists first
        assert!(is_name_registerable(domain_name, subdomain_name), error::invalid_state(ENAME_NOT_AVAILABLE));
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
    ) acquires DomainObject, NameRecord, SubdomainExt, RegisterNameEvents, ReverseRecord, SetReverseLookupEvents {
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
        let token_addr = get_token_addr_inline(domain_name, subdomain_name);
        if (object::is_object(token_addr)) {
            let record = borrow_global_mut<NameRecord>(token_addr);
            record.expiration_time_sec = name_expiration_time_secs;
            record.target_address = option::none();
            record.registration_time_sec = timestamp::now_seconds();
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
            &mut borrow_global_mut<RegisterNameEvents>(get_app_signer_addr()).register_name_events,
            RegisterNameEvent {
                domain_name,
                subdomain_name,
                registration_fee_octas: price,
                expiration_time_secs: name_expiration_time_secs,
            },
        );
    }

    // === RENEW DOMAIN ===

    public fun renew_domain(
        sign: &signer,
        domain_name: String,
        renewal_duration_secs: u64,
    ) acquires NameRecord, SubdomainExt, RenewNameEvents, ReverseRecord {
        // check the domain eligibility
        let length = validate_name_string(domain_name);

        validate_registration_duration(renewal_duration_secs);
        assert!(is_domain_in_renewal_window(domain_name), error::invalid_state(EDOMAIN_NOT_AVAILABLE_TO_RENEW));
        let price = v2_1_price_model::price_for_domain(length, renewal_duration_secs);
        // pay the price
        coin::transfer<AptosCoin>(sign, v2_1_config::fund_destination_address(), price);
        let record = get_record_mut(domain_name, option::none());
        record.expiration_time_sec = record.expiration_time_sec + renewal_duration_secs;

        // Idea here is that if this is a primary name, then the target_addr's reverse lookup should point back to this domain
        let is_primary_name = if (option::is_some(&record.target_address)) {
            let maybe_reverse_record = if (exists<ReverseRecord>(*option::borrow(&record.target_address))) {
                let reverse_record = borrow_global<ReverseRecord>(*option::borrow(&record.target_address));
                reverse_record.token_addr
            } else {
                option::none()
            };
            if (option::is_some(&maybe_reverse_record)) {
                let reverse_record_addr = *option::borrow(&maybe_reverse_record);
                get_token_addr_inline(domain_name, option::none()) == reverse_record_addr
            } else {
                false
            }
        } else {
            false
        };

        // log the event
        event::emit_event<RenewNameEvent>(
            &mut borrow_global_mut<RenewNameEvents>(get_app_signer_addr()).renew_name_events,
            RenewNameEvent {
                domain_name,
                subdomain_name: option::none(),
                renewal_fee_octas: price,
                expiration_time_secs: record.expiration_time_sec,
                target_address: record.target_address,
                is_primary_name,
            },
        );
    }

    // === SUBDOMAIN MANAGEMENT ===

    /// Disable or enable subdomain owner from transferring subdomain as domain owner
    public fun set_subdomain_transferability_as_domain_owner(
        router_signer: &signer,
        sign: &signer,
        domain_name: String,
        subdomain_name: String,
        transferrable: bool
    ) acquires NameRecord, SubdomainExt {
        assert!(address_of(router_signer) == @router_signer, error::permission_denied(ENOT_ROUTER));
        validate_subdomain_registered_and_domain_owned_by_signer(sign, domain_name, subdomain_name);
        let name_record_address = get_token_addr(domain_name, option::some(subdomain_name));
        let transfer_ref = &borrow_global_mut<NameRecord>(name_record_address).transfer_ref;
        if (transferrable) {
            object::enable_ungated_transfer(transfer_ref);
        } else {
            object::disable_ungated_transfer(transfer_ref);
        }
    }

    public fun transfer_subdomain_owner(
        sign: &signer,
        domain_name: String,
        subdomain_name: String,
        new_owner_address: address,
        new_target_address: Option<address>,
    ) acquires NameRecord, SubdomainExt, ReverseRecord, SetReverseLookupEvents {
        // validate user own the domain
        let signer_addr = signer::address_of(sign);
        assert!(
            is_token_owner(signer_addr, domain_name, option::none()),
            error::permission_denied(ENOT_OWNER_OF_DOMAIN)
        );
        assert!(
            !is_name_expired(domain_name, option::none()),
            error::permission_denied(ECANNOT_TRANSFER_SUBDOMAIN_WHILE_DOMAIN_HAS_EXPIRED)
        );

        let token_addr = get_token_addr_inline(domain_name, option::some(subdomain_name));
        let record = borrow_global_mut<NameRecord>(token_addr);
        record.target_address = new_target_address;
        object::transfer_with_ref(object::generate_linear_transfer_ref(&record.transfer_ref), new_owner_address);
        // clear the primary name
        clear_reverse_lookup_for_name(option::some(subdomain_name), domain_name);
    }

    /// this is for domain owner to update subdomain expiration time
    public fun set_subdomain_expiration(
        domain_admin: &signer,
        domain_name: String,
        subdomain_name: String,
        expiration_time_sec: u64,
    ) acquires NameRecord, SubdomainExt {
        validate_subdomain_registered_and_domain_owned_by_signer(domain_admin, domain_name, subdomain_name);
        // check if the expiration time is valid
        let domain_record = get_record(domain_name, option::none());
        assert!(
            domain_record.expiration_time_sec >= expiration_time_sec,
            error::invalid_state(ESUBDOMAIN_EXPIRATION_PASS_DOMAIN_EXPIRATION)
        );

        // check the auto-renew flag
        let subdomain_name_opt = option::some(subdomain_name);
        let token_addr = get_token_addr_inline(domain_name, subdomain_name_opt);
        let record = borrow_global_mut<NameRecord>(get_token_addr_inline(domain_name, subdomain_name_opt));
        assert!(exists<SubdomainExt>(token_addr), error::invalid_state(ENOT_A_SUBDOMAIN));
        let subdomain_ext = borrow_global<SubdomainExt>(token_addr);
        assert!(
            subdomain_ext.subdomain_expiration_policy != SUBDOMAIN_POLICY_LOOKUP_DOMAIN_EXPIRATION,
            error::invalid_state(ESUBDOMAIN_IS_AUTO_RENEW)
        );

        // manually set the expiration date
        record.expiration_time_sec = expiration_time_sec;
    }

    public fun set_subdomain_expiration_policy(
        domain_admin: &signer,
        domain_name: String,
        subdomain_name: String,
        subdomain_expiration_policy: u8,
    ) acquires NameRecord, SubdomainExt {
        validate_subdomain_registered_and_domain_owned_by_signer(domain_admin, domain_name, subdomain_name);
        validate_subdomain_expiration_policy(subdomain_expiration_policy);
        // if manually set the expiration date
        let token_addr = get_token_addr_inline(domain_name, option::some(subdomain_name));
        assert!(exists<SubdomainExt>(token_addr), error::invalid_state(ENOT_A_SUBDOMAIN));
        let subdomain_ext = borrow_global_mut<SubdomainExt>(token_addr);
        subdomain_ext.subdomain_expiration_policy = subdomain_expiration_policy;
    }

    public fun get_subdomain_renewal_policy(
        domain_name: String,
        subdomain_name: String,
    ): u8 acquires SubdomainExt {
        let token_addr = get_token_addr_inline(domain_name, option::some(subdomain_name));
        assert!(exists<SubdomainExt>(token_addr), error::invalid_state(ESUBDOMAIN_NOT_EXIST));
        let subdomain_ext = borrow_global_mut<SubdomainExt>(token_addr);
        subdomain_ext.subdomain_expiration_policy
    }

    // === TARGET ADDRESS FUNCTIONS ===

    public fun set_target_address(
        sign: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
        new_address: address
    ) acquires NameRecord, SubdomainExt, ReverseRecord, SetTargetAddressEvents, SetReverseLookupEvents {
        // If the domain name is a primary name, clear it.
        clear_reverse_lookup_for_name(subdomain_name, domain_name);

        let signer_addr = signer::address_of(sign);
        assert!(
            is_token_owner(signer_addr, domain_name, subdomain_name),
            error::permission_denied(ENOT_OWNER_OF_NAME)
        );
        assert!(
            !is_name_expired(domain_name, subdomain_name),
            error::permission_denied(ENAME_EXPIRED)
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
        let reverse_name_record_addr = *option::borrow(&maybe_reverse_lookup);
        let reverse_name_record = borrow_global<NameRecord>(reverse_name_record_addr);
        let reverse_name_record_subdomain = extract_subdomain_name(reverse_name_record_addr);
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
    ) acquires NameRecord, SetTargetAddressEvents {
        assert!(is_name_registered(domain_name, subdomain_name), error::not_found(ENAME_NOT_EXIST));
        let record = get_record_mut(domain_name, subdomain_name);
        record.target_address = option::some(new_address);
        emit_set_target_address_event(
            subdomain_name,
            domain_name,
            record.expiration_time_sec,
            record.target_address,
        );
    }

    /// This is a shared entry point for clearing the address of a domain or subdomain
    /// It enforces owner permissions
    public fun clear_target_address(
        sign: &signer,
        subdomain_name: Option<String>,
        domain_name: String
    ) acquires NameRecord, SubdomainExt, ReverseRecord, SetTargetAddressEvents, SetReverseLookupEvents {
        assert!(is_name_registered(domain_name, subdomain_name), error::not_found(ENAME_NOT_EXIST));

        let signer_addr = signer::address_of(sign);

        // Clear the reverse lookup if this name is the signer's reverse lookup
        let maybe_reverse_lookup = get_reverse_lookup(signer_addr);
        if (option::is_some(&maybe_reverse_lookup)) {
            let reverse_lookup = option::borrow(&maybe_reverse_lookup);
            if (get_token_addr_inline(domain_name, subdomain_name) == *reverse_lookup) {
                clear_reverse_lookup_internal(signer_addr);
            };
        };

        // Only the owner or the registered address can clear the address
        let is_owner = is_token_owner(signer_addr, domain_name, subdomain_name);
        let is_expired = is_name_expired(domain_name, subdomain_name);
        let is_target_address = get_target_address(domain_name, subdomain_name) == option::some<address>(
            signer_addr
        );

        assert!((is_owner && !is_expired) || is_target_address, error::permission_denied(ENOT_AUTHORIZED));

        let record = get_record_mut(domain_name, subdomain_name);
        record.target_address = option::none();
        emit_set_target_address_event(
            subdomain_name,
            domain_name,
            record.expiration_time_sec,
            record.target_address,
        );
    }

    // === PRIMARY NAMES ===

    /// Sets the |account|'s reverse lookup, aka "primary name". This allows a user to specify which of their Aptos Names
    /// is their "primary", so that dapps can display the user's primary name rather than their address.
    public entry fun set_reverse_lookup(
        account: &signer,
        subdomain_name: Option<String>,
        domain_name: String
    ) acquires NameRecord, SubdomainExt, ReverseRecord, SetTargetAddressEvents, SetReverseLookupEvents {
        // Name must be registered before assigning reverse lookup
        assert!(is_name_registered(domain_name, subdomain_name), error::not_found(ENAME_NOT_EXIST));
        let token_addr = get_token_addr_inline(domain_name, subdomain_name);
        set_target_address(account, domain_name, subdomain_name, address_of(account));
        set_reverse_lookup_internal(account, token_addr);
    }

    /// Clears the user's reverse lookup.
    public fun clear_reverse_lookup(
        account: &signer
    ) acquires NameRecord, SubdomainExt, ReverseRecord, SetReverseLookupEvents {
        let account_addr = signer::address_of(account);
        clear_reverse_lookup_internal(account_addr);
    }

    /// Returns the reverse lookup (the token addr) for an address if any.
    public fun get_reverse_lookup(
        account_addr: address
    ): Option<address> acquires ReverseRecord, NameRecord {
        if (!exists<ReverseRecord>(account_addr)) {
            return option::none()
        };
        let reverse_record = borrow_global<ReverseRecord>(account_addr);
        if (option::is_none(&reverse_record.token_addr)) {
            return option::none()
        };
        let token_addr = *option::borrow(&reverse_record.token_addr);
        let record = borrow_global<NameRecord>(token_addr);

        // check if record is expired
        if (is_time_expired(record.expiration_time_sec)) {
            return option::none()
        };
        return reverse_record.token_addr
    }

    /// Returns whether a ReverseRecord exists at `account_addr`
    public fun reverse_record_exists(account_addr: address): bool {
        exists<ReverseRecord>(account_addr)
    }

    fun set_reverse_lookup_internal(
        account: &signer,
        token_addr: address,
    ) acquires NameRecord, SubdomainExt, ReverseRecord, SetReverseLookupEvents {
        let account_addr = signer::address_of(account);
        let record_obj = object::address_to_object<NameRecord>(token_addr);
        assert!(object::owns(record_obj, account_addr), error::permission_denied(ENOT_AUTHORIZED));

        let prev_subdomain_name = option::none<String>();
        let prev_domain_name = option::none<String>();
        let prev_expiration_time_secs = option::none<u64>();
        if (!exists<ReverseRecord>(account_addr)) {
            move_to(account, ReverseRecord {
                token_addr: option::some(token_addr)
            })
        } else {
            let reverse_record = borrow_global_mut<ReverseRecord>(account_addr);

            // Lookup the previous reverse lookup
            if (option::is_some(&reverse_record.token_addr)) {
                let prev_token_addr = *option::borrow(&reverse_record.token_addr);
                let prev_record = borrow_global_mut<NameRecord>(prev_token_addr);
                prev_subdomain_name = extract_subdomain_name(prev_token_addr);
                prev_domain_name = option::some(prev_record.domain_name);
                // TODO: Should this be dynamic for subdomains?
                prev_expiration_time_secs = option::some(prev_record.expiration_time_sec);
            };
            reverse_record.token_addr = option::some(token_addr);
        };

        let record = borrow_global<NameRecord>(token_addr);
        emit_set_reverse_lookup_event(
            account_addr,
            prev_subdomain_name,
            prev_domain_name,
            prev_expiration_time_secs,
            extract_subdomain_name(token_addr),
            option::some(record.domain_name),
            option::some(record.expiration_time_sec)
        );
    }

    fun clear_reverse_lookup_internal(
        account_addr: address
    ) acquires NameRecord, SubdomainExt, ReverseRecord, SetReverseLookupEvents {
        let maybe_reverse_lookup = get_reverse_lookup(account_addr);
        if (option::is_none(&maybe_reverse_lookup)) {
            return
        };

        // Lookup the previous reverse lookup
        let token_addr = *option::borrow(&maybe_reverse_lookup);
        let record = borrow_global_mut<NameRecord>(token_addr);
        let prev_subdomain_name = extract_subdomain_name(token_addr);
        let prev_domain_name = option::some(record.domain_name);
        let prev_expiration_time_secs = option::some(record.expiration_time_sec);

        // Clear the reverse lookup
        let reverse_record = borrow_global_mut<ReverseRecord>(account_addr);
        reverse_record.token_addr = option::none();

        emit_set_reverse_lookup_event(
            account_addr,
            prev_subdomain_name,
            prev_domain_name,
            prev_expiration_time_secs,
            option::none(),
            option::none(),
            option::none()
        );
    }

    fun clear_reverse_lookup_for_name(
        subdomain_name: Option<String>,
        domain_name: String
    ) acquires NameRecord, SubdomainExt, ReverseRecord, SetReverseLookupEvents {
        if (!is_name_registered(domain_name, subdomain_name)) return;

        // If the name is a primary name, clear it
        let record = get_record(domain_name, subdomain_name);
        if (option::is_none(&record.target_address)) return;
        let target_address = *option::borrow(&record.target_address);
        let reverse_token_addr = get_reverse_lookup(target_address);
        if (option::is_none(&reverse_token_addr)) return;
        let reverse_record_addr = *option::borrow(&reverse_token_addr);
        let reverse_record = borrow_global<NameRecord>(reverse_record_addr);
        let reverse_record_subdomain_name = extract_subdomain_name(reverse_record_addr);
        if (reverse_record_subdomain_name == subdomain_name && reverse_record.domain_name == domain_name) {
            clear_reverse_lookup_internal(target_address);
        };
    }

    // === FORCE FUNCTIONS VIA GOVERNANCE ===

    /// Forcefully set the name of a domain.
    /// This is a privileged operation, used via governance, to forcefully set a domain address
    /// This can be used, for example, to forcefully set the domain for a system address domain
    public entry fun force_set_target_address(
        sign: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
        new_owner: address
    ) acquires NameRecord, SubdomainExt, ReverseRecord, SetTargetAddressEvents, SetReverseLookupEvents {
        v2_1_config::assert_signer_is_admin(sign);
        // If the domain name is a primary name, clear it.
        clear_reverse_lookup_for_name(subdomain_name, domain_name);
        set_target_address_internal(subdomain_name, domain_name, new_owner);
    }

    /// Forcefully create or seize a domain name. This is a privileged operation, used via governance.
    /// This can be used, for example, to forcefully create a domain for a system address domain, or to seize a domain from a malicious user.
    /// The `registration_duration_secs` parameter is the number of seconds to register the domain for, but is not limited to the maximum set in the config for domains registered normally.
    /// This allows, for example, to create a domain for the system address for 100 years so we don't need to worry about expiry
    /// Or for moderation purposes, it allows us to seize a racist/harassing domain for 100 years, and park it somewhere safe
    public entry fun force_create_or_seize_name(
        sign: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
        registration_duration_secs: u64
    ) acquires DomainObject, NameRecord, SubdomainExt, RegisterNameEvents, ReverseRecord, SetReverseLookupEvents {
        v2_1_config::assert_signer_is_admin(sign);
        // Register the name
        register_name_internal(sign, subdomain_name, domain_name, registration_duration_secs, 0);
    }

    /// This removes a name mapping from the registry; functionally this 'expires' it.
    /// This is a privileged operation, used via governance.
    public entry fun force_clear_registration(
        sign: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
    ) acquires NameRecord {
        v2_1_config::assert_signer_is_admin(sign);
        let record = get_record_mut(domain_name, subdomain_name);
        object::transfer_with_ref(
            object::generate_linear_transfer_ref(&record.transfer_ref),
            get_app_signer_addr(),
        );
        record.target_address = option::none();
    }

    public entry fun force_set_name_expiration(
        sign: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
        new_expiration_secs: u64
    ) acquires NameRecord {
        // check the signer eligibility
        v2_1_config::assert_signer_is_admin(sign);

        let record = get_record_mut(domain_name, subdomain_name);
        record.expiration_time_sec = new_expiration_secs;
    }


    // === HELPER FUNCTIONS ===

    fun validate_name_string(
        name: String,
    ): u64 {
        let (is_valid, length) = v2_1_string_validator::string_is_allowed(&name);
        assert!(is_valid, error::invalid_argument(ENAME_HAS_INVALID_CHARACTERS));
        assert!(length <= v2_1_config::max_domain_length(), error::out_of_range(ENAME_TOO_LONG));
        assert!(length >= v2_1_config::min_domain_length(), error::out_of_range(ENAME_TOO_SHORT));

        return length
    }

    public fun is_domain_in_renewal_window(
        domain_name: String,
    ): bool acquires NameRecord, SubdomainExt {
        // check if the domain is registered
        assert!(is_name_registered(domain_name, option::none()), error::not_found(ENAME_NOT_EXIST));
        // check if the domain is expired and past gract period already
        assert!(
            !is_name_expired_past_grace(domain_name, option::none()),
            error::invalid_state(ECANNOT_RENEW_NAME_THAT_IS_EXPIRED_AND_PAST_GRACE_PERIOD)
        );
        let record = get_record_mut(domain_name, option::none());

        record.expiration_time_sec <= timestamp::now_seconds() + MAX_REMAINING_TIME_FOR_RENEWAL_SEC
    }

    inline fun is_subdomain(subdomain_name: Option<String>): bool {
        option::is_some(&subdomain_name)
    }

    public fun get_app_signer_addr(): address {
        object::create_object_address(&@aptos_names_v2_1, APP_OBJECT_SEED)
    }

    fun get_app_signer(): signer acquires DomainObject {
        object::generate_signer_for_extending(&borrow_global<DomainObject>(get_app_signer_addr()).extend_ref)
    }

    inline fun get_token_addr_inline(
        domain_name: String,
        subdomain_name: Option<String>,
    ): address {
        token::create_token_address(
            &get_app_signer_addr(),
            &get_collection_name(is_subdomain(subdomain_name)),
            &v2_1_token_helper::get_fully_qualified_domain_name(subdomain_name, domain_name),
        )
    }

    public fun get_token_addr(
        domain_name: String,
        subdomain_name: Option<String>,
    ): address {
        token::create_token_address(
            &get_app_signer_addr(),
            &get_collection_name(is_subdomain(subdomain_name)),
            &v2_1_token_helper::get_fully_qualified_domain_name(subdomain_name, domain_name),
        )
    }

    fun get_record_obj(
        domain_name: String,
        subdomain_name: Option<String>,
    ): Object<NameRecord> {
        object::address_to_object(get_token_addr_inline(domain_name, subdomain_name))
    }

    inline fun get_record(
        domain_name: String,
        subdomain_name: Option<String>,
    ): &NameRecord acquires NameRecord {
        borrow_global<NameRecord>(get_token_addr_inline(domain_name, subdomain_name))
    }

    inline fun get_record_mut(
        domain_name: String,
        subdomain_name: Option<String>,
    ): &mut NameRecord acquires NameRecord {
        borrow_global_mut<NameRecord>(get_token_addr_inline(domain_name, subdomain_name))
    }

    inline fun extract_subdomain_name(token_addr: address): Option<String> {
        if (exists<SubdomainExt>(token_addr)) {
            let subdomain_ext = borrow_global<SubdomainExt>(token_addr);
            option::some(subdomain_ext.subdomain_name)
        } else {
            option::none<String>()
        }
    }

    inline fun get_collection_name(is_subdomain: bool): String {
        if (is_subdomain) {
            v2_1_config::subdomain_collection_name()
        } else {
            v2_1_config::domain_collection_name()
        }
    }

    fun validate_registration_duration(
        registration_duration_secs: u64,
    ) {
        assert!(
            registration_duration_secs % SECONDS_PER_YEAR == 0,
            error::invalid_argument(EDURATION_MUST_BE_WHOLE_YEARS)
        );

        assert!(
            registration_duration_secs <= v2_1_config::max_number_of_seconds_registered(),
            error::out_of_range(EINVALID_NUMBER_YEARS)
        );
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
    ) acquires NameRecord, SubdomainExt {
        assert!(is_name_registered(domain_name, option::some(subdomain_name)), error::not_found(ESUBDOMAIN_NOT_EXIST));
        // Ensure signer owns the domain we're registering a subdomain for
        assert!(
            is_token_owner(signer::address_of(sign), domain_name, option::none()),
            error::permission_denied(ENOT_OWNER_OF_DOMAIN)
        );
        // Ensure name is not expired
        assert!(
            !is_name_expired(domain_name, option::none()),
            error::permission_denied(EDOMAIN_EXPIRED)
        );
    }

    /// Checks for the name not existing, or being expired
    /// Returns true if the name is available for registration
    /// if this is a subdomain, and the domain doesn't exist, returns false
    /// Doesn't use the `name_is_expired` or `name_is_registered` internally to share the borrow
    public fun is_name_registerable(
        domain_name: String,
        subdomain_name: Option<String>,
    ): bool acquires DomainObject, NameRecord, SubdomainExt {
        // If this is a subdomain, ensure the domain also exists, and is not expired: i.e not registerable
        // So if the domain name is registerable, we return false, as the subdomain is not registerable
        if (is_subdomain(subdomain_name) && is_name_registerable(domain_name, option::none())) {
            return false
        };

        // Name is not registered, so name is registerable
        if (!is_name_registered(domain_name, subdomain_name)) {
            return true
        };
        // Name is not expired, so not registerable
        if (!is_name_expired(domain_name, subdomain_name)) {
            return false
        };

        // Name is expired and it is a subdomain. Skip the grace period check
        if (is_subdomain(subdomain_name)) {
            return true
        };

        let expiration_time_sec = get_expiration(domain_name, subdomain_name);

        // Name is expired and passed grace period, so name is registerable
        if (timestamp::now_seconds() > v2_1_config::reregistration_grace_sec() + expiration_time_sec) {
            return true
        } else {
            // Name is expired but haven't passed grace period, so name is not registerable
            return false
        }
    }

    /// Returns true if
    /// 1. The name is not registered OR
    /// 2. The name is a subdomain AND subdomain was registered before the domain OR
    /// 3. The name is registered AND is expired and past grace period
    public fun is_name_expired_past_grace(
        domain_name: String,
        subdomain_name: Option<String>,
    ): bool acquires NameRecord, SubdomainExt {
        if (!is_name_registered(domain_name, subdomain_name)) {
            true
        } else if (option::is_some(&subdomain_name) && is_subdomain_registered_before_domain(
            domain_name,
            *option::borrow(&subdomain_name)
        )) {
            true
        } else {
            let token_addr = get_token_addr_inline(domain_name, subdomain_name);
            let record = borrow_global<NameRecord>(token_addr);
            // check the auto-renew flag
            if (exists<SubdomainExt>(token_addr)) {
                let subdomain_ext = borrow_global<SubdomainExt>(token_addr);
                if (subdomain_ext.subdomain_expiration_policy == SUBDOMAIN_POLICY_LOOKUP_DOMAIN_EXPIRATION) {
                    // refer to the expiration date of the domain
                    let domain_record = get_record(domain_name, option::none());
                    return is_time_expired(domain_record.expiration_time_sec + v2_1_config::reregistration_grace_sec())
                }
            };
            is_time_expired(record.expiration_time_sec + v2_1_config::reregistration_grace_sec())
        }
    }

    /// Returns true if
    /// 1. The name is not registered OR
    /// 2. The name is a subdomain AND subdomain was registered before the domain OR
    /// 3. The name is registered AND is expired
    public fun is_name_expired(
        domain_name: String,
        subdomain_name: Option<String>,
    ): bool acquires NameRecord, SubdomainExt {
        if (!is_name_registered(domain_name, subdomain_name)) {
            true
        } else if (option::is_some(&subdomain_name) && is_subdomain_registered_before_domain(
            domain_name,
            *option::borrow(&subdomain_name)
        )) {
            true
        } else {
            let token_addr = get_token_addr_inline(domain_name, subdomain_name);
            let record = borrow_global<NameRecord>(token_addr);
            // check the auto-renew flag
            if (exists<SubdomainExt>(token_addr)) {
                let subdomain_ext = borrow_global<SubdomainExt>(token_addr);
                if (subdomain_ext.subdomain_expiration_policy == SUBDOMAIN_POLICY_LOOKUP_DOMAIN_EXPIRATION) {
                    // refer to the expiration date of the domain
                    let domain_record = get_record(domain_name, option::none());
                    return is_time_expired(domain_record.expiration_time_sec)
                }
            };
            is_time_expired(record.expiration_time_sec)
        }
    }

    /// Returns true if the object exists AND the owner is not the `token_resource` account
    public fun is_name_registered(
        domain_name: String,
        subdomain_name: Option<String>,
    ): bool {
        object::is_object(get_token_addr_inline(domain_name, subdomain_name)) &&
            !object::is_owner(get_record_obj(domain_name, subdomain_name), get_app_signer_addr())
    }

    /// Check if the address is the owner of the given aptos_name
    /// If the name does not exist returns false
    public fun is_token_owner(
        owner_addr: address,
        domain_name: String,
        subdomain_name: Option<String>,
    ): bool {
        if (!is_name_registered(domain_name, subdomain_name))
            return false;
        let record_obj = object::address_to_object<NameRecord>(get_token_addr_inline(domain_name, subdomain_name));
        object::owns(record_obj, owner_addr)
    }

    /// Returns a name's owner address. Returns option::none() if there is no owner.
    public fun get_name_owner_addr(
        subdomain_name: Option<String>,
        domain_name: String,
    ): Option<address> acquires NameRecord, SubdomainExt {
        // check if the name is registered
        if (!is_name_registered(domain_name, subdomain_name) || is_name_expired(
            domain_name,
            subdomain_name,
        )) return option::none();
        let record_obj = object::address_to_object<NameRecord>(get_token_addr_inline(domain_name, subdomain_name));
        option::some(object::owner(record_obj))
    }

    public fun get_expiration(
        domain_name: String,
        subdomain_name: Option<String>,
    ): u64 acquires NameRecord, SubdomainExt {
        let token_addr = get_token_addr_inline(domain_name, subdomain_name);
        let record = borrow_global<NameRecord>(token_addr);
        if (exists<SubdomainExt>(token_addr)) {
            // check the expiration policy if it's subdomain
            let subdomain_ext = borrow_global<SubdomainExt>(token_addr);
            if (subdomain_ext.subdomain_expiration_policy == SUBDOMAIN_POLICY_LOOKUP_DOMAIN_EXPIRATION) {
                // refer to the expiration date of the domain
                let domain_record = get_record(domain_name, option::none());

                return domain_record.expiration_time_sec
            };
        };
        return record.expiration_time_sec
    }

    public fun get_target_address(
        domain_name: String,
        subdomain_name: Option<String>,
    ): Option<address> acquires NameRecord, SubdomainExt {
        //  check the expiration sec if the name is a domain
        let expiration_sec = get_expiration(domain_name, subdomain_name);
        if (is_time_expired(expiration_sec)) {
            return option::none()
        } else {
            let record = get_record(domain_name, subdomain_name);
            return record.target_address
        }
    }

    public fun get_name_props_from_token_addr(
        token_addr: address
    ): (Option<String>, String) acquires NameRecord, SubdomainExt {
        let record = borrow_global<NameRecord>(token_addr);
        (extract_subdomain_name(token_addr), record.domain_name)
    }

    /// Given a time, returns true if that time is in the past, false otherwise
    public fun is_time_expired(expiration_time_sec: u64): bool {
        timestamp::now_seconds() >= expiration_time_sec
    }

    fun is_subdomain_registered_before_domain(
        domain_name: String,
        subdomain_name: String,
    ): bool acquires NameRecord {
        if(!is_name_registered(domain_name, option::some(subdomain_name))) {
            false
        } else {
            let domain_record = get_record(domain_name, option::none());
            let subdomain_record = get_record(domain_name, option::some(subdomain_name));
            subdomain_record.registration_time_sec < domain_record.registration_time_sec
        }
    }

    // === EVENTS ===

    fun emit_set_target_address_event(
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
            &mut borrow_global_mut<SetTargetAddressEvents>(get_app_signer_addr()).set_name_events,
            event,
        );
    }

    fun emit_set_reverse_lookup_event(
        account_addr: address,
        prev_subdomain_name: Option<String>,
        prev_domain_name: Option<String>,
        prev_expiration_time_secs: Option<u64>,
        curr_subdomain_name: Option<String>,
        curr_domain_name: Option<String>,
        curr_expiration_time_secs: Option<u64>,
    ) acquires SetReverseLookupEvents {
        let event = SetReverseLookupEvent {
            account_addr,

            prev_domain_name,
            prev_subdomain_name,
            prev_expiration_time_secs,

            curr_domain_name,
            curr_subdomain_name,
            curr_expiration_time_secs,
        };

        event::emit_event<SetReverseLookupEvent>(
            &mut borrow_global_mut<SetReverseLookupEvents>(get_app_signer_addr()).set_reverse_lookup_events,
            event,
        );
    }

    // ==== TIME HELPERS ====

    fun seconds_to_years(seconds: u64): u64 {
        seconds / SECONDS_PER_YEAR
    }

    // ==== TEST ONLY ====

    #[test_only]
    public fun init_module_for_test(account: &signer) {
        init_module(account);
    }

    #[test_only]
    public fun get_set_target_address_event_count(): u64 acquires SetTargetAddressEvents {
        event::counter(&borrow_global<SetTargetAddressEvents>(get_app_signer_addr()).set_name_events)
    }

    #[test_only]
    public fun get_register_name_event_count(): u64 acquires RegisterNameEvents {
        event::counter(&borrow_global<RegisterNameEvents>(get_app_signer_addr()).register_name_events)
    }

    #[test_only]
    public fun get_set_reverse_lookup_event_count(): u64 acquires SetReverseLookupEvents {
        event::counter(&borrow_global<SetReverseLookupEvents>(get_app_signer_addr()).set_reverse_lookup_events)
    }

    #[test(aptos = @0x1)]
    fun test_time_is_expired(aptos: &signer) {
        timestamp::set_time_has_started_for_testing(aptos);
        // Set the time to a nonzero value to avoid subtraction overflow.
        timestamp::update_global_time_for_test_secs(100);

        // If the expiration time is after the current time, we should return not expired
        assert!(!is_time_expired(timestamp::now_seconds() + 1), 1);

        // If the current time is equal to expiration time, consider it expired
        assert!(is_time_expired(timestamp::now_seconds()), 2);

        // If the expiration time is earlier than the current time, we should return expired
        assert!(is_time_expired(timestamp::now_seconds() - 1), 3);
    }
}
