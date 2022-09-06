// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

interface IStakedRewardUiDataProvider{
    // get unclamined rewards
    function getUnClaimedRewards(address user) external view returns(uint amount);

    // Claim rewards
    function claimRewards() external;
}