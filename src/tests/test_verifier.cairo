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
use openzeppelin::token::erc721::erc721;
use openzeppelin::token::erc721::erc721::ERC721Component::{
    ERC721CamelOnlyImpl, component_state_for_testing
};

#[starknet::interface]
trait IDummyNftContract<TContractState> {
    fn mint(ref self: TContractState, token_id: u256);
    fn transferFrom(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, tokenId: u256
    );
}

#[starknet::contract]
mod DummyNftContract {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use openzeppelin::token::erc721::erc721::ERC721Component;
    use openzeppelin::token::erc721::erc721::ERC721Component::{
        InternalTrait as ERC721InternalTrait, ERC721CamelOnlyImpl as ERC721CamelOnlyTrait,
    };
    use openzeppelin::introspection::src5::SRC5Component;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl ERC721CamelOnlyImpl = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ERC721Event: ERC721Component::Event,
        SRC5Event: SRC5Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, name: felt252, symbol: felt252) {
        self.erc721.initializer(name, symbol);
    }

    #[external(v0)]
    impl DummyNftContractImpl of super::IDummyNftContract<ContractState> {
        fn mint(ref self: ContractState, token_id: u256) {
            self.erc721._mint(get_caller_address(), token_id);
        }
        fn transferFrom(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, tokenId: u256
        ) {
            self.erc721.transferFrom(from, to, tokenId);
        }
    }
}

// type TestingState = erc721::ERC721Component::ComponentState<DummyNftContract::ContractState>;

// impl TestingStateDefault of Default<TestingState> {
//     fn default() -> TestingState {
//         component_state_for_testing()
//     }
// }

fn setup() -> (IIdentityDispatcher, INftPpVerifierDispatcher, IDummyNftContractDispatcher) {
    let identity = utils::deploy(Identity::TEST_CLASS_HASH, array![0x123, 0]);
    let pp_verifier = utils::deploy(NftPpVerifier::TEST_CLASS_HASH, array![0x123, identity.into()]);
    let erc721 = utils::deploy(DummyNftContract::TEST_CLASS_HASH, array!['NFT', 'NFT']);
    (
        IIdentityDispatcher { contract_address: identity },
        INftPpVerifierDispatcher { contract_address: pp_verifier },
        IDummyNftContractDispatcher { contract_address: erc721 },
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

    // mint NFT
    erc721.mint(1);

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
    // mint NFT
    erc721.mint(1);

    // It should revert as 0x456 is not owner of NFT
    set_contract_address(contract_address_const::<0x456>());
    identity.mint(1);
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
    // mint NFT
    erc721.mint(1);
    verifier.set_native_pp(erc721.contract_address, 1, id_1);
    assert(verifier.get_pp(id_1) == (0, erc721.contract_address, 1.into()), 'wrong data');

    // It should transfer NFT to 0x456, set it as pfp and reset verifier data for 0x123
    erc721.transferFrom(user_1, user_2, 1);
    set_contract_address(user_2);
    identity.mint(id_2);
    erc721.mint(2);
    verifier.set_native_pp(erc721.contract_address, 1, id_2);
    assert(verifier.get_pp(id_2) == (0, erc721.contract_address, 1.into()), 'wrong data');
    assert(verifier.get_pp(id_1) == (0, contract_address_const::<0>(), 0.into()), 'wrong data');
}

#[test]
#[available_gas(20000000000)]
fn test_enumerability_whitelist() {
    let (identity, verifier, erc721) = setup();
    let user_1 = contract_address_const::<0x123>();
    let user_2 = contract_address_const::<0x456>();
    let id_1: u128 = 1;
    let id_2: u128 = 2;

    let contract_1 = erc721.contract_address;
    let contract_2 = contract_address_const::<0x1111>();
    let contract_3 = contract_address_const::<0x2222>();

    // It should whitelist 2 NFT contract_addresses
    set_contract_address(user_1);
    verifier.whitelist_native_nft_contract(contract_1);
    verifier.whitelist_native_nft_contract(contract_2);
    verifier.whitelist_native_nft_contract(contract_3);

    let whitelisted_contracts = verifier.get_whitelisted_contracts();
    assert(whitelisted_contracts == array![contract_3, contract_2, contract_1], 'wrong data');

    // It should blacklist the first contract_address and return the right list of whitelisted contracts
    verifier.unwhitelist_native_nft_contract(contract_1);
    let whitelisted_contracts = verifier.get_whitelisted_contracts();
    assert(whitelisted_contracts == array![contract_3, contract_2], 'wrong data');

    // It should blacklist the last contract_address and return the right list of whitelisted contracts
    verifier.unwhitelist_native_nft_contract(contract_3);
    let whitelisted_contracts = verifier.get_whitelisted_contracts();
    assert(whitelisted_contracts == array![contract_2], 'wrong data');
}
