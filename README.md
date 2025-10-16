# Simple ETH Staking Protocol

A straightforward and secure staking protocol where users can stake ETH and earn ERC20 token rewards based on time and amount staked.

## 🎯 Protocol Overview

This protocol allows users to:

- Stake ETH and earn ERC20 token rewards
- Earn rewards proportional to their staked amount and time
- Flexible withdrawal options (partial or full)
- Claim rewards without unstaking

**Key Feature:** Uses a checkpoint mechanism to ensure fair reward distribution when users stake multiple times.

---

## 📊 Core Mechanics

### Reward Calculation

- **APY-based**: Rewards calculated as Annual Percentage Yield (configurable by owner)
- **Formula**: `rewards = (stakedAmount × timeStaked × annualRewardPercent) / (100 × SECONDS_PER_YEAR)`
- **Example**: Stake 10 ETH for 1 year at 10% APY = 1 ETH worth of reward tokens

### Checkpoint System (The Key Innovation)

**Problem Solved:**
If a user stakes 1 wei for 364 days, then stakes 10 ETH, they shouldn't get 10 ETH worth of rewards for the entire period—that would be unfair!

**Solution:**
Every time a user interacts (stake/unstake/claim), the contract:

1. Calculates rewards earned since last interaction with OLD staked amount
2. Saves those rewards in `rewardsEarned` (the checkpoint)
3. Updates timestamp to now
4. Then processes the new action

**Example Flow:**

```
Day 0:   User stakes 1 ETH → timestamp recorded, rewardsEarned = 0
Day 182: User stakes 5 ETH →
         ├─ Calculate: 1 ETH × 182 days × 10% APY = 0.05 ETH rewards
         ├─ Save checkpoint: rewardsEarned = 0.05 ETH
         ├─ Update: stakedAmount = 6 ETH, timestamp = now
         └─ Going forward: earns on 6 ETH
Day 365: User claims →
         ├─ Calculate: 6 ETH × 183 days × 10% APY = 0.3 ETH rewards
         ├─ Total rewards: 0.05 + 0.3 = 0.35 ETH ✅ (Fair!)
```

---

## 🔧 Main Functions

### User Functions

| Function               | Description                                         | Key Logic                                                   |
| ---------------------- | --------------------------------------------------- | ----------------------------------------------------------- |
| `stake()`              | Deposit ETH to start earning                        | Checkpoints existing rewards, then adds new stake           |
| `unstake()`            | Withdraw all ETH + claim all rewards                | Checkpoints, transfers rewards + principal, resets position |
| `withdrawETH(amount)`  | Partially withdraw ETH (keeps earning on remainder) | Checkpoints, validates minimum stake remains                |
| `claimRewards()`       | Claim accumulated rewards without unstaking         | Checkpoints, transfers only reward tokens                   |
| `emergencyWithdraw()`  | Withdraw principal only (forfeit rewards)           | Safety mechanism if reward system breaks                    |
| `pendingRewards(user)` | View unclaimed rewards                              | Read-only, doesn't modify state                             |

### Owner Functions

| Function                          | Description                         |
| --------------------------------- | ----------------------------------- |
| `fundRewards(amount)`             | Deposit reward tokens into contract |
| `setAnnualRewardPercent(percent)` | Update APY (max 1000% safety cap)   |
| `pause() / unpause()`             | Emergency stop/resume staking       |
| `emergencyWithdrawTokens()`       | Recover tokens if needed            |

---

## 🔐 Security Features

1. **ReentrancyGuard**: Prevents reentrancy attacks on withdraw/claim functions
2. **Pausable**: Owner can pause in emergencies
3. **Ownable2Step**: Safer ownership transfer (prevents accidental transfers)
4. **SafeERC20**: Handles tokens that don't return bool properly
5. **Checks-Effects-Interactions**: State updated before external calls
6. **Low-level call for ETH**: Uses `call{value:}` instead of deprecated `transfer()`
7. **Minimum Stake**: 0.01 ETH prevents dust attacks
8. **Reward Balance Check**: Ensures contract has tokens before paying rewards

---

## 📈 State Variables

### Per-User Storage (StakeInfo struct)

```solidity
struct StakeInfo {
    uint256 stakedAmount;      // Current ETH staked
    uint256 rewardsEarned;     // Checkpointed rewards (not yet claimed)
    uint256 lastUpdateTime;    // Last interaction timestamp
}
```

### Global State

- `totalStaked`: Total ETH in contract
- `annualRewardPercent`: Current APY (e.g., 10 = 10%)
- `rewardToken`: ERC20 token address for rewards
- `MIN_STAKE`: Minimum stake amount (0.01 ETH)

---

## 🎬 User Journey Examples

### Simple Stake & Claim

```
1. User stakes 5 ETH
2. Wait 365 days
3. User claims rewards → receives 0.5 ETH worth of tokens (10% APY)
4. User still has 5 ETH staked, continues earning
```

### Multiple Stakes (Shows Checkpoint Logic)

```
1. User stakes 2 ETH (Day 0)
2. Wait 180 days
3. User stakes 8 more ETH (Day 180)
   → Checkpoint: 2 ETH × 180 days = 0.1 ETH rewards saved
   → New stake: 10 ETH total
4. Wait 185 days
5. User unstakes (Day 365)
   → Calculate: 10 ETH × 185 days = 0.5 ETH rewards
   → Total: 0.1 + 0.5 = 0.6 ETH rewards ✅
   → Receives: 10 ETH principal + 0.6 ETH rewards
```

### Partial Withdrawal

```
1. User stakes 10 ETH
2. Wait 180 days
3. User withdraws 5 ETH
   → Still has 5 ETH staked, keeps earning
4. Wait 185 days
5. User claims → receives rewards for both periods
```

---
