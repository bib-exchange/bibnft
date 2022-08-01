// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.8.0;

interface IRewardDistributor {
    function distributeETHReward(uint amount)external payable ;
    function distributeBIBReward(uint amount)external payable ;
    function distributeBUSDReward(uint amount)external payable ;
}