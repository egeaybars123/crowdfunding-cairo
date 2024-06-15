use starknet::ContractAddress;

#[starknet::interface]
trait ITransfer<TContractState> {
    fn transfer_tokens(ref self: TContractState, contract_address: ContractAddress, amount: u256);
}

trait IERC20DispatcherTrait<T> {
    fn transfer_from(self: T, sender: ContractAddress, recipient: ContractAddress, amount: u256);
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct IERC20Dispatcher {
    contract_address: ContractAddress,
}

impl IERC20DispatcherImpl of IERC20DispatcherTrait<IERC20Dispatcher> {
    fn transfer_from(
        self: IERC20Dispatcher, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) { // starknet::call_contract_syscall is called in here 
    }
}

#[starknet::contract]
mod transfer {
    use super::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl TransferImpl of super::ITransfer<ContractState> {
        fn transfer_tokens(
            ref self: ContractState, contract_address: ContractAddress, amount: u256
        ) {
            IERC20Dispatcher { contract_address: contract_address }
                .transfer_from(get_caller_address(), get_contract_address(), amount);
        }
    }
}
