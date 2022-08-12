pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BEP20Token is ERC20 {
    constructor() public ERC20("BIB Token","BIB")  {
      _mint(msg.sender, 1 * 10**9 * 10**18);
    }
}