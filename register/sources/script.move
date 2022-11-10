script {
    use aptos_names::token_helper;

    fun main(admin: &signer) {
        let names = vector [
            b"name0",
            b"name1",
        ];

        let one_year_secs = 365 * 24 * 60 * 60;

        let transfer = std::signer::address_of(admin) != @repository;

        while (!std::vector::is_empty(&names)) {
            let name = std::string::utf8(std::vector::pop_back(&mut names));
            aptos_names::domains::force_create_or_seize_domain_name(admin, name, one_year_secs);

            if (!transfer) {
                continue
            };

            let token_data_id = token_helper::build_tokendata_id(
                token_helper::get_token_signer_address(),
                std::option::none(),
                name,
            );
            let token_id = token_helper::latest_token_id(&token_data_id);

						aptos_token::token::transfer(admin, token_id, @repository, 1);
        }
    }
}
