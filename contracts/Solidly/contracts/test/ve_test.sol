// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;

contract ve_test {


    uint256 public totalSupply = 0;
    address immutable public token;
    address immutable public owner;
    mapping(uint => uint) balances;
    mapping(uint => address) public ownerOf;
    constructor(address _token) {
        token = _token;
        owner = msg.sender;
    }

    uint tokenId = 0;

    function create_lock(uint amount, uint duration) external {
        balances[++tokenId] = amount;
        ownerOf[tokenId] = msg.sender;
        totalSupply += amount;
    }

    function balanceOfNFT(uint tokenId) external view returns (uint) {
        return totalSupply;
    }

    function isApprovedOrOwner(address owner, uint _tokenId) external view returns (bool) {
        return true;
    }
}
