# DeFi Vectors: An Overview

DeFi Vectors represent a dynamic component within decentralized finance (DeFi), designed to streamline token transfers across various networks and applications. These vectors are characterized by their operational simplicity and flexibility, making them an essential tool for developers and Decentralized Autonomous Organizations (DAOs) in the realm of dApp tokenization.

## Core Components

- **Source Address**: Managed by a vector agent (canister), it acts as the starting point for token transfers.
- **Destination Address**: The endpoint for token transfers, which can be located anywhere and does not need to be under the control of the vector agent.

## Operation

Vectors are initially configured within the vector agent. To use vectors, a simple transfer of tokens to their source address is sufficient. Requires no additional communication for the tokens to be moved to the destination according to predefined rules. The process is automated, leveraging heartbeats or timers to facilitate the transfer, enabling:

- **Multiple Transactions**: Clients can send several transactions to the source address over extended periods.
- **Automated Scheduling and Splitting**: Tokens can be scheduled for transfer or split among different addresses, enhancing functionality for various applications such as scheduler agents or splitter agents.

## Integration and Benefits

Integrating DeFi Vectors is straightforward, involving a single `icrc1_transfer` for primary operation, with no need for additional interfaces. This simplicity ensures robustness and reliability in dApp tokenization, offering significant advantages:

- **Speeds Up Development**: Reduces the complexity and time required to develop dApps.
- **Bulletproof Tokenization**: Minimizes potential points of failure, ensuring seamless operation.

## Advanced Capabilities

- **Cross-Ledger and Network Transfers**: In theory with the same mechanism vectors can facilitate token transfers across different ledgers on the Internet Computer (IC) and between various networks, supported by technologies like t-ecdsa. They already support cross-chain ICRC ledgers like ckBTC and ckETH, however, they can also directly work with non-wrapped tokens.
- **Exchange Vectors**: Specialized vectors can be employed by Decentralized Exchanges (DEXs) for enhanced service provision.
- **Messaging and Transaction Log**: Communication between vectors, clients, and the ledger is streamlined through the use of ICRC standards, allowing for efficient transaction logging and one-way calls without the need for callbacks and without relying on the IC messaging system from functioning without any failed responses.


## DeVeFi Exchange Vector 

The dapp provides users (called architects) with the ability to create DeFi exchange vectors. These vectors have a source address in one ledger and a destination address in another. They are configured by the user and are permanent, which allows them to be used inside contracts and by DAOs. The configuration allows the vector to specify the price at which it will trade tokens in its source address. 

## Governed by Neutrinite DAO

Once deployed inside Neutrinite SNS DAO all upgrades are governed by the DAO ensuring only the DAO as a whole, can modify the exchange vector canister with proposals. NTN - the governance token was distributed through the NNS launchpad ensuring wide distribution and decentralization.

## Matching

Our dApp utilizes an internal matching system and avoids direct interaction with other DEXes, as achieving reliable communication with them is currently not feasible. Instead, it leverages arbitrage traders who configure their bots to bring liquidity from both centralized and decentralized exchanges.

Every 3 seconds the contract executes its matching function using one of the IC's unique features - timers, without the need for external calls. All vector trading algorithms get evaluated with the same inputs - time and pair price. This results in a temporary order book. The matching system finds the closest buy & sell orders and executes them. There are no takers or makers. The price at which the trade occurs is the average between a matched buy and sell order. This means that both vectors will get a match at the price they resulted in after evaluation or better than it. 

## Trading Fees

There are no trading fees except ledger transaction fees - usually around 0.001$ 

The vector one-time creation fee is 5NTN ( ~50$ )

## Oracle rates

The ICP and BTC exchange rates are sourced from the DeFi Aggregator, which is overseen by Neutrinite. This aggregator retrieves the rates from the Exchange Rate Canister (XRC), a system regulated by the NNS. The valuation of these cryptocurrencies is based on their pairing with the USD. Within the subnet hosting XRC, all nodes execute IC HTTP outcalls to various pricing APIs, ensuring robust data integrity. For consensus to be achieved, it is imperative that each node arrives at identical results from these API calls. Moreover, by aggregating prices from multiple sources, the system safeguards against manipulation, ensuring that neither individual nodes nor external data providers can influence the XRC unduly. This multi-source approach enhances the reliability and accuracy of the exchange rates provided.

To clarify, the ICP/BTC exchange rate is not derived from Internet Computer DEX pools featuring ICP and ckBTC pairings. Instead, it reflects the prevailing global market rate, encompassing both centralized exchanges and decentralized exchanges.

Related to other DEX traded SNS tokens: In the evolving landscape of decentralized exchanges within the Internet Computer ecosystem, especially for tokens that experience limited liquidity, it is advisable to maintain a minimal amount of tokens inside the tradable balance `max_tradable_usd` and to approach trading activities with caution, executing trades gradually. This strategy helps in navigating the relatively thin liquidity without causing significant market impact. The DeFi aggregator plays a pivotal role by sourcing prices from a variety of DEXes to ensure the provision of the most reliable rates. However, given the nascent stage of the ecosystem and the lack of standardization in price retrieval from DEXes, initiating exchange vectors among these tokens should be considered highly experimental. To further mitigate risks associated with potential market manipulation or disruptions in oracle price data, it's prudent to set a `max` rate threshold that guarantees a beneficial trade outcome under any market conditions.

## Exchange vector trade algorithm

### Algo V1

- `max` (Float) 
Vector won't trade at an exchange rate higher than this value

- `multiplier` (Float) 
The evaluated rate is equal to the oracle rate multiplied by this parameter. To trade at a 1% higher rate multiplier should be 1.01, to trade at a 1% lower rate it should be 0.99

- `multiplier_wiggle` (Float) and `multiplier_wiggle_seconds` (Float)
These parameters are optional and allow for dynamic adjustment of the rate through a fluctuation effect. These parameters influence the rate by applying a sine function to the difference between the current timestamp and the timestamp when the vector was created. By doing so, the rate experiences slight increases and decreases, which can facilitate trade matching by ensuring more favorable rates most of the time, yet still allowing for adjustments to accommodate market conditions. Setting both parameters to zero disables this fluctuation effect, resulting in a static rate. This feature is particularly useful for vectors aiming to subtly modify the trade price to enhance the likelihood of trade matches over time.
$$
\text{final\_wiggle\_multiplier} = \sin\left(\frac{\text{timestamp\_now} - vector.\text{timestamp\_created}}{6.28} \, / \, \min\left(1, \text{multiplier\_wiggle\_seconds}\right)\right) \times \text{multiplier\_wiggle}
$$


- Trade `rate` is calculated with the following formula

$$
\text{final\_multiplier} = \text{final\_wiggle\_multiplier} + \text{multiplier}
$$


$$
\text{rate} = \min\left(\text{max}, \text{marketRate} \times \text{finalMultiplier}\right)
$$



- Tradable balance dynamics

    Vectors facilitate a controlled release mechanism for tokens, transferring them from the source address balance to their tradable balance over time. This process ensures that only the tokens within the tradable balance are considered for order matching, thereby regulating market activity.

    - Interval Seconds (interval_seconds): This parameter specifies the frequency, in seconds, at which tokens are incrementally added to the tradable balance. It defines the pace at which the source balance is tapped into, ensuring a steady supply of tokens for trading activities.

    - Interval Release USD (interval_release_usd): This indicates the monetary value of tokens added to the tradable balance with each interval. It quantifies the influx of tokens into the market, aligning it with desired liquidity targets.

    - Maximum Tradable USD (max_tradable_usd): This cap determines the upper limit of tokens' monetary value that the tradable balance can hold at any given time

    These mechanisms work together to manage liquidity efficiently, allowing for a balanced and gradual introduction of tokens into the market. Their application extends to various strategic uses, such as facilitating dollar-cost averaging accumulation over extended periods, effectively acting as a purchase bot. Moreover, by controlling the release of tokens, these measures prevent market manipulation over short periods, thereby protecting system users from being misled into disadvantageous trades. This approach ensures a more stable and reliable trading environment, safeguarding against abrupt market fluctuations and potential exploitation.



    $$
    \text{new\_tradable\_balance} = \min\left(\text{current\_source\_balance}, \min\left(\text{tradable\_balance} + \frac{\text{interval\_release\_usd}}{\text{rate}}, \frac{\text{max\_tradable\_usd}}{\text{rate}}\right)\right)
    $$

    Furthermore, to prevent the initiation of numerous low-value trades where transaction fees could become disproportionately high, the vector automatically deactivates and halts trading activities if the tradable balance falls below a threshold of 300 times the ledger transaction fee. This measure ensures efficient and cost-effective trading operations.




## Enhanced Transaction Management System (ETMS)
This guide explains the operational framework of our module, focusing on transaction management. It highlights how the module simplifies and enhances transaction processing.

The system enhances the Internet Computer by introducing internal atomicity for the application, designating canisters as the sole authorities over their controlled tokens. This approach directly tackles the challenges posed by asynchronous communication, ensuring transactions within the canister achieve internal atomicity before syncing with the master ledger. 

## Key Features

- **Synchronous API over Asynchronous Operations**: Developers can interact with the middleware using a synchronous API, while the middleware handles the asynchronous intricacies of ICRC ledger communication.

- **Automatic Handling of Incoming and Outgoing Transfers**: Simplifies the process of monitoring and responding to ledger transactions, making it easier to manage DeFi canister states and balances.

- **Automated Notification on Transfer Receipts**:
Automatically get notified of incoming transfers, enhancing the responsiveness of your canister to ledger activities.
Without using this exact mechanism, to monitor thousands of addresses one would have to make thousands of calls every few seconds. Which would be impossible. Instead of doing that, we are following the ledger transaction history.

- **Reliable Token Sending with Asynchronous Confidence**:
Queue transactions securely and manage in-transit balances effectively, without worrying about asynchronous call complexities. The system makes sure transactions are sent by confirming them while following the ledger blockchain.
The system employs one-way calls for transactions, ensuring that developers don't need to manage confirmations manually. Transactions are retried automatically, leveraging deduplication techniques for efficiency and reliability. 

- **Synchronous Balance Queries**:
Retrieve canister account balances synchronously, factoring in in-transit amounts for accurate financial management.

This example showcases how to initialize the middleware, start it within an actor, and automatically respond to received transfers by sending tokens back to the sender.


#### Autonomous Transaction Finalization in Local Queues
Upon inclusion in the local queue, transactions attain a status of finality. This signifies that the module autonomously manages the dispatch process, obviating the need for developers to await confirmation.

#### Persistent Transaction Registration and Retry Mechanism
Persistently, the system endeavors to register the transaction within the ledger. Despite any initial failures, the mechanism is designed to attempt indefinitely until successful registration is achieved.

#### Sequential Order and Transaction Processing Limitations 
Furthermore, while the module efficiently processes transactions, it does not assure the preservation of their original sequential order.

#### Delayed Reflection of Transactions in Remote Ledger Balances
The act of queueing and locally finalizing transactions does not instantaneously reflect changes in the remote ledger's balances. These updates will materialize after a delay, as the system processes the transactions.

#### Determining Transaction Confirmations via Ledger Logs
Transaction confirmations are not reliant on callbacks but are determined by reading the ledger transaction log.

#### Impact of High Transaction Volumes on State Synchronization
If the ledger experiences high transaction volumes, leading to delays in reading or reduced sending capabilities, there may be a lag in the local state synchronization.

#### Performance Guarantees and Proper Use of Transaction Modules
The module's intended performance guarantees are contingent upon developers utilizing it exclusively for transactions, without bypassing its mechanisms (calling ledgers directly).

#### Deduplication and Transaction Window Management in Retry Functionality
The retry functionality incorporates deduplication, which requires precise implementation. If deduplication or the transaction log is not correctly implemented, the system may not function as expected. NNS ICRC ledgers and the ICP ledger work as expected, but other ledgers may not.

#### Retry Mechanism for Failed One-Way Transactions
Should a one-way transaction fail to send due to a network error, it will be retried in the subsequent cycle, occurring 2 seconds later. If the transaction is sent but fails to appear in the ledger, it will be retried after a 1-minute interval.

#### Initial System Activation and Transaction Reading Parameters
Upon initial activation, the system commences reading from a specified block (or the most recent one). Transactions predating this block are disregarded and will not be reflected in the local balances.

#### Managing Transaction Hooks During Canister Reinstallation
While reinstalling the canister is generally discouraged, should it become necessary under exceptional circumstances, it is crucial to ensure that all transaction hooks are meticulously managed to prevent them from processing the same events more than once.

#### System Resilience Against Canister and Ledger Disruptions
Following the provided installation guidelines ensures the system's resilience through canister upgrades, restarts, or stops, maintaining both its queue and balances intact. This robustness extends to scenarios where the ledger itself may cease operations or undergo upgrades, safeguarding against inaccuracies in local balances or issues with the transaction queue.

#### Retry Strategy and Timing Adjustments for Unregistered Transactions
The system will try to resend the transaction multiple times during the first ICRC1 `transactionWindowNanos` (Fixed currently at 24 hours). 

#### Balance Management and Transaction Dispatch Mechanism
When a transaction is enqueued, its amount is deducted from the balance. This process involves maintaining two figures: balance, which represents the actual balance, and in_transit, which tracks the amount being dispatched through outgoing transactions. This mechanism prevents the system from initiating multiple transactions without sufficient balance.


### Testing ETMS

Enhanced Transaction Management System was isolated inside DeVeFi ledger middleware and tested there. The mechanism is the same.

### Test - 1 - Dynamic Ledger Endurance Analysis

#### Methodology
We executed tests on a locally deployed ledger canister, specifically the latest one from the SNSW. The testing process involved receiving a large volume of tokens and dividing these by sending 10,000 transactions to various accounts. These recipient accounts then forwarded the transactions to other accounts until the transaction amount fell below the transaction fee. This strategy allowed us to initiate with sufficient tokens for 20,000 transactions and assess the total number of transactions successfully processed at the end of the test.

Throughout the testing phase, we frequently stopped and restarted both the test canister equipped with this library and the ledger itself. Additionally, we performed several upgrades to the test canister during the testing period. Despite these interruptions, our trials consistently showed that no transactions were lost, whether in the sending or receiving phases.

We further tested the system's resilience by intentionally causing the replica to generate errors during the sending process. These induced errors did not disrupt the queue's functionality.

#### Important Notice
This testing was conducted exclusively with NNS blessed ICRC ledger developed by Dfinity, excluding the ICP ledger due to its distinct transaction log structure. It is important to note that the performance and reliability observed may not directly translate to other ledgers. The functionality of this library is contingent upon two key features: deduplication and the get_transactions method, which are slated for replacement with the upcoming ICRC-3 protocol. For optimal performance, both features must operate flawlessly.

#### Throughput Per Ledger
Sending to Library Queue: Limited only by canister memory and instruction limits.
Sending from Queue to Ledger: ~45 tx/s 
Reading from Ledger: ~250 tx/s

### Test - 2 - Integrity Verification Protocol

#### Methodology

Execute 20,000 transactions (the ledger is configured to split the archive after every 10,000 transactions). Obtain a hash from all account balances owned by the canister. Reinstall the canister and start from block 0 (removing hooks). Generate a second hash and compare it to the first; the two hashes should match. Additionally, retrieve all accounts using the new accounts function and directly check their balances by calling the ledger. Compare both sets of balances to ensure they match. The library has passed this test multiple times.

### Testing DeViFi exchange vector

DeVeFi exchange vector has automated tests using Pocket IC. 
The test environment deploys:
- ckBTC (ICRC) ledger
- NTN (ICRC) ledger
- ICP ledger
- Defi aggregator mock canister
- DeVeFi exchange vector agent

The first test ensures that the entire system functions correctly: vectors are created, ledger indexing is operational, prices are retrieved, tokens are traded, transactions are logged, and the traded tokens reach their destination addresses. 

The second test initiates 1000 vectors, half of which are ICP->ckBTC and the other half ckBTC->ICP, all with variable pseudo-random algorithm parameters. The system then sends tokens to their source addresses and allows sufficient time for these vectors to find matches. The outcome is several thousand trade transactions that are deterministically snapshotted. Any alterations in the vector code algorithms will produce a different snapshot, triggering an alert to signal the change. Additionally, these snapshots can be scrutinized to verify that trades have occurred as expected.
