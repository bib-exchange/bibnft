// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.8.0;

interface IFaucet {
    struct ClaimAssetsInfo {
        string asset;
        address addr;
        uint256 frozenDuration;
        uint256 maxToClaimed;
    }

    function addAssets(ClaimAssetsInfo[] memory _assets) external;

    function claim(string memory _asset) external;
}