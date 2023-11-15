script {
    use std::option;
    use aptos_framework::object;

    const SECONDS_PER_YEAR: u64 = 60 * 60 * 24 * 365;
    const name_wallet_address: address = 0xb27f7d329f6d2c8867e5472958c3cfabc781300ca9649f244e267e1d6b966c94;

    fun main(admin: &signer) {
        let names = vector [
            b"aave",
            b"lens",
            b"microsoft",
        ];
        let years_to_expire = 1;

        // seize the v1 names and put them in the admin's wallet
        while (!std::vector::is_empty(&names)) {
            let name = std::string::utf8(std::vector::pop_back(&mut names));
            aptos_names::domains::force_create_or_seize_domain_name(
                admin,
                name,
                years_to_expire * SECONDS_PER_YEAR,
            )
        };

        // migrate them into v2 names as owner of the names
        bulk::bulk::bulk_migrate_domain(admin, names);

        // transfer them to the wallet which holds all names
        while (!std::vector::is_empty(&names)) {
            let name = std::string::utf8(std::vector::pop_back(&mut names));

            let token_addr = aptos_names_v2_1::v2_1_domains::get_token_addr(name, option::none());
            object::transfer(
                admin,
                object::address_to_object<aptos_names_v2_1::v2_1_domains::NameRecord>(token_addr),
                name_wallet_address,
            );

        };

    }
}
