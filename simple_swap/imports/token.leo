// The `program` scope defines the data types, functions, and state associated with the `Token` program.
program Token.aleo {
    // On-chain storage of an `account` map, with `address` as the key,
    // and `u128` as the value.
    mapping account: address => u128;
    mapping tokens: field => u128;

    struct BalanceKey {
        Token_id: u128,
        user: address,
    }

    record Token {
        // Token id
        id: u128,
        // The Token owner.
        owner: address,
        // The Token amount.
        amount: u128,
    }

    /* Mint */
    // The function `mint_public` issues the specified Token amount for the Token receiver publicly on the network.
    transition mint_public(public receiver: address, public amount: u128) {
        // Mint the Tokens publicly by invoking the computation on-chain.
        return then finalize(receiver, amount);
    }

    finalize mint_public(public receiver: address, public amount: u128) {
        // Increments `account[receiver]` by `amount`.
        // If `account[receiver]` does not exist, it will be created.
        // If `account[receiver] + amount` overflows, `mint_public` is reverted.
        let receiver_amount: u128 = Mapping::get_or_use(account, receiver, 0u128);
        Mapping::set(account, receiver, receiver_amount + amount);
    }

    // The function `mint_private` initializes a new record with the specified amount of Tokens for the receiver.
    transition mint_private(receiver: address, amount: u128) -> Token {
        return Token {
            owner: receiver,
            amount: amount,
        };
    }

    /* Transfer */
    transition transfer_public(public receiver: address, public amount: u128) {
        // Transfer the Tokens publicly, by invoking the computation on-chain.
        return then finalize(self.caller, receiver, amount);
    }

    finalize transfer_public(public sender: address, public receiver: address, public amount: u128) {
        // Decrements `account[sender]` by `amount`.
        // If `account[sender]` does not exist, it will be created.
        // If `account[sender] - amount` underflows, `transfer_public` is reverted.
        let sender_amount: u128 = Mapping::get_or_use(account, sender, 0u128);
        Mapping::set(account, sender, sender_amount - amount);
        
        // Increments `account[receiver]` by `amount`.
        // If `account[receiver]` does not exist, it will be created.
        // If `account[receiver] + amount` overflows, `transfer_public` is reverted.
        let receiver_amount: u128 = Mapping::get_or_use(account, receiver, 0u128);
        Mapping::set(account, receiver, receiver_amount + amount);
    }

    // The function `transfer_private` sends the specified Token amount to the Token receiver from the specified Token record.
    transition transfer_private(sender: Token, receiver: address, amount: u128) -> (Token, Token) {
        // Checks the given Token record has sufficient balance.
        // This `sub` operation is safe, and the proof will fail if an overflow occurs.
        // `difference` holds the change amount to be returned to sender.
        let difference: u128 = sender.amount - amount;

        // Produce a Token record with the change amount for the sender.
        let remaining: Token = Token {
            owner: sender.owner,
            amount: difference,
        };

        // Produce a Token record for the specified receiver.
        let transferred: Token = Token {
            owner: receiver,
            amount: amount,
        };

        // Output the sender's change record and the receiver's record.
        return (remaining, transferred);
    }

    // The function `transfer_private_to_public` turns a specified Token amount from a Token record into public Tokens for the specified receiver.
    // This function preserves privacy for the sender's record, however it publicly reveals the Token receiver and the Token amount.
    transition transfer_private_to_public(sender: Token, public receiver: address, public amount: u128) -> Token {
        // Checks the given Token record has a sufficient Token amount.
        // This `sub` operation is safe, and the proof will fail if an underflow occurs.
        // `difference` holds the change amount for the caller.
        let difference: u128 = sender.amount - amount;

        // Produces a Token record with the change amount for the caller.
        let remaining: Token = Token {
            owner: sender.owner,
            amount: difference,
        };

        // Output the sender's change record.
        // Increment the Token amount publicly for the Token receiver.
        return remaining then finalize(receiver, amount);
    }

    finalize transfer_private_to_public(public receiver: address, public amount: u128) {
        // Increments `account[receiver]` by `amount`.
        // If `account[receiver]` does not exist, it will be created.
        // If `account[receiver] + amount` overflows, `transfer_private_to_public` is reverted.
        let receiver_amount: u128 = Mapping::get_or_use(account, receiver, 0u128);
        Mapping::set(account, receiver, receiver_amount + amount);
    }

    // The function `transfer_public_to_private` turns a specified Token amount from `account` into a Token record for the specified receiver.
    // This function preserves privacy for the receiver's record, however it publicly reveals the caller and the specified Token amount.
    transition transfer_public_to_private(public receiver: address, public amount: u128) -> Token {
        // Produces a Token record for the Token receiver.
        let transferred: Token = Token {
            owner: receiver,
            amount: amount,
        };

        // Output the receiver's record.
        // Decrement the Token amount of the caller publicly.
        return transferred then finalize(self.caller, amount);
    }

    finalize transfer_public_to_private(public sender: address, public amount: u128) {
        // Decrements `account[sender]` by `amount`.
        // If `account[sender]` does not exist, it will be created.
        // If `account[sender] - amount` underflows, `transfer_public_to_private` is reverted.
        let sender_amount: u128 = Mapping::get_or_use(account, sender, 0u128);
        Mapping::set(account, sender, sender_amount - amount);
    }
}
