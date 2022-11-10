#[test_only]
module aptos_names::domain_e2e_tests {
    use aptos_framework::chain_id;
    use aptos_framework::timestamp;
    use aptos_names::config;
    use aptos_names::domains;
    use aptos_names::time_helper;
    use aptos_names::test_helper;
    use aptos_names::test_utils;
    use std::option;
    use std::signer;
    use std::vector;

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    fun happy_path_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        let user_addr = signer::address_of(user);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());

        // Set an address and verify it
        test_helper::set_name_address(user, option::none(), test_helper::domain_name(), user_addr);

        // Ensure the owner can clear the address
        test_helper::clear_name_address(user, option::none(), test_helper::domain_name());

        // And also can clear if the user is the registered address, but not owner
        test_helper::set_name_address(user, option::none(), test_helper::domain_name(), signer::address_of(rando));
        test_helper::clear_name_address(rando, option::none(), test_helper::domain_name());

        // Set it back for following tests
        test_helper::set_name_address(user, option::none(), test_helper::domain_name(), user_addr);
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    fun e2e_test_with_valid_signature(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        /*
          Signature generated with scripts/generateKeys.ts
            yarn ts-node --compilerOptions '{"target": "es6", "module": "commonjs", "esModuleInterop": true}'  ./scripts/generateKeys.ts

          let proof_struct = RegisterDomainProofChallenge {
              account_address: AccountAddress::from_hex_literal(APTOS_NAMES).unwrap(),
              module_name: String::from("verify"),
              struct_name: String::from("RegisterDomainProofChallenge"),
              sequence_number: 0,
              register_address: *register_account.address(),
              domain_name: String::from("test"),
              chain_id: 4,
          };
      */

        let signature: vector<u8> = x"f004a92a27f962352456bb5b6728d4d37361d16b5932ed012f8f07bc94e3e73dbf38b643b6e16caa97ff313d48c8fe524325529b7c0e9abf7bd9d5183ff97a03";
        e2e_test_with_signature(myself, user, aptos, rando, foundation, signature);
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 65537)]
    fun e2e_test_with_invalid_signature(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let signature: vector<u8> = x"2b0340b4529e3f90f0b1af7364241c51172c1133f0c077b7836962c3f104115832ccec0b74382533c33d9bd14a6e68021e5c23439242ddd43047e7929084ac01";
        e2e_test_with_signature(myself, user, aptos, rando, foundation, signature);
    }

    #[test_only]
    fun e2e_test_with_signature(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer, signature: vector<u8>) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        let user_addr = signer::address_of(user);

        chain_id::initialize_for_test(&aptos, 4);
        config::set_unrestricted_mint_enabled(myself, false);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, signature);

        // Set an address and verify it
        test_helper::set_name_address(user, option::none(), test_helper::domain_name(), user_addr);

        // Ensure the owner can clear the address
        test_helper::clear_name_address(user, option::none(), test_helper::domain_name());

        // And also can clear if the user is the registered address, but not owner
        test_helper::set_name_address(user, option::none(), test_helper::domain_name(), signer::address_of(rando));
        test_helper::clear_name_address(rando, option::none(), test_helper::domain_name());

        // Set it back for following tests
        test_helper::set_name_address(user, option::none(), test_helper::domain_name(), user_addr);
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 327696)]
    fun test_register_domain_abort_with_disabled_unrestricted_mint(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        chain_id::initialize_for_test(&aptos, 4);
        config::set_unrestricted_mint_enabled(myself, false);

        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    fun names_are_registerable_after_expiry_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());

        // Set the time past the domain's expiration time
        let (_, expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(option::none(), test_helper::domain_name());
        timestamp::update_global_time_for_test_secs(expiration_time_sec + 5);

        // It should now be: expired, registered, AND registerable
        assert!(domains::name_is_expired(option::none(), test_helper::domain_name()), 80);
        assert!(domains::name_is_registered(option::none(), test_helper::domain_name()), 81);
        assert!(domains::name_is_registerable(option::none(), test_helper::domain_name()), 82);

        // Lets try to register it again, now that it is expired
        test_helper::register_name(rando, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 2, vector::empty<u8>());

        // And again!
        let (_, expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(option::none(), test_helper::domain_name());
        timestamp::update_global_time_for_test_secs(expiration_time_sec + 5);

        // It should now be: expired, registered, AND registerable
        assert!(domains::name_is_expired(option::none(), test_helper::domain_name()), 80);
        assert!(domains::name_is_registered(option::none(), test_helper::domain_name()), 81);
        assert!(domains::name_is_registerable(option::none(), test_helper::domain_name()), 82);

        // Lets try to register it again, now that it is expired
        test_helper::register_name(rando, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 3, vector::empty<u8>());
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 196611)]
    fun dont_allow_double_domain_registrations_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());
        // Ensure we can't register it again
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 327689)]
    fun dont_allow_rando_to_set_domain_address_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());
        // Ensure we can't set it as a rando. The expected target address doesn't matter as it won't get hit
        test_helper::set_name_address(rando, option::none(), test_helper::domain_name(), @aptos_names);
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 327682)]
    fun dont_allow_rando_to_clear_domain_address_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain, and set its address
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());
        test_helper::set_name_address(user, option::none(), test_helper::domain_name(), signer::address_of(user));

        // Ensure we can't clear it as a rando
        test_helper::clear_name_address(rando, option::none(), test_helper::domain_name());
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    fun owner_can_clear_domain_address_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain, and set its address
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());
        test_helper::set_name_address(user, option::none(), test_helper::domain_name(), signer::address_of(rando));

        // Ensure we can clear as owner
        test_helper::clear_name_address(user, option::none(), test_helper::domain_name());
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    fun admin_can_force_set_name_address_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        let rando_addr = signer::address_of(rando);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());

        domains::force_set_domain_address(myself, test_helper::domain_name(), rando_addr);
        let (_property_version, _expiration_time_sec, target_address) = domains::get_name_record_v1_props_for_name(option::none(), test_helper::domain_name());
        test_utils::print_actual_expected(b"set_domain_address: ", target_address, option::some(rando_addr), false);
        assert!(target_address == option::some(rando_addr), 33);
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 327681)]
    fun rando_cant_force_set_name_address_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        let rando_addr = signer::address_of(rando);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());

        // Rando is not allowed to do this
        domains::force_set_domain_address(rando, test_helper::domain_name(), rando_addr);
    }


    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    fun admin_can_force_seize_domain_name_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());
        let (is_owner, _token_id) = domains::is_owner_of_name(signer::address_of(user), option::none(), test_helper::domain_name());
        assert!(is_owner, 1);

        // Take the domain name for much longer than users are allowed to register it for
        domains::force_create_or_seize_name(myself, option::none(), test_helper::domain_name(), test_helper::two_hundred_year_secs());
        let (is_owner, _token_id) = domains::is_owner_of_name(signer::address_of(myself), option::none(), test_helper::domain_name());
        assert!(is_owner, 2);

        // Ensure the expiration_time_sec is set to the new far future value
        let (_, expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(option::none(), test_helper::domain_name());
        assert!(time_helper::seconds_to_years(expiration_time_sec) == 200, time_helper::seconds_to_years(expiration_time_sec));
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    fun admin_can_force_create_domain_name_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let _ = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);

        // No domain is registered yet
        assert!(!domains::name_is_registered(option::none(), test_helper::domain_name()), 1);

        // Take the domain name for much longer than users are allowed to register it for
        domains::force_create_or_seize_name(myself, option::none(), test_helper::domain_name(), test_helper::two_hundred_year_secs());
        let (is_owner, _token_id) = domains::is_owner_of_name(signer::address_of(myself), option::none(), test_helper::domain_name());
        assert!(is_owner, 2);

        // Ensure the expiration_time_sec is set to the new far future value
        let (_, expiration_time_sec, _) = domains::get_name_record_v1_props_for_name(option::none(), test_helper::domain_name());
        assert!(time_helper::seconds_to_years(expiration_time_sec) == 200, time_helper::seconds_to_years(expiration_time_sec));

        // Try to nuke the domain
        assert!(domains::name_is_registered(option::none(), test_helper::domain_name()), 3);
        domains::force_clear_registration(myself, option::none(), test_helper::domain_name());
        assert!(!domains::name_is_registered(option::none(), test_helper::domain_name()), 4);
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 327681)]
    fun rando_cant_force_seize_domain_name_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let rando = vector::borrow(&users, 1);

        // Register the domain
        test_helper::register_name(user, option::none(), test_helper::domain_name(), test_helper::one_year_secs(), test_helper::fq_domain_name(), 1, vector::empty<u8>());
        let (is_owner, _token_id) = domains::is_owner_of_name(signer::address_of(user), option::none(), test_helper::domain_name());
        assert!(is_owner, 1);

        // Take the domain name for much longer than users are allowed to register it for
        domains::force_create_or_seize_name(rando, option::none(), test_helper::domain_name(), test_helper::two_hundred_year_secs());
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 327681)]
    fun rando_cant_force_create_domain_name_e2e_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let rando = vector::borrow(&users, 1);

        // No domain is registered yet
        assert!(!domains::name_is_registered(option::none(), test_helper::domain_name()), 1);

        // Take the domain name for much longer than users are allowed to register it for
        domains::force_create_or_seize_name(rando, option::none(), test_helper::domain_name(), test_helper::two_hundred_year_secs());
    }
}
