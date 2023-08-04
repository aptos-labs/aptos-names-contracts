module aptos_names_v2::migrate_helper {
    friend aptos_names_v2::domains;

    use std::option::Option;
    use std::string::String;
    use aptos_token::token;

    public(friend) fun burn_token_v1(
        user: &signer,
        burn_signer: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
    ): (u64, Option<address>) {
        // Clear the domain
        aptos_names::domains::clear_domain_address(user, domain_name);

        // Get the v1 token info
        let (
            expiration_time_sec,
            target_addr
        ) = aptos_names::domains::get_name_record_v1_props_for_name(
            subdomain_name,
            domain_name,
        );
        let tokendata_id = aptos_names::token_helper::build_tokendata_id(
            aptos_names::token_helper::get_token_signer_address(),
            subdomain_name,
            domain_name,
        );
        let token_id = aptos_names::token_helper::latest_token_id(&tokendata_id);

        // Burn by sending to `burn_signer`
        token::direct_transfer(
            user,
            burn_signer,
            token_id,
            1,
        );

        (expiration_time_sec, target_addr)
    }
}
