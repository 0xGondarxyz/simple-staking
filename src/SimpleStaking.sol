// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract SimpleStaking is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public rewardToken;
    uint256 public annualRewardPercent; // e.g., 10 for 10% APY

    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public totalStaked; // Track total ETH staked in contract
    uint256 public constant MIN_STAKE = 0.01 ether;

    // User staking info
    struct StakeInfo {
        uint256 stakedAmount; // Current staked ETH amount
        uint256 rewardsEarned; // Accumulated rewards (checkpointed but not claimed)
        uint256 lastUpdateTime; // Last time rewards were calculated
    }

    mapping(address => StakeInfo) public stakes;

    // Events
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, uint256 rewards);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 rewards);

    constructor(address _rewardToken, uint256 _annualRewardPercent) Ownable(msg.sender) {
        rewardToken = IERC20(_rewardToken);
        annualRewardPercent = _annualRewardPercent;
    }

    // Internal helper to calculate rewards for a given amount and time
    function calculateRewards(uint256 stakedAmount, uint256 timeStaked) public view returns (uint256) {
        return (stakedAmount * timeStaked * annualRewardPercent) / (100 * SECONDS_PER_YEAR);
    }

    // CRITICAL: Update user's earned rewards before any state change
    function _updateRewards(address user) internal {
        StakeInfo storage userStake = stakes[user];

        // If user has staked amount, calculate rewards since last update
        if (userStake.stakedAmount > 0) {
            uint256 timeElapsed = block.timestamp - userStake.lastUpdateTime;
            uint256 newRewards = calculateRewards(userStake.stakedAmount, timeElapsed);
            userStake.rewardsEarned += newRewards;
        }

        // Update timestamp to now
        userStake.lastUpdateTime = block.timestamp;
    }

    // Stake ETH
    function stake() public payable whenNotPaused {
        require(msg.value >= MIN_STAKE, "Stake amount must be greater than 0");

        // CHECKPOINT: Update rewards with OLD staked amount before changing it
        _updateRewards(msg.sender);

        // Update user's stake
        stakes[msg.sender].stakedAmount += msg.value;
        totalStaked += msg.value;

        emit Staked(msg.sender, msg.value);
    }

    function unstake() public whenNotPaused nonReentrant {
        require(stakes[msg.sender].stakedAmount >= MIN_STAKE, "No staked amount");

        // CHECKPOINT: Update rewards with OLD staked amount before changing it
        _updateRewards(msg.sender);

        // Update user's stake
        uint256 stakedAmount = stakes[msg.sender].stakedAmount;
        stakes[msg.sender].stakedAmount = 0;
        totalStaked -= stakedAmount;

        // Update user's rewards
        uint256 rewards = stakes[msg.sender].rewardsEarned;
        require(rewardToken.balanceOf(address(this)) >= rewards, "Insufficient reward tokens in contract");

        stakes[msg.sender].rewardsEarned = 0;

        //transfer rewards to user
        rewardToken.safeTransfer(msg.sender, rewards);

        // Transfer staked ETH to user with low level call method
        (bool success,) = msg.sender.call{value: stakedAmount}(" ");
        require(success, "Transfer failed");
        //note we keep this as cautionary example
        // payable(msg.sender).transfer(stakedAmount);

        emit Unstaked(msg.sender, stakedAmount);
    }

    function withdrawETH(uint256 amount) public whenNotPaused nonReentrant {
        require(stakes[msg.sender].stakedAmount >= amount, "Insufficient staked amount");

        // CHECKPOINT: Update rewards with OLD staked amount before changing it
        _updateRewards(msg.sender);

        // Update user's stake
        stakes[msg.sender].stakedAmount -= amount;
        require(stakes[msg.sender].stakedAmount >= MIN_STAKE, "Less than minimum stake");

        totalStaked -= amount;

        // Transfer staked ETH to user with low level call method
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        //note we keep this as cautionary example
        // payable(msg.sender).transfer(amount);

        emit Withdrawn(msg.sender, amount, pendingRewards(msg.sender));
    }

    function claimRewards() public whenNotPaused nonReentrant {
        // CHECKPOINT: Update rewards with OLD staked amount before changing it
        _updateRewards(msg.sender);

        require(stakes[msg.sender].rewardsEarned > 0, "No rewards to claim");

        // Update user's stake
        uint256 rewards = stakes[msg.sender].rewardsEarned;
        require(rewardToken.balanceOf(address(this)) >= rewards, "Insufficient reward tokens in contract");

        stakes[msg.sender].rewardsEarned = 0;

        // Transfer reward tokens to user
        rewardToken.safeTransfer(msg.sender, rewards);

        emit RewardsClaimed(msg.sender, rewards);
    }

    function emergencyWithdraw() external nonReentrant {
        uint256 stakedAmount = stakes[msg.sender].stakedAmount;
        require(stakedAmount > 0, "No staked amount");

        stakes[msg.sender].stakedAmount = 0;
        stakes[msg.sender].rewardsEarned = 0;
        stakes[msg.sender].lastUpdateTime = 0;
        totalStaked -= stakedAmount;

        (bool success,) = msg.sender.call{value: stakedAmount}("");
        require(success, "Transfer failed");
    }

    // View function to see pending rewards (without checkpointing)
    function pendingRewards(address user) public view returns (uint256) {
        StakeInfo memory userStake = stakes[user];

        if (userStake.stakedAmount == 0) {
            return userStake.rewardsEarned;
        }

        uint256 timeElapsed = block.timestamp - userStake.lastUpdateTime;
        uint256 newRewards = calculateRewards(userStake.stakedAmount, timeElapsed);

        return userStake.rewardsEarned + newRewards;
    }

    // Fund the contract with reward tokens
    function fundRewards(uint256 amount) external onlyOwner {
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    // Update reward rate
    function setAnnualRewardPercent(uint256 _newPercent) external onlyOwner {
        require(_newPercent <= 1000, "Reward percent too high"); // Max 1000% to prevent mistakes
        annualRewardPercent = _newPercent;
    }

    // Pause/Unpause functions
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Emergency withdraw for owner (if needed)
    function emergencyWithdrawTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(msg.sender, amount);
    }

    // Get all stake info at once
    function getStakeInfo(address user)
        external
        view
        returns (uint256 stakedAmount, uint256 rewardsEarned, uint256 pendingReward, uint256 lastUpdateTime)
    {
        StakeInfo memory userStake = stakes[user];
        return (userStake.stakedAmount, userStake.rewardsEarned, pendingRewards(user), userStake.lastUpdateTime);
    }

    // Check reward token balance in contract
    function rewardTokenBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }

    // if we don't have a receive func or fallback func, the contract will not accept ETH
    receive() external payable {}
    fallback() external payable {}
}
