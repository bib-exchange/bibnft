
pragma solidity ^0.8.9;

interface IBIBDividend {
    
    function setNodeBalance(address nodeOwner, uint256 amount) external;
    function setUserBalance(address user, uint256 amount) external;
}