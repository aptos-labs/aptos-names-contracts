/*
Provides a singleton wrapper around PropertyMap to allow for easy and dynamic configurability of contract options.
This includes things like the maximum number of years that a name can be registered for, etc.

Anyone can read, but only admins can write, as all write methods are gated via permissions checks
*/

module aptos_names_v2::v2_config {
    friend aptos_names_v2::v2_domains;

    use aptos_framework::account;
    use aptos_framework::aptos_account;
    use aptos_framework::object;
    use std::error;
    use std::signer;
    use std::string::{Self, String};

    const CONFIG_OBJECT_SEED: vector<u8> = b"ANS v2 config";

    const CONFIG_KEY_ENABLED: vector<u8> = b"enabled";
    const CONFIG_KEY_ADMIN_ADDRESS: vector<u8> = b"admin_address";
    const CONFIG_KEY_FUND_DESTINATION_ADDRESS: vector<u8> = b"fund_destination_address";
    const CONFIG_KEY_MAX_NUMBER_OF_SECONDS_REGISTERED: vector<u8> = b"max_number_of_seconds_registered";
    const CONFIG_KEY_MAX_DOMAIN_LENGTH: vector<u8> = b"max_domain_length";
    const CONFIG_KEY_MIN_DOMAIN_LENGTH: vector<u8> = b"min_domain_length";
    const CONFIG_KEY_TOKENDATA_DESCRIPTION: vector<u8> = b"tokendata_description";
    const CONFIG_KEY_TOKENDATA_URL_PREFIX: vector<u8> = b"tokendata_url_prefix";
    const CONFIG_KEY_DOMAIN_PRICE_PREFIX: vector<u8> = b"domain_price_";
    const CONFIG_KEY_SUBDOMAIN_PRICE: vector<u8> = b"subdomain_price";
    /// The number of seconds after a name expires that it can be re-registered
    const CONFIG_KEY_REREGISTRATION_GRACE_SEC: vector<u8> = b"reregistration_grace_sec";

    const DOMAIN_COLLECTION_NAME: vector<u8> = b"Aptos Domain Names V2";
    const SUBDOMAIN_COLLECTION_NAME: vector<u8> = b"Aptos Subdomain Names V2";

    /// Raised if the signer is not authorized to perform an action
    const ENOT_AUTHORIZED: u64 = 1;
    /// Raised if there is an invalid value for a configuration
    const EINVALID_VALUE: u64 = 2;
    /// Domain length is invalid, it must be at least 3 characters
    const EINVALID_DOMAIN_LENGTH: u64 = 3;

    const SECONDS_PER_YEAR: u64 = 60 * 60 * 24 * 365;
    const SECONDS_PER_DAY: u64 = 60 * 60 * 24;

    struct Config has key, store {
        enabled: bool,
        admin_address: address,
        fund_destination_address: address,
        max_number_of_seconds_registered: u64,
        max_domain_length: u64,
        min_domain_length: u64,
        tokendata_description: String,
        tokendata_url_prefix: String,
        domain_price_length_3: u64,
        domain_price_length_4: u64,
        domain_price_length_5: u64,
        domain_price_length_6_and_above: u64,
        subdomain_price: u64,
        /// The number of seconds after a name expires that it can be re-registered
        reregistration_grace_sec: u64,
        extend_ref: object::ExtendRef,
    }

    public(friend) fun initialize_config(
        framework: &signer,
        admin_address: address,
        fund_destination_address: address
    ) {
        let constructor_ref = object::create_named_object(
            framework,
            CONFIG_OBJECT_SEED,
        );
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let config_signer = object::generate_signer(&constructor_ref);

        move_to(&config_signer, Config {
            enabled: true,
            admin_address,
            fund_destination_address,
            max_number_of_seconds_registered: SECONDS_PER_YEAR * 2,
            max_domain_length: 63,
            min_domain_length: 3,
            tokendata_description: string::utf8(b"This is an official Aptos Labs Name Service Name"),
            tokendata_url_prefix: string::utf8(b"https://www.aptosnames.com/api/mainnet/v1/metadata/"),
            domain_price_length_3: 20 * octas(),
            domain_price_length_4: 10 * octas(),
            domain_price_length_5: 5 * octas(),
            domain_price_length_6_and_above: octas(),
            // 0.2 APT
            subdomain_price: octas() / 5,
            // The number of seconds after a name expires that it can be re-registered
            reregistration_grace_sec: 30 * SECONDS_PER_DAY,
            extend_ref,
        });
    }


    public fun get_config_signer_addr(): address {
        object::create_object_address(&@aptos_names_v2, CONFIG_OBJECT_SEED)
    }

    fun get_config_signer(): signer acquires Config {
        object::generate_signer_for_extending(&borrow_global<Config>(@aptos_names_v2).extend_ref)
    }

    //
    // Configuration Shortcuts
    //

    public fun octas(): u64 {
        100000000
    }

    #[view]
    public fun is_enabled(): bool acquires Config {
        borrow_global<Config>(get_config_signer_addr()).enabled
    }

    #[view]
    public fun fund_destination_address(): address acquires Config {
        borrow_global<Config>(get_config_signer_addr()).fund_destination_address
    }

    #[view]
    public fun admin_address(): address acquires Config {
        borrow_global<Config>(get_config_signer_addr()).admin_address
    }

    #[view]
    public fun max_number_of_seconds_registered(): u64 acquires Config {
        borrow_global<Config>(get_config_signer_addr()).max_number_of_seconds_registered
    }

    #[view]
    public fun max_domain_length(): u64 acquires Config {
        borrow_global<Config>(get_config_signer_addr()).max_domain_length
    }

    #[view]
    public fun min_domain_length(): u64 acquires Config {
        borrow_global<Config>(get_config_signer_addr()).min_domain_length
    }

    #[view]
    public fun tokendata_description(): String acquires Config {
        borrow_global<Config>(get_config_signer_addr()).tokendata_description
    }

    #[view]
    public fun tokendata_url_prefix(): String acquires Config {
        borrow_global<Config>(get_config_signer_addr()).tokendata_url_prefix
    }

    #[view]
    public fun domain_collection_name(): String {
        return string::utf8(DOMAIN_COLLECTION_NAME)
    }

    #[view]
    public fun subdomain_collection_name(): String {
        return string::utf8(SUBDOMAIN_COLLECTION_NAME)
    }

    #[view]
    public fun domain_price_for_length(domain_length: u64): u64 acquires Config {
        assert!(domain_length >= 3, error::invalid_argument(EINVALID_DOMAIN_LENGTH));
        if (domain_length == 3) {
            borrow_global<Config>(get_config_signer_addr()).domain_price_length_3
        } else if (domain_length == 4) {
            borrow_global<Config>(get_config_signer_addr()).domain_price_length_4
        } else if (domain_length == 5) {
            borrow_global<Config>(get_config_signer_addr()).domain_price_length_5
        } else {
            borrow_global<Config>(get_config_signer_addr()).domain_price_length_6_and_above
        }
    }

    #[view]
    public fun subdomain_price(): u64 acquires Config {
        borrow_global<Config>(get_config_signer_addr()).subdomain_price
    }

    #[view]
    public fun reregistration_grace_sec(): u64 acquires Config {
        borrow_global<Config>(get_config_signer_addr()).reregistration_grace_sec
    }

    /// Admins will be able to intervene when necessary.
    /// The account will be used to manage names that are being used in a way that is harmful to others.
    /// Alternatively, the deployer can be used to perform admin actions.
    public fun signer_is_admin(sign: &signer): bool acquires Config {
        signer::address_of(sign) == admin_address() || signer::address_of(sign) == @aptos_names_v2
    }

    public fun assert_signer_is_admin(sign: &signer) acquires Config {
        assert!(signer_is_admin(sign), error::permission_denied(ENOT_AUTHORIZED));
    }

    //
    // Setters
    //

    public entry fun set_is_enabled(sign: &signer, enabled: bool) acquires Config {
        assert_signer_is_admin(sign);
        borrow_global_mut<Config>(get_config_signer_addr()).enabled = enabled
    }

    public entry fun set_fund_destination_address(sign: &signer, addr: address) acquires Config {
        assert_signer_is_admin(sign);
        aptos_account::assert_account_is_registered_for_apt(addr);
        borrow_global_mut<Config>(get_config_signer_addr()).fund_destination_address = addr
    }

    public entry fun set_admin_address(sign: &signer, addr: address) acquires Config {
        assert_signer_is_admin(sign);
        assert!(account::exists_at(addr), error::invalid_argument(EINVALID_VALUE));
        borrow_global_mut<Config>(get_config_signer_addr()).admin_address = addr
    }

    public entry fun set_max_number_of_seconds_registered(sign: &signer, max_seconds_registered: u64) acquires Config {
        assert_signer_is_admin(sign);
        assert!(max_seconds_registered > 0, error::invalid_argument(EINVALID_VALUE));
        borrow_global_mut<Config>(get_config_signer_addr()).max_number_of_seconds_registered = max_seconds_registered
    }

    public entry fun set_max_domain_length(sign: &signer, domain_length: u64) acquires Config {
        assert_signer_is_admin(sign);
        assert!(domain_length > 0, error::invalid_argument(EINVALID_VALUE));
        borrow_global_mut<Config>(get_config_signer_addr()).max_domain_length = domain_length
    }

    public entry fun set_min_domain_length(sign: &signer, domain_length: u64) acquires Config {
        assert_signer_is_admin(sign);
        assert!(domain_length > 0, error::invalid_argument(EINVALID_VALUE));
        borrow_global_mut<Config>(get_config_signer_addr()).min_domain_length = domain_length
    }

    public entry fun set_tokendata_description(sign: &signer, description: String) acquires Config {
        assert_signer_is_admin(sign);
        borrow_global_mut<Config>(get_config_signer_addr()).tokendata_description = description
    }

    public entry fun set_tokendata_url_prefix(sign: &signer, url_prefix: String) acquires Config {
        assert_signer_is_admin(sign);
        borrow_global_mut<Config>(get_config_signer_addr()).tokendata_url_prefix = url_prefix
    }

    public entry fun set_subdomain_price(sign: &signer, price: u64) acquires Config {
        assert_signer_is_admin(sign);
        borrow_global_mut<Config>(get_config_signer_addr()).subdomain_price = price
    }

    public entry fun set_domain_price_for_length(sign: &signer, price: u64, length: u64) acquires Config {
        assert_signer_is_admin(sign);
        assert!(length >= 3, error::invalid_argument(EINVALID_DOMAIN_LENGTH));
        assert!(length >= 3, length);
        if (length == 3) {
            borrow_global_mut<Config>(get_config_signer_addr()).domain_price_length_3 = price
        } else if (length == 4) {
            borrow_global_mut<Config>(get_config_signer_addr()).domain_price_length_4 = price
        } else if (length == 5) {
            borrow_global_mut<Config>(get_config_signer_addr()).domain_price_length_5 = price
        } else {
            borrow_global_mut<Config>(get_config_signer_addr()).domain_price_length_6_and_above = price
        }
    }

    public entry fun set_reregistration_grace_sec(sign: &signer, reregistration_grace_sec: u64) acquires Config {
        assert_signer_is_admin(sign);
        borrow_global_mut<Config>(get_config_signer_addr()).reregistration_grace_sec = reregistration_grace_sec
    }

    //
    // Tests
    //

    #[test_only]
    friend aptos_names_v2::v2_price_model;
    #[test_only]
    use aptos_framework::coin;
    #[test_only]
    use aptos_framework::aptos_coin::AptosCoin;
    #[test_only]
    use aptos_framework::timestamp;

    #[test_only]
    public fun initialize_aptoscoin_for(framework: &signer) {
        let (burn_cap, mint_cap) = aptos_framework::aptos_coin::initialize_for_test(framework);
        coin::register<AptosCoin>(framework);
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test_only]
    public fun set_fund_destination_address_test_only(addr: address) acquires Config {
        borrow_global_mut<Config>(get_config_signer_addr()).fund_destination_address = addr;
    }

    #[test_only]
    public fun set_admin_address_test_only(addr: address) acquires Config {
        borrow_global_mut<Config>(get_config_signer_addr()).admin_address = addr
    }

    #[test_only]
    public fun initialize_for_test(aptos_names_v2: &signer, aptos: &signer) acquires Config {
        timestamp::set_time_has_started_for_testing(aptos);
        initialize_aptoscoin_for(aptos);
        initialize_config(aptos_names_v2, @aptos_names_v2, @aptos_names_v2);
        set_admin_address_test_only(@aptos_names_v2);
    }

    #[test(myself = @aptos_names_v2)]
    fun test_default_token_configs_are_set(myself: signer) acquires Config {
        account::create_account_for_test(signer::address_of(&myself));

        initialize_config(&myself, @aptos_names_v2, @aptos_names_v2);
        set_fund_destination_address_test_only(@aptos_names_v2);

        set_tokendata_description(&myself, string::utf8(b"test description"));
        assert!(tokendata_description() == string::utf8(b"test description"), 1);

        set_tokendata_url_prefix(&myself, string::utf8(b"test_prefix"));
        assert!(tokendata_url_prefix() == string::utf8(b"test_prefix"), 1);
    }

    #[test(myself = @aptos_names_v2)]
    fun test_default_tokens_configs_are_set(myself: signer) acquires Config {
        account::create_account_for_test(signer::address_of(&myself));

        initialize_config(&myself, @aptos_names_v2, @aptos_names_v2);
        set_fund_destination_address_test_only(@aptos_names_v2);

        set_tokendata_description(&myself, string::utf8(b"test description"));
        assert!(tokendata_description() == string::utf8(b"test description"), 1);

        set_tokendata_url_prefix(&myself, string::utf8(b"test_prefix"));
        set_tokendata_description(&myself, string::utf8(b"test_desc"));
    }

    #[test(myself = @aptos_names_v2, rando = @0x266f, aptos = @0x1)]
    fun test_configs_are_set(myself: &signer, rando: &signer, aptos: &signer) acquires Config {
        account::create_account_for_test(signer::address_of(myself));
        account::create_account_for_test(signer::address_of(rando));
        account::create_account_for_test(signer::address_of(aptos));

        // initializes coin, which is required for transfers
        coin::register<AptosCoin>(myself);
        initialize_for_test(myself, aptos);

        assert!(is_enabled(), 0);
        set_is_enabled(myself, false);
        assert!(!is_enabled(), 0);

        assert!(max_domain_length() == 63, 3);
        set_max_domain_length(myself, 25);
        assert!(max_domain_length() == 25, 3);

        assert!(max_number_of_seconds_registered() == SECONDS_PER_YEAR * 2, 4);
        set_max_number_of_seconds_registered(myself, SECONDS_PER_YEAR * 5);
        assert!(max_number_of_seconds_registered() == SECONDS_PER_YEAR * 5, 4);

        assert!(fund_destination_address() == signer::address_of(myself), 5);
        coin::register<AptosCoin>(rando);
        set_fund_destination_address(myself, signer::address_of(rando));
        assert!(fund_destination_address() == signer::address_of(rando), 5);

        assert!(admin_address() == signer::address_of(myself), 6);
        set_admin_address(myself, signer::address_of(rando));
        assert!(admin_address() == signer::address_of(rando), 6);
    }


    #[test(myself = @aptos_names_v2, rando = @0x266f, aptos = @0x1)]
    #[expected_failure(abort_code = 393218, location = aptos_framework::aptos_account)]
    fun test_cant_set_foundation_address_without_coin(myself: &signer, rando: &signer, aptos: &signer) acquires Config {
        account::create_account_for_test(signer::address_of(myself));
        account::create_account_for_test(signer::address_of(rando));
        account::create_account_for_test(signer::address_of(aptos));

        // initializes coin, which is required for transfers
        coin::register<AptosCoin>(myself);
        initialize_for_test(myself, aptos);

        assert!(fund_destination_address() == signer::address_of(myself), 5);
        set_fund_destination_address(myself, signer::address_of(rando));
        assert!(fund_destination_address() == signer::address_of(rando), 5);
    }

    #[test(myself = @aptos_names_v2, rando = @0x266f, aptos = @0x1)]
    #[expected_failure(abort_code = 327681, location = aptos_names_v2::v2_config)]
    fun test_foundation_config_requires_admin(myself: &signer, rando: &signer, aptos: &signer) acquires Config {
        account::create_account_for_test(signer::address_of(myself));
        account::create_account_for_test(signer::address_of(rando));
        account::create_account_for_test(signer::address_of(aptos));

        coin::register<AptosCoin>(myself);
        initialize_for_test(myself, aptos);

        assert!(fund_destination_address() == signer::address_of(myself), 5);
        set_fund_destination_address(rando, signer::address_of(rando));
    }

    #[test(myself = @aptos_names_v2, rando = @0x266f, aptos = @0x1)]
    #[expected_failure(abort_code = 327681, location = aptos_names_v2::v2_config)]
    fun test_admin_config_requires_admin(myself: &signer, rando: &signer, aptos: &signer) acquires Config {
        account::create_account_for_test(signer::address_of(myself));
        account::create_account_for_test(signer::address_of(rando));
        account::create_account_for_test(signer::address_of(aptos));

        initialize_for_test(myself, aptos);
        coin::register<AptosCoin>(myself);

        assert!(admin_address() == signer::address_of(myself), 6);
        assert!(admin_address() != signer::address_of(rando), 7);

        set_admin_address(rando, signer::address_of(rando));
    }
}
