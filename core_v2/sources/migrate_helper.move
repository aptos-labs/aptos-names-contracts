module aptos_names_v2::migrate_helper {
    friend aptos_names_v2::domains;

    use aptos_token::token;
    use std::option::{Self, Option};
    use std::signer::address_of;
    use std::string::String;

    public(friend) fun burn_token_v1(
        user: &signer,
        burn_signer: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
    ): (u64, Option<address>, bool) {
        let maybe_primary_name = aptos_names::domains::get_reverse_lookup(address_of(user));
        let is_primary_name = if(option::is_some(&maybe_primary_name)) {
            let (primary_subdomain_name, primary_domain_name) = aptos_names::domains::get_name_record_key_v1_props(
                &option::extract(&mut maybe_primary_name)
            );
            subdomain_name == primary_subdomain_name && domain_name == primary_domain_name
        } else {
            false
        };

        // Clear the domain
        aptos_names::domains::clear_domain_address(user, domain_name);

        // Get the v1 token info
        let (
            _property_version,
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

        (expiration_time_sec, target_addr, is_primary_name)
    }
}
