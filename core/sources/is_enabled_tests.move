#[test_only]
module aptos_names::is_enabled_tests {
    use std::signer;
    use std::string;
    use aptos_framework::chain_id;
    use aptos_names::config;
    use aptos_names::domains;
    use aptos_names::test_helper;
    use std::vector;

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 851969, location = aptos_names::domains)]
    fun is_enabled_register_domain_test(
        myself: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users =
            test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Disable ANS
        config::set_is_enabled(myself, false);

        // Register the domain fails
        domains::register_domain(user, test_helper::domain_name(), 1);
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 851969, location = aptos_names::domains)]
    fun is_enabled_register_domain_with_signature_test(
        myself: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users =
            test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Disable ANS
        config::set_is_enabled(myself, false);

        // Register the domain fails
        chain_id::initialize_for_test(&aptos, 4);
        domains::register_domain_with_signature(
            user,
            test_helper::domain_name(),
            1,
            x"f004a92a27f962352456bb5b6728d4d37361d16b5932ed012f8f07bc94e3e73dbf38b643b6e16caa97ff313d48c8fe524325529b7c0e9abf7bd9d5183ff97a03");
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 851969, location = aptos_names::domains)]
    fun is_enabled_register_subdomain_test(
        myself: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users =
            test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Disable ANS
        config::set_is_enabled(myself, false);

        // Register the subdomain fails
        domains::register_subdomain(user, test_helper::subdomain_name(),
            test_helper::domain_name(), 1,);
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 851969, location = aptos_names::domains)]
    fun is_enabled_set_domain_address_test(
        myself: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users =
            test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user2 = vector::borrow(&users, 1);

        // Register the domain succeeds
        domains::register_domain(user, test_helper::domain_name(), 1);

        // Disable ANS write
        config::set_is_enabled(myself, false);

        // Should not be able to set address because ANS write is disabled
        domains::set_domain_address(user, test_helper::domain_name(),
            signer::address_of(user2))
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 851969, location = aptos_names::domains)]
    fun is_enabled_set_subdomain_address_test(
        myself: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users =
            test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);
        let user2 = vector::borrow(&users, 1);

        // Register the domain succeeds
        domains::register_domain(user, test_helper::domain_name(), 1);
        domains::register_subdomain(user, test_helper::subdomain_name(),
            test_helper::domain_name(), 1,);

        // Disable ANS write
        config::set_is_enabled(myself, false);

        // Should not be able to set address because ANS write is disabled
        domains::set_subdomain_address(user, test_helper::subdomain_name(),
            test_helper::domain_name(), signer::address_of(user2))
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 851969, location = aptos_names::domains)]
    fun is_enabled_clear_domain_address_test(
        myself: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users =
            test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain succeeds
        domains::register_domain(user, test_helper::domain_name(), 1);
        domains::set_domain_address(user, test_helper::domain_name(),
            signer::address_of(user));

        // Disable ANS write
        config::set_is_enabled(myself, false);

        // Should not be able to clear address because ANS write is disabled
        domains::clear_domain_address(user, test_helper::domain_name())
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 851969, location = aptos_names::domains)]
    fun is_enabled_clear_subdomain_address_test(
        myself: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users =
            test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain succeeds
        domains::register_domain(user, test_helper::domain_name(), 1);
        domains::register_subdomain(user, test_helper::subdomain_name(),
            test_helper::domain_name(), 1,);
        domains::set_subdomain_address(user, test_helper::subdomain_name(),
            test_helper::domain_name(), signer::address_of(user));
        // Disable ANS write
        config::set_is_enabled(myself, false);

        // Should not be able to clear address because ANS write is disabled
        domains::clear_subdomain_address(user, test_helper::subdomain_name(),
            test_helper::domain_name())
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 851969, location = aptos_names::domains)]
    fun is_enabled_set_primary_name_test(
        myself: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users =
            test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain succeeds
        domains::register_domain(user, test_helper::domain_name(), 1);
        domains::set_reverse_lookup_entry(user, string::utf8(b""),
            test_helper::domain_name());

        // Disable ANS write
        config::set_is_enabled(myself, false);

        // Should not be able to set primary name because ANS write is disabled
        domains::set_reverse_lookup_entry(user, string::utf8(b""),
            test_helper::domain_name());
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 851969, location = aptos_names::domains)]
    fun is_enabled_clear_primary_name_test(
        myself: &signer,
        user: signer,
        aptos: signer,
        rando: signer,
        foundation: signer
    ) {
        let users =
            test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Register the domain succeeds
        domains::register_domain(user, test_helper::domain_name(), 1);
        domains::register_subdomain(user, test_helper::subdomain_name(),
            test_helper::domain_name(), 1,);
        domains::set_reverse_lookup_entry(user, string::utf8(b""),
            test_helper::domain_name());

        // Disable ANS write
        config::set_is_enabled(myself, false);

        // Should not be able to clear primary name because ANS write is disabled
        domains::clear_reverse_lookup_entry(user)
    }
}
