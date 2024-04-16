contract;

mod abis;

use ::abis::{AirdropContract};

use std::{
    asset::transfer,
    auth::msg_sender,
    block::height,
    call_frames::msg_asset_id,
    context::{
        msg_amount,
        this_balance,
    },
    hash::{
        Hash,
        sha256,
    },
};

/// The state of a claim.
pub enum ClaimState {
    /// The claim is unclaimed.
    Unclaimed: (),
    /// The claim has been claimed for the given amount.
    Claimed: u64,
}

impl core::ops::Eq for ClaimState {
    fn eq(self, other: Self) -> bool {
        match (self, other) {
            (ClaimState::Claimed(balance1), ClaimState::Claimed(balance2)) => {
                balance1 == balance2
            },
            (ClaimState::Unclaimed, ClaimState::Unclaimed) => true,
            _ => false,
        }
    }
}

// Errors related to permissions.
pub enum AccessError {
    /// The caller is not the admin of the contract.
    CallerNotAdmin: (),
    /// There are not enough coins in the contract to perform the operation.
    NotEnoughCoins: (),
    /// The user has already claimed their coins.
    UserAlreadyClaimed: (),
}

/// Errors related to the initialization of the contract.
pub enum InitError {
    /// The contract has already been initialized.
    AlreadyInitialized: (),
    /// No coins were transferred during initialization.
    CannotAirdropZeroCoins: (),
}

/// Errors related to the state of the contract.
pub enum StateError {
    /// The claim period is not active.
    ClaimPeriodNotActive: (),
    /// The claim period is active.
    ClaimPeriodActive: (),
}

pub struct ClaimEvent {
    /// The quantity of an asset which is to be transferred to the user.
    amount: u64,
    /// The user that has a claim to coins with a valid proof.
    claimer: Identity,
    /// The identity that will receive the transferred asset.
    to: Identity,
}

pub struct ClawbackEvent {
    /// The quantity of an asset which will be returned after the claiming period has ended.
    amount: u64,
    /// The user that will receive the remaining asset balance.
    to: Identity,
}

pub struct CreateAirdropEvent {
    /// The user which can claim any left over coins after the claiming period.
    admin: Identity,
    /// The asset which is to be distributed.
    asset: AssetId,
    /// The block at which the claiming period will end.
    end_block: u32,
}

storage {
    /// The Identity which has the ability to clawback unclaimed coins of an asset.
    admin: Option<Identity> = Option::None,
    /// The asset which is to be distributed.
    asset: Option<AssetId> = Option::None,
    /// The block at which the claiming period will end.
    end_block: u32 = 0,
    /// Stores the ClaimState of users that have interacted with the Airdrop Distributor contract.
    /// Maps (user => claim)
    claims: StorageMap<Identity, ClaimState> = StorageMap {},
}


impl AirdropContract for Contract {
    #[storage(read, write)]
    fn claim(amount: u64, to: Identity) {
        // The claiming period must be open
        require(
            storage
                .end_block
                .read() > height(),
            StateError::ClaimPeriodNotActive,
        );

        // Users cannot claim twice
        let sender = msg_sender().unwrap();
        require(
            storage
                .claims
                .get(sender)
                .try_read()
                .unwrap_or(ClaimState::Unclaimed) == ClaimState::Unclaimed,
            AccessError::UserAlreadyClaimed,
        );

        // There must be enough coins left in the contract
        let asset = storage.asset.read().unwrap();
        require(this_balance(asset) >= amount, AccessError::NotEnoughCoins);

        storage.claims.insert(sender, ClaimState::Claimed(amount));

        // Transfer coins
        transfer(to, asset, amount);

        log(ClaimEvent {
            amount,
            claimer: sender,
            to,
        });
    }

    #[storage(read)]
    fn clawback() {
        let admin = storage.admin.read();
        require(
            admin
                .is_some() && admin
                .unwrap() == msg_sender()
                .unwrap(),
            AccessError::CallerNotAdmin,
        );
        require(
            storage
                .end_block
                .read() <= height(),
            StateError::ClaimPeriodActive,
        );

        let asset = storage.asset.read().unwrap();
        let balance = this_balance(asset);
        require(balance > 0, AccessError::NotEnoughCoins);

        // Send the remaining balance of coins to the admin
        transfer(admin.unwrap(), asset, balance);

        log(ClawbackEvent {
            amount: balance,
            to: admin.unwrap(),
        })
    }

    #[payable]
    #[storage(read, write)]
    fn constructor(
        admin: Identity,
        claim_time: u32
    ) {
        // If `end_block` is set to a value other than 0, we know that the constructor has already
        // been called.
        require(storage.end_block.read() == 0, InitError::AlreadyInitialized);
        require(msg_amount() > 0, InitError::CannotAirdropZeroCoins);

        let asset = msg_asset_id();
        storage.end_block.write(claim_time + height());
        storage.asset.write(Option::Some(asset));
        storage.admin.write(Option::Some(admin));

        log(CreateAirdropEvent {
            admin,
            asset: asset,
            end_block: claim_time
        });
    }
}


