/*
Provides a singleton wrapper around PropertyMap to allow for easy and dynamic configurability of contract options.
This includes things like the maximum number of years that a name can be registered for, etc.

Anyone can read, but only admins can write, as all write methods are gated via permissions checks
*/

module aptos_names_v2::v2_config {
    friend aptos_names_v2::v2_domains;

    use aptos_framework::account;
    use aptos_framework::aptos_account;
    use aptos_std::ed25519::{Self, UnvalidatedPublicKey};
    use aptos_names_v2::v2_string_validator;
    use aptos_token::property_map::{Self, PropertyMap};
    use std::error;
    use std::signer;
    use std::string::{Self, String};
    use std::vector;

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

    const DOMAIN_TYPE: vector<u8> = b"domain";
    const SUBDOMAIN_TYPE: vector<u8> = b"subdomain";

    const DOMAIN_COLLECTION_NAME: vector<u8> = b"Aptos Domain Names V2";
    const SUBDOMAIN_COLLECTION_NAME: vector<u8> = b"Aptos Subdomain Names V2";

    /// Raised if the signer is not authorized to perform an action
    const ENOT_AUTHORIZED: u64 = 1;
    /// Raised if there is an invalid value for a configuration
    const EINVALID_VALUE: u64 = 2;

    const SECONDS_PER_YEAR: u64 = 60 * 60 * 24 * 365;

    struct Config has key, store {
        config: PropertyMap,
    }

    public(friend) fun initialize_config(
        deployer: &signer,
        admin_address: address,
        fund_destination_address: address
    ) acquires Config {
        move_to(deployer, Config {
            config: property_map::empty(),
        });

        // Temporarily set this to framework to allow other methods below to be set with framework signer
        set(@aptos_names_v2, config_key_admin_address(), &signer::address_of(deployer));

        set_is_enabled(deployer, true);

        set_max_number_of_seconds_registered(deployer, SECONDS_PER_YEAR * 2);
        set_min_domain_length(deployer, 3);
        set_max_domain_length(deployer, 63);

        // TODO: SET THIS TO SOMETHING REAL
        set_tokendata_description(deployer, string::utf8(b"This is an official Aptos Labs Name Service Name"));
        set_tokendata_url_prefix(deployer, string::utf8(b"https://www.aptosnames.com/api/mainnet/v1/metadata/"));

        // 0.2 APT
        set_subdomain_price(deployer, octas() / 5);
        set_domain_price_for_length(deployer, (80 * octas()), 3);
        set_domain_price_for_length(deployer, (40 * octas()), 4);
        set_domain_price_for_length(deployer, (20 * octas()), 5);
        set_domain_price_for_length(deployer, (5 * octas()), 6);

        // We set it directly here to allow boostrapping the other values
        set(@aptos_names_v2, config_key_fund_destination_address(), &fund_destination_address);
        set(@aptos_names_v2, config_key_admin_address(), &admin_address);
    }


    //
    // Configuration Shortcuts
    //

    public fun octas(): u64 {
        100000000
    }

    public fun is_enabled(): bool acquires Config {
        read_bool(@aptos_names_v2, &config_key_enabled())
    }

    public fun fund_destination_address(): address acquires Config {
        read_address(@aptos_names_v2, &config_key_fund_destination_address())
    }

    public fun admin_address(): address acquires Config {
        read_address(@aptos_names_v2, &config_key_admin_address())
    }

    public fun max_number_of_seconds_registered(): u64 acquires Config {
        read_u64(@aptos_names_v2, &config_key_max_number_of_seconds_registered())
    }

    public fun max_domain_length(): u64 acquires Config {
        read_u64(@aptos_names_v2, &config_key_max_domain_length())
    }

    public fun min_domain_length(): u64 acquires Config {
        read_u64(@aptos_names_v2, &config_key_min_domain_length())
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

    public fun tokendata_description(): String acquires Config {
        read_string(@aptos_names_v2, &config_key_tokendata_description())
    }

    public fun tokendata_url_prefix(): String acquires Config {
        read_string(@aptos_names_v2, &config_key_tokendata_url_prefix())
    }

    public fun domain_type(): String {
        return string::utf8(DOMAIN_TYPE)
    }

    public fun subdomain_type(): String {
        return string::utf8(SUBDOMAIN_TYPE)
    }

    public fun domain_collection_name(): String {
        return string::utf8(DOMAIN_COLLECTION_NAME)
    }

    public fun subdomain_collection_name(): String {
        return string::utf8(SUBDOMAIN_COLLECTION_NAME)
    }

    public fun domain_price_for_length(domain_length: u64): u64 acquires Config {
        read_u64(@aptos_names_v2, &config_key_domain_price(domain_length))
    }

    public fun subdomain_price(): u64 acquires Config {
        read_u64(@aptos_names_v2, &config_key_subdomain_price())
    }

    #[view]
    public fun reregistration_grace_sec(): u64 acquires Config {
        let key = config_key_reregistration_grace_sec();
        let key_exists = property_map::contains_key(&borrow_global<Config>(@aptos_names).config, &key);
        if (key_exists) {
            read_u64(@aptos_names, &key)
        } else {
            // Default to 0 if key DNE
            0
        }
    }

    //
    // Setters
    //

    public entry fun set_is_enabled(sign: &signer, enabled: bool) acquires Config {
        assert_signer_is_admin(sign);
        set(@aptos_names_v2, config_key_enabled(), &enabled)
    }

    public entry fun set_fund_destination_address(sign: &signer, addr: address) acquires Config {
        assert_signer_is_admin(sign);
        aptos_account::assert_account_is_registered_for_apt(addr);

        set(@aptos_names_v2, config_key_fund_destination_address(), &addr)
    }

    public entry fun set_admin_address(sign: &signer, addr: address) acquires Config {
        assert_signer_is_admin(sign);
        assert!(account::exists_at(addr), error::invalid_argument(EINVALID_VALUE));
        set(@aptos_names_v2, config_key_admin_address(), &addr)
    }

    public entry fun set_max_number_of_seconds_registered(sign: &signer, max_seconds_registered: u64) acquires Config {
        assert_signer_is_admin(sign);
        assert!(max_seconds_registered > 0, error::invalid_argument(EINVALID_VALUE));
        set(@aptos_names_v2, config_key_max_number_of_seconds_registered(), &max_seconds_registered)
    }

    public entry fun set_max_domain_length(sign: &signer, domain_length: u64) acquires Config {
        assert_signer_is_admin(sign);
        assert!(domain_length > 0, error::invalid_argument(EINVALID_VALUE));
        set(@aptos_names_v2, config_key_max_domain_length(), &domain_length)
    }

    public entry fun set_min_domain_length(sign: &signer, domain_length: u64) acquires Config {
        assert_signer_is_admin(sign);
        assert!(domain_length > 0, error::invalid_argument(EINVALID_VALUE));
        set(@aptos_names_v2, config_key_min_domain_length(), &domain_length)
    }

    public entry fun set_tokendata_description(sign: &signer, description: String) acquires Config {
        assert_signer_is_admin(sign);
        set(@aptos_names_v2, config_key_tokendata_description(), &description)
    }

    public entry fun set_tokendata_url_prefix(sign: &signer, description: String) acquires Config {
        assert_signer_is_admin(sign);
        set(@aptos_names_v2, config_key_tokendata_url_prefix(), &description)
    }

    public entry fun set_subdomain_price(sign: &signer, price: u64) acquires Config {
        assert_signer_is_admin(sign);
        set(@aptos_names_v2, config_key_subdomain_price(), &price)
    }

    public entry fun set_domain_price_for_length(sign: &signer, price: u64, length: u64) acquires Config {
        assert_signer_is_admin(sign);
        assert!(price > 0, error::invalid_argument(EINVALID_VALUE));
        assert!(length > 0, error::invalid_argument(EINVALID_VALUE));
        set(@aptos_names_v2, config_key_domain_price(length), &price)
    }

    public entry fun set_reregistration_grace_sec(sign: &signer, reregistration_grace_sec: u64) acquires Config {
        assert_signer_is_admin(sign);
        set(@aptos_names, config_key_reregistration_grace_sec(), &reregistration_grace_sec);
    }

    //
    // Configuration Methods
    //

    public fun config_key_enabled(): String {
        string::utf8(CONFIG_KEY_ENABLED)
    }

    public fun config_key_admin_address(): String {
        string::utf8(CONFIG_KEY_ADMIN_ADDRESS)
    }

    public fun config_key_fund_destination_address(): String {
        string::utf8(CONFIG_KEY_FUND_DESTINATION_ADDRESS)
    }

    public fun config_key_max_number_of_seconds_registered(): String {
        string::utf8(CONFIG_KEY_MAX_NUMBER_OF_SECONDS_REGISTERED)
    }

    public fun config_key_max_domain_length(): String {
        string::utf8(CONFIG_KEY_MAX_DOMAIN_LENGTH)
    }

    public fun config_key_min_domain_length(): String {
        string::utf8(CONFIG_KEY_MIN_DOMAIN_LENGTH)
    }

    public fun config_key_tokendata_description(): String {
        string::utf8(CONFIG_KEY_TOKENDATA_DESCRIPTION)
    }

    public fun config_key_tokendata_url_prefix(): String {
        string::utf8(CONFIG_KEY_TOKENDATA_URL_PREFIX)
    }

    public fun config_key_domain_price(domain_length: u64): String {
        let key = string::utf8(CONFIG_KEY_DOMAIN_PRICE_PREFIX);
        string::append(&mut key, v2_string_validator::u128_to_string((domain_length as u128)));
        key
    }

    public fun config_key_subdomain_price(): String {
        string::utf8(CONFIG_KEY_SUBDOMAIN_PRICE)
    }

    public fun config_key_reregistration_grace_sec(): String {
        string::utf8(CONFIG_KEY_REREGISTRATION_GRACE_SEC)
    }

    fun set<T: copy>(addr: address, config_name: String, value: &T) acquires Config {
        let map = &mut borrow_global_mut<Config>(addr).config;
        let value = property_map::create_property_value(value);
        if (property_map::contains_key(map, &config_name)) {
            property_map::update_property_value(map, &config_name, value);
        } else {
            property_map::add(map, config_name, value);
        };
    }

    public fun read_string(addr: address, key: &String): String acquires Config {
        property_map::read_string(&borrow_global<Config>(addr).config, key)
    }

    public fun read_u8(addr: address, key: &String): u8 acquires Config {
        property_map::read_u8(&borrow_global<Config>(addr).config, key)
    }

    public fun read_u64(addr: address, key: &String): u64 acquires Config {
        property_map::read_u64(&borrow_global<Config>(addr).config, key)
    }

    public fun read_address(addr: address, key: &String): address acquires Config {
        property_map::read_address(&borrow_global<Config>(addr).config, key)
    }

    public fun read_u128(addr: address, key: &String): u128 acquires Config {
        property_map::read_u128(&borrow_global<Config>(addr).config, key)
    }

    public fun read_bool(addr: address, key: &String): bool acquires Config {
        property_map::read_bool(&borrow_global<Config>(addr).config, key)
    }

    public fun read_unvalidated_public_key(addr: address, key: &String): UnvalidatedPublicKey acquires Config {
        let value = property_map::borrow_value(property_map::borrow(&borrow_global<Config>(addr).config, key));
        // remove the length of this vector recorded at index 0
        vector::remove(&mut value, 0);
        ed25519::new_unvalidated_public_key_from_bytes(value)
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
        set(@aptos_names_v2, config_key_fund_destination_address(), &addr)
    }

    #[test_only]
    public fun set_admin_address_test_only(addr: address) acquires Config {
        set(@aptos_names_v2, config_key_admin_address(), &addr)
    }

    #[test_only]
    public fun initialize_for_test(aptos_names_v2: &signer, aptos: &signer) acquires Config {
        timestamp::set_time_has_started_for_testing(aptos);
        initialize_aptoscoin_for(aptos);
        initialize_config(aptos_names_v2, @aptos_names_v2, @aptos_names_v2);
        set_admin_address_test_only(signer::address_of(aptos_names_v2));
    }

    #[test(myself = @aptos_names_v2)]
    fun test_default_token_configs_are_set(myself: signer) acquires Config {
        account::create_account_for_test(signer::address_of(&myself));

        initialize_config(&myself, @aptos_names_v2, @aptos_names_v2);
        set(@aptos_names_v2, config_key_admin_address(), &@aptos_names_v2);

        set_tokendata_description(&myself, string::utf8(b"test description"));
        assert!(tokendata_description() == string::utf8(b"test description"), 1);

        set_tokendata_url_prefix(&myself, string::utf8(b"test_prefix"));
        assert!(tokendata_url_prefix() == string::utf8(b"test_prefix"), 1);
    }

    #[test(myself = @aptos_names_v2)]
    fun test_default_tokens_configs_are_set(myself: signer) acquires Config {
        account::create_account_for_test(signer::address_of(&myself));

        initialize_config(&myself, @aptos_names_v2, @aptos_names_v2);
        set(@aptos_names_v2, config_key_admin_address(), &@aptos_names_v2);

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
