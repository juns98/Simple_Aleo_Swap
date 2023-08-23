// The 'basic_swap' program.
program simple_swap.aleo {
    // key for public balance of token
    struct BalanceKey {
        token_id: field,
        user: address,
    }
    // private token record
    record Token {
        token_id: field,
        owner: address,
        amount: u128,
    }
    // public token mapping (BalanceKey => amount)
    mapping tokens : field => u128;

    // ====================== token ====================== //
    transition create_token(public id: field, public total_supply: u128)  {
       return then finalize(id, self.caller, total_supply);
    }
    finalize create_token(public id: field, public caller: address, public total_supply: u128) {
        let balance_key : field = get_balance_id(id, caller);
        assert(!Mapping::contains(tokens, balance_key));
        Mapping::set(tokens, balance_key, total_supply);
    }
 
    transition convert_public_token_to_private(caller: Token, convert_amount: u128) -> Token {
        let token_id: field = caller.token_id;
        let owner: address = caller.owner;
        let amount: u128 = caller.amount;
        let balance_after: u128 = amount + convert_amount;
        let transferred : Token = Token {
            token_id: caller.token_id,
            owner: caller.owner,
            amount: balance_after,
        };
        return (transferred) then finalize(token_id, self.caller, amount);
    }
    finalize convert_public_token_to_private(id: field, public caller: address, amount: u128) {
        let balance_key : field = get_balance_id(id, caller);
        // error if amount > balance
        let difference : u128 = Mapping::get_or_use(tokens, balance_key, 0u128) - amount;
        Mapping::set(tokens, balance_key, difference);
    }

    transition convert_private_token_to_public(id: field, amount: u128) -> Token {
        let transferred : Token = Token {
            token_id: id,
            owner: self.caller,
            amount: amount,
        };
        return (transferred) then finalize(id, self.caller, amount);
    }
    finalize convert_private_token_to_public(id: field, public caller: address, amount: u128) {
        let balance_key : field = get_balance_id(id, caller);
        // error if amount > balance
        let difference : u128 = Mapping::get_or_use(tokens, balance_key, 0u128) - amount;
        Mapping::set(tokens, balance_key, difference);
    }

    transition transfer_token_public(token_id: field, to: address, amount: u128) {
        return then finalize(token_id, self.caller, to, amount);
    }
    finalize transfer_token_public (token_id: field, public from: address, public to: address, public amount: u128) {
        let from_balance_key : field = get_balance_id(token_id, from);
        let from_balance : u128 = Mapping::get_or_use(tokens, from_balance_key, 0u128);
        assert(from_balance >= amount);
        Mapping::set(tokens, from_balance_key, from_balance - amount);

        let to_balance_key : field = get_balance_id(token_id, to);
        let to_balance : u128 = Mapping::get_or_use(tokens, to_balance_key, 0u128);
        Mapping::set(tokens, to_balance_key, to_balance + amount);
    }

    transition transfer_token_private(caller: Token, to: address, amount: u128) {
        let token_id: field = caller.token_id;
        let owner: address = caller.owner;
        let balance: u128 = caller.amount;
        assert(balance >= amount);
        let difference: u128 = balance - amount;

        let remaining: Token = Token {
            token_id: caller.token_id,
             owner: caller.owner,
            amount: balance - amount,
        }
        let transferred : Token = Token {
            token_id: caller.token_id,
            owner: caller.owner,
            amount: balance - amount,
        };
        return (remaining, transferred) ;
    } 
    finalize transfer_token_private(c)

    transition test() -> bool {
        assert(1u8 == 1u8);
        return 1u8==1u8 then finalize();
    } 
    finalize test() {
        assert(1u8 == 2u8);
    }

    // // public transfer 
    // transition transfer(public token_id: field, public to: address, public amount: u128) {
    //     return then finalize(token_id, self.caller, to, amount);
    // }
    // finalize transfer(public token_id: field, public from: address, public to: address, public amount: u128) {
    //     assert(Mapping::contains(tokens, token_id));
    //     let bid_from: field = get_balance_id(token_id, from);
    //     let bal_from: u128 = Mapping::get(balances, bid_from);
    //     Mapping::set(balances, bid_from, bal_from - amount);

    //     let bid_to: field = get_balance_id(token_id, to);
    //     let bal_to: u128 = Mapping::get_or_use(balances, bid_to, 0u128);
    //     Mapping::set(balances, bid_to, bal_to + amount);
    // }

    // Build a key of the mapping `balances`
    inline get_balance_id(token_id_: field, user_: address) -> field {
        // copy to avoid compiling error
        let token_id: field = token_id_;
        let user: address = user_;
        return BHP256::hash_to_field(BalanceKey {token_id, user});
    }
}
