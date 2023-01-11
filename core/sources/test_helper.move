#[test_only]
module aptos_names::test_helper {
    use aptos_framework::account;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use aptos_names::config;
    use aptos_names::domains;
    use aptos_names::price_model;
    use aptos_names::test_utils;
    use aptos_names::time_helper;
    use aptos_names::token_helper;
    use aptos_token::token;
    use std::option::{Self, Option};
    use std::signer;
    use std::string::{Self, String};
    use std::vector;

    // Ammount to mint to test accounts during the e2e tests
    const MINT_AMOUNT_APT: u64 = 500;

    // 500 APT
    public fun mint_amount(): u64 {
        MINT_AMOUNT_APT * config::octas()
    }

    public fun domain_name(): String {
        string::utf8(b"test")
    }

    public fun subdomain_name(): String {
        string::utf8(b"sub")
    }

    public fun one_year_secs(): u64 {
        time_helper::years_to_seconds(1)
    }

    public fun two_hundred_year_secs(): u64 {
        time_helper::years_to_seconds(200)
    }

    public fun fq_domain_name(): String {
        string::utf8(b"test.apt")
    }

    public fun fq_subdomain_name(): String {
        string::utf8(b"sub.test.apt")
    }

    public fun e2e_test_setup(myself: &signer, user: signer, aptos: &signer, rando: signer, foundation: &signer): vector<signer> {
        account::create_account_for_test(@aptos_names);
        let new_accounts = setup_and_fund_accounts(aptos, foundation, vector[user, rando]);
        timestamp::set_time_has_started_for_testing(aptos);
        domains::init_module_for_test(myself);
        config::set_fund_destination_address_test_only(signer::address_of(foundation));
        new_accounts
    }

    /// Register the domain, and verify the registration was done correctly
    public fun register_name(user: &signer, subdomain_name: Option<String>, domain_name: String, registration_duration_secs: u64, expected_fq_domain_name: String, expected_property_version: u64, signature: vector<u8>) {
        let user_addr = signer::address_of(user);

        let is_subdomain = option::is_some(&subdomain_name);

        let user_balance_before = coin::balance<AptosCoin>(user_addr);
        let user_reverse_lookup_before = domains::get_reverse_lookup(user_addr);
        let maybe_target_address = domains::name_resolved_address(subdomain_name, domain_name);
        let name_reverse_lookup_before = if (option::is_some(&maybe_target_address)) {
            domains::get_reverse_lookup(*option::borrow(&maybe_target_address))
        } else {
            option::none()
        };
        let is_expired_before = domains::name_is_registered(subdomain_name, domain_name) && domains::name_is_expired(subdomain_name, domain_name);
        let register_name_event_v1_event_count_before = domains::get_register_name_event_v1_count();
        let set_name_address_event_v1_event_count_before = domains::get_set_name_address_event_v1_count();
        let set_reverse_lookup_event_v1_event_count_before = domains::get_set_reverse_lookup_event_v1_count();

        let years = (time_helper::seconds_to_years(registration_duration_secs) as u8);
        if (option::is_none(&subdomain_name)) {
            if (vector::length(&signature)== 0) {
                domains::register_domain(user, domain_name, years);
            } else {
                domains::register_domain_with_signature(user, domain_name, years, signature);
            }
        } else {
            domains::register_subdomain(user, *option::borrow(&subdomain_name), domain_name, registration_duration_secs);
        };

        // It should now be: not expired, registered, and not registerable
        assert!(!domains::name_is_expired(subdomain_name, domain_name), 12);
        assert!(!domains::name_is_registerable(subdomain_name, domain_name), 13);
        assert!(domains::name_is_registered(subdomain_name, domain_name), 14);

        let (is_owner, token_id) = domains::is_owner_of_name(user_addr, subdomain_name, domain_name);
        let (tdi_creator, tdi_collection, tdi_name, tdi_property_version) = token::get_token_id_fields(&token_id);

        assert!(is_owner, 3);
        assert!(tdi_creator == token_helper::get_token_signer_address(), 4);
        assert!(tdi_collection == config::collection_name_v1(), 5);
        test_utils::print_actual_expected(b"tdi_name: ", tdi_name, expected_fq_domain_name, false);
        assert!(tdi_name == expected_fq_domain_name, 6);
        test_utils::print_actual_expected(b"tdi_property_version: ", tdi_property_version, expected_property_version, false);
        assert!(tdi_property_version == expected_property_version, tdi_property_version);

        let expected_user_balance_after;
        let user_balance_after = coin::balance<AptosCoin>(user_addr);
        if (is_subdomain) {
            // If it's a subdomain, we only charge a nomincal fee
            expected_user_balance_after = user_balance_before - price_model::price_for_subdomain_v1(registration_duration_secs);
        } else {
            let domain_price = price_model::price_for_domain_v1(string::length(&domain_name), years);
            assert!(domain_price / config::octas() == 40, domain_price / config::octas());
            expected_user_balance_after = user_balance_before - domain_price;
        };

        test_utils::print_actual_expected(b"user_balance_after: ", user_balance_after, expected_user_balance_after, false);
        assert!(user_balance_after == expected_user_balance_after, expected_user_balance_after);

        // Ensure the name was registered correctly, with an expiration timestamp one year in the future
        let (property_version, expiration_time_sec, target_address) = domains::get_name_record_v1_props_for_name(subdomain_name, domain_name);
        assert!(time_helper::seconds_to_days(expiration_time_sec - timestamp::now_seconds()) == 365, 10);

        if (is_subdomain) {
            if (option::is_none(&user_reverse_lookup_before)) {
                // Should automatically point to the users address
                assert!(target_address == option::some(user_addr), 11);
            } else {
                // We haven't set a target address yet!
                assert!(target_address == option::none(), 11);
            }
        } else {
            // Should automatically point to the users address
            assert!(target_address == option::some(user_addr), 11);
        };

        // And the property version is correct
        test_utils::print_actual_expected(b"property_version: ", property_version, expected_property_version, false);
        assert!(property_version == expected_property_version, 12);

        // Ensure the properties were set correctly
        let token_data_id = token_helper::build_tokendata_id(token_helper::get_token_signer_address(), subdomain_name, domain_name);
        let (creator, collection_name, token_name) = token::get_token_data_id_fields(&token_data_id);
        assert!(creator == token_helper::get_token_signer_address(), 20);
        assert!(collection_name == string::utf8(b"Aptos Names V1"), 21);
        assert!(token_name == token_name, 22);

        // Assert events have been correctly emmitted
        let register_name_event_v1_num_emitted = domains::get_register_name_event_v1_count() - register_name_event_v1_event_count_before;
        let set_name_address_event_v1_num_emitted = domains::get_set_name_address_event_v1_count() - set_name_address_event_v1_event_count_before;
        let set_reverse_lookup_event_v1_num_emitted = domains::get_set_reverse_lookup_event_v1_count() - set_reverse_lookup_event_v1_event_count_before;

        test_utils::print_actual_expected(b"register_name_event_v1_num_emitted: ", register_name_event_v1_num_emitted, 1, false);
        assert!(register_name_event_v1_num_emitted == 1, register_name_event_v1_num_emitted);

        // Reverse lookup should be set if user did not have one before
        if (option::is_none(&user_reverse_lookup_before)) {
            let maybe_reverse_lookup_after = domains::get_reverse_lookup(user_addr);
            if (option::is_some(&maybe_reverse_lookup_after)) {
                let reverse_lookup_after = option::borrow(&maybe_reverse_lookup_after);
                assert!(*reverse_lookup_after == domains::create_name_record_key_v1(subdomain_name, domain_name), 36);
            } else {
                // Reverse lookup is not set, even though user did not have a reverse lookup before.
                assert!(false, 37);
            };
            // If we are registering over a name that is already registered but expired and was a primary name,
            // that name should be removed from being a primary name.
            if (option::is_some(&name_reverse_lookup_before) && is_expired_before) {
                assert!(set_reverse_lookup_event_v1_num_emitted == 2, set_reverse_lookup_event_v1_num_emitted);
            } else {
                assert!(set_reverse_lookup_event_v1_num_emitted == 1, set_reverse_lookup_event_v1_num_emitted);
            }
        } else {
            // If we are registering over a name that is already registered but expired and was the user's primary name,
            // that name should be removed from being a primary name and the new one should be set.
            if (option::is_some(&name_reverse_lookup_before)
                && option::is_some(&user_reverse_lookup_before)
                && *option::borrow(&name_reverse_lookup_before) == *option::borrow(&user_reverse_lookup_before)
                && is_expired_before
            ) {
                assert!(set_reverse_lookup_event_v1_num_emitted == 2, set_reverse_lookup_event_v1_num_emitted);
            } else if (option::is_some(&name_reverse_lookup_before) && is_expired_before) {
                // If we are registering over a name that is already registered but expired and was a primary name,
                // that name should be removed from being a primary name.
                assert!(set_reverse_lookup_event_v1_num_emitted == 1, set_reverse_lookup_event_v1_num_emitted);
            } else {
                assert!(set_reverse_lookup_event_v1_num_emitted == 0, set_reverse_lookup_event_v1_num_emitted);
            }
        };

        if (is_subdomain) {
            if (option::is_none(&user_reverse_lookup_before)) {
                // Should automatically point to the users address
                test_utils::print_actual_expected(b"set_name_address_event_v1_num_emitted: ", set_name_address_event_v1_num_emitted, 1, false);
                assert!(set_name_address_event_v1_num_emitted == 1, set_name_address_event_v1_num_emitted);
            } else {
                // We haven't set a target address yet!
                test_utils::print_actual_expected(b"set_name_address_event_v1_num_emitted: ", set_name_address_event_v1_num_emitted, 0, false);
                assert!(set_name_address_event_v1_num_emitted == 0, set_name_address_event_v1_num_emitted);
            }
        } else {
            // Should automatically point to the users address
            test_utils::print_actual_expected(b"set_name_address_event_v1_num_emitted: ", set_name_address_event_v1_num_emitted, 1, false);
            assert!(set_name_address_event_v1_num_emitted == 1, set_name_address_event_v1_num_emitted);
        };
    }

    /// Set the domain address, and verify the address was set correctly
    public fun set_name_address(user: &signer, subdomain_name: Option<String>, domain_name: String, expected_target_address: address) {
        let user_addr = signer::address_of(user);

        let register_name_event_v1_event_count_before = domains::get_register_name_event_v1_count();
        let set_name_address_event_v1_event_count_before = domains::get_set_name_address_event_v1_count();
        let set_reverse_lookup_event_v1_event_count_before = domains::get_set_reverse_lookup_event_v1_count();
        let maybe_reverse_lookup_before = domains::get_reverse_lookup(user_addr);

        domains::set_name_address(user, subdomain_name, domain_name, expected_target_address);
        let (_property_version, _expiration_time_sec, target_address) = domains::get_name_record_v1_props_for_name(subdomain_name, domain_name);
        test_utils::print_actual_expected(b"set_domain_address: ", target_address, option::some(expected_target_address), false);
        assert!(target_address == option::some(expected_target_address), 33);

        // When setting the target address to an address that is *not* the owner's, the reverse lookup should also be cleared
        if (signer::address_of(user) != expected_target_address) {
            let maybe_reverse_lookup = domains::get_reverse_lookup(user_addr);
            assert!(option::is_none(&maybe_reverse_lookup), 33);
        };

        // Assert events have been correctly emmitted
        let register_name_event_v1_num_emitted = domains::get_register_name_event_v1_count() - register_name_event_v1_event_count_before;
        let set_name_address_event_v1_num_emitted = domains::get_set_name_address_event_v1_count() - set_name_address_event_v1_event_count_before;
        let set_reverse_lookup_event_v1_num_emitted = domains::get_set_reverse_lookup_event_v1_count() - set_reverse_lookup_event_v1_event_count_before;

        test_utils::print_actual_expected(b"register_name_event_v1_num_emitted: ", register_name_event_v1_num_emitted, 0, false);
        assert!(register_name_event_v1_num_emitted == 0, register_name_event_v1_num_emitted);

        test_utils::print_actual_expected(b"set_name_address_event_v1_num_emitted: ", set_name_address_event_v1_num_emitted, 1, false);
        assert!(set_name_address_event_v1_num_emitted == 1, set_name_address_event_v1_num_emitted);

        // If the signer had a reverse lookup before, and set his reverse lookup name to a different address, it should be cleared
        if (option::is_some(&maybe_reverse_lookup_before)) {
            let (maybe_reverse_subdomain, reverse_domain) = domains::get_name_record_key_v1_props(option::borrow(&maybe_reverse_lookup_before));
            if (maybe_reverse_subdomain == subdomain_name && reverse_domain == domain_name && signer::address_of(user) != expected_target_address) {
                assert!(set_reverse_lookup_event_v1_num_emitted == 1, set_reverse_lookup_event_v1_num_emitted);
            };
        };
    }

    /// Clear the domain address, and verify the address was cleared
    public fun clear_name_address(user: &signer, subdomain_name: Option<String>, domain_name: String) {
        let user_addr = signer::address_of(user);
        let register_name_event_v1_event_count_before = domains::get_register_name_event_v1_count();
        let set_name_address_event_v1_event_count_before = domains::get_set_name_address_event_v1_count();
        let set_reverse_lookup_event_v1_event_count_before = domains::get_set_reverse_lookup_event_v1_count();
        let maybe_reverse_lookup_before = domains::get_reverse_lookup(user_addr);

        // And also can clear if is registered address, but not owner
        if (option::is_none(&subdomain_name)) {
            domains::clear_domain_address(user, domain_name);
        } else {
            domains::clear_subdomain_address(user, *option::borrow(&subdomain_name), domain_name);
        };
        let (_property_version, _expiration_time_sec, target_address) = domains::get_name_record_v1_props_for_name(subdomain_name, domain_name);
        test_utils::print_actual_expected(b"clear_domain_address: ", target_address, option::none(), false);
        assert!(target_address == option::none(), 32);

        if (option::is_some(&maybe_reverse_lookup_before)) {
            let reverse_lookup_before = option::borrow(&maybe_reverse_lookup_before);
            if (*reverse_lookup_before == domains::create_name_record_key_v1(subdomain_name, domain_name)) {
                let reverse_lookup_after = domains::get_reverse_lookup(user_addr);
                assert!(option::is_none(&reverse_lookup_after), 35);

                let set_reverse_lookup_event_v1_num_emitted = domains::get_set_reverse_lookup_event_v1_count() - set_reverse_lookup_event_v1_event_count_before;
                assert!(set_reverse_lookup_event_v1_num_emitted == 1, set_reverse_lookup_event_v1_num_emitted);
            };
        };

        // Assert events have been correctly emmitted
        let register_name_event_v1_num_emitted = domains::get_register_name_event_v1_count() - register_name_event_v1_event_count_before;
        let set_name_address_event_v1_num_emitted = domains::get_set_name_address_event_v1_count() - set_name_address_event_v1_event_count_before;

        test_utils::print_actual_expected(b"register_name_event_v1_num_emitted: ", register_name_event_v1_num_emitted, 0, false);
        assert!(register_name_event_v1_num_emitted == 0, register_name_event_v1_num_emitted);

        test_utils::print_actual_expected(b"set_name_address_event_v1_num_emitted: ", set_name_address_event_v1_num_emitted, 1, false);
        assert!(set_name_address_event_v1_num_emitted == 1, set_name_address_event_v1_num_emitted);
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
}
