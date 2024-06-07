module aptos_names::verify {
    use std::string;
    use aptos_framework::account;
    use aptos_framework::chain_id;
    use aptos_std::ed25519;
    use aptos_names::config;

    friend aptos_names::domains;

    struct RegisterDomainProofChallenge has drop {
        sequence_number: u64,
        register_address: address,
        domain_name: string::String,
        chain_id: u8,
    }

    const EINVALID_PROOF_OF_KNOWLEDGE: u64 = 1;

    public(friend) fun assert_register_domain_signature_verifies(signature: vector<u8>, account_address: address, domain_name: string::String) {
        let chain_id = chain_id::get();
        let sequence_number = account::get_sequence_number(account_address);
        let register_domain_proof_challenge = RegisterDomainProofChallenge {
            sequence_number,
            register_address: account_address,
            domain_name,
            chain_id
        };

        let captcha_public_key = config::captcha_public_key();
        let sig = ed25519::new_signature_from_bytes(signature);
        assert!(ed25519::signature_verify_strict_t(&sig, &captcha_public_key, register_domain_proof_challenge), std::error::invalid_argument(EINVALID_PROOF_OF_KNOWLEDGE));
    }
}
