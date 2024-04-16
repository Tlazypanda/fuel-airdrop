library;

abi AirdropContract {
    #[storage(read, write)]
    fn claim(amount: u64, to: Identity);

    #[storage(read)]
    fn clawback();

    #[payable]
    #[storage(read, write)]
    fn constructor(admin: Identity, claim_time: u32);
}