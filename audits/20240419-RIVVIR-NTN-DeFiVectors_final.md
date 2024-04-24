# DeFiVector Dapp - For NTN DAO

## Security Assessment

April 19th, 2024 - Final Report

Prepared By:
RIVVIR Tech, LLC, Austin Fatheree

### About RIVVIR Tech, LLC

RIVVIR Tech LLC is a Texas based company that provides technology consulting and engineering services.  Among other services, we perform security audits of MOTOKO based canisters and have an extensive history of building MOTOKO based canisters, participating on both sides of the security audit table, and have participated in ICRC Working Groups.  For information regarding our services, please reach out to austin at rivvir.com.

### Disclosure:

This security assessment was conducted within a specified timeframe and depended substantially on data furnished by the client, along with its affiliates and partners. Consequently, it's important to acknowledge that the insights presented in this report do not represent an exhaustive enumeration of all potential security vulnerabilities or anomalies within the evaluated system or codebase. This report highlights key findings as per the information available and the scope of the assessment during the conducted period. We make no warranties or guarantees about the efficacy or security of the audited contracts and these findings are provided as informational content only.  Clients must rely on their own judgment, implementation, and must make their own warranties and guarantees of their published code.

© 2024 by RIVVIR Tech, LLC

All rights reserved. RIVVIR Tech hereby asserts its right to be identified as the creator of this report in the United States, United Kingdom, EU, and Globally.

This report is considered by RIVVIR Tech to be business confidential information; it is licensed to the NTN DAO for informational purposes. Material within this report may not be reproduced or distributed in part or in whole without the express written permission of RIVVIR Tech LLC.

## Executive Summary

### Engagement Overview

NTN DAO engaged RIVVIR Tech LLC to review its DeFiVectors Back end Canister.  From March 19th to March 30th Austin Fatheree reviewed the contract, made suggestions, investigated the contract and produced a draft. Over the next weeks, NTN refactored codes based on our recommendation and the recommendation of other auditors.  On April 19th we evaluated the response of NTN to the original draft and updated our report.

### Project Scope

Our efforts were focused on identifying uneeded complexity, security issues, poor code quality, potential exploits, and other issues involved in the backend canister controlled by the NTN DAO that performs various DeFi operations based on the DeFi Vectors concept.

### Summary of Findings

The audit uncovered scalability and deadlock concerns that we feel need to be addressed and/or publicly justified by the team before moving forward with the deployment of the DeFi Vectors canister contract. These concerns are addressable and most high severity issues have to do with potential DoS or Cycle Drain attacks or Canister Deadlocks due to network outages. From our review, it appears the core logic of the canister is sound. NTN has provided test frameworks and we will analyzing those in a future report and they are not considered in this report.

Exposure Analysis

| Severity     | Count |
|--------------|-------|
| High         |      0|
| Medium       |      2|
| Low          |      6|
| Informational|      3|

Category Breakdown

| Category             | Count |
|----------------------|-------|
| Data Validation      |      1| 
| Memory Safety        |      1| 
| Denial of Service    |      4| 
| Complexity Management|      | 
| Data Handling        |      | 
| Auditing and Logging |      1|
| Code Standards       |      3|
| Data Integrity       |      |
| Privacy              |      2|

#### Notable Findings

Upon revision by NTN we have not identified any High Severity open items.  The remaining items either have plans in place to improve code quality, reporting, or are highly difficult issues to take advantage of. 

## Project Goals

Our goals in this project is to make sure that the NTN DeFi Vector canister does what it is intended to do. We want to:

- check motoko coding conventions and best practices
- address intercanister workflows
- identify exploits that would allow the stalling of the canister's workflows.
- identify potential cycle drain and DoS attacks.
- make sure upgrades work appropriately

## Project Targets

The initial Draft was performed against the commit c0ad67ed34b48c050176c6bd60394bb0f2969499 at github.com/Neutrinomic/defivectors. The final draft was completed against ef4bf03326af9df9feacdc94cc0eb1ee9ed6d397.

We audited the backend motoko files.  An audit of the web application was not done.

## Code Maturity

| Category                               | Summary| Result           |
|----------------------------------------|------------------------------------------------|------------------|
| Arithmetic                             | Mature. While the use of floating-point arithmetic introduces a risk of rounding errors, the project could benefit from a transition to fixed-point arithmetic to mitigate this risk.| Strong           |
| Auditing and Logging                               | Generally. The current implementation focuses on error logging with some logging for positive events. Implementing comprehensive logging for key state transitions, alongside error logging, is recommended to improve auditability and transparency.| Moderate         |
| Authentication / Access Controls       | Mature. The smart contract employs Principal-based access controls for critical functions, effectively managing access and permissions based on the caller's identity.| Strong         |
| Complexity Management                 | Mature. Overall there is deliberate reduction in complexity via seperation of concerns and workflow based modules. Staggered timer mechanism introduce unnecessary complexity. Simplifying this aspects and ensuring a robust timer initiation will help.| Strong           |
| Cryptography and Key Management        | Mature. The use of the Internet Computer's Principal and identity management infrastructure provides a solid foundation for secure interactions with the contract. However, the code review did not specifically target cryptographic operations, as these are largely abstracted by the platform.| Strong           |
| Data Handling                          | Mature. Sufficient data checks, storage, and data handling.             | Strong           |
| Documentation                          | Mature. The smart contract and associated types are well-documented within the codebase. However, there is room for improvement in documenting operational practices, especially concerning the handling of upgrades and migrations.| Strong           |
| Maintenance                            | Underdeveloped. The lack of a clear migration strategy and the presence of unused imports and references indicate potential challenges in maintaining and upgrading the contract. Implementing a migration framework and clean-up of unused code can improve long-term maintainability.| Moderate         |
| Memory Safety and Error Handling       | Errors are handled in both sync and async scenarios and memory overflow are handled.| Strong           |
| Testing and Verification               | Extensive integration tests were provided.  We had some platform dependent issues, running complete tests and would suggest tests be adjusted to be platform and cpu speed agnostic.                                                                                                                                 | Moderate             |

## Summary of findings


### Title: RVVR-VECTOR-6 - Potential Audit Data Missing

Finding ID: RVVR-VECTOR-6

Severity: Low

Difficulty: N/A

Type: Auditing and Logging

Target: [Github Code Reference](https://github.com/Neutrinomic/defivectors/blob/8f3055bd3e5537d4c1bbeb87e58d59b58f5bb0bd/src/types.mo#L197)

#### Description:

The contract may miss critical audit data, specifically the transaction ID from the remote ledger for transactions such as `#source_in`. Capturing and recording the transaction ID for operations handled by the contract provides precise traceability and may enhance interoperability with other services or debugging efforts.

#### Exploit Scenario:

Alice, a contract administrator, tries to correlate contract transactions with their corresponding entries in a remote ledger. Without recording remote ledger transaction IDs, Alice faces challenges in efficiently mapping contract operations to ledger entries, complicating audits and possibly impairing issue resolution or reconciliation processes.

#### Recommendations:

Incorporate storage of the transaction ID from the remote ledger within the contract's transaction-related records. This addition will empower administrators and users with better tracking abilities, enhancing the contract’s transparency and auditability. Specifically, upon receipt or sending of transactions, capture the remote ledger's transaction ID alongside the contract's internal record of the operation.

#### NTN Response:

> Scheduled for future improvements.

#### Response Evaluation:

We continue to recommend the inclusion of this data as soon as possible, but the outstanding issue does not contain any security related concerns.


### Title: RVVR-VECTOR-7 - Unnecessary Function and Potential Front Running Leak

Finding ID: RVVR-VECTOR-7

Severity: Medium

Difficulty: High

Type: Privacy

Target: [Github Code Reference](https://github.com/Neutrinomic/defivectors/blob/8f3055bd3e5537d4c1bbeb87e58d59b58f5bb0bd/src/types.mo#L280C17-L280C39), https://github.com/Neutrinomic/defivectors/blob/8f3055bd3e5537d4c1bbeb87e58d59b58f5bb0bd/src/types.mo#L272

#### Description:

The `getPrincipalSubaccount` function is included in the types file but is not utilized within the project, suggesting it should be removed. Additionally, the usage of a deterministic subaccount could expose a potential vector for front running if an attacker can monitor and anticipate it.

#### Exploit Scenario:

An attacker monitors the source address for activity right after a deposit is made. If the pattern of the deterministic subaccount generation is decoded, the attacker may manipulate trades or behaviors to their advantage, exploiting the known data.

#### Recommendations:

1. **Remove or Modify Unused Functions**: Consider removing the unused `getPrincipalSubaccount` function to clean up the codebase. For functions like `getDVectorSubaccount` that may expose the contract to front running risks:
   
   - Introduce randomness or complexity in determining the subaccount. This can make it more challenging for attackers to predict subaccounts.
   
   - Rotate subaccounts after each transaction using a nonce to keep the account random and one step ahead of potential attackers. Implement a dual-mode to have both a permanent and a random subaccount, allowing users to choose their security level.

2. **Implement Additional Security Measures**: Consider adding permissioned endpoints that can only be queried by the vector owner to reveal the next destination. This could mitigate risks associated with deterministic behavior and potential front-running.

Note: While the specific implementation of Vectors in this contract may not be directly affected, we include these recommendations for future planning and standardization purposes.

#### NTN Response:

The unused function was removed.

Concerning the remaining function

> Not sure it's worth trying to hide that if vectors are used as intended - slow long term accumulation and not instant large trades. Besides if it's an instant large trade, the attacker will have probably 2-3 sec to react before the canister finds the transaction and executes it

#### Response evaluation

We agree that the architecture of the DeFI vector alleviates some of the risk of this and that the opportunity window is small. This is still an outstanding issue and we recommend NTN provide information to system users informing them of the risks involved with divining potential market information from the behavior of consistently sub-accounted transactions.


### Title: RVVR-VECTOR-10 - Missing Fee could cause lost transactions

Finding ID: RVVR-VECTOR-10

Severity: Low

Difficulty: N/A

Type: Denial of Service

Target: [Github Code Reference](https://github.com/Neutrinomic/defivectors/blob/696560c480f7d1a39d6a0275e99d77391b742fe3/src/indexers/icrc.mo#L96)

#### Description:

The ICRC-3 standard and the Legacy Block standard generally require a fee to be present, but future ledger implementations that omit this requirement may cause the related code to exit prematurely with a null. The absence of a fee in such implementations could lead to transaction failures, impacting the contract's intended functionality.

#### Exploit Scenario:

A future version of a related ledger omits the requirement for a transaction fee, leading to a scenario where the absence of a fee causes the contract to exit out of processes prematurely. This could result in lost transactions and potential operational disruptions.

#### Recommendations:

Ensure robustness of the contract against future revisions of ledger standards by setting the transaction fee to 0 if a null value is encountered. This approach would mitigate the risk of lost transactions due to missing fee requirements in future ledger implementations.

#### NTN Response:

> Scheduled for future improvements.

#### Response Evaluation:

Until this item is fixed we suggest only allowing uses with ledgers that can be confirmed to always provide a fee.



### Title: RVVR-VECTOR-14 - Lack of Migration and Back Up Strategy

Finding ID: RVVR-VECTOR-14

Severity: Informational

Difficulty: N/A

Type: Code Standards

Target: Entire Contract (General Practice)

#### Description:

The contract does not include an explicit migration strategy, which could be essential in scenarios like attacks or unexpected malfunctions. Migration strategies are critical for ensuring data integrity and smooth transition during upgrades or in emergencies.

#### Exploit Scenario:

In the event of an attack or a major upgrade requirement, the absence of a migration strategy could lead to challenges in transferring state or data to a new version or instance of the contract, potentially resulting in data loss or extended downtime.

#### Recommendations:

- **Implement a Migration Framework**: Adopt a well-defined migration framework from the start of the project. Consider using existing solutions like [motoko-migrations](https://github.com/ZhenyaUsenko/motoko-migrations) as a basis for developing and managing migrations.
  
- **Plan for Emergency Migrations**: Develop emergency migration plans, including procedures for rapid state transfer in response to critical vulnerabilities or attacks. Ensure the plan includes roles, responsibilities, and step-by-step procedures.
  
- **Regularly Test Migrations**: Integrate migration testing into the development lifecycle to ensure that data and state can be moved accurately and completely. Use test environments to simulate various migration scenarios, including major upgrades and response to attacks.

- **Consider Data Backup**: Depending on the sensitivity of data and decentralization of the contract, consider backup functions that stream out current state so that, in an emergency or failed upgrade scenario, data can be recovered.

#### NTN Response:

> Scheduled for future improvements.

#### Evaluation Response

This remains an outstanding issue and we highly suggest a formal Migration Framework, Migration Plan, and Backup Plan.  At this time this issue poses no immediate security risk.



### Title: RVVR-VECTOR-15 - Unbounded Compute and Data Validation Concerns

Finding ID: RVVR-VECTOR-15

Severity: Medium

Difficulty: High - Expensive

Type: Memory Safety / Denial of Service

Target: Entire Contract (General Practice)

#### Description:

The `prepare_vectors` and `settle` processes contain potential unbounded computation cycles which could hit the cycle limit, potentially causing a Denial of Service. These processes do not chunk or progressively handle computations, leading to a lack of scalability.

#### Exploit Scenario:

An attacker could target the contract by creating a large number of vectors, pushing the computation beyond the cycle limit in the `prepare_vectors` or `settle` sections, effectively stalling these processes.

#### Recommendations:

Implement break conditions within loop iterations to prevent unbounded computation. Consider chunking or progressive computing to allow for fault tolerance and continued operation even under stress.

#### NTN Response:

>Vectors are expensive, it will be infeasible for an attacker to spam the system. 
>There is a performance monitor and with 1000 vectors cycle consumption was at 1% of the total allowed for the update call/timer 

#### Response Evaluation:

We agree that with the cost of the vector this is a highly unlikely attack. As the TVL locked into DeFi vectors increase we suggest reevaluating the potential for this attack to be executed.  1000 * 100 is only 100,000 and 100,000 * even a large value is well within the universe of DeFi valuations and TVL.  This issue does not expose a serious short term security risk, but should be monitored.


### Title: RVVR-VECTOR-17 - Cycle Drain via Unbounded Input

Finding ID: RVVR-VECTOR-17

Severity: Low

Difficulty: High

Type: Denial of Service

Target: 
- DVectorChangeRequest.destination#Set : Account - [Github Code Reference](https://github.com/Neutrinomic/defivectors/blob/696560c480f7d1a39d6a0275e99d77391b742fe3/src/types.mo#L71)
- DestinationEndpoint.address : Account - [Github Code Reference](https://github.com/Neutrinomic/defivectors/blob/696560c480f7d1a39d6a0275e99d77391b742fe3/src/types.mo#L33)
- withdraw_vector(arg.to) : [Github Code Reference](https://github.com/Neutrinomic/defivectors/blob/696560c480f7d1a39d6a0275e99d77391b742fe3/src/main.mo#L429)

#### Description:

The contract has a low public exposure footprint which is commendable. However, some inputs can be unbounded such as the 'Account' in several calls (see targets above), potentially allowing an attacker to drain cycles by uploading very large blobs. The 'withdraw_vector' function does not validate these potentially large, unbounded blobs leading to a cycle drain vulnerability.

#### Exploit Scenario:

An attacker could exploit these vulnerabilities by sending large, unbounded inputs in a subaccount which are not checked for validity, causing the canister to consume excessive cycles to process or store this data, ultimately draining the canister's resources.

#### Recommendations:

1. **Implement Input Validation**: For each of the targeted inputs, ensure there are checks in place to limit the size and structure of incoming data. This could include checking the length of blobs and rejecting requests that exceed reasonable limits.

2. **Use Inspect Message for Rate Limiting**: For ingress calls, apply the Inspect Message feature to establish rate limits on sensitive public functions, thereby preventing or mitigating DOS attacks from external entities.

3. **Review and Test Query Functions**: Although queries are free and not analyzed for vulnerabilities in this audit, it is advisable to review and prepare for the possibility of query charging being introduced. Ensure that expensive operations do not inadvertently become DOS vectors.

#### NTN Response

> Added checks for is_valid_account to public methods. Not implementing inspect message at this time.

#### Response evaluation

This generally addresses the concern.  Due to inter-canister calls not being checked by inspect message, the use of inspect message cannot prevent this behavior entirely.  Despite this we still recommend adding this check to make attacks from outside the Internet Computer harder.  We have downgraded the Severity to Low and the difficulty to high.

### Title: RVVR-VECTOR-18 - Minimum Fee should handle 0 fee ledgers

Finding ID: RVVR-VECTOR-18

Severity: Low

Difficulty: N/A

Type: Data Validation

Target: [Github Code Reference 1](https://github.com/Neutrinomic/defivectors/blob/696560c480f7d1a39d6a0275e99d77391b742fe3/src/main.mo#L438), [Github Code Reference 2](https://github.com/Neutrinomic/defivectors/blob/696560c480f7d1a39d6a0275e99d77391b742fe3/src/matching.mo#L79)

#### Description:

In scenarios where a ledger might offer 0 fee transactions, users could exploit this to spam the canister with numerous withdrawal requests that perform no action, leading to unnecessary strain on resources. Likewise, the `apply_active_rules` function could be influenced negatively by such zero-fee conditions.

#### Exploit Scenario:

An attacker takes advantage of a ledger that allows for zero-fee transactions to bombard the system with pointless withdrawal requests. This could cause unnecessary computational load or even obfuscate legitimate transactions amidst the noise.

#### Recommendations:

The contract should include conditional logic to set a minimum fee if the detected fee is 0 or if the ledger does not require a fee. This change ensures that the system remains robust against potential spam attacks stemming from zero-fee transactions. Consider making the multiplier or minimum fee a configurable variable, offering flexibility for adjustments based on the operational context and specific ledgers in use. This precaution ensures the contract retains resilience against various ledger configurations while maintaining service integrity and operational efficiency.

In addition to mitigating potential spam, careful consideration should be given to the `apply_active_rules` function within the `matching.mo` module, ensuring that it appropriately handles scenarios where transaction fees are nonexistent or minimal. This careful handling will help maintain the contract's intended functionality across diverse ledger environments, preserving the efficacy of vector operations and transaction handling within the system.

#### NTN Response:

> At this point we will be adding only SNS and CK ledgers, so that won't be a problem

#### Response Evaluation:

Given this presupposition there is no immediate security risk.  We suggest updating the logic at some point so that other tokens can be supported.

### Title: RVVR-VECTOR-19 - Memory Corruption Error Handling may stall canister

Finding ID: RVVR-VECTOR-19

Severity: Low

Difficulty: HIGH

Type: Denial of Service

Target: [Github Code Reference](https://github.com/Neutrinomic/defivectors/blob/696560c480f7d1a39d6a0275e99d77391b742fe3/src/architect.mo#L32C21-L32C32)

#### Description:

The `Architect.get_vectors` function contains several `trap` statements expected to catch moments when items are not found in their respective collections. Typically, using `trap` in libraries is advised against due to its harsh stopping of processing. This can lead to potential stalls in the canister, impacting overall reliability and usability.

#### Exploit Scenario:

During routine operation, if an item is sought but not present in the expected collections, the `trap` statement will halt the process. This abrupt stop can lead to cascading failures or halt the canister's functionality, requiring manual intervention to diagnose and restart operations.

#### Recommendations:

Consider returning a `Result<#ok,#err>` instead of using `trap`. This change allows calling functions the opportunity to handle the error according to the broader application context, increasing the robustness and reliability of the canister. 

- In cases where continuing despite missing items is acceptable, the function can simply log the issue to an error log and proceed with the process. This approach prevents complete stalls while still signaling an underlying issue that may need attention.

- If halting the canister is indeed the desired outcome upon such errors, better error reporting can facilitate quicker diagnostics and resolution. Providing detailed error messages or logging specific details about the failure context can help developers or maintainers address the issues more efficiently.

#### NTN Response:

>  Scheduled for future improvements

#### Response Evaluation:

The code quality of the DeFi vectors solution makes this an unlikely scenario to encounter.  As the system begins to reach a point where upgrades and manual type upgrades come into play, the risk will be increased and we suggest addressing this issue before that is necessary.

### Title: RVVR-VECTOR-20 - Floating Point Arithmetic Concerns

Finding ID: RVVR-VECTOR-20

Severity: Informational

Difficulty: N/A

Type: Coding Standards

Target: Entire Contract (General Practice)

#### Description:

The application utilizes floating-point arithmetic in various sections, which, while deterministic on the Internet Computer (IC), can introduce small but cumulative rounding errors and potentially lead to inaccuracy in numerical reporting. Floating-point operations might not always yield precise outcomes due to these inherent limitations, which could impact financial calculations or logic dependent on exact values.

#### Exploit Scenario:

N/A

#### Recommendations:

- **Adopt Fixed-Point Arithmetic**: Whenever possible, refactor the application to use fixed-point arithmetic. This involves multiplying values by a power of 10 to handle them as integers during all intermediary steps of a calculation, only converting back to a floating-point representation when necessary. This approach significantly reduces the potential for rounding errors and inaccuracies.

- **Review and Refactor Float Usage**: For specific cases where floating-point usage is unavoidable (such as trigonometric functions), carefully review the logic to minimize the number of operations that could amplify rounding errors. Convert these floating-point results back into fixed-point format as soon as possible to confine the potential error scope.

#### NTN Response:

> Maybe at some point it will be changed. We will calculate what is the loss here from rounding errors, but it seems to be less than 1$ for tens of thousands $ trades

#### Evaluation Response:

We understand the stance of the DAO and agree that the functional value may be small, but we maintain the suggestion to consider updating the arithmetic in the future.  Small values may not be consequential to traders, but the administrators supporting large DeFi systems built on this platform may encounter frustrating audit and administrative overhead if values do not tie off as expected.  This does not pose any significant security issues at small value denominations, but as the value of items traded increases the differences may grow or compound in unexpected ways.

### Title: RVVR-VECTOR-21 - Wiggle Manipulation

Finding ID: RVVR-VECTOR-21

Severity: Low

Difficulty: High

Type: Privacy

Target: [Github Code Reference](https://github.com/Neutrinomic/defivectors/blob/696560c480f7d1a39d6a0275e99d77391b742fe3/src/matching.mo#L50)

#### Description:

The calculation for the `wiggle` variable is directly dependent on `Time.now()`, which correlates to the block timestamp proposed by a block-producing node. This dependency introduces the possibility for a block producer to manipulate the timestamp to simulate various outcomes and optimize for a preferred result, such as achieving the highest bid in a transaction. While this risk is considered low on the Internet Computer, it could become a more serious issue if custom replica configurations are introduced.

#### Exploit Scenario:

A malicious or profit-maximizing block producer could manipulate the timestamp of blocks they produce, adjusting the `wiggle` variable calculation within the contract. By simulating different timestamps, the actor finds a preferred outcome that benefits them, potentially at the expense of other contract participants.

This is currently a low concern issue on the Internet Computer, but may become more serious if custom replicas emerge.

#### Recommendations:

1. Introduce an alternative source of randomness. A timer could be used to pull randomenss from the random beacon at regular intervals.

2. Ensure that the random adjustment of wiggle is in chunks large enough to lay outside of time manipulation of an expected maximum time for producing a block.

#### NTN Response:

>It will be left the way it is for now

#### Response Evaluation:

We suggest continuing to monitor and test of potential ways to predict the wiggle and determine if there is a valid security concern with the chosen randomness and wiggle method.

### Title: RVVR-VECTOR-23 - Unconfigurable Variables may complicate sending

Finding ID: RVVR-VECTOR-23

Severity: Informational

Difficulty: N/A

Type: Code Standards

Target: [Github Code Reference](https://github.com/Neutrinomic/defivectors/blob/696560c480f7d1a39d6a0275e99d77391b742fe3/src/sender.mo#L25)

#### Description:

Certain variables, such as the retry interval and the maximum number of sends per cycle within the sender module, are hardcoded into the contract, limiting flexibility. The ability to configure these variables might be crucial under varying network conditions or during operational tuning.

#### Exploit Scenario:

N/A

#### Recommendations:

- **Variable Configuration**: Transition hardcoded values to configurable parameters that can be updated by authorized parties. This enhancement provides flexibility in adjusting operational behaviors without requiring contract redeployment.
  
- **Management Interface**: Develop an administrative interface or set of management functions that allow authorized users to adjust these variables dynamically, in response to observed network conditions or performance metrics.

#### NTN Response:

> Scheduled for future improvement

#### Response Evaluation:

We suggest fixing this in a future release. There is no immediate security risk.


## Identified Issues that were addressed by NTN DAO.

The following issues were identified during our initial review of the canister code and are provided for informational purposes only as they may be instructive to other projects building on the Internet Computer.  NTN has addressed the threat of any security issues from the below listed items.

### Title: RVVR-VECTOR-1 - Transaction History Grows Unbounded

Finding ID: RVVR-VECTOR-1

Severity: Low

Difficulty: High - Expensive

Type: Memory Safety

Target: [Github Code Reference](https://github.com/Neutrinomic/defivectors/blob/8f3055bd3e5537d4c1bbeb87e58d59b58f5bb0bd/src/main.mo#L62C3-L62C56)

#### Description:

The contract's design allows the `_history_mem` variable, which stores transaction history, to grow unbounded. While it's unlikely that a vector will produce enough transactions to entirely fill available memory, the growth of this vector can degrade performance for operations that involve transaction history.

#### Exploit Scenario:

Bob uses the contract excessively, creating a large number of transactions. Over time, the `_history_mem` grows significantly, leading to decreased performance in operations scanning or utilizing this transaction history.

#### Recommendations:

Implement an archival strategy that maintains `_history_mem` at a manageable size. Older records not needed for active contract functionality could be moved to an archival canister or otherwise pruned from active memory, ensuring that the contract remains performant and within reasonable memory usage bounds. Documentation should caution future developers about the risks associated with large, unbounded vectors and recommend practices for managing or mitigating these risks.

#### NTN Response

Added a sliding window buffer strategy with a max history size of 200,000.

#### Response evaluation

This is a satisfactory response if the history is ultimately not important to have from an audit perspective.  We would advise documenting the archival strategy such that once a particular vector hits 200,000, the information is contained elsewhere(off chain is fine as most actionable items will have certifiable transaction ids held elsewhere.)


### Title: RVVR-VECTOR-2 - Staggered Timers May Not Stagger Correctly

Finding ID: RVVR-VECTOR-2

Severity: Low

Difficulty: Low

Type: Complexity Management

Target: [Github Code Reference](https://github.com/Neutrinomic/defivectors/blob/8f3055bd3e5537d4c1bbeb87e58d59b58f5bb0bd/src/main.mo#L158)

#### Description:

The code attempts to stagger the startup of internal timers by sequentially initiating each timer in a loop with a 1-second delay between each initialization. However, given the nature of the replica's processing rounds, there's no guarantee that such a delay will effectively distribute the timer starts across different rounds. This could potentially lead to the timers not being staggered as intended, which might affect performance or lead to unexpected behavior.

#### Exploit Scenario:

Upon canister initialization or upgrade, the developer intends for each component's timer to start in separate processing rounds for load distribution. However, due to the mechanics of the IC replica, two or more timers may end up starting in the same round, defeating the purpose of staggering and potentially causing performance bottlenecks.

#### Recommendations:

- If the intention behind staggering the timers is to distribute load, consider implementing a more robust mechanism that verifies the start of a timer in a new round before initiating the next one. This could involve state checks and explicit `await`s to ensure round transitions.
- If timer staggering is not crucial for the application's performance or correctness, simplifying the code to eliminate unnecessary complexity could be beneficial. Removing the staggering logic and starting all timers simultaneously will reduce code complexity and potential sources of bugs.
- Document the purpose behind timer staggering, including its benefits and limitations, to inform future development and maintenance efforts.

**Summary**: The current approach to staggering timer initialization may not achieve its intended effect due to the processing characteristics of the IC replica. A review and potential revision of the timer initiation strategy are recommended to ensure performance optimization and code simplicity.

#### NTN Response:

> Intentional, stays the way it is
?"Removing the staggering logic and starting all timers simultaneously will reduce code complexity and potential sources of bugs." 
> The timers weren't starting otherwise. For some reason we can only start 3 timers inside the actor body and the rest get ignored.

#### Response evaluation:

Given the technical limitations at the current moment, this response is satisfactory. We suggest coordinating with the motoko and replica team to determine why NTN is seeing this behavior.

### Title: RVVR-VECTOR-3 - Possible Deduplication Errors

Finding ID: RVVR-VECTOR-3

Severity: Medium

Difficulty: N/A

Type: Data Handling

Target: [Github Code Reference](https://github.com/Neutrinomic/defivectors/blob/8f3055bd3e5537d4c1bbeb87e58d59b58f5bb0bd/src/main.mo#L181)

#### Description:

The `icrc2_transfer_from` does not provide a `memo` or a `created_at_time`, which may cause two quickly succeeding requests for the same amount and with the same participants to fail due to potential deduplication errors.

#### Exploit Scenario:

Alice initiates two transfers in quick succession with the same amount to the same receiver. Without a unique `memo` or `created_at_time` for each transaction, the ledger may not be able to distinguish between the two, potentially rejecting the second as a duplicate.

#### Recommendations:

Incorporate a unique identifier for each transaction, such as increasing nonces or utilizing timestamps, within the `memo` field to ensure that each transfer is recognized as distinct by the ledger. This precaution helps prevent unintended transaction denials due to deduplication mechanisms.

#### NTN Response:

> According to ICRC1, if the create_at_time is null than deduplication is skipped

#### Response evaluation

We have confirmed the specification. As long as the create_at_time is specified as null, deduplication should not be performed.

### Title: RVVR-VECTOR-4 - Incorrect Account Label and Hardcoded Principals

Finding ID: RVVR-VECTOR-4

Severity: Low

Difficulty: N/A

Type: Code Standards

Target: [Github Code Reference 1](https://github.com/Neutrinomic/defivectors/blob/8f3055bd3e5537d4c1bbeb87e58d59b58f5bb0bd/src/main.mo#L31), [Github Code Reference 2](https://github.com/Neutrinomic/defivectors/blob/8f3055bd3e5537d4c1bbeb87e58d59b58f5bb0bd/src/rates.mo#L12C9-L12C65)

#### Description:

The contract code utilizes hard-coded principals for certain canisters, such as the government canister ID and the DEFI_AGGREGATOR canister. The use of hard-coded values, especially when mislabeled (e.g., a self-authenticating principal referred to as a canister principal), can lead to confusion and potential inefficiencies in managing connections and dependencies between canisters. Relying on hard-coded principals also lacks flexibility, making it difficult to respond to changes in underlying canisters without deploying a new version of the contract.

#### Exploit Scenario:

A developer might rely on the contract without realizing that the 'gov_canister_id' does not point to a canister but instead refers to a self-authenticating principal. This misunderstanding could lead to misconfiguration or misidentification of canister dependencies. Additionally, should the DEFI_AGGREGATOR canister need to be replaced or upgraded, the lack of a dynamic configuration mechanism would necessitate a contract update and redeployment, leading to potential service disruptions.

#### Recommendations:

- Relabel the variable if it does not represent a canister principal to avoid confusion.
- Convert hard-coded principals to stable variables that can be updated via configuration functions. This approach improves flexibility and maintainability, allowing administrators to update critical dependencies without necessitating a full contract redeployment.
- Implement validation checks to ensure provided principals adhere to expected formats and roles within the contract's ecosystem.

#### NTN Response:

Canister IDs were converted to configuration variables.

#### Response evaluation

The response satisfactorily relives issue.


### Title: RVVR-VECTOR-5 - Possible Data Loss Due to Non-Nullable Variants

Finding ID: RVVR-VECTOR-5

Severity: Medium

Difficulty: N/A

Type: Data Integrity

Target: [Github Code Reference 1](https://github.com/Neutrinomic/defivectors/blob/8f3055bd3e5537d4c1bbeb87e58d59b58f5bb0bd/src/types.mo#L90), [Github Code Reference 2](https://github.com/Neutrinomic/defivectors/blob/8f3055bd3e5537d4c1bbeb87e58d59b58f5bb0bd/src/types.mo#L192)

#### Description:

The project's data types utilize non-nullable variants, which may lead to a potential risk of data loss during upgrades. If a variant is removed and not handled properly, all associated data could be lost because of the upgrade process. The lack of nullable options for these variants further exacerbates this risk, as it offers no fallback mechanism for missing or removed data.

#### Exploit Scenario:

A future update to the contract removes or modifies one of the existing variants. Upon deploying the update, the associated data for any removed or improperly migrated variants is lost, impacting the application's data integrity and causing potential operational disruptions.

#### Recommendations:

Consider making variant types nullable by wrapping them in an optional type or implementing versioned types to manage upgrades more safely. This approach will provide a mechanism for preserving data integrity during contract updates. Additionally, document and implement rigorous upgrade testing protocols to simulate and evaluate the impact of changes to variant types on existing data. Establish development guidelines to avoid removing or significantly altering variants without a migration strategy to minimize data loss risks.

See example:
https://m7sm4-2iaaa-aaaab-qabra-cai.raw.ic0.app/?tag=3362168132


#### NTN Response:

Canister IDs were converted to configuration variables.

>Good idea, but they wont be modified or removed, only new will be added

#### Response evaluation

The response shows clear understanding of the issue and conscious choice to move forward with proper code hygiene in place.  This issue poses no security risk.



### Title: RVVR-VECTOR-8 - Potential Deadlock in Loop via Assert Statement

Finding ID: RVVR-VECTOR-8

Severity: High

Difficulty: N/A

Type: Denial of Service

Target: [Github Code Reference](https://github.com/Neutrinomic/defivectors/blob/8f3055bd3e5537d4c1bbeb87e58d59b58f5bb0bd/src/matching.mo#L66C33-L66C98)

#### Description:

The assert statement within the loop of the preparation function may lead to a potential deadlock scenario, halting further processing of vectors. The existence of a condition where `v.source_balance_tradable` exceeds `v.source_balance_available` triggers an assert that could interrupt the entire function's execution, preventing the processing of subsequent vectors. 

#### Exploit Scenario:

During normal operation, a vector's tradable balance exceeds its available balance due to an unforeseen bug or incorrect balance update. This results in the assert condition being hit, causing the function to exit early and halting the processing of any vectors that follow in the sequence. This could potentially lock the contract's functionality, preventing the processing of all vectors until manual intervention is performed.

#### Recommendations:

Replace the `assert` statement with a control flow statement such as `if(...) continue preparation;`, ensuring that the loop can skip over problematic vectors while allowing further processing of other vectors. This approach increases the robustness of the contract's processing loop and avoids a complete halt in operations due to single case failures.

#### NTN Response:

Commit 200cc9973f995264b4486886a020939ff7599494

#### Response evaluation

The response satisfactorily relives issue.

### Title: RVVR-VECTOR-9 - Array Use Instead of Vector for Unconfirmed Transactions

Finding ID: RVVR-VECTOR-9

Severity: Low

Difficulty: N/A

Type: Memory Safety

Target: [Github Code Reference](https://github.com/Neutrinomic/defivectors/blob/8f3055bd3e5537d4c1bbeb87e58d59b58f5bb0bd/src/matching.mo#L256)

#### Description:

The contract uses arrays to manage `unconfirmed_transactions`, which could grow indefinitely. The choice of arrays over vectors in this context might lead to performance degradation as arrays have linear complexity for append operations. This is particularly concerning if a malfunction on a remote ledger results in a significant accumulation of transactions.

#### Exploit Scenario:

Suppose a remote ledger begins to delay or fail in confirming transactions consistently. In that case, the `unconfirmed_transactions` array may rapidly grow as new transactions continue to be appended, causing increased memory usage and degraded performance of the contract, potentially leading to delays or failures in transaction processing.

#### Recommendations:

- **Transition to Vector**: Consider refactoring the use of arrays for managing `unconfirmed_transactions` to vectors. Vectors offer better performance for append operations, especially when dealing with a potentially unbounded set of items.
  
- **Implement Monitoring and Alerts**: Establish monitoring for the size of the `unconfirmed_transactions` collection. If the collection size exceeds a predefined threshold, trigger alerts for manual inspection or automated handling.

#### NTN Response:

Code Updated:

```
if (vector.unconfirmed_transactions.size() > 10) return #err("too many unconfirmed transactions");
```

> when trading the minimum amount has been increased to 300 times the ledger fee, this will make it harder for someone to intentionally abuse it


#### Response Evaluation:

This satisfactorily relieves the issue.


### Title: RVVR-VECTOR-11 - XRC Not Used and Hardcoded Principals

Finding ID: RVVR-VECTOR-11

Severity: Low

Difficulty: N/A

Type: Code Standards

Target: [Github Code Reference](https://github.com/Neutrinomic/defivectors/blob/696560c480f7d1a39d6a0275e99d77391b742fe3/src/main.mo#L11)

#### Description:

The contract includes references and imports related to the XRC standard but does not utilize them in any functional part of the code. Moreover, the contract contains hardcoded principals for certain canisters, which could limit flexibility and adaptability in different environments or use cases.

#### Exploit Scenario:

A new developer reviewing the contract for extension or maintenance might be misled by the presence of XRC references, expecting related functionalities to be present or to be implemented. The use of hardcoded principals would necessitate contract updates to maintain accuracy with external changes, thus creating unnecessary maintenance overhead.

#### Recommendations:

- **Code Clean-up**: Remove unused imports and references, such as those related to the XRC standard, to avoid confusion and to streamline the contract code.


#### NTN Response:

Code Updated:

```
if (vector.unconfirmed_transactions.size() > 10) return #err("too many unconfirmed transactions");
```

> fixed, references removed


#### Response Evaluation:

This satisfactorily relieves the issue.




### Title: RVVR-VECTOR-12 - Upgrading ledger or network congestion may lead to loss of payment upon vector creation

Finding ID: RVVR-VECTOR-12

Severity: High

Difficulty: Low

Type: Denial of Service

Target: [Github Code Reference](https://github.com/Neutrinomic/defivectors/blob/696560c480f7d1a39d6a0275e99d77391b742fe3/src/main.mo#L336)

#### Description:

The `create_vector` endpoint charges users for the creation of a vector in either ICP or NTN. After payment, a vector is created, but two variables depend on awaiting a call to a ledger. These awaits occur after the payments and any failure in one or the other will cause a trap, rolling back the transaction with the vector not created.

#### Exploit Scenario:

Alice tries to create a vector and pays the required fee in ICP. However, due to network congestion or the ledger canister upgrading, a subsequent await call for ledger meta data fails, resulting in the entire transaction being rolled back. Alice loses the fee paid without the vector being created, as the payment is not refunded.

#### Recommendations:

Create the vector in a locked state (or give ownership to the canister), then charge the customer. If the payments fail, you can delete the vector, and if it succeeds, unlock the vector. Surround the charges with try/catch to capture network or canister status errors and handle them appropriately without losing the payment or vector creation.

#### NTN Response

>The two queries after charging were removed (in another commit), they were for debug purposes

#### Response evaluation

The response satisfactorily relives issue.


### Title: RVVR-VECTOR-13 - Upgrading ledger or network congestion may lead to failure of metadata retrieval timers

Finding ID: RVVR-VECTOR-13

Severity: High

Difficulty: Low

Type: Denial of Service

Target: [Github Code Reference](https://github.com/Neutrinomic/defivectors/blob/696560c480f7d1a39d6a0275e99d77391b742fe3/src/ledgermeta.mo#L16)

#### Description:

The LedgerMeta retrieval process does not account for failed attempts to fetch data due to network issues, ledger upgrades, or other transient errors. This lack of error handling could cause the metadata retrieval timers to fail, potentially leaving the contract without crucial ledger metadata indefinitely.

#### Exploit Scenario:

Consider a scenario where the ledger is temporarily unavailable due to an upgrade when a metadata retrieval attempt is made. The lack of a fallback or retry mechanism means the retrieval process halts, preventing future updates to ledger metadata that could be necessary for correct contract functionality.

#### Recommendations:

Implement a robust error-handling mechanism for metadata retrieval operations. This could include:

- Utilizing `try`/`catch` structures to handle exceptions during ledger interaction, ensuring the system remains operational even in the face of transient ledger or network issues.

#### NTN Response

Commit: 8ba57d94a2d256fe4cfb8db7620533f2c96aabe9

#### Response evaluation

The response satisfactorily relives issue.


### Title: RVVR-VECTOR-16 - Possible to Clear Inflight Vector

Finding ID: RVVR-VECTOR-16

Severity: Medium

Difficulty: N/A

Type: Data Validation

Target: [Github Code Reference](https://github.com/Neutrinomic/defivectors/blob/696560c480f7d1a39d6a0275e99d77391b742fe3/src/main.mo#L225)

#### Description:

The contract provides a functionality to clear a vector, which might be misused or misunderstood. The clear function, as implemented, lacks the robust business logic checks applied when setting a vector, which could lead to unintended situations where funds may be lost. This raises concerns about the clarity and safety of the operation, especially considering its implications on user funds and vector integrity.

#### Exploit Scenario:

An unsuspecting user, attempting to modify a vector's destination or properties, might use the clear function without realizing it could potentially interfere with inflight transactions or allocated funds. This could inadvertently lead to loss of access to the funds or at least uncertainty about the funds' status.

#### Recommendations:

If the intention behind providing the clear functionality is to serve as a recovery or emergency mechanism, it would be prudent to rename it to `#unsafe_clear` to more accurately reflect its implications and risks. This nomenclature change would alert users to the potential dangers associated with its invocation.

Furthermore, if the clear function serves as a regular operational utility for users, it is crucial to extend the same level of business logic verification and safeguards as provided for setting a vector. This ensures consistent safety measures across the contract's operations, reducing the risk of unintended consequences. 

Lastly, consider introducing a test case that demonstrates the situation where funds could potentially be lost through the misuse of this function. Such a test would serve not only as a safeguard for future development but also as a form of documentation, highlighting specific pitfalls to be avoided by users and developers alike.

#### NTN Response:

>When #cleared funds won't be lost. The funds are already in a remote destination address and the canister doesn't control these accounts. The queued transactions already have a copy of the destination address and they won't be affected

#### Evaluation Response:

This logic clears up confusion about the process and satisfies the concern.

### Title: RVVR-VECTOR-22 - Positive Logging

Finding ID: RVVR-VECTOR-22

Severity: Informational

Difficulty: N/A

Type: Code Standards

Target: Entire Contract (General Practice)

#### Description:

The current implementation logs errors but lacks a structured approach towards logging positive state changes and significant events. Implementing a comprehensive logging strategy for both negative and positive events could enhance the auditability and transparency of the contract. This is especially relevant under circumstances where unexpected canister states emerge.

#### Exploit Scenario:

N/A

#### Recommendations:

- **Implement Comprehensive Logging**: Integrate logging for key state transitions and significant events alongside error logging. This could provide a more complete picture of the contract's operation over time, facilitating debugging, audits, and operational oversight.
  
- **Consider Public and Private Logs**: Utilize an ICRC-3 transaction log for public events to leverage the transparent nature of blockchain technology. For sensitive data or operations, implement a private log accessible only to contract administrators or authorized parties.

#### NTN Response:

>Added vector create event, will add more in the future. Some events cant be added if we want to have vector algos private

#### Response Evaluation:

The additional logging should help and we understand the privacy concerns.  We consider this concern addressed.


### Title: RVVR-VECTOR-24 - Lack of Rate Limiting on Public Functions

Finding ID: RVVR-VECTOR-24

Severity: Informational

Difficulty: N/A

Type: Denial of Service

Target: Public Functions (`create_vector`, `modify_vector`, `withdraw_vector`)

#### Description:

Public functions within the contract, such as `create_vector`, `modify_vector`, and `withdraw_vector`, do not incorporate rate limiting controls. This omission could expose the contract to resource exhaustion attacks or other forms of abuse, aiming to degrade contract performance or availability.

#### Exploit Scenario:

An attacker floods the contract with high volumes of calls to these public functions, consuming significant computational resources and potentially disrupting service for legitimate users.

#### Recommendations:

- **Implement Rate Limiting**: Institute rate-limiting checks within these functions to prevent abuse. 
  
- **Use Inspect Message for Rate Limiting**: Leveraging the `Inspect Message` feature grants the ability to evaluate and throttle requests before they're executed, providing an additional layer of defense against DoS attacks from external ingress attacks. Note this will not deter attacks from other canisters.

- **Monitor and Alert**: Establish monitoring on the frequency and volume of requests to sensitive public functions. Implement alerting mechanisms to notify administrators of potential abuse patterns, enabling rapid response.

#### NTN Response:

> `withdraw` has max 10 withdrawls per vector, `create` costs a lot, modify vector - yes, good catch, we will add rate limit allowing only one modification per N seconds

#### Response Evaluation

This response satisfies the security concerns.
