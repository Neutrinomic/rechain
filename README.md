# Rechain

This Motoko library serves as a middleware framework enabling the integration of blockchain functionalities directly into dApps on the IC. It aims to abstract the complexities involved in blockchain operations, such as block creation, transaction management, hashing, certification and archival processes, allowing developers to incorporate ledger functionalities with minimal overhead.

**Core Components and Functionalities:**

Reducer Pattern for State Management: Employs a reducer pattern to manage state transitions based on actions. This approach allows for a more structured and predictable state management process, crucial for maintaining the consistency of blockchain states. It will allow easy replaying of state.

Has a modified stable memory version of the Sliding Window Buffer (by Research AG)

Modularity and Extensibility: Designed with modularity at its core, the library allows developers to define custom actions, errors, and reducer functions.

Reducer Libraries: Developers can publish their reducers as libraries, enabling others to incorporate these libraries into their canisters for efficient remote state synchronization. This process involves tracking a remote ledger's transaction log and reconstructing the required state segments in their canisters. This mechanism facilitates the development of dApps that can in certain cases can do remotely atomic synchronous operations within asynchronous environments, similar to the DeVeFi Ledger Middleware's capabilities.

**Example 1 - Simple**

https://github.com/Neutrinomic/rechain_example

The provided example illustrates the use of the library in a token transfer system. It showcases the definition of actions for token transfers and minting, error handling mechanisms, and the implementation of reducer functions to manage the application's state. 

**Example 2 - Advanced - Ledger with ICRC1, ICRC3, ICRC4**
https://github.com/Neutrinomic/minimalistic_ledger


**Middleware (Alpha | POC | Untested):**
https://mops.one/rechain
https://github.com/Neutrinomic/rechain

**TODO:**
- Compliance with ICRC3
- Certification
- Creating & communicating with archive canisters

**ICRC-3 problems**
- (not using) Generic Values are hard to use and probably prone to errors. Our reducers will have to reduce Generic Values if we want to replay state. Motoko CDK could add support for these that won't result in bloated code at some point in the future. These also need a schema. Sounds like what Candid is supposed to do  https://forum.dfinity.org/t/icrc-3-draft-v2-and-next-steps/25132/3
- (currently using) Hashing Candid binary format has other problems, but these can be fixed by making Candid produce the same binary on different platforms or ignored if we restrict hash verification only to Motoko canisters https://forum.dfinity.org/t/icrc-3-draft-v2-and-next-steps/25132/6 


## Install
```
mops add rechain
```

## Usage



