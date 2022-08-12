
pragma solidity 0.8.9;

contract NFTCardStakeMock {
    
    function isStaked(uint tokenId) external view returns(bool) {
        if (tokenId > 10) return false;
        return true;
    }
}