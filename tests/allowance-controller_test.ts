import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
    name: "Allowance Controller: Test Grant Allowance",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const spender = accounts.get('wallet_1')!;
        
        const block = chain.mineBlock([
            Tx.contractCall(
                'allowance-controller', 
                'grant-allowance', 
                [
                    types.principal(spender.address), 
                    types.string('transfer'), 
                    types.uint(1000), 
                    types.none()
                ], 
                deployer.address
            )
        ]);

        // Verify successful allowance grant
        assertEquals(block.receipts[0].result, '(ok true)');
    }
});

Clarinet.test({
    name: "Allowance Controller: Test Consume Allowance",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const spender = accounts.get('wallet_1')!;
        
        // First, grant an allowance
        chain.mineBlock([
            Tx.contractCall(
                'allowance-controller', 
                'grant-allowance', 
                [
                    types.principal(spender.address), 
                    types.string('transfer'), 
                    types.uint(1000), 
                    types.none()
                ], 
                deployer.address
            )
        ]);

        // Then, consume the allowance
        const block = chain.mineBlock([
            Tx.contractCall(
                'allowance-controller', 
                'consume-allowance', 
                [
                    types.principal(deployer.address), 
                    types.string('transfer'), 
                    types.uint(250)
                ], 
                spender.address
            )
        ]);

        // Verify successful allowance consumption
        assertEquals(block.receipts[0].result, '(ok true)');
    }
});

Clarinet.test({
    name: "Allowance Controller: Test Modify Allowance",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const spender = accounts.get('wallet_1')!;
        
        // First, grant an initial allowance
        chain.mineBlock([
            Tx.contractCall(
                'allowance-controller', 
                'grant-allowance', 
                [
                    types.principal(spender.address), 
                    types.string('transfer'), 
                    types.uint(1000), 
                    types.none()
                ], 
                deployer.address
            )
        ]);

        // Then, modify the allowance
        const block = chain.mineBlock([
            Tx.contractCall(
                'allowance-controller', 
                'modify-allowance', 
                [
                    types.principal(spender.address), 
                    types.string('transfer'), 
                    types.uint(500), 
                    types.none()
                ], 
                deployer.address
            )
        ]);

        // Verify successful allowance modification
        assertEquals(block.receipts[0].result, '(ok true)');
    }
});