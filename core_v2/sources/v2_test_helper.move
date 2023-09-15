#[test_only]
module aptos_names_v2::v2_test_helper {
    use aptos_framework::account;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use aptos_names_v2::v2_config;
    use aptos_names_v2::v2_domains;
    use aptos_names_v2::v2_price_model;
    use aptos_names_v2::v2_test_utils;
    use std::option::{Self, Option};
    use std::signer;
    use std::string::{Self, String};
    use std::vector;

    // Ammount to mint to test accounts during the e2e tests
    const MINT_AMOUNT_APT: u64 = 500;
    const SECONDS_PER_DAY: u64 = 60 * 60 * 24;
    const SECONDS_PER_YEAR: u64 = 60 * 60 * 24 * 365;

    // 500 APT
    public fun mint_amount(): u64 {
        MINT_AMOUNT_APT * v2_config::octas()
    }

    public fun domain_name(): String {
        string::utf8(b"test")
    }

    public fun subdomain_name(): String {
        string::utf8(b"sub")
    }

    public fun one_year_secs(): u64 {
        SECONDS_PER_YEAR
    }

    public fun two_hundred_year_secs(): u64 {
        SECONDS_PER_YEAR * 200
    }

    public fun fq_domain_name(): String {
        string::utf8(b"test.apt")
    }

    public fun fq_subdomain_name(): String {
        string::utf8(b"sub.test.apt")
    }

    public fun invalid_subdomain_name(): String {
        string::utf8(b"a")
    }

    /// Sets up test by initializing ANS v2
    public fun e2e_test_setup(
        aptos_names_v2: &signer,
        user: signer,
        aptos: &signer,
        rando: signer,
        foundation: &signer
    ): vector<signer> {
        account::create_account_for_test(@aptos_names_v2);
        let new_accounts = setup_and_fund_accounts(aptos, foundation, vector[user, rando]);
        timestamp::set_time_has_started_for_testing(aptos);
        aptos_names_v2::v2_domains::init_module_for_test(aptos_names_v2);
        v2_config::set_fund_destination_address_test_only(signer::address_of(foundation));
        new_accounts
    }

    /// Register the domain, and verify the registration was done correctly
    public fun register_name(
        router_signer: &signer,
        user: &signer,
        subdomain_name: Option<String>,
        domain_name: String,
        registration_duration_secs: u64,
        _expected_fq_domain_name: String,
        _expected_property_version: u64,
    ) {
        let user_addr = signer::address_of(user);

        let is_subdomain = option::is_some(&subdomain_name);

        let user_balance_before = coin::balance<AptosCoin>(user_addr);
        let register_name_event_event_count_before = v2_domains::get_register_name_event_count();
        let set_target_address_event_event_count_before = v2_domains::get_set_target_address_event_count();

        if (option::is_none(&subdomain_name)) {
            v2_domains::register_domain(router_signer, user, domain_name, registration_duration_secs);
        } else {
            v2_domains::register_subdomain(
                router_signer,
                user,
                domain_name,
                *option::borrow(&subdomain_name),
                timestamp::now_seconds() + registration_duration_secs
            );
        };

        // It should now be: not expired, registered, and not registerable
        assert!(!v2_domains::is_name_expired(domain_name, subdomain_name), 12);
        assert!(!v2_domains::is_name_registerable(domain_name, subdomain_name), 13);
        assert!(v2_domains::is_name_registered(domain_name, subdomain_name), 14);

        let is_owner = v2_domains::is_token_owner(user_addr, domain_name, subdomain_name);
        let is_expired = v2_domains::is_name_expired(domain_name, subdomain_name);
        // TODO: Re-enable / Re-write
        // let (tdi_creator, tdi_collection, tdi_name, tdi_property_version) = token::get_token_id_fields(&token_id);

        assert!(is_owner && !is_expired, 3);

        let expected_user_balance_after;
        let user_balance_after = coin::balance<AptosCoin>(user_addr);
        if (is_subdomain) {
            // If it's a subdomain, we only charge a nomincal fee
            expected_user_balance_after = user_balance_before - v2_price_model::price_for_subdomain(
                registration_duration_secs
            );
        } else {
            let domain_price = v2_price_model::price_for_domain(
                string::length(&domain_name),
                registration_duration_secs
            );
            assert!(domain_price / v2_config::octas() == 40, domain_price / v2_config::octas());
            expected_user_balance_after = user_balance_before - domain_price;
        };

        v2_test_utils::print_actual_expected(
            b"user_balance_after: ",
            user_balance_after,
            expected_user_balance_after,
            false
        );
        assert!(user_balance_after == expected_user_balance_after, expected_user_balance_after);

        // Ensure the name was registered correctly, with an expiration timestamp one year in the future
        let expiration_time_sec = v2_domains::get_expiration(domain_name, subdomain_name);
        assert!(seconds_to_days(expiration_time_sec - timestamp::now_seconds()) == 365, 10);

        let (expiration_time_sec_lookup_result, _) = v2_domains::get_name_record_props(subdomain_name, domain_name);
        assert!(
            seconds_to_days(expiration_time_sec_lookup_result - timestamp::now_seconds()) == 365, 100);

        // TODO: Re-enable / Re-write
        // Ensure the properties were set correctly
        // let token_data_id = token_helper::build_tokendata_id(token_helper::get_token_signer_address(), subdomain_name, domain_name);
        // let (creator, collection_name, token_name) = token::get_token_data_id_fields(&token_data_id);
        // assert!(creator == domains::get_token_signer_address(), 20);
        // assert!(collection_name == string::utf8(b"Aptos Names V1"), 21);
        // assert!(token_name == token_name, 22);

        // Assert events have been correctly emmitted
        let register_name_event_num_emitted = v2_domains::get_register_name_event_count(
        ) - register_name_event_event_count_before;
        let set_target_address_event_num_emitted = v2_domains::get_set_target_address_event_count(
        ) - set_target_address_event_event_count_before;

        v2_test_utils::print_actual_expected(
            b"register_name_event_num_emitted: ",
            register_name_event_num_emitted,
            1,
            false
        );
        assert!(register_name_event_num_emitted == 1, register_name_event_num_emitted);

        v2_test_utils::print_actual_expected(
            b"set_target_address_event_num_emitted: ",
            set_target_address_event_num_emitted,
            1,
            false
        );
    }

    /// Set the domain address, and verify the address was set correctly
    public fun set_target_address(
        user: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
        expected_target_address: address
    ) {
        let user_addr = signer::address_of(user);

        let register_name_event_event_count_before = v2_domains::get_register_name_event_count();
        let set_target_address_event_event_count_before = v2_domains::get_set_target_address_event_count();
        let set_reverse_lookup_event_event_count_before = v2_domains::get_set_reverse_lookup_event_count();
        let maybe_reverse_lookup_before = v2_domains::get_reverse_lookup(user_addr);

        v2_domains::set_target_address(user, domain_name, subdomain_name, expected_target_address);
        let target_address = v2_domains::get_target_address(domain_name, subdomain_name);
        v2_test_utils::print_actual_expected(
            b"set_domain_address: ",
            target_address,
            option::some(expected_target_address),
            false
        );
        assert!(target_address == option::some(expected_target_address), 33);

        // When setting the target address to an address that is *not* the owner's, the reverse lookup should also be cleared
        if (signer::address_of(user) != expected_target_address) {
            let maybe_reverse_lookup = v2_domains::get_reverse_lookup(user_addr);
            assert!(option::is_none(&maybe_reverse_lookup), 33);
        };

        // Assert events have been correctly emmitted
        let register_name_event_num_emitted = v2_domains::get_register_name_event_count(
        ) - register_name_event_event_count_before;
        let set_target_address_event_num_emitted = v2_domains::get_set_target_address_event_count(
        ) - set_target_address_event_event_count_before;
        let set_reverse_lookup_event_num_emitted = v2_domains::get_set_reverse_lookup_event_count(
        ) - set_reverse_lookup_event_event_count_before;

        v2_test_utils::print_actual_expected(
            b"register_name_event_num_emitted: ",
            register_name_event_num_emitted,
            0,
            false
        );
        assert!(register_name_event_num_emitted == 0, register_name_event_num_emitted);

        v2_test_utils::print_actual_expected(
            b"set_target_address_event_num_emitted: ",
            set_target_address_event_num_emitted,
            1,
            false
        );
        assert!(set_target_address_event_num_emitted == 1, set_target_address_event_num_emitted);

        // If the signer had a reverse lookup before, and set his reverse lookup name to a different address, it should be cleared
        if (option::is_some(&maybe_reverse_lookup_before)) {
            let (maybe_reverse_subdomain, reverse_domain) = v2_domains::get_name_props_from_token_addr(
                *option::borrow(&maybe_reverse_lookup_before)
            );
            if (maybe_reverse_subdomain == subdomain_name && reverse_domain == domain_name && signer::address_of(
                user
            ) != expected_target_address) {
                assert!(set_reverse_lookup_event_num_emitted == 1, set_reverse_lookup_event_num_emitted);
            };
        };
    }

    /// Clear the domain address, and verify the address was cleared
    public fun clear_target_address(user: &signer, subdomain_name: Option<String>, domain_name: String) {
        let user_addr = signer::address_of(user);
        let register_name_event_event_count_before = v2_domains::get_register_name_event_count();
        let set_target_address_event_event_count_before = v2_domains::get_set_target_address_event_count();
        let set_reverse_lookup_event_event_count_before = v2_domains::get_set_reverse_lookup_event_count();
        let maybe_reverse_lookup_before = v2_domains::get_reverse_lookup(user_addr);

        v2_domains::clear_target_address(user, subdomain_name, domain_name);
        let target_address = v2_domains::get_target_address(domain_name, subdomain_name);
        v2_test_utils::print_actual_expected(b"clear_domain_address: ", target_address, option::none(), false);
        assert!(target_address == option::none(), 32);

        if (option::is_some(&maybe_reverse_lookup_before)) {
            let reverse_lookup_before = option::borrow(&maybe_reverse_lookup_before);
            if (*reverse_lookup_before == v2_domains::get_token_addr(domain_name, subdomain_name)) {
                let reverse_lookup_after = v2_domains::get_reverse_lookup(user_addr);
                assert!(option::is_none(&reverse_lookup_after), 35);

                let set_reverse_lookup_event_num_emitted = v2_domains::get_set_reverse_lookup_event_count(
                ) - set_reverse_lookup_event_event_count_before;
                assert!(set_reverse_lookup_event_num_emitted == 1, set_reverse_lookup_event_num_emitted);
            };
        };

        // Assert events have been correctly emmitted
        let register_name_event_num_emitted = v2_domains::get_register_name_event_count(
        ) - register_name_event_event_count_before;
        let set_target_address_event_num_emitted = v2_domains::get_set_target_address_event_count(
        ) - set_target_address_event_event_count_before;

        v2_test_utils::print_actual_expected(
            b"register_name_event_num_emitted: ",
            register_name_event_num_emitted,
            0,
            false
        );
        assert!(register_name_event_num_emitted == 0, register_name_event_num_emitted);

        v2_test_utils::print_actual_expected(
            b"set_target_address_event_num_emitted: ",
            set_target_address_event_num_emitted,
            1,
            false
        );
        assert!(set_target_address_event_num_emitted == 1, set_target_address_event_num_emitted);
    }

    public fun setup_and_fund_accounts(aptos: &signer, foundation: &signer, users: vector<signer>): vector<signer> {
        let (burn_cap, mint_cap) = aptos_framework::aptos_coin::initialize_for_test(aptos);

        let len = vector::length(&users);
        let i = 0;
        while (i < len) {
            let user = vector::borrow(&users, i);
            let user_addr = signer::address_of(user);
            account::create_account_for_test(user_addr);
            coin::register<AptosCoin>(user);
            coin::deposit(user_addr, coin::mint<AptosCoin>(mint_amount(), &mint_cap));
            assert!(coin::balance<AptosCoin>(user_addr) == mint_amount(), 1);
            i = i + 1;
        };

        account::create_account_for_test(signer::address_of(foundation));
        coin::register<AptosCoin>(foundation);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
        users
    }

    fun seconds_to_days(seconds: u64): u64 {
        seconds / SECONDS_PER_DAY
    }
}
