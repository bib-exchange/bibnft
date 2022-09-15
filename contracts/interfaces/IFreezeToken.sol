pragma solidity ^0.8.0;

interface IFreezeToken {
    function getFreezeAmount(address _account) external view returns(uint256);
    function setFreezeTokenAddress(address _freezeToken) external;
    function freezeToken() external view returns(address);
}
