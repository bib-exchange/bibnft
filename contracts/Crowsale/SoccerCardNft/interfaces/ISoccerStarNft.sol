// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

interface ISoccerStarNft {

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
        onlyWhenNotPaused
        callerIsUser;

    function publicSaleMintRound1(BlindBoxesType _blindBoxes, uint256 quantity) external payable onlyWhenNotPaused callerIsUser;

    function publicSaleMintRound2(BlindBoxesType _blindBoxes, uint256 quantity) external payable onlyWhenNotPaused callerIsUser;

    function publicSaleMintRound3(BlindBoxesType _blindBoxes, uint256 quantity) external payable onlyWhenNotPaused callerIsUser;

    function publicSaleMintRound4(BlindBoxesType _blindBoxes, uint256 quantity) external payable onlyWhenNotPaused callerIsUser;

    function publicSaleMintRound5(BlindBoxesType _blindBoxes, uint256 quantity) external payable onlyWhenNotPaused callerIsUser

    function publicSaleMint(uint256 quantity) external payable onlyWhenNotPaused;

    function ownerMint(uint256 quantity) external onlyOwner onlyWhenNotPaused;

    function tokenURI(uint _tokenId) public view virtual override returns (string memory);

    function setBaseURI(string memory uri) external onlyOwner;

    function reveal(uint256 tokenID, string memory _name,string memory _country,string memory _position, uint256 _starLevel, uint256 _gradient) public onlyOwner


    function refund(uint256[] calldata tokenIds) external;

    function withdraw() external onlyOwner;

    function setBaseURI(string memory uri) external onlyOwner;


}
