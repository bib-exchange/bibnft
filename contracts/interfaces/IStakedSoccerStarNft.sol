// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

interface IStakedSoccerStarNft {

    struct DepositInfo{
        uint round;
        uint totalDeposit;
        uint totalStaked;
        uint totalPower;
        uint totalClaimed;
    }

    struct UserStakedInfo{
        uint tokenId;
        uint round;
        uint unfrozenTime;
        int claimedRound;
    }

    // Trigred when adim deposit a specified funds to pool
    event Deposit(address sender,uint round, uint amount);

    // Trigred to end an reward period
    event CloseRound(address sender, uint round, uint totalDeposit, uint totalStaked, uint totalPower);

    // Trigred to stake a nft card
    event Stake(address sender, uint tokenId);

    // Triggered when redeem the staken
    event Redeem(address sender, uint  tokenId);

    // Triggered after unfrozen peroid
    event Withdraw(address sender, uint  tokenId);

    // Triggered when reward is taken
    event ClaimReward(address sender, uint amount);

    // deposit a specified funds to pool
    function deposit(uint amount) external;

    // close a reward period
    function closeRound() external;

    // user staken the spcified token
    function stake(uint tokenId) external;

    // user redeem the spcified token
    function redeem(uint tokenId) external;

    // user withdraw the spcified token
    function withdraw(uint tokenId) external;

    // Get unclaimed rewards 
    function getUnClaimedRewards(address user) external view returns(uint amount);

    // Claim rewards
    function claimRewards() external;

    // Get deposit info
    function getDepositInfo() external returns(DepositInfo[] memory depositInfo);

    // Get deposit info by page
    function getDepositInfoByPage(uint pageSt, uint pageSz) external view returns(DepositInfo[] memory depositInfo);

    // Get user staked info
    function getUserStakedInfo(address user) external view returns(UserStakedInfo[] memory userStaked);

    // Get user stake info by page
    function getUserStakedInfoByPage(address user,uint pageSt, uint pageSz) external view returns(UserStakedInfo[] memory userStaked);

    // Get current round
    function getCurrentRound() external view returns(uint round);

    // Check if is the specified token is staking
    function isStaking(uint tokenId) external view returns(bool);

    // Check if the specified token is staked
    function isStaked(uint tokenId) external view returns(bool);

    // Check if the specified token is unfreezing
    function isUnfreezing(uint tokenId) external view returns(bool);

    // Check if the specified token is withdrawable
    function isWithdrawAble(uint tokenId) external view returns(bool);
}
