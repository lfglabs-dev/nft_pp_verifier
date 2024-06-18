#[starknet::contract]
mod NftPpVerifier {
    use core::array::SpanTrait;
    use core::option::OptionTrait;
    use starknet::{
        ContractAddress, get_caller_address, get_contract_address, ClassHash,
        storage_access::StorageAddress, SyscallResultTrait
    };
    use traits::{TryInto, Into};

    use openzeppelin::token::erc721::interface::{
        IERC721CamelOnlyDispatcher, IERC721CamelOnlyDispatcherTrait
    };
    use nft_pp_verifier::interface::verifier::{
        INftPpVerifier, INftPpVerifierDispatcher, INftPpVerifierDispatcherTrait
    };
    use identity::interface::identity::{IIdentityDispatcher, IIdentityDispatcherTrait};

    #[storage]
    struct Storage {
        owner_of_starknet_pp: LegacyMap::<(ContractAddress, u256), u128>,
        whitelisted_contracts: LegacyMap::<ContractAddress, bool>,
        whitelist_index: felt252,
        whitelist_by_id: LegacyMap::<felt252, ContractAddress>,
        admin: ContractAddress,
        identity_contract: ContractAddress,
    }

    //
    // Constructor
    //

    #[constructor]
    fn constructor(
        ref self: ContractState, admin_addr: ContractAddress, identity_addr: ContractAddress
    ) {
        self.admin.write(admin_addr);
        self.identity_contract.write(identity_addr);
    }

    #[external(v0)]
    impl NftPpVerifierImpl of INftPpVerifier<ContractState> {
        fn get_pp(self: @ContractState, id: u128) -> (felt252, starknet::ContractAddress, u256) {
            let nft_contract = self.get_nft_contract(id);
            let nft_id = self.get_nft_id(id);
            // todo: handle network, for now returns 0 (native Starknet)
            (0, nft_contract, nft_id)
        }

        fn get_starknet_pp(self: @ContractState, id: u128) -> (starknet::ContractAddress, u256) {
            let nft_contract = self.get_nft_contract(id);
            let nft_id = self.get_nft_id(id);
            (nft_contract, nft_id)
        }

        fn get_owner_of_starknet_pp(
            self: @ContractState, nft_contract: starknet::ContractAddress, nft_id: u256
        ) -> u128 {
            self.owner_of_starknet_pp.read((nft_contract, nft_id))
        }

        fn set_native_pp(
            ref self: ContractState, nft_contract: starknet::ContractAddress, nft_id: u256, id: u128
        ) {
            // assert NFT contract is whitelisted 
            assert(self.whitelisted_contracts.read(nft_contract), 'Contract not whitelisted');

            // assert caller is owner of NFT
            let caller = get_caller_address();
            let owner = IERC721CamelOnlyDispatcher { contract_address: nft_contract }
                .ownerOf(nft_id);
            assert(caller == owner, 'Caller not owner of NFT');

            let identity = self.identity_contract.read();

            let id_owner = IIdentityDispatcher { contract_address: identity }.owner_from_id(id);
            assert(caller == id_owner, 'Caller not owner of ID');

            let prev_owner_id = self.owner_of_starknet_pp.read((nft_contract, nft_id));
            if prev_owner_id != 0 {
                // remove prev owner
                IIdentityDispatcher { contract_address: identity }
                    .set_verifier_data(prev_owner_id, 'nft_pp_contract', 0, 0);
                IIdentityDispatcher { contract_address: identity }
                    .set_extended_verifier_data(prev_owner_id, 'nft_pp_id', array![0, 0].span(), 0);
            }

            IIdentityDispatcher { contract_address: identity }
                .set_verifier_data(id, 'nft_pp_contract', nft_contract.into(), 0);
            IIdentityDispatcher { contract_address: identity }
                .set_extended_verifier_data(
                    id, 'nft_pp_id', array![nft_id.low.into(), nft_id.high.into()].span(), 0
                );

            self.owner_of_starknet_pp.write((nft_contract, nft_id), id);
        }

        fn get_whitelisted_contracts(self: @ContractState) -> Array<ContractAddress> {
            let mut whitelisted_contracts = array![];
            let mut last_index = self.whitelist_index.read();
            loop {
                if last_index == 0 {
                    break;
                }
                let contract = self.whitelist_by_id.read(last_index);
                if self.whitelisted_contracts.read(contract) {
                    whitelisted_contracts.append(contract);
                }
                last_index -= 1;
            };
            whitelisted_contracts
        }

        // Admin
        fn whitelist_native_nft_contract(
            ref self: ContractState, nft_contract: starknet::ContractAddress
        ) {
            assert(get_caller_address() == self.admin.read(), 'Caller not admin');
            self.whitelisted_contracts.write(nft_contract, true);
            let last_index = self.whitelist_index.read();
            self.whitelist_by_id.write(last_index + 1, nft_contract);
            self.whitelist_index.write(last_index + 1);
        }

        fn unwhitelist_native_nft_contract(
            ref self: ContractState, nft_contract: starknet::ContractAddress
        ) {
            assert(get_caller_address() == self.admin.read(), 'Caller not admin');
            self.whitelisted_contracts.write(nft_contract, false);
        }

        fn storage_write(
            ref self: ContractState,
            address_domain: u32,
            address: starknet::StorageAddress,
            value: felt252
        ) {
            assert(get_caller_address() == self.admin.read(), 'Caller not admin');
            starknet::storage_write_syscall(address_domain, address, value).unwrap_syscall()
        }

        fn set_admin(ref self: ContractState, new_admin: starknet::ContractAddress) {
            assert(get_caller_address() == self.admin.read(), 'Caller not admin');
            self.admin.write(new_admin);
        }

        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            assert(get_caller_address() == self.admin.read(), 'you are not admin');
            // todo: use components
            assert(!new_class_hash.is_zero(), 'Class hash cannot be zero');
            starknet::replace_class_syscall(new_class_hash).unwrap();
        }
    }
    //
    // Internals
    //

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn get_nft_contract(self: @ContractState, id: u128) -> ContractAddress {
            let nft_contract = IIdentityDispatcher {
                contract_address: self.identity_contract.read()
            }
                .get_verifier_data(id, 'nft_pp_contract', get_contract_address(), 0);

            nft_contract.try_into().expect('error converting contract addr')
        }

        fn get_nft_id(self: @ContractState, id: u128) -> u256 {
            let mut nft_id_arr = IIdentityDispatcher {
                contract_address: self.identity_contract.read()
            }
                .get_extended_verifier_data(id, 'nft_pp_id', 2, get_contract_address(), 0);

            u256 {
                low: (*nft_id_arr.pop_front().expect('error getting nft id'))
                    .try_into()
                    .expect('error converting nft id low'),
                high: (*nft_id_arr.pop_front().expect('error getting nft id'))
                    .try_into()
                    .expect('error converting nft id high'),
            }
        }
    }
}
