use starknet::ContractAddress;

#[starknet::interface]
pub trait IDistributPrize<TContractState> {
    fn distribute_prize(ref self: TContractState, winner: ContractAddress);
    fn set_pool(ref self: TContractState, amount: u256);
    fn total_pool(self: @TContractState) -> u256;
}

const ETH_CONTRACT_ADDRESS: felt252 =
    0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;

#[starknet::contract]
mod DistributPrize {
    use super::{IDistributPrize, ETH_CONTRACT_ADDRESS};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, contract_address_const, get_contract_address};

    #[storage]
    struct Storage {
        total_pool: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        PrizeDistributed: PrizeDistributed,
        PoolUpdated: PoolUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct PrizeDistributed {
        #[key]
        winner: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct PoolUpdated {
        amount: u256,
        total_pool: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.total_pool.write(0);
    }

    #[abi(embed_v0)]
    impl DistributPrizeImpl of IDistributPrize<ContractState> {
        fn distribute_prize(ref self: ContractState, winner: ContractAddress) {
            let eth_contract_address = contract_address_const::<ETH_CONTRACT_ADDRESS>();
            let eth_dispatcher = IERC20Dispatcher { contract_address: eth_contract_address };
            let balance = eth_dispatcher.balance_of(get_contract_address());

            let current_pool = self.total_pool.read();
            assert(current_pool > 0, 'No funds to distribute');

            assert(current_pool < balance, 'Balance is more than pool');

            let eth_dispatcher = IERC20Dispatcher {
                contract_address: contract_address_const::<ETH_CONTRACT_ADDRESS>(),
            };
            eth_dispatcher.transfer(winner, current_pool);
            self.total_pool.write(0);

            self.emit(PrizeDistributed { winner, amount: current_pool });
        }

        fn set_pool(ref self: ContractState, amount: u256) {
            let current_pool = self.total_pool.read();
            self.total_pool.write(amount + current_pool);

            self.emit(PoolUpdated { amount, total_pool: self.total_pool.read() })
        }

        fn total_pool(self: @ContractState) -> u256 {
            self.total_pool.read()
        }
    }
}

