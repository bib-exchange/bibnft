//SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import {DividendPayingToken} from "../misc/DividendPayingToken.sol";
import {IBalanceHook} from "../interfaces/IBalanceHook.sol";

contract StakedDividendTracker is IBalanceHook, DividendPayingToken{
    address caller;
    constructor(address _caller, address _rewardToken)
    DividendPayingToken(_rewardToken, "Staked Reward Token", "SRT"){
        caller = _caller;
    }

    modifier onlyCaller(){
        require(msg.sender == caller, "ONLY_CALLER");
        _;
    }

    function hookBalanceChange(address user, uint newBalance) public override onlyCaller{
        _setBalance(user, newBalance);
    }
}