// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

abstract contract ISoccerStarNft {

    /**
     * @dev Check if the given address is qualified, implemented on demand.
     *
     * Requirements:
     *
     * - `account` account to be checked
     * - `data`  data to prove if a user is qualified.
     *           For instance, it can be a MerkleProof to prove if a user is in a whitelist
     *
     * Return:
     *
     * - `bool` whether the account is qualified for ITO
     * - `string` if not qualified, it contains the error message(reason)
     */


    function preSaleMint(uint256 quantity, bytes32[] calldata proof)
        external
        payable
        onlyWhenNotPaused;

    function publicSaleMint(uint256 quantity) external payable onlyWhenNotPaused;

    function ownerMint(uint256 quantity) external onlyOwner onlyWhenNotPaused;

    function refund(uint256[] calldata tokenIds) external;

    function withdraw() external onlyOwner;

    function _isAllowlisted(
        address _account,
        bytes32[] calldata _proof,
        bytes32 _root
    ) internal pure returns (bool);

    function setBaseURI(string memory uri) external onlyOwner;


}
