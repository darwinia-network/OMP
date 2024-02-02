// This file is part of Darwinia.
// Copyright (C) 2018-2023 Darwinia Network
// SPDX-License-Identifier: GPL-3.0
//
// Darwinia is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Darwinia is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Darwinia. If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.8.17;

import "../Verifier.sol";

contract ORMPOracle is Verifier {
    event Assigned(bytes32 indexed msgHash, uint256 fee);
    event SetFee(uint256 indexed chainId, uint256 fee);
    event SetApproved(address operator, bool approve);
    event Withdrawal(address indexed to, uint256 amt);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ImportedMessageRoot(uint256 indexed chainId, uint256 indexed messageIndex, bytes32 messageRoot);

    address public immutable PROTOCOL;

    address public owner;
    // chainId => price
    mapping(uint256 => uint256) public feeOf;
    // chainId => messageIndex => messageRoot
    mapping(uint256 => mapping(uint256 => bytes32)) rootOf;
    // operator => isApproved
    mapping(address => bool) public approvedOf;

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    modifier onlyApproved() {
        require(isApproved(msg.sender), "!approve");
        _;
    }

    constructor(address dao, address ormp) {
        PROTOCOL = ormp;
        owner = dao;
    }

    receive() external payable {}

    /// @dev Only could be called by owner.
    /// @notice Each channel has a corresponding oracle, and the message root should match with it.
    /// @param chainId The source chain id.
    /// @param messageIndex The source chain message index corresponds to the respective channel.
    /// @param messageRoot The source chain message root corresponding to the channel.
    function importMessageRoot(uint256 chainId, uint256 messageIndex, bytes32 messageRoot) external onlyOwner {
        rootOf[chainId][messageIndex] = messageRoot;
        emit ImportedMessageRoot(chainId, messageIndex, messageRoot);
    }

    function changeOwner(address newOwner) external onlyOwner {
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function setApproved(address operator, bool approve) external onlyOwner {
        approvedOf[operator] = approve;
        emit SetApproved(operator, approve);
    }

    function isApproved(address operator) public view returns (bool) {
        return approvedOf[operator];
    }

    function withdraw(address to, uint256 amount) external onlyApproved {
        (bool success,) = to.call{value: amount}("");
        require(success, "!withdraw");
        emit Withdrawal(to, amount);
    }

    function setFee(uint256 chainId, uint256 fee_) external onlyApproved {
        feeOf[chainId] = fee_;
        emit SetFee(chainId, fee_);
    }

    function fee(uint256 toChainId, address /*ua*/ ) public view returns (uint256) {
        uint256 f = feeOf[toChainId];
        require(f != 0, "!fee");
        return f;
    }

    function assign(bytes32 msgHash) external payable {
        require(msg.sender == PROTOCOL, "!auth");
        emit Assigned(msgHash, msg.value);
    }

    function merkleRoot(uint256 chainId, uint256 messageIndex) public view override returns (bytes32) {
        return rootOf[chainId][messageIndex];
    }
}
