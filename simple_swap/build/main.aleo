program simple_swap.aleo;

struct BalanceKey:
    token_id as field;
    user as address;

record Token:
    owner as address.private;
    token_id as field.private;
    amount as u128.private;


mapping tokens:
	key left as field.public;
	value right as u128.public;



function create_token:
    input r0 as field.public;
    input r1 as u128.public;

    finalize r0 self.caller r1;

finalize create_token:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as u128.public;
    cast r0 r1 into r3 as BalanceKey;
    hash.bhp256 r3 into r4 as field;    contains tokens[r4] into r5;
    not r5 into r6;
    assert.eq r6 true;
    set r2 into tokens[r4];


function convert_public_token_to_private:
    input r0 as Token.record;
    input r1 as u128.private;
    add r0.amount r1 into r2;
    cast r0.owner r0.token_id r2 into r3 as Token.record;
    output r3 as Token.record;

    finalize r0.token_id self.caller r0.amount;

finalize convert_public_token_to_private:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as u128.public;
    cast r0 r1 into r3 as BalanceKey;
    hash.bhp256 r3 into r4 as field;    get.or_use tokens[r4] 0u128 into r5;
    sub r5 r2 into r6;
    set r6 into tokens[r4];


function convert_private_token_to_public:
    input r0 as field.private;
    input r1 as u128.private;
    cast self.caller r0 r1 into r2 as Token.record;
    output r2 as Token.record;

    finalize r0 self.caller r1;

finalize convert_private_token_to_public:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as u128.public;
    cast r0 r1 into r3 as BalanceKey;
    hash.bhp256 r3 into r4 as field;    get.or_use tokens[r4] 0u128 into r5;
    sub r5 r2 into r6;
    set r6 into tokens[r4];


function transfer_token_public:
    input r0 as field.private;
    input r1 as address.private;
    input r2 as u128.private;

    finalize r0 self.caller r1 r2;

finalize transfer_token_public:
    input r0 as field.public;
    input r1 as address.public;
    input r2 as address.public;
    input r3 as u128.public;
    cast r0 r1 into r4 as BalanceKey;
    hash.bhp256 r4 into r5 as field;    get.or_use tokens[r5] 0u128 into r6;
    gte r6 r3 into r7;
    assert.eq r7 true;
    sub r6 r3 into r8;
    set r8 into tokens[r5];
    cast r0 r2 into r9 as BalanceKey;
    hash.bhp256 r9 into r10 as field;    get.or_use tokens[r10] 0u128 into r11;
    add r11 r3 into r12;
    set r12 into tokens[r10];


function test:
    is.eq 1u8 1u8 into r0;
    assert.eq r0 true;
    is.eq 1u8 1u8 into r1;
    output r1 as boolean.private;

    finalize;

finalize test:
    is.eq 1u8 2u8 into r0;
    assert.eq r0 true;
