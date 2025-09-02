# Vault & Roles: A Dynamic On-Chain Identity Protocol

[](https://opensource.org/licenses/MIT)
[](https://github.com/)
[](https://soliditylang.org/)

This project introduces a novel smart contract system that merges a secure, time-locked `Vault` with a dynamic, on-chain `RoleManager`. Users are programmatically granted roles based on their deposit behavior, creating a decentralized and automated on-chain reputation system. The protocol leverages **Chainlink Automation** to manage temporary roles, ensuring the system remains self-sustaining and efficient.

## ✨ Core Concepts

The protocol is built on a simple yet powerful premise: your on-chain actions define your on-chain identity. Instead of relying on admins to grant permissions, this system does so automatically based on transparent rules.

### The Vault Mechanism

The `Vault` is a straightforward, non-custodial contract where users can lock ETH for predefined periods (6 months, 1 year, or 5 years). This isn't about generating yield; it's about demonstrating commitment to the ecosystem. By locking funds, users signal their long-term belief and are rewarded with a corresponding status.

### Dynamic & Programmatic Roles

This is the core of the protocol's logic. The `RoleManager` contract, inherited by the `Vault`, assigns roles based on a user's deposit amount, lock duration, and frequency of interaction. Roles are not just labels; they are verifiable on-chain credentials.

### Decentralized Automation with Chainlink

To manage temporary roles without centralized intervention, the protocol integrates **Chainlink Automation (Keepers)**. The `checkUpkeep` function periodically scans for users whose temporary roles have expired. If conditions are met, `performUpkeep` is automatically called to revoke the role, creating a fully decentralized and reliable lifecycle for on-chain status.

-----

## 🏆 The Roles

Roles are granted to users who meet specific criteria, creating a clear hierarchy of community members.

| Role | Badge | Criteria for Obtaining |
| :--- | :--- | :--- |
| **`LONG_TERM_WHALE`** | 🐋 | Deposit **≥ 1 ETH** for **5 years**. |
| **`FREQUENT_WHALE`** | 🐳 | Make **≥ 3 deposits** of **≥ 1 ETH** each. |
| **`BIG_DEPOSITOR`** | 💰 | Make a single deposit of **≥ 5 ETH**. |
| **`TEMP_BIG_FAN`** | 🔥 | A temporary role for active users who make smaller deposits. It encourages consistent engagement and is automatically managed by Chainlink Automation. |

-----

## 🚀 Future Potential & Extensibility

This protocol is designed as a foundational layer for a much larger ecosystem. The on-chain roles can be used as building blocks for a wide range of features:

  * **Token-Gated Access:** Use roles to grant access to exclusive Discord channels, forums, or even other dApps and DAO governance platforms.
  * **NFT & Airdrop Rewards:** Automatically mint and distribute unique NFTs or airdrop tokens to users who achieve high-tier roles like `LONG_TERM_WHALE`.
  * **DeFi Integration:** The locked funds in the vault could be routed to blue-chip lending protocols like Aave or Compound to generate yield for the depositors or the protocol's treasury.
  * **Advanced Gamification:** Introduce more complex roles, "prestige" levels for users who hold multiple roles, and on-chain quests to unlock new statuses.
  * **Web3 Social & Community Building:** Build a frontend that visualizes user roles, creating a social platform where reputation is earned, not given.

-----

## 🛠️ Getting Started (For Developers)

This project is built with [**Foundry**](https://github.com/foundry-rs/foundry).

### Prerequisites

  - [Foundry](https://getfoundry.sh/)

### Installation & Setup

1.  **Clone the repository:**

    ```bash
    git clone <YOUR_REPO_URL>
    cd <YOUR_REPO_DIRECTORY>
    ```

2.  **Install dependencies:**

    ```bash
    forge install
    ```

### Core Commands

  * **Compile Contracts:**
    ```bash
    forge build
    ```
  * **Run Tests:**
    ```bash
    forge test
    ```
  * **Deploy:**
    The project includes deployment scripts in the `script/` directory. Deploy the `Vault` contract using:
    ```bash
    forge script script/DeployVault.s.sol --rpc-url <YOUR_RPC_URL> --private-key <YOUR_PRIVATE_KEY> --broadcast
    ```

## 📜 License

This project is licensed under the **MIT License**. See the `LICENSE` file for details.