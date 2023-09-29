use array::ArrayTrait;
use debug::PrintTrait;
use zeroable::Zeroable;
use traits::Into;
use starknet::{ContractAddress, contract_address_const};
use starknet::testing::set_contract_address;
use super::utils;
use identity::identity::main::Identity;
use identity::interface::identity::{IIdentityDispatcher, IIdentityDispatcherTrait};
use nft_pp_verifier::nft_pp_verifier::NftPpVerifier;
use nft_pp_verifier::interface::verifier::{INftPpVerifierDispatcher, INftPpVerifierDispatcherTrait};
use openzeppelin::token::erc721::interface::{
    IERC721CamelOnlyDispatcher, IERC721CamelOnlyDispatcherTrait
};
use openzeppelin::token::erc721::erc721::ERC721;

fn setup() -> (IIdentityDispatcher, INftPpVerifierDispatcher, IERC721CamelOnlyDispatcher) {
    let identity = utils::deploy(Identity::TEST_CLASS_HASH, ArrayTrait::<felt252>::new());
    let pp_verifier = utils::deploy(NftPpVerifier::TEST_CLASS_HASH, array![0x123, identity.into()]);
    let erc721 = utils::deploy(ERC721::TEST_CLASS_HASH, array!['NFT', 'NFT', 0x123, 1, 0]);
    (
        IIdentityDispatcher { contract_address: identity },
        INftPpVerifierDispatcher { contract_address: pp_verifier },
        IERC721CamelOnlyDispatcher { contract_address: erc721 },
    )
}

#[test]
#[available_gas(20000000000)]
fn test_set_pfp() {
    let (identity, verifier, erc721) = setup();
    let caller = contract_address_const::<0x123>();
    set_contract_address(caller);
    identity.mint(1);

    // Whitelist NFT contract 
    verifier.whitelist_native_nft_contract(erc721.contract_address);

    // It should set native pfp for user 0x123
    verifier.set_native_pp(erc721.contract_address, 1, 1);
    let pfp_data = verifier.get_pp(1);
    assert(pfp_data == (0, erc721.contract_address, 1.into()), 'wrong data');
}

#[test]
#[available_gas(20000000000)]
#[should_panic(expected: ('Contract not whitelisted', 'ENTRYPOINT_FAILED'))]
fn test_set_pfp_not_whitelisted() {
    let (identity, verifier, erc721) = setup();
    let caller = contract_address_const::<0x123>();
    set_contract_address(caller);
    identity.mint(1);

    // It should revert as NFT contract is not whitelisted
    verifier.set_native_pp(erc721.contract_address, 1, 1);
}

#[test]
#[available_gas(20000000000)]
#[should_panic(expected: ('Caller not owner of NFT', 'ENTRYPOINT_FAILED'))]
fn test_set_pfp_not_owner() {
    let (identity, verifier, erc721) = setup();

    // Whitelist NFT contract 
    set_contract_address(contract_address_const::<0x123>());
    verifier.whitelist_native_nft_contract(erc721.contract_address);

    set_contract_address(contract_address_const::<0x456>());
    identity.mint(1);

    // It should revert as 0x456 is not owner of NFT
    verifier.set_native_pp(erc721.contract_address, 1, 1);
}

#[test]
#[available_gas(20000000000)]
fn test_set_pfp_transfered() {
    let (identity, verifier, erc721) = setup();
    let user_1 = contract_address_const::<0x123>();
    let user_2 = contract_address_const::<0x456>();
    let id_1: u128 = 1;
    let id_2: u128 = 2;

    // Whitelist NFT contract 
    set_contract_address(user_1);
    verifier.whitelist_native_nft_contract(erc721.contract_address);

    // mint identity & set NFT as pfp
    identity.mint(id_1);
    verifier.set_native_pp(erc721.contract_address, 1, id_1);
    assert(verifier.get_pp(id_1) == (0, erc721.contract_address, 1.into()), 'wrong data');

    // It should transfer NFT to 0x456, set it as pfp and reset verifier data for 0x123
    erc721.transferFrom(user_1, user_2, 1);
    set_contract_address(user_2);
    identity.mint(id_2);
    verifier.set_native_pp(erc721.contract_address, 1, id_2);
    assert(verifier.get_pp(id_2) == (0, erc721.contract_address, 1.into()), 'wrong data');
    assert(verifier.get_pp(id_1) == (0, contract_address_const::<0>(), 0.into()), 'wrong data');
}
