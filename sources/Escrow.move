
module escrow::Escrow{
    use std::signer::address_of;
    use std::string;
    use aptos_framework::coin;
    use aptos_std::table::{Self, Table};
    use aptos_std::type_info;
    use aptos_framework::account;
    #[test_only]
    use std::debug;

    // Error map
    const EESCROW_ALREADY_EXIST: u64 = 1;
    const EESCROW_NOT_EXIST: u64 = 2;
    const ECANT_TAKE_OWN_ESCROW: u64 = 3;

    struct CreateEscrowEvent has key {
        escrow_addr: address
    }

    /// Droppable version of CoinInfo + address (so it can be used as key in a table)
    struct CoinId has copy, drop, store {
        name: string::String,
        /// Symbol of the coin, usually a shorter version of the name.
        /// For example, Singapore Dollar is SGD.
        symbol: string::String,
        /// Number of decimals used to get its user representation.
        /// For example, if `decimals` equals `2`, a balance of `505` coins should
        /// be displayed to a user as `5.05` (`505 / 10 ** 2`).
        decimals: u8,
        ///CoinType address
        addr: address, 
    }

    struct TokenEscrow has key {
        escrow_addr: address,
        escrow_signer_cap: account::SignerCapability,
    }

    struct Offers has key {
        offers: Table<CoinId, Offer>,
    }

    struct Offer has store, drop {
        token_a_id: CoinId,
        token_b_id: CoinId,
        token_a_amount: u64,
        token_b_amount: u64,
    }

    /// A helper function that returns the address of CoinType.
    fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }

    fun get_coin_id<CoinType>(): CoinId {
        let name = coin::name<CoinType>();
        let symbol = coin::symbol<CoinType>();
        let decimals = coin::decimals<CoinType>();
        let addr = coin_address<CoinType>();
        CoinId {
            name,
            symbol,
            decimals,
            addr,
        }
    }

    fun check_register_coin<CoinType>(sig: &signer) {
        let addr = address_of(sig);
        if (!coin::is_account_registered<CoinType>(addr)) {
                coin::register<CoinType>(sig);
            };
    }

    fun create_escrow_resource(initiator: &signer): address {
        // init escrow signer + cap
        let (escrow_signer, escrow_signer_cap) = account::create_resource_account(initiator, b"escrow");

        move_to(
                &escrow_signer,
                TokenEscrow {
                    escrow_addr: address_of(&escrow_signer),
                    escrow_signer_cap,
                }
            );

        move_to(
            &escrow_signer, 
            Offers {
                offers: table::new<CoinId, Offer>(),
            }
        );

        address_of(&escrow_signer)

    }

    /// Function that creates an escrow table at a user's address.
    public entry fun init_escrow(initiator: &signer) {

        // TODO: if resource does not exist else abort
        let escrow_signer_addr = create_escrow_resource(initiator);

        move_to(initiator, CreateEscrowEvent { escrow_addr: escrow_signer_addr });
    }

    public entry fun add_offer<TokenA, TokenB>(initiator: &signer, pay_amount: u64, receive_amount: u64) acquires TokenEscrow, Offers, CreateEscrowEvent {
        let initiator_addr = address_of(initiator);

        // Register Tokens if not already registered
        check_register_coin<TokenA>(initiator);
        check_register_coin<TokenB>(initiator);

        // Acquire escrow
        let escrow_addr =
            borrow_global<CreateEscrowEvent>(initiator_addr).escrow_addr; 
        let escrow = borrow_global_mut<TokenEscrow>(escrow_addr);
        let escrow_signer = account::create_signer_with_capability(&escrow.escrow_signer_cap);

        // Register tokens for escrow
        check_register_coin<TokenA>(&escrow_signer);
        check_register_coin<TokenB>(&escrow_signer);

        // Transfer token A
        coin::transfer<TokenA>(initiator, escrow_addr, pay_amount);

        // Create offer
        let token_a_id = get_coin_id<TokenA>();
        let token_b_id = get_coin_id<TokenB>();

        let offer = Offer {
            token_a_id,
            token_b_id,
            token_a_amount: pay_amount,
            token_b_amount: receive_amount,
        };

        let offers = &mut borrow_global_mut<Offers>(escrow_addr).offers;
        // Check that offer for this token type doesn't already exist
        assert!(!table::contains(offers, token_a_id), EESCROW_ALREADY_EXIST);
        table::add(offers, token_a_id, offer);

    }

    public entry fun cancel_offer<TokenA, TokenB>(initiator: &signer) acquires TokenEscrow, Offers, CreateEscrowEvent {
        let initiator_addr = address_of(initiator);

        // Acquire escrow
        let escrow_addr =
            borrow_global<CreateEscrowEvent>(initiator_addr).escrow_addr; 
        let escrow = borrow_global_mut<TokenEscrow>(escrow_addr);
        let escrow_signer = account::create_signer_with_capability(&escrow.escrow_signer_cap);

        let offers = &mut borrow_global_mut<Offers>(escrow_addr).offers;  
        let token_a_id = get_coin_id<TokenA>();      
        // Check that offer for this token type exists
        assert!(table::contains(offers, token_a_id), EESCROW_ALREADY_EXIST);
        table::remove(offers, token_a_id);

        coin::transfer<TokenA>(&escrow_signer, initiator_addr, coin::balance<TokenA>(escrow.escrow_addr)); // This should be safe bc every person has their own escrow but is it?
    }

  public entry fun take_offer<TokenA, TokenB>(taker: &signer, initiator_addr: address) acquires TokenEscrow, Offers, CreateEscrowEvent {
        let taker_addr = address_of(taker);

        // check that taker != initiator
        assert!(taker_addr != initiator_addr, ECANT_TAKE_OWN_ESCROW);

        // Register Tokens if not already registered
        check_register_coin<TokenA>(taker);
        check_register_coin<TokenB>(taker);
      
        // Acquire escrow
        let escrow_addr =
            borrow_global<CreateEscrowEvent>(initiator_addr).escrow_addr; 
        let escrow = borrow_global_mut<TokenEscrow>(escrow_addr);

        let offers = &mut borrow_global_mut<Offers>(escrow_addr).offers; 
        let token_a_id = get_coin_id<TokenA>();   

        // Check that offer for this token type exists
        assert!(table::contains(offers, token_a_id), EESCROW_NOT_EXIST);
        let offer = table::remove(offers, token_a_id);

         // Withdraw token A
        let escrow_signer = account::create_signer_with_capability(&escrow.escrow_signer_cap);

        // Transfer token A (taker receives)
        coin::transfer<TokenA>(&escrow_signer, taker_addr, coin::balance<TokenA>(escrow.escrow_addr)); // This should be safe bc every person has their own escrow but is it?

        //Transfer token B (taker pays)
        coin::transfer<TokenB>(taker, initiator_addr, offer.token_b_amount);
  }

    #[test_only]
    use aptos_framework::managed_coin;


    #[test_only]
    struct TokenA {}
    #[test_only]
    struct TokenB {}

    #[test_only]
    fun init_money(root: signer, destination: &signer, taker: &signer): (CoinId, CoinId) {
        let dst_addr = address_of(destination);

        managed_coin::initialize<TokenA>(&root, b"TokenA", b"PAY", 8, false);
        coin::register<TokenA>(destination);
        coin::register<TokenA>(taker);
        managed_coin::mint<TokenA>(&root, dst_addr, 500);
        managed_coin::mint<TokenA>(&root, address_of(taker), 500);

        let pay_token_id = get_coin_id<TokenA>();

        managed_coin::initialize<TokenB>(&root, b"TokenB", b"RECV", 8, false);
        coin::register<TokenB>(destination);
        coin::register<TokenB>(taker);
        managed_coin::mint<TokenB>(&root, dst_addr, 500);
        managed_coin::mint<TokenB>(&root, address_of(taker), 500);

        let receive_token_id =  get_coin_id<TokenB>();

        (pay_token_id, receive_token_id)
    }


  #[test(initiator = @0xACE, taker = @0xBB)]
    public entry fun test_init_money(initiator: signer, taker: signer) {
        let root = aptos_framework::account::create_account_for_test(@escrow);
        aptos_framework::account::create_account_for_test(address_of(&initiator));
        aptos_framework::account::create_account_for_test(address_of(&taker));

        init_money(root, &initiator, &taker);

        assert!(coin::balance<TokenA>(address_of(&initiator)) == 500, 1);
        assert!(coin::balance<TokenB>(address_of(&initiator)) == 500, 1);
        assert!(coin::balance<TokenA>(address_of(&taker)) == 500, 1);
        assert!(coin::balance<TokenB>(address_of(&taker)) == 500, 1);
    }

  #[test(initiator = @0xACE)]
    public entry fun test_init_escrow(initiator: signer) acquires CreateEscrowEvent {
        aptos_framework::account::create_account_for_test(address_of(&initiator));

        init_escrow(&initiator);

        // acquire event to get escrow_addr
        let escrow_addr =
            borrow_global<CreateEscrowEvent>(address_of(&initiator)).escrow_addr;

        assert!(exists<TokenEscrow>(escrow_addr), 1);
        assert!(exists<Offers>(escrow_addr), 2);
    }

  #[test(initiator = @0xACE, taker = @0xBB)]
    public entry fun test_add_offer(initiator: signer, taker: signer) acquires TokenEscrow, Offers, CreateEscrowEvent {

        let root = aptos_framework::account::create_account_for_test(@escrow);
        aptos_framework::account::create_account_for_test(address_of(&initiator));
        aptos_framework::account::create_account_for_test(address_of(&taker));

        let (token_a_id, _token_b_id) = init_money(root, &initiator, &taker);

        init_escrow(&initiator);

        add_offer<TokenA, TokenB>(&initiator, 1, 5);

        let escrow_addr =
            borrow_global<CreateEscrowEvent>(address_of(&initiator)).escrow_addr;

        assert!(coin::balance<TokenA>(escrow_addr) == 1, 1);
        assert!(coin::balance<TokenB>(escrow_addr) == 0, 2);

        assert!(coin::balance<TokenA>(address_of(&initiator)) == 499, 3);
        assert!(coin::balance<TokenB>(address_of(&initiator)) == 500, 4);

        let offers = &mut borrow_global_mut<Offers>(escrow_addr).offers;
        assert!(table::contains(offers, token_a_id), 5);

        debug::print(table::borrow(offers, token_a_id));
        // TODO: not sure this is actually generalized for all coins??
    }

    #[test(initiator = @0xACE, taker = @0xBB)]
    #[expected_failure(abort_code = 1)]
    public entry fun test_cant_add_offer_if_offer_exists(initiator: signer, taker: signer) acquires TokenEscrow, Offers, CreateEscrowEvent {

        let root = aptos_framework::account::create_account_for_test(@escrow);
        aptos_framework::account::create_account_for_test(address_of(&initiator));
        aptos_framework::account::create_account_for_test(address_of(&taker));

        let (_token_a_id, _token_b_id) = init_money(root, &initiator, &taker);

        init_escrow(&initiator);

        add_offer<TokenA, TokenB>(&initiator, 1, 5);
        add_offer<TokenA, TokenB>(&initiator, 2, 10);
    }

    #[test(initiator = @0xACE, taker = @0xBB)]
    public entry fun test_cancel_offer(initiator: signer, taker: signer) acquires TokenEscrow, Offers, CreateEscrowEvent {

        let root = aptos_framework::account::create_account_for_test(@escrow);
        aptos_framework::account::create_account_for_test(address_of(&initiator));
        aptos_framework::account::create_account_for_test(address_of(&taker));

        let (token_a_id, _token_b_id) = init_money(root, &initiator, &taker);

        init_escrow(&initiator);

        add_offer<TokenA, TokenB>(&initiator, 1, 5);

        let escrow_addr =
            borrow_global<CreateEscrowEvent>(address_of(&initiator)).escrow_addr;

        assert!(coin::balance<TokenA>(escrow_addr) == 1, 1);
        assert!(coin::balance<TokenB>(escrow_addr) == 0, 2);

        assert!(coin::balance<TokenA>(address_of(&initiator)) == 499, 3);
        assert!(coin::balance<TokenB>(address_of(&initiator)) == 500, 4);

        let offers = &mut borrow_global_mut<Offers>(escrow_addr).offers;
        assert!(table::contains(offers, token_a_id), 5);

        cancel_offer<TokenA, TokenB>(&initiator);

        assert!(coin::balance<TokenA>(escrow_addr) == 0, 6);
        assert!(coin::balance<TokenB>(escrow_addr) == 0, 7);

        assert!(coin::balance<TokenA>(address_of(&initiator)) == 500, 8);
        assert!(coin::balance<TokenB>(address_of(&initiator)) == 500, 9);

        let offers = &mut borrow_global_mut<Offers>(escrow_addr).offers;
        assert!(!table::contains(offers, token_a_id), 10);
    }

    #[test(initiator = @0xACE, taker = @0xBB)]
    #[expected_failure]
    public entry fun test_cancel_offer_only_works_with_initiator(initiator: signer, taker: signer) acquires TokenEscrow, Offers, CreateEscrowEvent {

        let root = aptos_framework::account::create_account_for_test(@escrow);
        aptos_framework::account::create_account_for_test(address_of(&initiator));
        aptos_framework::account::create_account_for_test(address_of(&taker));

        let (_token_a_id, _token_b_id) = init_money(root, &initiator, &taker);

        init_escrow(&initiator);

        add_offer<TokenA, TokenB>(&initiator, 1, 5);
        cancel_offer<TokenA, TokenB>(&taker);

    }

    #[test(initiator = @0xACE, taker = @0xBB)]
    public entry fun test_take_offer(initiator: signer, taker: signer) acquires TokenEscrow, Offers, CreateEscrowEvent {

        let root = aptos_framework::account::create_account_for_test(@escrow);
        aptos_framework::account::create_account_for_test(address_of(&initiator));
        aptos_framework::account::create_account_for_test(address_of(&taker));

        let (token_a_id, _token_b_id) = init_money(root, &initiator, &taker);


        init_escrow(&initiator);

        add_offer<TokenA, TokenB>(&initiator, 1, 5);

        let escrow_addr =
            borrow_global<CreateEscrowEvent>(address_of(&initiator)).escrow_addr;

        assert!(coin::balance<TokenA>(escrow_addr) == 1, 1);
        assert!(coin::balance<TokenB>(escrow_addr) == 0, 2);

        assert!(coin::balance<TokenA>(address_of(&initiator)) == 499, 3);
        assert!(coin::balance<TokenB>(address_of(&initiator)) == 500, 4);
        assert!(coin::balance<TokenA>(address_of(&taker)) == 500, 5);
        assert!(coin::balance<TokenB>(address_of(&taker)) == 500, 6);

        take_offer<TokenA, TokenB>(&taker, address_of(&initiator));

        let offers = &mut borrow_global_mut<Offers>(escrow_addr).offers;
        assert!(!table::contains(offers, token_a_id), 100);

        assert!(coin::balance<TokenA>(escrow_addr) == 0, 7);
        assert!(coin::balance<TokenB>(escrow_addr) == 0, 8);

        assert!(coin::balance<TokenA>(address_of(&initiator)) == 499, 9);
        assert!(coin::balance<TokenB>(address_of(&initiator)) == 505, 10);
        assert!(coin::balance<TokenA>(address_of(&taker)) == 501, 11);
        assert!(coin::balance<TokenB>(address_of(&taker)) == 495, 12);
    }


    #[test(initiator = @0xACE, taker = @0xBB)]
    #[expected_failure(abort_code = 3)]
    public entry fun test_cant_take_own_offer(initiator: signer, taker: signer) acquires TokenEscrow, Offers, CreateEscrowEvent {

        let root = aptos_framework::account::create_account_for_test(@escrow);
        aptos_framework::account::create_account_for_test(address_of(&initiator));
        aptos_framework::account::create_account_for_test(address_of(&taker));

        let (token_a_id, _token_b_id) = init_money(root, &initiator, &taker);


        init_escrow(&initiator);

        add_offer<TokenA, TokenB>(&initiator, 1, 5);

        let escrow_addr =
            borrow_global<CreateEscrowEvent>(address_of(&initiator)).escrow_addr;

        assert!(coin::balance<TokenA>(escrow_addr) == 1, 1);
        assert!(coin::balance<TokenB>(escrow_addr) == 0, 2);

        assert!(coin::balance<TokenA>(address_of(&initiator)) == 499, 3);
        assert!(coin::balance<TokenB>(address_of(&initiator)) == 500, 4);
        assert!(coin::balance<TokenA>(address_of(&taker)) == 500, 5);
        assert!(coin::balance<TokenB>(address_of(&taker)) == 500, 6);

        take_offer<TokenA, TokenB>(&initiator, address_of(&initiator));

        let offers = &mut borrow_global_mut<Offers>(escrow_addr).offers;
        assert!(!table::contains(offers, token_a_id), 100);

        assert!(coin::balance<TokenA>(escrow_addr) == 0, 7);
        assert!(coin::balance<TokenB>(escrow_addr) == 0, 8);

        assert!(coin::balance<TokenA>(address_of(&initiator)) == 500, 9);
        assert!(coin::balance<TokenB>(address_of(&initiator)) == 500, 10);
    }

    #[test(initiator = @0xACE, taker = @0xBB)]
    #[expected_failure(abort_code = 2)]
    public entry fun test_cant_take_offer_that_doesnt_exist(initiator: signer, taker: signer) acquires TokenEscrow, Offers, CreateEscrowEvent {

        let root = aptos_framework::account::create_account_for_test(@escrow);
        aptos_framework::account::create_account_for_test(address_of(&initiator));
        aptos_framework::account::create_account_for_test(address_of(&taker));

        let (_token_a_id, _token_b_id) = init_money(root, &initiator, &taker);

        init_escrow(&initiator);

        take_offer<TokenA, TokenB>(&taker, address_of(&initiator));
    }

}
