pragma solidity ^0.8.0;

interface ITokenDividendTracker {
    function excludeFromDividends(address account) external;
    function excludedFromDividends(address account) external view returns(bool);
}