script {
    use aptos_names::token_helper;

    fun main(offerer: &signer) {
        let names = vector [
            b"name0",
            b"name1",
        ];

        let recipients = vector [
            @0x1,
            @0x2,
        ];

        assert!(std::vector::length(&names) == std::vector::length(&recipients), 1);

        while (!std::vector::is_empty(&names)) {
            let name = std::vector::pop_back(&mut names);
            let recipient = std::vector::pop_back(&mut recipients);

            let token_data_id = token_helper::build_tokendata_id(
                token_helper::get_token_signer_address(),
                std::option::none(),
                std::string::utf8(name),
            );
            let token_id = token_helper::latest_token_id(&token_data_id);
            aptos_token::token_transfers::offer(offerer, recipient, token_id, 1);
        }
    }
}
