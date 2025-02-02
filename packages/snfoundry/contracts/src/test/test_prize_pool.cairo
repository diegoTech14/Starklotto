#[cfg(test)]
mod tests {
    use starknet::ContractAddress;
    use snforge_std::{test_case, declare, ContractClass, PreparedContract, ContractInvoker};
    use starknet::get_caller_address;

    #[test_case]
    fn test_constructor_and_initial_fee() {
        let contract_class: ContractClass = declare("PrizePool");
        let contract: PreparedContract = contract_class.deploy();

        let admin: ContractAddress = ContractAddress::from_felt(0x123456);
        let fee_setter: ContractAddress = ContractAddress::from_felt(0x789abc);

        let prize_pool: ContractInvoker<PrizePool> = contract.into();

        // Initialize contract with constructor
        prize_pool.constructor(admin, fee_setter);

        // Check that the platform fee is initially 10%
        let fee = prize_pool.get_platform_fee();
        assert_eq!(fee, 10_u256);
    }

    #[test_case]
    fn test_set_platform_fee() {
        let contract_class: ContractClass = declare("PrizePool");
        let contract: PreparedContract = contract_class.deploy();

        let admin: ContractAddress = ContractAddress::from_felt(0x123456);
        let fee_setter: ContractAddress = ContractAddress::from_felt(0x789abc);

        let prize_pool: ContractInvoker<PrizePool> = contract.into();

        prize_pool.constructor(admin, fee_setter);
        
        // Try setting a new fee
        prize_pool.set_platform_fee(15_u256);

        // Verify the fee has been updated
        let new_fee = prize_pool.get_platform_fee();
        assert_eq!(new_fee, 15_u256);
    }

    #[test_case]
    fn test_split_prize() {
        let contract_class: ContractClass = declare("PrizePool");
        let contract: PreparedContract = contract_class.deploy();

        let admin: ContractAddress = ContractAddress::from_felt(0x123456);
        let fee_setter: ContractAddress = ContractAddress::from_felt(0x789abc);

        let prize_pool: ContractInvoker<PrizePool> = contract.into();
        prize_pool.constructor(admin, fee_setter);

        // Set the fee to 20%
        prize_pool.set_platform_fee(20_u256);

        // Split a prize of 1000 tokens
        let (winner_share, platform_share) = prize_pool.split_prize(1000_u256);

        // Expected calculations
        assert_eq!(winner_share, 800_u256); // 80% goes to winner
        assert_eq!(platform_share, 200_u256); // 20% goes to platform reserves
    }

    #[test_case]
    fn test_withdraw_reserves() {
        let contract_class: ContractClass = declare("PrizePool");
        let contract: PreparedContract = contract_class.deploy();

        let admin: ContractAddress = ContractAddress::from_felt(0x123456);
        let fee_setter: ContractAddress = ContractAddress::from_felt(0x789abc);

        let prize_pool: ContractInvoker<PrizePool> = contract.into();
        prize_pool.constructor(admin, fee_setter);

        // Split a prize so that reserves increase
        prize_pool.set_platform_fee(25_u256);
        prize_pool.split_prize(1000_u256); // Should add 250 to reserves

        // Check reserves before withdrawal
        let initial_reserves = prize_pool.get_platform_reserves();
        assert_eq!(initial_reserves, 250_u256);

        // Withdraw 100 tokens from reserves
        let recipient: ContractAddress = ContractAddress::from_felt(0xABCDEF);
        prize_pool.withdraw_reserves(100_u256, recipient);

        // Verify reserves after withdrawal
        let updated_reserves = prize_pool.get_platform_reserves();
        assert_eq!(updated_reserves, 150_u256); // 250 - 100 = 150
    }

    #[test_case]
    fn test_getters() {
        let contract_class: ContractClass = declare("PrizePool");
        let contract: PreparedContract = contract_class.deploy();

        let admin: ContractAddress = ContractAddress::from_felt(0x123456);
        let fee_setter: ContractAddress = ContractAddress::from_felt(0x789abc);

        let prize_pool: ContractInvoker<PrizePool> = contract.into();
        prize_pool.constructor(admin, fee_setter);

        // Verify initial values
        let initial_fee = prize_pool.get_platform_fee();
        let initial_reserves = prize_pool.get_platform_reserves();

        assert_eq!(initial_fee, 10_u256);
        assert_eq!(initial_reserves, 0_u256);
    }
}
