//SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockStaked {
    uint public round;
    uint public totalDeposit;
    uint public totalStaked;
    uint public totalPower;

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

    function deposit(uint amount) public {

        emit CloseRound(msg.sender, round, totalDeposit, totalStaked, totalPower);

        emit Deposit(msg.sender, round, amount);

        totalDeposit += 10;
        round++;
    }

    // close a reward period
    function closeRound() public {
        emit CloseRound(msg.sender, round, totalDeposit, totalStaked, totalPower);
        round++;
    }

    // user staken the spcified token
    function stake(uint tokenId) public {
        emit CloseRound(msg.sender, round, totalDeposit, totalStaked, totalPower);
         
        emit Stake(msg.sender, tokenId);

        round++;
        totalStaked++;
        totalPower += 20;
    }

    // user redeem the spcified token
    function redeem(uint tokenId) public {
        emit CloseRound(msg.sender, round, totalDeposit, totalStaked, totalPower);

        emit Redeem(msg.sender, tokenId);

        round++;
        totalPower -= 20;
    }

    // user withdraw the spcified token
    function withdraw(uint tokenId) public{
        emit CloseRound(msg.sender, round, totalDeposit, totalStaked, totalPower);

        emit Redeem(msg.sender, tokenId);

        round++;
        totalStaked--;
    }
}