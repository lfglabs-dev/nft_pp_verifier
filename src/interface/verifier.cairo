use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
trait INftPpVerifier<TContractState> {
    // user
    fn get_pp(self: @TContractState, id: u128) -> (felt252, ContractAddress, u256);
    fn get_starknet_pp(self: @TContractState, id: u128) -> (ContractAddress, u256);
    fn get_owner_of_starknet_pp(
        self: @TContractState, nft_contract: ContractAddress, nft_id: u256
    ) -> u128;
    fn set_native_pp(
        ref self: TContractState, nft_contract: ContractAddress, nft_id: u256, id: u128
    );

    // admin
    fn whitelist_native_nft_contract(ref self: TContractState, nft_contract: ContractAddress);
    fn unwhitelist_native_nft_contract(ref self: TContractState, nft_contract: ContractAddress);
    fn set_admin(ref self: TContractState, new_admin: ContractAddress);
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}
