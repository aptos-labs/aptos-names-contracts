#[test_only]
module aptos_names::is_enabled_tests {
    use aptos_framework::chain_id;
    use aptos_names::config;
    use aptos_names::domains;
    use aptos_names::test_helper;
    use std::vector;

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 851969, location = aptos_names::domains)]
    fun is_enabled_register_domain_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Disable ANS
        config::set_is_enabled(myself, false);

        // Register the domain fails
        domains::register_domain(user, test_helper::domain_name(), 1);
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 851969, location = aptos_names::domains)]
    fun is_enabled_register_domain_with_signature_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Disable ANS
        config::set_is_enabled(myself, false);

        // Register the domain fails
        chain_id::initialize_for_test(&aptos, 4);
        domains::register_domain_with_signature(
            user,
            test_helper::domain_name(),
            1,
            x"f004a92a27f962352456bb5b6728d4d37361d16b5932ed012f8f07bc94e3e73dbf38b643b6e16caa97ff313d48c8fe524325529b7c0e9abf7bd9d5183ff97a03"
        );
    }

    #[test(myself = @aptos_names, user = @0x077, aptos = @0x1, rando = @0x266f, foundation = @0xf01d)]
    #[expected_failure(abort_code = 851969, location = aptos_names::domains)]
    fun is_enabled_register_subdomain_test(myself: &signer, user: signer, aptos: signer, rando: signer, foundation: signer) {
        let users = test_helper::e2e_test_setup(myself, user, &aptos, rando, &foundation);
        let user = vector::borrow(&users, 0);

        // Disable ANS
        config::set_is_enabled(myself, false);

        // Register the subdomain fails
        domains::register_subdomain(
            user,
            test_helper::subdomain_name(),
            test_helper::domain_name(),
            1,
        );
    }
}
