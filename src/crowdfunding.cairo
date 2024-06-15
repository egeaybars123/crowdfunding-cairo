use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, Hash, starknet::Store)]
struct Campaign {
    beneficiary: ContractAddress,
    token_addr: ContractAddress,
    goal: u256,
    amount: u256,
    numFunders: u64,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct Funder {
    funder_addr: ContractAddress,
    amount_funded: u256
}

#[starknet::interface]
trait ICrowdfunding<TContractState> {
    fn create_campaign(
        ref self: TContractState,
        _beneficiary: ContractAddress,
        _token_addr: ContractAddress,
        _goal: u256
    );
    fn contribute(ref self: TContractState, campaign_no: u64, amount: u256);
    fn withdraw_funds(ref self: TContractState, campaign_no: u64);
    fn get_funder_identifier(
        self: @TContractState, campaign_no: u64, funder_addr: ContractAddress
    ) -> felt252;
    fn get_funder_contribution(self: @TContractState, identifier_hash: felt252) -> u256;
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
mod Crowdfunding {
    use crowdfunding::crowdfunding::ICrowdfunding;
    use super::{Campaign, Funder, IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use core::poseidon::{PoseidonTrait, poseidon_hash_span};
    use core::hash::{HashStateTrait, HashStateExTrait};
    use core::traits::{Into};

    #[storage]
    struct Storage {
        campaign_no: u64,
        campaigns: LegacyMap<u64, Campaign>,
        funder_no: LegacyMap<felt252, Funder>,
    }

    #[abi(embed_v0)]
    impl CrowdfundingImpl of super::ICrowdfunding<ContractState> {
        fn create_campaign(
            ref self: ContractState,
            _beneficiary: ContractAddress,
            _token_addr: ContractAddress,
            _goal: u256
        ) {
            let new_campaign_no: u64 = self.campaign_no.read() + 1;
            self.campaign_no.write(new_campaign_no);
            let new_campaign: Campaign = Campaign {
                beneficiary: _beneficiary,
                token_addr: _token_addr,
                goal: _goal,
                amount: 0,
                numFunders: 0
            };

            self.campaigns.write(new_campaign_no, new_campaign);
        }

        fn contribute(ref self: ContractState, campaign_no: u64, amount: u256) {
            let mut campaign = self.campaigns.read(campaign_no);
            campaign.amount += amount;
            campaign.numFunders += 1;

            let funder_addr = get_caller_address();
            let funder_identifier: felt252 = self.get_funder_identifier(campaign_no, funder_addr);
            let new_funder_amount = amount + self.get_funder_contribution(funder_identifier);
            let funder = Funder { funder_addr: funder_addr, amount_funded: new_funder_amount };

            self.funder_no.write(funder_identifier, funder);
            self.campaigns.write(campaign_no, campaign);

            IERC20Dispatcher { contract_address: campaign.token_addr }
                .transfer_from(funder_addr, get_contract_address(), amount);
        }

        fn withdraw_funds(ref self: ContractState, campaign_no: u64) {
            let campaign = self.campaigns.read(campaign_no);
            let caller = get_caller_address();
            assert(caller == campaign.beneficiary, 'Not the beneficiary');
            assert(campaign.amount >= campaign.goal, 'Goal not reached');
        }

        fn get_funder_identifier(
            self: @ContractState, campaign_no: u64, funder_addr: ContractAddress
        ) -> felt252 {
            let campaign: Campaign = self.campaigns.read(campaign_no);
            let hash_identifier = PoseidonTrait::new()
                .update(campaign_no.into())
                .update(campaign.beneficiary.into())
                .update(funder_addr.into())
                .finalize();

            hash_identifier
        }

        fn get_funder_contribution(self: @ContractState, identifier_hash: felt252) -> u256 {
            let funder = self.funder_no.read(identifier_hash);

            funder.amount_funded
        }
    }
}
