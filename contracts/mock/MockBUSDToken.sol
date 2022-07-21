//SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockBUSD is ERC20{
    constructor() ERC20("BUSD", "BUSD Coin"){
        _mint(msg.sender, 1_000_000_000 ether);
    }
}