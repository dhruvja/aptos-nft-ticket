module NftTicket::Ticket {

    use std::signer;
    use std::vector;

    use aptos_framework::account;
    use aptos_framework::aptos_account;
    use aptos_framework::managed_coin;
    use aptos_framework::coin;

    const EVENUE_NOT_CREATED: u64 = 0;
    const EINVALID_VENUE_OWNER: u64 = 1;
    const EINVALID_VECTOR_LENGTH: u64 = 2;
    const ETICKET_NOT_FOUND: u64 = 3;
    const ETICKETS_NOT_AVAILABLE: u64 = 4;
    const EINVALID_BALANCE: u64 = 5;

    struct Ticket has store {
        name: vector<u8>,
        description: vector<u8>, 
        max_quantity: u64,
        price: u64,
        available: u64
    }

    struct Venue<phantom CoinType> has key {
        name: vector<u8>,
        description: vector<u8>,
        tickets: vector<Ticket>,
        owner: address
    }

    public entry fun create_venue<CoinType>(venue_owner: &signer, name: vector<u8>, description: vector<u8>) {
        let tickets = vector::empty<Ticket>();
        let venue_owner_addr = signer::address_of(venue_owner);

        // creating a resource account which would create collection and mint tokens
        let (resource, _resource_signer_cap) = account::create_resource_account(venue_owner, name);
        move_to<Venue<CoinType>>(&resource, Venue {name, description, tickets, owner: venue_owner_addr});

        // create a collection with the venue name and resource account as the creator
    }

    public entry fun create_ticket<CoinType>(venue_owner: &signer, venue_resource: address, name: vector<u8>, description: vector<u8>, max_quantity: u64, price: u64) acquires Venue {
        assert!(exists<Venue<CoinType>>(venue_resource), EVENUE_NOT_CREATED);
       
        let venue_owner_addr = signer::address_of(venue_owner); 
        let venue_info = borrow_global_mut<Venue<CoinType>>(venue_resource);
        assert!(venue_info.owner == venue_owner_addr, EINVALID_VENUE_OWNER);

        let ticket = Ticket {
            name,
            description,
            max_quantity,
            price,
            available: max_quantity // At the point of creation, max quantity of tickets would be equal to available tickets
        };

        vector::push_back(&mut venue_info.tickets, ticket);

        // Creating a token data for this particular type of ticket which would be used to mint NFTs
    }

    public entry fun purchase_ticket<CoinType>(buyer: &signer, venue_resource: address, name: vector<u8>, quantity: u64) acquires Venue {
        assert!(exists<Venue<CoinType>>(venue_resource), EVENUE_NOT_CREATED);

        let venue_info = borrow_global_mut<Venue<CoinType>>(venue_resource);
        let ticket_count = vector::length(&venue_info.tickets);

        let i = 0;
        while (i < ticket_count) {
            let current = vector::borrow<Ticket>(&venue_info.tickets, i);
            if (current.name == name) {
                break
            };
            i = i +1;
        };
        assert!(i != ticket_count, ETICKET_NOT_FOUND);

        let ticket = vector::borrow<Ticket>(&venue_info.tickets, i);
        assert!(ticket.available >= quantity, ETICKETS_NOT_AVAILABLE);

        let total_price = ticket.price * quantity;
        coin::transfer<CoinType>(buyer, venue_info.owner, total_price);

        // Mint the NFT to the buyer account
    }

    #[test_only]
    public fun get_resource_account(source: address, seed: vector<u8>)  : address {
        use std::hash;
        use aptos_std::from_bcs;
        use std::bcs;
        let bytes = bcs::to_bytes(&source);
        vector::append(&mut bytes, seed);
        from_bcs::to_address(hash::sha3_256(bytes))
    }

    #[test_only]
    struct FakeCoin {}

    #[test_only]
    public fun initialize_coin_and_mint(admin: &signer, user: &signer, mint_amount: u64) {
        let user_addr = signer::address_of(user);
        managed_coin::initialize<FakeCoin>(admin, b"fake", b"F", 9, false);
        aptos_account::create_account(user_addr);
        managed_coin::register<FakeCoin>(user);
        managed_coin::mint<FakeCoin>(admin, user_addr, mint_amount); 
    }

    
    #[test(venue_owner = @0x4, buyer = @0x5, module_owner = @NftTicket)]
    public fun can_create_venue(venue_owner: signer, buyer: signer, module_owner: signer) acquires Venue {
        let venue_name = b"Eminem Concert";
        let venue_description = b"This concert would be lit";
        let venue_owner_addr = signer::address_of(&venue_owner);
        let buyer_addr = signer::address_of(&buyer);

        let initial_mint_amount: u64 = 10000;
        initialize_coin_and_mint(&module_owner, &buyer, initial_mint_amount);
        aptos_account::create_account(venue_owner_addr);
        managed_coin::register<FakeCoin>(&venue_owner);

        create_venue<FakeCoin>(&venue_owner, venue_name, venue_description);
        let venue_resource = get_resource_account(venue_owner_addr, venue_name);
        assert!(exists<Venue<FakeCoin>>(venue_resource), EVENUE_NOT_CREATED);


        let ticket_name = b"Front row";
        let ticket_description = b"You can see a lot of people";
        let ticket_price = 100;
        let max_tickets = 50; 
        create_ticket<FakeCoin>(&venue_owner, venue_resource, ticket_name, ticket_description, max_tickets ,ticket_price);

        let venue_info = borrow_global_mut<Venue<FakeCoin>>(venue_resource);
        assert!(vector::length(&venue_info.tickets) == 1, EINVALID_VECTOR_LENGTH);

        purchase_ticket<FakeCoin>(&buyer, venue_resource, ticket_name, 1);
        assert!(coin::balance<FakeCoin>(buyer_addr) == (initial_mint_amount - ticket_price), EINVALID_BALANCE);
        assert!(coin::balance<FakeCoin>(venue_owner_addr) == (ticket_price), EINVALID_BALANCE);
        
    }

}