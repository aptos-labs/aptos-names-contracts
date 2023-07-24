module aptos_names_v2::domains {
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::aptos_account;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::object::{Self, Object, is_object};
    use aptos_framework::timestamp;
    use aptos_names_v2::config;
    use aptos_names_v2::price_model;
    use aptos_names_v2::time_helper;
    use aptos_names_v2::token_helper;
    use aptos_names_v2::utf8_utils;
    use aptos_names_v2::verify;
    use aptos_token_objects::collection;
    use aptos_token_objects::token;
    use std::bcs;
    use std::error;
    use std::option::{Self, Option};
    use std::signer;
    use std::signer::address_of;
    use std::string::{Self, String, utf8};

    const COLLECTION_DESCRIPTION: vector<u8> = b".apt names from Aptos Labs";
    const COLLECTION_URI: vector<u8> = b"https://aptosnames.com";

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
    const EDOMAIN_TOO_LONG: u64 = 10;
    /// The subdomain name is too long- it exceeds the configured maximum number of utf8 glyphs
    const ESUBDOMAIN_TOO_LONG: u64 = 11;
    /// The domain name contains invalid characters: it is not a valid domain name
    const EDOMAIN_HAS_INVALID_CHARACTERS: u64 = 12;
    /// The subdomain name contains invalid characters: it is not a valid domain name
    const ESUBDOMAIN_HAS_INVALID_CHARACTERS: u64 = 13;
    /// The subdomain registration duration can not be longer than its parent domain
    const ESUBDOMAIN_CAN_NOT_EXCEED_DOMAIN_REGISTRATION: u64 = 14;
    /// The subdomain name is too short (must be >= 3)
    const ESUBDOMAIN_TOO_SHORT: u64 = 15;
    /// The required `register_domain_signature` for `register_domain` is missing
    const EVALID_SIGNATURE_REQUIRED: u64 = 16;
    /// The domain is too short.
    const EDOMAIN_TOO_SHORT: u64 = 17;

    /// Manager object refs
    struct Manager has key {
        /// The extend_ref of the manager object to get its signer
        extend_ref: object::ExtendRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct DomainNameRecordV2 has key {
        name: String,
        expiration_time_sec: u64,
        target_address: Option<address>,
        subdomain_collection: String,

        transfer_ref: object::TransferRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct SubdomainNameRecordV2 has key {
        name: String,
        expiration_time_sec: u64,
        target_address: Option<address>,
        domain: Object<DomainNameRecordV2>,

        transfer_ref: object::TransferRef,
        burn_ref: token::BurnRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct ReverseRecord has key {
        token_addr: Option<address>,
    }

    /// Holder for `SetReverseLookupEventV1` events
    struct SetReverseLookupEventsV1 has key, store {
        set_reverse_lookup_events: event::EventHandle<SetReverseLookupEventV1>,
    }

    /// Holder for `SetNameAddressEventV1` events
    struct SetNameAddressEventsV1 has key, store {
        set_name_events: event::EventHandle<SetNameAddressEventV1>,
    }

    /// Holder for `RegisterNameEventV1` events
    struct RegisterNameEventsV1 has key, store {
        register_name_events: event::EventHandle<RegisterNameEventV1>,
    }

    /// A name has been set as the reverse lookup for an address, or
    /// the reverse lookup has been cleared (in which case |target_address|
    /// will be none)
    struct SetReverseLookupEventV1 has drop, store {
        subdomain_name: Option<String>,
        domain_name: String,
        target_address: Option<address>,
    }

    /// A name (potentially subdomain) has had it's address changed
    /// This could be to a new address, or it could have been cleared
    struct SetNameAddressEventV1 has drop, store {
        subdomain_name: Option<String>,
        domain_name: String,
        expiration_time_secs: u64,
        new_address: Option<address>,
    }

    /// A name (potentially subdomain) has been registered on chain
    /// Includes the the fee paid for the registration, and the expiration time
    /// Also includes the so we can tell which version of a given domain NFT is the latest
    struct RegisterNameEventV1 has drop, store {
        subdomain_name: Option<String>,
        domain_name: String,
        registration_fee_octas: u64,
        expiration_time_secs: u64,
    }

    /// This is only callable during publishing
    fun init_module(account: &signer) acquires Manager {
        let funds_address: address = @aptos_names_funds;
        let admin_address: address = @aptos_names_admin;

        if (!account::exists_at(funds_address)) {
            aptos_account::create_account(funds_address);
        };

        if (!account::exists_at(admin_address)) {
            aptos_account::create_account(admin_address);
        };

        config::initialize_v1(account, admin_address, funds_address);

        move_to(account, SetNameAddressEventsV1 {
            set_name_events: account::new_event_handle<SetNameAddressEventV1>(account),
        });

        move_to(account, RegisterNameEventsV1 {
            register_name_events: account::new_event_handle<RegisterNameEventV1>(account),
        });

        create_manager(account);
        create_domain_collection(&manager_signer());

        move_to(account, SetReverseLookupEventsV1 {
            set_reverse_lookup_events: account::new_event_handle<SetReverseLookupEventV1>(account),
        });
    }

    fun create_domain_collection(admin: &signer) {
        collection::create_unlimited_collection(
            admin,
            utf8(COLLECTION_DESCRIPTION),
            string::utf8(config::domain_collection_name_v1()),
            option::none(),
            utf8(COLLECTION_URI),
        );
    }

    /// Creates the manager object.
    fun create_manager(sender: &signer) {
        let constructor_ref = object::create_object(signer::address_of(sender));
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        move_to(sender, Manager { extend_ref });
    }

    /// Returns the signer of the manager object.
    fun manager_signer(): signer acquires Manager {
        let manager = borrow_global<Manager>(@aptos_names_v2);
        object::generate_signer_for_extending(&manager.extend_ref)
    }

    /// Returns the address of the manager object.
    fun manager_address(): address acquires Manager {
        let manager = borrow_global<Manager>(@aptos_names_v2);
        object::address_from_extend_ref(&manager.extend_ref)
    }

    #[view]
    public fun domain_addr(
        domain_name: String
    ): address acquires Manager {
        token::create_token_address(
            &manager_address(),
            &string::utf8(config::domain_collection_name_v1()),
            &domain_name,
        )
    }

    #[view]
    public fun subdomain_addr(
        domain_token: Object<DomainNameRecordV2>,
        subdomain_name: String
    ): address acquires DomainNameRecordV2 {
        let domain_token_addr = object::object_address(&domain_token);
        let subdomain_collection_name = &borrow_global<DomainNameRecordV2>(copy domain_token_addr).subdomain_collection;
        token::create_token_address(&domain_token_addr, subdomain_collection_name, &subdomain_name)
    }

    public fun get_record_obj(
        domain_name: String,
        subdomain_name: Option<String>,
    ): Object<NameRecordV2> acquires CollectionCapabilityV2 {
        object::address_to_object(token_addr_inline(domain_name, subdomain_name))
    }

    inline fun get_record(
        domain_name: String,
        subdomain_name: Option<String>,
    ): &NameRecordV2 acquires CollectionCapabilityV2 {
        borrow_global(token_addr_inline(domain_name, subdomain_name))
    }

    inline fun get_record_mut(
        domain_name: String,
        subdomain_name: Option<String>,
    ): &mut NameRecordV2 acquires CollectionCapabilityV2 {
        borrow_global_mut(token_addr_inline(domain_name, subdomain_name))
    }

    /// Creates a token for the name.
    /// NOTE: This function performs no validation checks
    fun create_token(
        to_addr: address,
        domain_name: String,
        subdomain_name: Option<String>,
        expiration_time_sec: u64,
    ) acquires CollectionCapabilityV2 {
        let name = token_helper::get_fully_qualified_domain_name(subdomain_name, domain_name);
        let description = config::tokendata_description();
        let uri: string::String = config::tokendata_url_prefix();
        string::append(&mut uri, name);
        let constructor_ref = token::create_named_token(
            &get_token_signer(),
            string::utf8(config::collection_name_v1()),
            description,
            name,
            option::none(),
            uri,
        );
        let token_signer = object::generate_signer(&constructor_ref);
        let record = NameRecordV2 {
            domain_name,
            subdomain_name,
            expiration_time_sec,
            target_address: option::none(),
            transfer_ref: object::generate_transfer_ref(&constructor_ref),
        };
        move_to(&token_signer, record);
        let record_obj = object::object_from_constructor_ref<NameRecordV2>(&constructor_ref);
        object::transfer(&get_token_signer(), record_obj, to_addr);
    }

    fun register_domain_generic(
        sign: &signer,
        domain_name: String,
        num_years: u8
    ) acquires CollectionCapabilityV2, NameRecordV2, RegisterNameEventsV1, ReverseRecord, SetNameAddressEventsV1, SetReverseLookupEventsV1 {
        assert!(config::is_enabled(), error::unavailable(ENOT_ENABLED));
        assert!(
            num_years > 0 && num_years <= config::max_number_of_years_registered(),
            error::out_of_range(EINVALID_NUMBER_YEARS)
        );

        let subdomain_name = option::none<String>();

        assert!(name_is_registerable(subdomain_name, domain_name), error::invalid_state(ENAME_NOT_AVAILABLE));

        // Conver the num_years to its seconds representation for the inner method
        let registration_duration_secs: u64 = time_helper::years_to_seconds((num_years as u64));

        let (is_valid, length) = utf8_utils::string_is_allowed(&domain_name);
        assert!(is_valid, error::invalid_argument(EDOMAIN_HAS_INVALID_CHARACTERS));
        assert!(length <= config::max_domain_length(), error::out_of_range(EDOMAIN_TOO_LONG));
        assert!(length >= config::min_domain_length(), error::out_of_range(EDOMAIN_TOO_SHORT));

        let price = price_model::price_for_domain_v1(length, num_years);
        coin::transfer<AptosCoin>(sign, config::fund_destination_address(), price);

        register_name_internal(sign, subdomain_name, domain_name, registration_duration_secs, price);
    }

    /// A wrapper around `register_name` as an entry function.
    /// Option<String> is not currently serializable, so we have these convenience methods
    public entry fun register_domain(
        sign: &signer,
        domain_name: String,
        num_years: u8
    ) acquires CollectionCapabilityV2, NameRecordV2, RegisterNameEventsV1, ReverseRecord, SetNameAddressEventsV1, SetReverseLookupEventsV1 {
        assert!(config::unrestricted_mint_enabled(), error::permission_denied(EVALID_SIGNATURE_REQUIRED));
        register_domain_generic(sign, domain_name, num_years);
    }

    public entry fun register_domain_with_signature(
        sign: &signer,
        domain_name: String,
        num_years: u8,
        signature: vector<u8>
    ) acquires CollectionCapabilityV2, NameRecordV2, RegisterNameEventsV1, ReverseRecord, SetNameAddressEventsV1, SetReverseLookupEventsV1 {
        let account_address = signer::address_of(sign);
        verify::assert_register_domain_signature_verifies(signature, account_address, domain_name);
        register_domain_generic(sign, domain_name, num_years);
    }

    /// A wrapper around `register_name` as an entry function.
    /// Option<String> is not currently serializable, so we have these convenience method
    /// `expiration_time_sec` is the timestamp, in seconds, when the name expires
    public entry fun register_subdomain(
        sign: &signer,
        subdomain_name: String,
        domain_name: String,
        expiration_time_sec: u64
    ) acquires CollectionCapabilityV2, NameRecordV2, RegisterNameEventsV1, ReverseRecord, SetNameAddressEventsV1, SetReverseLookupEventsV1 {
        assert!(config::is_enabled(), error::unavailable(ENOT_ENABLED));

        assert!(
            name_is_registerable(option::some(subdomain_name), domain_name),
            error::invalid_state(ENAME_NOT_AVAILABLE)
        );

        // We are registering a subdomain name: this has no cost, but is only doable by the owner of the domain
        let (is_valid, length) = utf8_utils::string_is_allowed(&subdomain_name);
        assert!(is_valid, error::invalid_argument(ESUBDOMAIN_HAS_INVALID_CHARACTERS));
        assert!(length <= config::max_domain_length(), error::out_of_range(ESUBDOMAIN_TOO_LONG));
        assert!(length >= config::min_domain_length(), error::out_of_range(ESUBDOMAIN_TOO_SHORT));

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
    ) acquires CollectionCapabilityV2, NameRecordV2, RegisterNameEventsV1, ReverseRecord, SetNameAddressEventsV1, SetReverseLookupEventsV1 {
        // If we're registering a name that exists but is expired, and the expired name is a primary name,
        // it should get removed from being a primary name.
        clear_reverse_lookup_for_name(subdomain_name, domain_name);

        let name_expiration_time_secs = timestamp::now_seconds() + registration_duration_secs;

        // if it is a subdomain, and it expires later than its domain, throw an error
        // This is done here so that any governance moderation activities must abide by the same invariant
        if (option::is_some(&subdomain_name)) {
            let record = get_record(domain_name, option::none());
            assert!(
                name_expiration_time_secs <= record.expiration_time_sec,
                error::out_of_range(ESUBDOMAIN_CAN_NOT_EXCEED_DOMAIN_REGISTRATION)
            );
        };

        // If the token already exists, transfer it to the signer
        // Else, create a new one and transfer it to the signer
        let account_addr = signer::address_of(sign);
        let token_addr = token_addr_inline(domain_name, subdomain_name);
        if (object::is_object(token_addr)) {
            let record = borrow_global_mut<NameRecordV2>(token_addr);
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

        let reverse_lookup_result = get_reverse_lookup(account_addr);
        if (option::is_none(&reverse_lookup_result)) {
            // If the user has no reverse lookup set, set the user's reverse lookup.
            set_reverse_lookup(sign, subdomain_name, domain_name);
        } else if (option::is_none(&subdomain_name)) {
            // Automatically set the name to point to the sender's address
            set_name_address_internal(subdomain_name, domain_name, signer::address_of(sign));
        };

        event::emit_event<RegisterNameEventV1>(
            &mut borrow_global_mut<RegisterNameEventsV1>(@aptos_names_v2).register_name_events,
            RegisterNameEventV1 {
                subdomain_name,
                domain_name,
                registration_fee_octas: price,
                expiration_time_secs: name_expiration_time_secs,
            },
        );
    }

    /// Forcefully set the name of a domain.
    /// This is a privileged operation, used via governance, to forcefully set a domain address
    /// This can be used, for example, to forcefully set the domain for a system address domain
    public entry fun force_set_domain_address(
        sign: &signer,
        domain_name: String,
        new_owner: address
    ) acquires CollectionCapabilityV2, NameRecordV2, ReverseRecord, SetNameAddressEventsV1, SetReverseLookupEventsV1 {
        force_set_name_address(sign, option::none(), domain_name, new_owner);
    }

    public entry fun force_set_subdomain_address(
        sign: &signer,
        subdomain_name: String,
        domain_name: String,
        new_owner: address
    ) acquires CollectionCapabilityV2, NameRecordV2, ReverseRecord, SetNameAddressEventsV1, SetReverseLookupEventsV1 {
        force_set_name_address(sign, option::some(subdomain_name), domain_name, new_owner);
    }

    fun force_set_name_address(
        sign: &signer,
        subdomain_name: Option<String>,
        domain_name: String,
        new_owner: address
    ) acquires CollectionCapabilityV2, NameRecordV2, ReverseRecord, SetNameAddressEventsV1, SetReverseLookupEventsV1 {
        config::assert_signer_is_admin(sign);
        // If the domain name is a primary name, clear it.
        clear_reverse_lookup_for_name(subdomain_name, domain_name);
        set_name_address_internal(subdomain_name, domain_name, new_owner);
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
    ) acquires CollectionCapabilityV2, NameRecordV2, RegisterNameEventsV1, ReverseRecord, SetNameAddressEventsV1, SetReverseLookupEventsV1 {
        force_create_or_seize_name(sign, option::none(), domain_name, registration_duration_secs);
    }

    public entry fun force_create_or_seize_subdomain_name(
        sign: &signer,
        subdomain_name: String,
        domain_name: String,
        registration_duration_secs: u64
    ) acquires CollectionCapabilityV2, NameRecordV2, RegisterNameEventsV1, ReverseRecord, SetNameAddressEventsV1, SetReverseLookupEventsV1 {
        force_create_or_seize_name(sign, option::some(subdomain_name), domain_name, registration_duration_secs);
    }

    public fun force_create_or_seize_name(
        sign: &signer,
        subdomain_name: Option<String>,
        domain_name: String,
        registration_duration_secs: u64
    ) acquires CollectionCapabilityV2, NameRecordV2, RegisterNameEventsV1, ReverseRecord, SetNameAddressEventsV1, SetReverseLookupEventsV1 {
        config::assert_signer_is_admin(sign);
        // Register the name
        register_name_internal(sign, subdomain_name, domain_name, registration_duration_secs, 0);
    }

    #[legacy_entry_fun]
    /// This removes a name mapping from the registry; functionally this 'expires' it.
    /// This is a privileged operation, used via governance.
    public entry fun force_clear_registration(
        sign: &signer,
        subdomain_name: Option<String>,
        domain_name: String
    ) acquires CollectionCapabilityV2, NameRecordV2 {
        config::assert_signer_is_admin(sign);
        let record = get_record_mut(domain_name, subdomain_name);
        object::transfer_with_ref(
            object::generate_linear_transfer_ref(&record.transfer_ref),
            get_token_signer_address()
        );
        record.target_address = option::none();
    }

    /// Checks for the name not existing, or being expired
    /// Returns true if the name is available for registration
    /// if this is a subdomain, and the domain doesn't exist, returns false
    /// Doesn't use the `name_is_expired` or `name_is_registered` internally to share the borrow
    public fun name_is_registerable(
        subdomain_name: Option<String>,
        domain_name: String
    ): bool acquires CollectionCapabilityV2, NameRecordV2 {
        // If this is a subdomain, ensure the domain also exists, and is not expired: i.e not registerable
        // So if the domain name is registerable, we return false, as the subdomain is not registerable
        if (option::is_some(&subdomain_name) && name_is_registerable(option::none(), domain_name)) {
            return false
        };
        // Check to see if the domain is registered, or expired
        !name_is_registered(subdomain_name, domain_name) || name_is_expired(subdomain_name, domain_name)
    }

    /// Returns true if the name is registered, and is expired.
    /// If the name does not exist, raises an error
    public fun name_is_expired(
        subdomain_name: Option<String>,
        domain_name: String
    ): bool acquires CollectionCapabilityV2, NameRecordV2 {
        let record = get_record(domain_name, subdomain_name);
        time_is_expired(record.expiration_time_sec)
    }

    /// Returns true if the object exists AND the owner is not the `token_resource` account
    public fun name_is_registered(
        subdomain_name: Option<String>,
        domain_name: String
    ): bool acquires CollectionCapabilityV2 {
        object::is_object(token_addr_inline(domain_name, subdomain_name)) &&
        !object::is_owner(get_record_obj(domain_name, subdomain_name), get_token_signer_address())
    }

    /// Check if the address is the owner of the given aptos_name
    /// If the name does not exist or owner owns an expired name, returns false
    public fun is_owner_of_name(
        owner_addr: address,
        subdomain_name: Option<String>,
        domain_name: String
    ): bool acquires CollectionCapabilityV2, NameRecordV2 {
        if (!name_is_registered(subdomain_name, domain_name) || name_is_expired(
            subdomain_name,
            domain_name
        )) return false;
        let record_obj = object::address_to_object<NameRecordV2>(token_addr_inline(domain_name, subdomain_name));
        object::owns(record_obj, owner_addr)
    }

    /// gets the address pointed to by a given name
    /// Is `Option<address>` because the name may not be registered, or it may not have an address associated with it
    public fun name_resolved_address(
        subdomain_name: Option<String>,
        domain_name: String
    ): Option<address> acquires CollectionCapabilityV2, NameRecordV2 {
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
    ) acquires CollectionCapabilityV2, NameRecordV2, ReverseRecord, SetNameAddressEventsV1, SetReverseLookupEventsV1 {
        set_name_address(sign, option::none(), domain_name, new_address);
    }

    public entry fun set_subdomain_address(
        sign: &signer,
        subdomain_name: String,
        domain_name: String,
        new_address: address
    ) acquires CollectionCapabilityV2, NameRecordV2, ReverseRecord, SetNameAddressEventsV1, SetReverseLookupEventsV1 {
        set_name_address(sign, option::some(subdomain_name), domain_name, new_address);
    }

    public fun set_name_address(
        sign: &signer,
        subdomain_name: Option<String>,
        domain_name: String,
        new_address: address
    ) acquires CollectionCapabilityV2, NameRecordV2, ReverseRecord, SetNameAddressEventsV1, SetReverseLookupEventsV1 {
        // If the domain name is a primary name, clear it.
        clear_reverse_lookup_for_name(subdomain_name, domain_name);

        let signer_addr = signer::address_of(sign);
        assert!(
            is_owner_of_name(signer_addr, subdomain_name, domain_name),
            error::permission_denied(ENOT_OWNER_OF_NAME)
        );

        set_name_address_internal(subdomain_name, domain_name, new_address);

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
        let reverse_name_record = borrow_global<NameRecordV2>(*option::borrow(&maybe_reverse_lookup));
        if (reverse_name_record.domain_name == domain_name &&
            reverse_name_record.subdomain_name == subdomain_name &&
            signer_addr != new_address
        ) {
            clear_reverse_lookup(sign);
        };
    }

    fun set_name_address_internal(
        subdomain_name: Option<String>,
        domain_name: String,
        new_address: address
    ) acquires CollectionCapabilityV2, NameRecordV2, SetNameAddressEventsV1 {
        assert!(name_is_registered(subdomain_name, domain_name), error::not_found(ENAME_NOT_EXIST));
        let record = get_record_mut(domain_name, subdomain_name);
        record.target_address = option::some(new_address);
        emit_set_name_address_event_v1(
            subdomain_name,
            domain_name,
            record.expiration_time_sec,
            record.target_address,
        );
    }

    public entry fun clear_domain_address(
        sign: &signer,
        domain_name: String
    ) acquires CollectionCapabilityV2, NameRecordV2, ReverseRecord, SetNameAddressEventsV1, SetReverseLookupEventsV1 {
        clear_name_address(sign, option::none(), domain_name);
    }

    public entry fun clear_subdomain_address(
        sign: &signer,
        subdomain_name: String,
        domain_name: String
    ) acquires CollectionCapabilityV2, NameRecordV2, ReverseRecord, SetNameAddressEventsV1, SetReverseLookupEventsV1 {
        clear_name_address(sign, option::some(subdomain_name), domain_name);
    }

    /// This is a shared entry point for clearing the address of a domain or subdomain
    /// It enforces owner permissions
    fun clear_name_address(
        sign: &signer,
        subdomain_name: Option<String>,
        domain_name: String
    ) acquires CollectionCapabilityV2, NameRecordV2, ReverseRecord, SetNameAddressEventsV1, SetReverseLookupEventsV1 {
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
        emit_set_name_address_event_v1(
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
    ) acquires CollectionCapabilityV2, NameRecordV2, ReverseRecord, SetNameAddressEventsV1, SetReverseLookupEventsV1 {
        // Name must be registered before assigning reverse lookup
        if (!name_is_registered(subdomain_name, domain_name)) {
            return
        };
        let token_addr = token_addr_inline(domain_name, subdomain_name);
        set_name_address(account, subdomain_name, domain_name, address_of(account));
        set_reverse_lookup_internal(account, token_addr);
    }

    /// Entry function for clearing reverse lookup.
    public entry fun clear_reverse_lookup_entry(
        account: &signer
    ) acquires CollectionCapabilityV2, NameRecordV2, ReverseRecord, SetReverseLookupEventsV1 {
        clear_reverse_lookup(account);
    }

    /// Clears the user's reverse lookup.
    public fun clear_reverse_lookup(
        account: &signer
    ) acquires CollectionCapabilityV2, NameRecordV2, ReverseRecord, SetReverseLookupEventsV1 {
        let account_addr = signer::address_of(account);
        clear_reverse_lookup_internal(account_addr);
    }

    inline fun reverse_record_addr(account_addr: address): address acquires CollectionCapabilityV2 {
        // TODO: Use object ExtendRef
        object::create_object_address(
            &get_token_signer_address(),
            bcs::to_bytes(&account_addr),

        )
    }

    /// Returns the reverse lookup (the token addr) for an address if any.
    public fun get_reverse_lookup(
        account_addr: address
    ): Option<address> acquires CollectionCapabilityV2, ReverseRecord {
        let reverse_record_addr = reverse_record_addr(account_addr);
        if (is_object(reverse_record_addr)) {
            let reverse_record = borrow_global<ReverseRecord>(reverse_record_addr);
            reverse_record.token_addr
        } else {
            option::none()
        }
    }

    fun set_reverse_lookup_internal(
        account: &signer,
        token_addr: address,
    ) acquires CollectionCapabilityV2, NameRecordV2, ReverseRecord, SetReverseLookupEventsV1 {
        let account_addr = signer::address_of(account);
        let record = borrow_global<NameRecordV2>(token_addr);
        let record_obj = object::address_to_object<NameRecordV2>(token_addr);
        assert!(object::owns(record_obj, account_addr), error::permission_denied(ENOT_AUTHORIZED));

        let reverse_record_addr = reverse_record_addr(account_addr);
        if (!is_object(reverse_record_addr)) {
            // TODO: Use object ExtendRef
            let constructor_ref = object::create_named_object(&get_token_signer(), bcs::to_bytes(&account_addr));
            let reverse_record_signer = &object::generate_signer(&constructor_ref);
            move_to(reverse_record_signer, ReverseRecord {
                token_addr: option::some(token_addr)
            })
        } else {
            let reverse_record = borrow_global_mut<ReverseRecord>(reverse_record_addr);
            reverse_record.token_addr = option::some(token_addr);
        };

        emit_set_reverse_lookup_event_v1(
            record.subdomain_name,
            record.domain_name,
            option::some(account_addr)
        );
    }

    fun clear_reverse_lookup_internal(
        account_addr: address
    ) acquires CollectionCapabilityV2, NameRecordV2, ReverseRecord, SetReverseLookupEventsV1 {
        let maybe_reverse_lookup = get_reverse_lookup(account_addr);
        if (option::is_none(&maybe_reverse_lookup)) {
            return
        };
        let token_addr = *option::borrow(&maybe_reverse_lookup);
        let record = borrow_global<NameRecordV2>(token_addr);
        let reverse_record_addr = reverse_record_addr(account_addr);
        let reverse_record = borrow_global_mut<ReverseRecord>(reverse_record_addr);
        reverse_record.token_addr = option::none();
        emit_set_reverse_lookup_event_v1(
            record.subdomain_name,
            record.domain_name,
            option::none()
        );
    }

    fun clear_reverse_lookup_for_name(
        subdomain_name: Option<String>,
        domain_name: String
    ) acquires CollectionCapabilityV2, NameRecordV2, ReverseRecord, SetReverseLookupEventsV1 {
        if (!name_is_registered(subdomain_name, domain_name)) return;

        // If the name is a primary name, clear it
        let record = get_record(domain_name, subdomain_name);
        if (option::is_none(&record.target_address)) return;
        let target_address = *option::borrow(&record.target_address);
        let reverse_token_addr = get_reverse_lookup(target_address);
        if (option::is_none(&reverse_token_addr)) return;
        let reverse_record = borrow_global<NameRecordV2>(*option::borrow(&reverse_token_addr));
        if (reverse_record.subdomain_name == subdomain_name && reverse_record.domain_name == domain_name) {
            clear_reverse_lookup_internal(target_address);
        };
    }

    fun emit_set_name_address_event_v1(
        subdomain_name: Option<String>,
        domain_name: String,
        expiration_time_secs: u64,
        new_address: Option<address>
    ) acquires SetNameAddressEventsV1 {
        let event = SetNameAddressEventV1 {
            subdomain_name,
            domain_name,
            expiration_time_secs,
            new_address,
        };

        event::emit_event<SetNameAddressEventV1>(
            &mut borrow_global_mut<SetNameAddressEventsV1>(@aptos_names_v2).set_name_events,
            event,
        );
    }

    fun emit_set_reverse_lookup_event_v1(
        subdomain_name: Option<String>,
        domain_name: String,
        target_address: Option<address>
    ) acquires SetReverseLookupEventsV1 {
        let event = SetReverseLookupEventV1 {
            subdomain_name,
            domain_name,
            target_address,
        };

        event::emit_event<SetReverseLookupEventV1>(
            &mut borrow_global_mut<SetReverseLookupEventsV1>(@aptos_names_v2).set_reverse_lookup_events,
            event,
        );
    }

    public fun get_name_record_v1_props_for_name(
        subdomain: Option<String>,
        domain: String,
    ): (u64, Option<address>) acquires CollectionCapabilityV2, NameRecordV2 {
        let record = get_record(domain, subdomain);
        (record.expiration_time_sec, record.target_address)
    }

    public fun get_record_props_from_token_addr(
        token_addr: address
    ): (Option<String>, String) acquires NameRecordV2 {
        let record = borrow_global<NameRecordV2>(token_addr);
        (record.subdomain_name, record.domain_name)
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
    public fun get_set_name_address_event_v1_count(): u64 acquires SetNameAddressEventsV1 {
        event::counter(&borrow_global<SetNameAddressEventsV1>(@aptos_names_v2).set_name_events)
    }

    #[test_only]
    public fun get_register_name_event_v1_count(): u64 acquires RegisterNameEventsV1 {
        event::counter(&borrow_global<RegisterNameEventsV1>(@aptos_names_v2).register_name_events)
    }

    #[test_only]
    public fun get_set_reverse_lookup_event_v1_count(): u64 acquires SetReverseLookupEventsV1 {
        event::counter(&borrow_global<SetReverseLookupEventsV1>(@aptos_names_v2).set_reverse_lookup_events)
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
