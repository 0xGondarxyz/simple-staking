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

    constructor(address _rewardToken, uint256 _annualRewardPercent) Ownable(msg.sender) {
        rewardToken = IERC20(_rewardToken);
        annualRewardPercent = _annualRewardPercent;
    }

    // Internal helper to calculate rewards
    function calculateRewards(uint256 stakedAmount, uint256 timeStaked) internal view returns (uint256) {
        return (stakedAmount * timeStaked * annualRewardPercent) / (100 * SECONDS_PER_YEAR);
    }

    // Your implementation functions go here

    //if we don't have a receive func or fallback func, the contract will not accept ETH
    receive() external payable {}
    fallback() external payable {}
}
