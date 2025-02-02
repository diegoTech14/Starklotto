use starknet::ContractAddress;
use openzeppelin::token::erc20::ERC20Component;

#[starknet::interface]
trait IPrizePool<TContractState> {
    fn set_platform_fee(ref self: TContractState, percentage: u256);
    fn split_prize(ref self: TContractState, total_amount: u256) -> (u256, u256);
    fn withdraw_reserves(ref self: TContractState, amount: u256, recipient: ContractAddress);
    fn get_platform_fee(ref self: TContractState) -> u256;
    fn get_platform_reserves(ref self: TContractState) -> u256;
}
#[starknet::contract]
mod PrizePool {
    use super::*;
    use openzeppelin::access::accesscontrol::{
        AccessControlComponent, AccessControlInternalTrait, DEFAULT_ADMIN_ROLE
    };
    use starknet::{get_caller_address, ClassHash};
    use zeroable::Zeroable;
    
    const PLATFORM_FEE_SETTER_ROLE: felt252 = selector!("PLATFORM_FEE_SETTER_ROLE");
    
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        platform_fee_percentage: u256,
        platform_reserves: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        ERC20Event: ERC20Component::Event,
        FeeUpdated: FeeUpdated,
        ReservesWithdrawn: ReservesWithdrawn,
    }

    #[derive(Drop, starknet::Event)]
    struct FeeUpdated {
        old_fee: u256,
        new_fee: u256
    }

    #[derive(Drop, starknet::Event)]
    struct ReservesWithdrawn {
        amount: u256,
        recipient: ContractAddress
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        fee_setter: ContractAddress
    ) {
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, admin);
        self.accesscontrol._grant_role(PLATFORM_FEE_SETTER_ROLE, fee_setter);
        
        // Initial platform fee: 10% 
        self.platform_fee_percentage.write(10_u256);
    }

    #[abi(embed_v0)]
    impl IPrizePoolImpl of IPrizePool<ContractState> {
        fn set_platform_fee(ref self: ContractState, percentage: u256) {
            self.accesscontrol.assert_only_role(PLATFORM_FEE_SETTER_ROLE);
            
            assert(!percentage.is_zero(), "Fee cannot be zero");
            assert(percentage <= 100_u256, "Fee cannot exceed 100%");
            
            let old_fee = self.platform_fee_percentage.read();
            self.platform_fee_percentage.write(percentage);
            
            self.emit(FeeUpdated { old_fee, new_fee: percentage });
        }

        fn split_prize(ref self: ContractState, total_amount: u256) -> (u256, u256) {
            let fee_percent = self.platform_fee_percentage.read();
            
            let (platform_share, remainder) = u256_wide_mul_div(total_amount, fee_percent, 100_u256);
            
            self.platform_reserves.write(self.platform_reserves.read() + platform_share);
            
            // Winner gets remainder
            let winner_share = total_amount - platform_share;
            
            (winner_share, platform_share)
        }

        fn withdraw_reserves(ref self: ContractState, amount: u256, recipient: ContractAddress) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            
            let current_reserves = self.platform_reserves.read();
            assert(current_reserves >= amount, "Insufficient reserves");
            
            self.platform_reserves.write(current_reserves - amount);
            
            self.erc20.transfer(recipient, amount);
            
            self.emit(ReservesWithdrawn { amount, recipient });
        }

        fn get_platform_fee(ref self: ContractState) -> u256 {
            self.platform_fee_percentage.read()
        }

        fn get_platform_reserves(ref self: ContractState) -> u256 {
            self.platform_reserves.read()
        }
    }


    fn u256_wide_mul_div(value: u256, numerator: u256, denominator: u256) -> (u256, u256) {
        let (high, low) = value.widening_mul(numerator);
        let full_value = u512_from_u256s(high, low);
        let result = full_value / denominator.into();
        let remainder = full_value % denominator.into();
        (result.into(), remainder.into())
    }

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelImpl = ERC20Component::ERC20CamelImpl<ContractState>;
}
