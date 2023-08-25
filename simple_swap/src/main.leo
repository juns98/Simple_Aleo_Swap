// The 'basic_swap' program.
program simple_swap.aleo {
    // key for public balance of token
    struct BalanceKey {
        token_id: field,
        user: address,
    }
    struct PairKey {
        token_a: field,
        token_b: field,
    }
    // private token record
    record Token {
        token_id: u64,
        owner: address,
        amount: u128,
    }
    // struct for tokenInfo
    struct TokenInfo {
        token_id: u64,
        total_supply: u128,
        decimals: u8,
    }
    // public token mapping (BalanceKey => amount)
    mapping tokens : field => u128;
    mapping token_lists : u64 => TokenInfo;
    mapping deposit_lists_in: field => u128;
    mapping deposit_lists_out: field => u128;

    // ====================== token ====================== //
    transition init_token(public id: u128, public decimals: u8, public total_supply: u128)  {
       return then finalize(id, self.caller, total_supply);
    }
    finalize create_token(public id: field, public caller: address,public decimals: u8, public total_supply: u128) {
        assert(!Mapping::contains(tokens, id));
        Mapping::set(tokens, id, TokenInfo {
            token_id: id,
            total_supply: total_supply,
            decimals: decimals,
        });
    }

    transition add_liquidity(maker: Token, maker_address: address, amount_in: u128, token_out: u128, amount_out: u128) {
        let token_id: field = maker.token_id;
        let owner: address = maker.owner;
        let balance: u128 = maker.amount;
        assert(balance >= amount);
        let difference: u128 = balance - amount;

        let remaining: Token = Token {
            token_id: maker.token_id,
            owner: maker.owner,
            amount: maker.amount - amount,
        };
        return remaining then finalize(token_id, maker_address, amount_in, token_out, amount_out);
    }
    finalize add_liquidity(token_id_in: u128, public maker_address: address, amount_in: u128,
        token_id_out: u128, amount_out: u128) {
        let deposit_id : field = get_deposit_id(token_id_in, token_id_out, maker_address);
        // if deposit_id already exists in deposit_lists, add amount to it
        let amount_in: u128 = Mapping::get_or_use(deposit_lists_in, deposit_id, 0u128) + amount_in;
        let amount_out: u128 = Mapping::get_or_use(deposit_lists_out, deposit_id, 0u128) + amount_out;
        Mapping::set(deposit_lists_in, deposit_id, amount_in);
        Mapping::set(deposit_lists_out, deposit_id, amount_out);
    }

    struct Request {

    }

    transition swap(taker: Token, amount_in: u128, token_out: u128, amount_out: u128) {
        let token_id: field = taker.token_id;
        let owner: address = taker.owner;
        let balance: u128 = taker.amount;
        assert(balance >= amount);
        let difference: u128 = balance - amount;

        let remaining: Token = Token {
            token_id: token_id,
            owner: owner,
            amount: balance - amount_in,
        };

        let receiving: Token = Token {
            token_id: token_out,
            owner: owner,
            amount: amount_out,
        }
        return (remaining, receiving) then finalize(token_id, token_out, taker_address, amount);
    }
    finalize swap(token_id_in: u128, token_out_id: u128, public taker_address: address, 
        amount_in: u128,amount_out: u128) {
        let deposit_id : field = get_deposit_id(token_id_in, token_id_out, taker_address);
        // if deposit_id already exists in deposit_lists, add amount to it
        let amount_in: u128 = Mapping::get_or_use(deposit_lists_in, deposit_id, 0u128) + amount_in;
        let amount_out: u128 = Mapping::get_or_use(deposit_lists_out, deposit_id, 0u128) + amount_out;
        Mapping::set(deposit_lists_in, deposit_id, amount_in);
        Mapping::set(deposit_lists_out, deposit_id, amount_out);
    }

    struct DepositInfo {
        token_in_id: u128,
        token_out_id: u128,
        user: address,
    }

    function get_deposit_id(token_in_id: u128, token_out_id: u128, user: address) -> field {
        return BHP256::hash_to_field(DepositInfo {
            token_in_id,
            token_out_id, 
            user
        });
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

    transition convert_private_token_to_public(caller: Token, amount: u128) -> Token {
        let transferred : Token = Token {
            token_id: caller.token_id,
            owner: caller.owner,
            amount: caller.amount - amount,
        };
        return transferred then finalize(id, self.caller, amount);
    }
    finalize convert_private_token_to_public(id: field, public caller: address, amount: u128) {
        let balance_key : field = get_balance_id(id, caller);
        // error if amount > balance
        let result : u128 = Mapping::get_or_use(tokens, balance_key, 0u128) + amount;
        Mapping::set(tokens, balance_key, result);
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
        };
        let transferred : Token = Token {
            token_id: caller.token_id,
            owner: to,
            amount: amount,
        };
        return (remaining, transferred);
    } 

    // Merge two `PrivateToken` records into a new `PrivateToken` record.
    // The two records being joined must have the same owner and the token id.
    transition join(private pt1: PrivateToken, private pt2: PrivateToken) -> PrivateToken {
        assert_eq(pt1.token, pt2.token);
        // the following should always be true
        // assert_eq(pt1.owner, pt2.owner);
        // assert_eq(pt1.owner, self.caller);
        return PrivateToken {
            owner: pt1.owner,
            token: pt1.token,
            amount: pt1.amount + pt2.amount,
        };
    }

    // ========================= liquidity =========================

    // Create a new pair and add initial liquidity.
    // A pair must be created through this function before subsequent liquidity and swap operations can be performed.
    // Each pair is also a standard token (called liquidity pool token or LP token) created automatically when the pair is created,
    // and its token_id is the same as pair_id: `lp_token_id = pair_id = bhp256_hash({token_a: field, token_b: field})`.
    // The caller's token_a and token_b will be transferred to the program, and LP tokens will be minted to the `to` address.
    transition create_pair(
        public token_a: field,
        public token_b: field,
        public amount_a: u128,
        public amount_b: u128,
        public to: address
     ) {
        assert(token_a < token_b);
        assert(amount_a > 0u128);
        assert(amount_b > 0u128);
        return then finalize(self.caller, token_a, token_b, amount_a, amount_b, to);
    }

    finalize create_pair(
        public caller: address,
        public token_a_id: field,
        public token_b_id: field,
        public amount_a: u128,
        public amount_b: u128,
        public to: address
    ) {
        let pair_id: field = get_pair_id(token_a_id, token_b_id);
        let liquidity: u128 = sqrt_u128(amount_a * amount_b);
        assert(liquidity > 0u128);

        let ti_pair: TokenInfo = Mapping::get_or_use(tokens, pid, TokenInfo {
            name: 5183377571718029925300968712562field, // AleoSwap-Pair
            symbol: 4281168field, // ASP
            decimals: 6u8,
            total_supply: 0u128,
            admin: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc,
        });
        assert_eq(ti_pair.total_supply, 0u128);

        let pair: Pair = Mapping::get_or_use(pairs, pid, Pair {
            reserve_a: 0u128,
            reserve_b: 0u128,
        });

        // update balances
        let bid_a: field = get_balance_id(token_a, caller);
        Mapping::set(balances, bid_a, Mapping::get(balances, bid_a) - amount_a);
        let bid_b: field = get_balance_id(token_b, caller);
        Mapping::set(balances, bid_b, Mapping::get(balances, bid_b) - amount_b);

        // mint liquidity
        let bid_p: field = get_balance_id(pid, to);
        Mapping::set(balances, bid_p, Mapping::get_or_use(balances, bid_p, 0u128) + liquidity);
        Mapping::set(tokens, pid, TokenInfo {
            name: ti_pair.name,
            symbol: ti_pair.symbol,
            decimals: ti_pair.decimals,
            total_supply: ti_pair.total_supply + liquidity,
            admin: ti_pair.admin,
        });

        // update pair
        Mapping::set(pairs, pid, Pair {
            reserve_a: pair.reserve_a + amount_a,
            reserve_b: pair.reserve_b + amount_b,
        });
    }

    // Create a new pair and add initial liquidity privately.
    transition create_pair_privately(
        private pt_a: PrivateToken,
        private pt_b: PrivateToken,
        public amount_a: u128,
        public amount_b: u128,
        private to: address,
        public pair_id: field,
        public liquidity: u128,
     ) -> (PrivateToken, PrivateToken, PrivateToken) {
        let token_a: field = pt_a.token;
        let token_b: field = pt_b.token;
        assert(token_a < token_b);
        assert(amount_a > 0u128);
        assert(amount_b > 0u128);
        assert(liquidity > 0u128);
        let change_a: PrivateToken = PrivateToken {
            owner: pt_a.owner,
            token: token_a,
            amount: pt_a.amount - amount_a,
        };
        let change_b: PrivateToken = PrivateToken {
            owner: pt_b.owner,
            token: token_b,
            amount: pt_b.amount - amount_b,
        };

        // let pid: field = get_pair_id(token_a, token_b);
        // let liquidity: u128 = sqrt_u128(amount_a * amount_b);
        let pt_lp: PrivateToken = PrivateToken {
            owner: to,
            token: pair_id,
            amount: liquidity,
        };
        return (pt_lp, change_a, change_b) then finalize(token_a, token_b, amount_a, amount_b, pair_id, liquidity);
    }
    finalize create_pair_privately(
        public token_a: field,
        public token_b: field,
        public amount_a: u128,
        public amount_b: u128,
        public pid_in: field,
        public liquidity_in: u128,
    ) {
        let pid: field = get_pair_id(token_a, token_b);
        assert(pid_in == pid);
        let liquidity: u128 = sqrt_u128(amount_a * amount_b);
        assert(liquidity_in == liquidity);

        let ti_pair: TokenInfo = Mapping::get_or_use(tokens, pid, TokenInfo {
            name: 5183377571718029925300968712562field, // AleoSwap-Pair
            symbol: 4281168field, // ASP
            decimals: 6u8,
            total_supply: 0u128,
            admin: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc,
        });
        assert_eq(ti_pair.total_supply, 0u128);

        let pair: Pair = Mapping::get_or_use(pairs, pid, Pair {
            reserve_a: 0u128,
            reserve_b: 0u128,
        });

        // mint liquidity
        Mapping::set(tokens, pid, TokenInfo {
            name: ti_pair.name,
            symbol: ti_pair.symbol,
            decimals: ti_pair.decimals,
            total_supply: ti_pair.total_supply + liquidity,
            admin: ti_pair.admin,
        });

        // update pair
        Mapping::set(pairs, pid, Pair {
            reserve_a: pair.reserve_a + amount_a,
            reserve_b: pair.reserve_b + amount_b,
        });
    }

    // Add liquidity to a pair.
    // The caller's `token_a` and `token_b` will be transferred to the program, and LP tokens will be minted to the `to` address.
    transition add_liquidity(
        public token_a: field,
        public token_b: field,
        public amount_a: u128,
        public amount_b: u128,
        public min_a: u128,
        public min_b: u128,
        public to: address
     ) {
        assert(token_a < token_b);
        assert(amount_a > 0u128 && amount_a >= min_a);
        assert(amount_b > 0u128 && amount_b >= min_b);
        return then finalize(self.caller, token_a, token_b, amount_a, amount_b, min_a, min_b, to);
    }

    finalize add_liquidity(
        public caller: address,
        public token_a: field,
        public token_b: field,
        public amount_a: u128,
        public amount_b: u128,
        public min_a: u128,
        public min_b: u128,
        public to: address
    ) {
        let pid: field = get_pair_id(token_a, token_b);
        let pair: Pair = Mapping::get(pairs, pid);
        let ti_pair: TokenInfo = Mapping::get(tokens, pid);
        let liq_a: u128 = amount_a * ti_pair.total_supply / pair.reserve_a;
        let liq_b: u128 = amount_b * ti_pair.total_supply / pair.reserve_b;
        let liquidity: u128 = liq_a <= liq_b ? liq_a : liq_b;
        amount_a = liq_a <= liquidity
                ? amount_a
                : (liquidity * pair.reserve_a + ti_pair.total_supply - 1u128) / ti_pair.total_supply;
        amount_b = liq_b <= liquidity
                ? amount_b
                : (liquidity * pair.reserve_b + ti_pair.total_supply - 1u128) / ti_pair.total_supply;
        assert(liquidity > 0u128);
        assert(amount_a >= min_a);
        assert(amount_b >= min_b);

        // update balances
        let bid_a: field = get_balance_id(token_a, caller);
        Mapping::set(balances, bid_a, Mapping::get(balances, bid_a) - amount_a);
        let bid_b: field = get_balance_id(token_b, caller);
        Mapping::set(balances, bid_b, Mapping::get(balances, bid_b) - amount_b);

        // mint liquidity
        let bid_p: field = get_balance_id(pid, to);
        Mapping::set(balances, bid_p, Mapping::get_or_use(balances, bid_p, 0u128) + liquidity);
        Mapping::set(tokens, pid, TokenInfo {
            name: ti_pair.name,
            symbol: ti_pair.symbol,
            decimals: ti_pair.decimals,
            total_supply: ti_pair.total_supply + liquidity,
            admin: ti_pair.admin,
        });

        // update pair
        Mapping::set(pairs, pid, Pair {
            reserve_a: pair.reserve_a + amount_a,
            reserve_b: pair.reserve_b + amount_b,
        });
    }

    // Remove liquidity from a pair.
    // The caller's LP tokens will be burned, `token_a` and `token_b` will be transferred to the `to` address.
    transition remove_liquidity(
        public token_a: field,
        public token_b: field,
        public liquidity: u128,
        public min_a: u128,
        public min_b: u128,
        public to: address,
     ) {
        assert(token_a < token_b);
        assert(liquidity > 0u128);
        return then finalize(self.caller, token_a, token_b, liquidity, min_a, min_b, to);
    }

    finalize remove_liquidity(
        public caller: address,
        public token_a: field,
        public token_b: field,
        public liquidity: u128,
        public min_a: u128,
        public min_b: u128,
        public to: address,
    ) {
        let pid: field = get_pair_id(token_a, token_b);
        let ti_pair: TokenInfo = Mapping::get(tokens, pid);
        let pair: Pair = Mapping::get(pairs, pid);

        // calculate token amounts
        let amount_a: u128 = liquidity * pair.reserve_a / ti_pair.total_supply;
        let amount_b: u128 = liquidity * pair.reserve_b / ti_pair.total_supply;
        assert(amount_a >= min_a && amount_b >= min_b);
        assert(amount_a > 0u128 || amount_b > 0u128);

        // burn liquidity
        let bid_p: field = get_balance_id(pid, caller);
        Mapping::set(balances, bid_p, Mapping::get(balances, bid_p) - liquidity);
        Mapping::set(tokens, pid, TokenInfo {
            name: ti_pair.name,
            symbol: ti_pair.symbol,
            decimals: ti_pair.decimals,
            total_supply: ti_pair.total_supply - liquidity,
            admin: ti_pair.admin,
        });

        // update pair
        Mapping::set(pairs, pid, Pair {
            reserve_a: pair.reserve_a - amount_a,
            reserve_b: pair.reserve_b - amount_b,
        });

        // send tokens
        let bid_a: field = get_balance_id(token_a, to);
        let bid_b: field = get_balance_id(token_b, to);
        Mapping::set(balances, bid_a, Mapping::get_or_use(balances, bid_a, 0u128) + amount_a);
        Mapping::set(balances, bid_b, Mapping::get_or_use(balances, bid_b, 0u128) + amount_b);
    }

    // ========================= swap exact =========================

    // Exchange a fixed amount of public input tokens for a variable amount of public output tokens.
    transition swap_exact_tokens_for_tokens(
        public token_in: field,
        public token_out: field,
        public amount_in: u128,
        public amount_out_min: u128,
        public to: address,
     ) {
        assert(token_in != token_out);
        assert(amount_in > 0u128);
        return then finalize(self.caller, token_in, token_out, amount_in, amount_out_min, to);
    }

    finalize swap_exact_tokens_for_tokens(
        public caller: address,
        public token_in: field,
        public token_out: field,
        public amount_in: u128,
        public amount_out_min: u128,
        public to: address,
    ) {
        let token_a: field = token_in < token_out ? token_in : token_out;
        let token_b: field = token_in < token_out ? token_out : token_in;
        let pid: field = get_pair_id(token_a, token_b);
        let pair: Pair = Mapping::get(pairs, pid);

        // calculate output amount
        let reserve_in: u128 = token_a == token_in ? pair.reserve_a : pair.reserve_b;
        let reserve_out: u128 = token_a == token_out ? pair.reserve_a : pair.reserve_b;
        let amount_in_with_fee: u128 = amount_in * 997u128;
        let amount_out: u128 = amount_in_with_fee * reserve_out / (reserve_in * 1000u128 + amount_in_with_fee);
        assert(amount_out >= amount_out_min);
        assert(amount_out > 0u128);

        // transfer input token
        let bid_in: field = get_balance_id(token_in, caller);
        Mapping::set(balances, bid_in, Mapping::get(balances, bid_in) - amount_in);

        // update pair
        let reserve_in_new: u128 = reserve_in + amount_in;
        let reserve_out_new: u128 = reserve_out - amount_out;
        Mapping::set(pairs, pid, Pair {
            reserve_a: token_a == token_in ? reserve_in_new : reserve_out_new,
            reserve_b: token_b == token_in ? reserve_in_new : reserve_out_new,
        });

        // transfer output token
        let bid_out: field = get_balance_id(token_out, to);
        Mapping::set(balances, bid_out, Mapping::get_or_use(balances, bid_out, 0u128) + amount_out);
    }

    // Exchange a fixed amount of private input tokens for a variable amount of public output tokens.
    transition swap_exact_private_for_public(
        private pt_in: PrivateToken,
        public token_out: field,
        public amount_in: u128,
        public amount_out_min: u128,
        public to: address,
     ) -> (PrivateToken) {
        let token_in: field = pt_in.token;
        assert(token_in != token_out);
        assert(amount_in > 0u128);

        let change_in: PrivateToken = PrivateToken {
            owner: pt_in.owner,
            token: token_in,
            amount: pt_in.amount - amount_in,
        };
        return change_in then finalize(token_in, token_out, amount_in, amount_out_min, to);
    }

    finalize swap_exact_private_for_public(
        public token_in: field,
        public token_out: field,
        public amount_in: u128,
        public amount_out_min: u128,
        public to: address,
    ) {
        let token_a: field = token_in < token_out ? token_in : token_out;
        let token_b: field = token_in < token_out ? token_out : token_in;
        let pid: field = get_pair_id(token_a, token_b);
        let pair: Pair = Mapping::get(pairs, pid);

        // calculate output amount
        let reserve_in: u128 = token_a == token_in ? pair.reserve_a : pair.reserve_b;
        let reserve_out: u128 = token_a == token_out ? pair.reserve_a : pair.reserve_b;
        let amount_in_with_fee: u128 = amount_in * 997u128;
        let amount_out: u128 = amount_in_with_fee * reserve_out / (reserve_in * 1000u128 + amount_in_with_fee);
        assert(amount_out >= amount_out_min);
        assert(amount_out > 0u128);

        // input token has been transferred privately

        // update pair
        let reserve_in_new: u128 = reserve_in + amount_in;
        let reserve_out_new: u128 = reserve_out - amount_out;
        Mapping::set(pairs, pid, Pair {
            reserve_a: token_a == token_in ? reserve_in_new : reserve_out_new,
            reserve_b: token_b == token_in ? reserve_in_new : reserve_out_new,
        });

        // transfer output token
        let bid_out: field = get_balance_id(token_out, to);
        Mapping::set(balances, bid_out, Mapping::get_or_use(balances, bid_out, 0u128) + amount_out);
    }

    // Exchange a fixed amount of private input tokens for a variable amount of private output tokens.
    transition swap_exact_private_for_private(
        private pt_in: PrivateToken,
        public token_out: field,
        public amount_in: u128,
        public amount_out_min: u128,
        private to_pri: address,
        public to_pub: address,
     ) -> (PrivateToken, PrivateToken){
        let token_in: field = pt_in.token;
        assert(token_in != token_out);
        assert(amount_in > 0u128);
        let pt_out: PrivateToken = PrivateToken {
            owner: to_pri,
            token: token_out,
            amount: amount_out_min,
        };
        let change_in: PrivateToken = PrivateToken {
            owner: pt_in.owner,
            token: token_in,
            amount: pt_in.amount - amount_in,
        };
        return (pt_out, change_in) then finalize(token_in, token_out, amount_in, amount_out_min, to_pub);
    }

    finalize swap_exact_private_for_private(
        public token_in: field,
        public token_out: field,
        public amount_in: u128,
        public amount_out_min: u128,
        public to: address,
    ) {
        let token_a: field = token_in < token_out ? token_in : token_out;
        let token_b: field = token_in < token_out ? token_out : token_in;
        let pid: field = get_pair_id(token_a, token_b);
        let pair: Pair = Mapping::get(pairs, pid);

        // calculate output amount
        let reserve_in: u128 = token_a == token_in ? pair.reserve_a : pair.reserve_b;
        let reserve_out: u128 = token_a == token_out ? pair.reserve_a : pair.reserve_b;
        let amount_in_with_fee: u128 = amount_in * 997u128;
        let amount_out: u128 = amount_in_with_fee * reserve_out / (reserve_in * 1000u128 + amount_in_with_fee);
        assert(amount_out >= amount_out_min);
        assert(amount_out > 0u128);

        // input token has been transferred privately

        // update pair
        let reserve_in_new: u128 = reserve_in + amount_in;
        let reserve_out_new: u128 = reserve_out - amount_out;
        Mapping::set(pairs, pid, Pair {
            reserve_a: token_a == token_in ? reserve_in_new : reserve_out_new,
            reserve_b: token_b == token_in ? reserve_in_new : reserve_out_new,
        });

        // transfer output token (minus the private part)
        let bid_out: field = get_balance_id(token_out, to);
        let amount_out_diff: u128 = amount_out - amount_out_min;
        Mapping::set(balances, bid_out, Mapping::get_or_use(balances, bid_out, 0u128) + amount_out_diff);
    }

    // Exchange a fixed amount of public input tokens for a variable amount of private output tokens.
    transition swap_exact_public_for_private(
        public token_in: field,
        public token_out: field,
        public amount_in: u128,
        public amount_out_min: u128,
        private to_pri: address,
        public to_pub: address,
     ) -> (PrivateToken) {
        assert(token_in != token_out);
        assert(amount_in > 0u128);

        let pt_out: PrivateToken = PrivateToken {
            owner: to_pri,
            token: token_out,
            amount: amount_out_min,
        };
        return pt_out then finalize(self.caller, token_in, token_out, amount_in, amount_out_min, to_pub);
    }

    finalize swap_exact_public_for_private(
        public caller: address,
        public token_in: field,
        public token_out: field,
        public amount_in: u128,
        public amount_out_min: u128,
        public to_pub: address,
    ) {
        let token_a: field = token_in < token_out ? token_in : token_out;
        let token_b: field = token_in < token_out ? token_out : token_in;
        let pid: field = get_pair_id(token_a, token_b);
        let pair: Pair = Mapping::get(pairs, pid);

        // calculate output amount
        let reserve_in: u128 = token_a == token_in ? pair.reserve_a : pair.reserve_b;
        let reserve_out: u128 = token_a == token_out ? pair.reserve_a : pair.reserve_b;
        let amount_in_with_fee: u128 = amount_in * 997u128;
        let amount_out: u128 = amount_in_with_fee * reserve_out / (reserve_in * 1000u128 + amount_in_with_fee);
        assert(amount_out >= amount_out_min);
        assert(amount_out > 0u128);

        // transfer input token
        let bid_in: field = get_balance_id(token_in, caller);
        Mapping::set(balances, bid_in, Mapping::get(balances, bid_in) - amount_in);

        // update pair
        let reserve_in_new: u128 = reserve_in + amount_in;
        let reserve_out_new: u128 = reserve_out - amount_out;
        Mapping::set(pairs, pid, Pair {
            reserve_a: token_a == token_in ? reserve_in_new : reserve_out_new,
            reserve_b: token_b == token_in ? reserve_in_new : reserve_out_new,
        });

        // transfer output token(minus the private part)
        let bid_out: field = get_balance_id(token_out, to_pub);
        let amount_out_diff: u128 = amount_out - amount_out_min;
        Mapping::set(balances, bid_out, Mapping::get_or_use(balances, bid_out, 0u128) + amount_out_diff);
    }

    // ========================= swap for exact =========================

    // Exchange a variable amount of public input tokens for a fixed amount of public output tokens.
    transition swap_tokens_for_exact_tokens(
        public token_in: field,
        public token_out: field,
        public amount_in_max: u128,
        public amount_out: u128,
        public to: address,
     ) {
        assert(token_in != token_out);
        assert(amount_out > 0u128);
        return then finalize(self.caller, token_in, token_out, amount_in_max, amount_out, to);
    }

    finalize swap_tokens_for_exact_tokens(
        public caller: address,
        public token_in: field,
        public token_out: field,
        public amount_in_max: u128,
        public amount_out: u128,
        public to: address,
    ) {
        let token_a: field = token_in < token_out ? token_in : token_out;
        let token_b: field = token_in < token_out ? token_out : token_in;
        let pid: field = get_pair_id(token_a, token_b);
        let pair: Pair = Mapping::get(pairs, pid);

        // calculate input amount
        let reserve_in: u128 = token_a == token_in ? pair.reserve_a : pair.reserve_b;
        let reserve_out: u128 = token_a == token_out ? pair.reserve_a : pair.reserve_b;
        let amount_in: u128 = reserve_in * amount_out * 1000u128 / ((reserve_out - amount_out) * 997u128) + 1u128;
        assert(amount_in <= amount_in_max);
        assert(amount_in > 0u128);

        // transfer input token
        let bid_in: field = get_balance_id(token_in, caller);
        Mapping::set(balances, bid_in, Mapping::get(balances, bid_in) - amount_in);

        // update pair
        let reserve_in_new: u128 = reserve_in + amount_in;
        let reserve_out_new: u128 = reserve_out - amount_out;
        Mapping::set(pairs, pid, Pair {
            reserve_a: token_a == token_in ? reserve_in_new : reserve_out_new,
            reserve_b: token_b == token_in ? reserve_in_new : reserve_out_new,
        });

        // transfer output token
        let bid_out: field = get_balance_id(token_out, to);
        Mapping::set(balances, bid_out, Mapping::get_or_use(balances, bid_out, 0u128) + amount_out);
    }

    // Exchange a variable amount of private input tokens for a fixed amount of public output tokens.
    transition swap_private_for_exact_public(
        private pt_in: PrivateToken,
        public token_out: field,
        public amount_in_max: u128,
        public amount_out: u128,
        public to: address,
        public refund_to: address,
     ) -> (PrivateToken) {
        let token_in: field = pt_in.token;
        assert(token_in != token_out);
        assert(amount_out > 0u128);

        // All amount_in_max is transferred, any excess will be returned in public
        let change_in: PrivateToken = PrivateToken {
            owner: pt_in.owner,
            token: token_in,
            amount: pt_in.amount - amount_in_max,
        };

        return change_in then finalize(token_in, token_out, amount_in_max, amount_out, to, refund_to);
    }

    finalize swap_private_for_exact_public(
        public token_in: field,
        public token_out: field,
        public amount_in_max: u128,
        public amount_out: u128,
        public to: address,
        public refund_to: address,
    ) {
        let token_a: field = token_in < token_out ? token_in : token_out;
        let token_b: field = token_in < token_out ? token_out : token_in;
        let pid: field = get_pair_id(token_a, token_b);
        let pair: Pair = Mapping::get(pairs, pid);

        // calculate input amount
        let reserve_in: u128 = token_a == token_in ? pair.reserve_a : pair.reserve_b;
        let reserve_out: u128 = token_a == token_out ? pair.reserve_a : pair.reserve_b;
        let amount_in: u128 = reserve_in * amount_out * 1000u128 / ((reserve_out - amount_out) * 997u128) + 1u128;
        assert(amount_in <= amount_in_max);
        assert(amount_in > 0u128);

        // refund input token
        let bid_refund: field = get_balance_id(token_in, refund_to);
        let refund_amount: u128 = amount_in_max - amount_in;
        Mapping::set(balances, bid_refund, Mapping::get_or_use(balances, bid_refund, 0u128) + refund_amount);

        // update pair
        let reserve_in_new: u128 = reserve_in + amount_in;
        let reserve_out_new: u128 = reserve_out - amount_out;
        Mapping::set(pairs, pid, Pair {
            reserve_a: token_a == token_in ? reserve_in_new : reserve_out_new,
            reserve_b: token_b == token_in ? reserve_in_new : reserve_out_new,
        });

        // transfer output token
        let bid_out: field = get_balance_id(token_out, to);
        Mapping::set(balances, bid_out, Mapping::get_or_use(balances, bid_out, 0u128) + amount_out);
    }

    // Exchange a variable amount of private input tokens for a fixed amount of private output tokens.
    transition swap_private_for_exact_private(
        private pt_in: PrivateToken,
        public token_out: field,
        public amount_in_max: u128,
        public amount_out: u128,
        private to_pri: address,
        public refund_to: address,
     ) -> (PrivateToken, PrivateToken) {
        let token_in: field = pt_in.token;
        assert(token_in != token_out);
        assert(amount_out > 0u128);
        let pt_out: PrivateToken = PrivateToken {
            owner: to_pri,
            token: token_out,
            amount: amount_out,
        };
        // All amount_in_max is transferred, any excess will be returned in public
        let change_in: PrivateToken = PrivateToken {
            owner: pt_in.owner,
            token: token_in,
            amount: pt_in.amount - amount_in_max,
        };
        return (pt_out, change_in) then finalize(token_in, token_out, amount_in_max, amount_out, refund_to);
    }

    finalize swap_private_for_exact_private(
        public token_in: field,
        public token_out: field,
        public amount_in_max: u128,
        public amount_out: u128,
        public refund_to: address,
    ) {
        let token_a: field = token_in < token_out ? token_in : token_out;
        let token_b: field = token_in < token_out ? token_out : token_in;
        let pid: field = get_pair_id(token_a, token_b);
        let pair: Pair = Mapping::get(pairs, pid);

        // calculate input amount
        let reserve_in: u128 = token_a == token_in ? pair.reserve_a : pair.reserve_b;
        let reserve_out: u128 = token_a == token_out ? pair.reserve_a : pair.reserve_b;
        let amount_in: u128 = reserve_in * amount_out * 1000u128 / ((reserve_out - amount_out) * 997u128) + 1u128;
        assert(amount_in <= amount_in_max);
        assert(amount_in > 0u128);

        // refund input token
        let bid_refund: field = get_balance_id(token_in, refund_to);
        let refund_amount: u128 = amount_in_max - amount_in;
        Mapping::set(balances, bid_refund, Mapping::get_or_use(balances, bid_refund, 0u128) + refund_amount);

        // update pair
        let reserve_in_new: u128 = reserve_in + amount_in;
        let reserve_out_new: u128 = reserve_out - amount_out;
        Mapping::set(pairs, pid, Pair {
            reserve_a: token_a == token_in ? reserve_in_new : reserve_out_new,
            reserve_b: token_b == token_in ? reserve_in_new : reserve_out_new,
        });

        // output token has been transferred privately
    }

    // Exchange a variable amount of public input tokens for a fixed amount of private output tokens.
    transition swap_public_for_exact_private(
        public token_in: field,
        public token_out: field,
        public amount_in_max: u128,
        public amount_out: u128,
        private to_pri: address,
     ) -> (PrivateToken) {
        assert(token_in != token_out);
        assert(amount_out > 0u128);
        let pt_out: PrivateToken = PrivateToken {
            owner: to_pri,
            token: token_out,
            amount: amount_out,
        };
        return pt_out then finalize(self.caller, token_in, token_out, amount_in_max, amount_out);
    }

    finalize swap_public_for_exact_private(
        public caller: address,
        public token_in: field,
        public token_out: field,
        public amount_in_max: u128,
        public amount_out: u128,
    ) {
        let token_a: field = token_in < token_out ? token_in : token_out;
        let token_b: field = token_in < token_out ? token_out : token_in;
        let pid: field = get_pair_id(token_a, token_b);
        let pair: Pair = Mapping::get(pairs, pid);

        // calculate input amount
        let reserve_in: u128 = token_a == token_in ? pair.reserve_a : pair.reserve_b;
        let reserve_out: u128 = token_a == token_out ? pair.reserve_a : pair.reserve_b;
        let amount_in: u128 = reserve_in * amount_out * 1000u128 / ((reserve_out - amount_out) * 997u128) + 1u128;
        assert(amount_in <= amount_in_max);
        assert(amount_in > 0u128);

        // transfer input token
        let bid_in: field = get_balance_id(token_in, caller);
        Mapping::set(balances, bid_in, Mapping::get(balances, bid_in) - amount_in);

        // update pair
        let reserve_in_new: u128 = reserve_in + amount_in;
        let reserve_out_new: u128 = reserve_out - amount_out;
        Mapping::set(pairs, pid, Pair {
            reserve_a: token_a == token_in ? reserve_in_new : reserve_out_new,
            reserve_b: token_b == token_in ? reserve_in_new : reserve_out_new,
        });

        // output token has been transferred privately
    }

    // ========================= inline =========================
    // Build a key of the mapping `balances`
    inline get_balance_id(token_id_: field, user_: address) -> field {
        // copy to avoid compiling error
        let token_id: field = token_id_;
        let user: address = user_;
        return BHP256::hash_to_field(BalanceKey {token_id, user});
    }

    // Build a key of the mapping `allowance`
    inline get_allowance_id(token_id_: field, payer_: address, spender_: address) -> field {
        let token: field = token_id_;
        let payer: address = payer_;
        let spender: address = spender_;
        // copy to avoid compiling error
        return BHP256::hash_to_field(AllowanceKeyData {token, payer, spender});
    }

    // Build the id of a pair
    inline get_pair_id(token_a_: field, token_b_: field) -> field {
        // copy to avoid compiling error
        let token_a: field = token_a_;
        let token_b: field = token_b_;
        assert(token_a < token_b);
        return  BHP256::hash_to_field(PairKeyData {token_a, token_b});
    }

    // sqrt for u128
    inline sqrt_u128(a: u128) -> u128 {
        if (a == 0u128) {
            return 0u128;
        }
        let result: u128 = 1u128.shl(log2(a) / 2u32);

        result = (result + a / result) >> 1u32;
        result = (result + a / result) >> 1u32;
        result = (result + a / result) >> 1u32;
        result = (result + a / result) >> 1u32;
        result = (result + a / result) >> 1u32;
        result = (result + a / result) >> 1u32;
        result = (result + a / result) >> 1u32;
        return min_u128(result, a / result);
    }

    // log2 for u128
    inline log2(value: u128) -> u32 {
        let result: u32 = 0u32;
        // if value >> 128u32 > 0u128 {
        //     value >>= 128u32;
        //     result += 12832;
        // }
        if value >> 64u32 > 0u128 {
            value >>= 64u32;
            result += 64u32;
        }
        if value >> 32u32 > 0u128 {
            value >>= 32u32;
            result += 32u32;
        }
        if value >> 16u32 > 0u128 {
            value >>= 16u32;
            result += 16u32;
        }
        if value >> 8u32 > 0u128 {
            value >>= 8u32;
            result += 8u32;
        }
        if value >> 4u32 > 0u128 {
            value >>= 4u32;
            result += 4u32;
        }
        if value >> 2u32 > 0u128 {
            value >>= 2u32;
            result += 2u32;
        }
        if value >> 1u32 > 0u128 {
            result += 1u32;
        }
        return result;
    }

    // min for u128
    inline min_u128(a: u128, b: u128) -> u128 {
        return a < b ? a : b;
    }

    transition test() -> bool {
        assert(1u8 == 1u8);
        return 1u8==1u8 then finalize();
    } 
    finalize test() {
        assert(1u8 == 2u8);
    }
}
