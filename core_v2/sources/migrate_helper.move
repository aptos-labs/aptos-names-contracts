module aptos_names_v2::migrate_helper {
    friend aptos_names_v2::domains;

    use aptos_names::token_helper::{build_tokendata_id, get_token_signer_address};
    use std::option::Option;
    use std::string::String;
    use aptos_token::token;
    use aptos_names::domains;

     public(friend) fun burn_token_v1(
        user: &signer,
        domain_name: String,
        subdomain_name: Option<String>,
    ): (u64, Option<address>) {
        let (
            property_version,
            expiration_time_sec,
            target_addr
        ) = domains::get_name_record_v1_props_for_name(
            subdomain_name,
            domain_name,
        );
        let tokendata_id = build_tokendata_id(
            get_token_signer_address(),
            subdomain_name,
            domain_name,
        );
        let (creator, collection_name, name) = token::get_token_data_id_fields(&tokendata_id);

        token::burn(
            user,
            creator,
            collection_name,
            name,
            property_version,
            1,
        );

        (expiration_time_sec, target_addr)
    }
}
