use starknet::{ContractAddress, contract_address_const, get_contract_address};
use contracts::DistributePrize::{IDistributPrizeDispatcher, IDistributPrizeDispatcherTrait};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

use snforge_std::{
    declare, CheatSpan, cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait, spy_events, EventSpyAssertionsTrait, get_class_hash,
};

fn USER() -> ContractAddress {
    contract_address_const::<0x01d6abf4f5963082fc6c44d858ac2e89434406ed682fb63155d146c5d69c22d6>()
}

fn WINNER() -> ContractAddress {
    contract_address_const::<0x01f0d3e6e3b1116fbf69dd670e5c079c8c3b6e5a789f00270ba049b6c22a0d3b>()
}

const ETH_CONTRACT_ADDRESS: felt252 =
    0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;

fn __setup__() -> ContractAddress {
    let class_hash = declare("DistributPrize").unwrap().contract_class();

    let mut calldata = array![];

    let (contract_address, _) = class_hash.deploy(@calldata).unwrap();

    contract_address
}

#[test]
fn test_set_pool() {
    let contract_address = __setup__();
    let dispatcher = IDistributPrizeDispatcher { contract_address };

    dispatcher.set_pool(50);

    let pool_value = dispatcher.total_pool();

    assert!(pool_value == 50, "Invalid pool value");
}

#[test]
#[fork("SEPOLIA_LATEST")]
fn test_distribute_prize() {
    let contract_address = __setup__();
    let user = USER();
    let eth_contract_address = contract_address_const::<ETH_CONTRACT_ADDRESS>();
    let dispatcher = IDistributPrizeDispatcher { contract_address };

    dispatcher.set_pool(100);

    let pool = dispatcher.total_pool();

    let erc20_dispatcher = IERC20Dispatcher { contract_address: eth_contract_address };
    cheat_caller_address(eth_contract_address, user, CheatSpan::TargetCalls(2));

    let balance_of_winner_before_distribution = erc20_dispatcher.balance_of(WINNER());

    erc20_dispatcher.transfer(contract_address, 1000);
    erc20_dispatcher.approve(contract_address, pool);
    dispatcher.distribute_prize(WINNER());

    let balance_of_winner_after_distribution = erc20_dispatcher.balance_of(WINNER());

    assert!(
        balance_of_winner_after_distribution == balance_of_winner_before_distribution + pool,
        "Invalid winner balance",
    );

    let pool_value = dispatcher.total_pool();

    assert!(pool_value == 0, "Invalid pool value");
}
