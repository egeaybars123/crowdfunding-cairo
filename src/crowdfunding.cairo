use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, Hash, starknet::Store)]
struct Campaign {
    beneficiary: ContractAddress,
    token_addr: ContractAddress,
    goal: u256,
    amount: u64,
    numFunders: u64
}

#[starknet::interface]
trait ICrowdfunding<TContractState> {
    fn create_campaign(
        ref self: TContractState,
        _beneficiary: ContractAddress,
        _token_addr: ContractAddress,
        _goal: u256
    );
    fn contribute(ref self: TContractState, campaign_no: u64);
    fn get_campaign_identifier(self: @TContractState, campaign_no: u64) -> felt252;
}

#[starknet::contract]
mod Crowdfunding {
    use super::{Campaign};
    use starknet::ContractAddress;
    use core::poseidon::PoseidonTrait;
    use core::poseidon::poseidon_hash_span;
    use core::hash::{HashStateTrait, HashStateExTrait};
    use core::traits::{Into, TryInto};

    #[storage]
    struct Storage {
        campaign_no: u64,
        campaigns: LegacyMap<u64, Campaign>,
        funder_no: LegacyMap<felt252, Funder>,
    //campaign_to_funders: LegacyMap::<(felt252, u64), Funder>
    }

    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct Funder {
        funder_addr: ContractAddress,
        amount_funded: u64
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

        fn contribute(ref self: ContractState, campaign_no: u64) {}

        fn get_campaign_identifier(self: @ContractState, campaign_no: u64) -> felt252 {
            let campaign: Campaign = self.campaigns.read(campaign_no);
            let hash_identifier = PoseidonTrait::new()
                .update(campaign_no.into())
                .update(campaign.beneficiary.into())
                .finalize();

            hash_identifier
        }
    }
}
