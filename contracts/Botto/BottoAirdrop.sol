// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


/**
 * @dev These functions deal with verification of Merkle trees (hash trees),
 */
library MerkleProof {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
}

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::safeApprove: approve failed'
        );
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::safeTransfer: transfer failed'
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::transferFrom: transferFrom failed'
        );
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper::safeTransferETH: ETH transfer failed');
    }
}
/// @title Eleven-Yellow BOTTO token airdrop service
/// @notice Claimable token airdrop for predetermined recipients
/// @dev Merkle tree root based proof & verification for token airdrop recipients
contract BottoAirdrop is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    address public immutable botto;
    bytes32 public immutable merkleRoot;
    uint256 public immutable endsAfter;
    uint256 public totalClaimed = 0;
    mapping(address => bool) public claimed;

    event AirdropTransfer(address to, uint256 amount);
    event RecoveryTransfer(address token, uint256 amount, address recipient);

    /// @param botto_ BOTTO ERC20 contract address
    /// @param merkleRoot_ the merkle root used for claim verification
    /// @param endsAfter_ timestamp at which the contract owner can recover all unclaimed tokens
    /// @dev Expects BOTTO token contract address
    /// @dev Precalculated verification merkle root is generated from airdrop participant list
    /// @dev End time ensures airdrop cannot be ended before the specified timestamp
    constructor(
        address botto_,
        bytes32 merkleRoot_,
        uint256 endsAfter_
    ) {
        botto = botto_;
        merkleRoot = merkleRoot_;
        endsAfter = endsAfter_;
    }

    /// @notice Returns airdrop tokens to claimant if merkle proof matches claimant & claim amount
    /// @param proof_ the merkle tree path from leaf to root
    /// @param claimant_ address of the claimant (can be any valid address, not just msg.sender)
    /// @param claim_ the amount of tokens being claimed
    /// @dev Proof is generated from airdrop participants list based on sha3 of packed `claimant_ claim_`
    function claim(
        bytes32[] memory proof_,
        address payable claimant_,
        uint256 claim_
    ) public nonReentrant {
        require(claimed[claimant_] != true, "Already claimed");
        require(verify(proof_, claimant_, claim_) == true, "Invalid proof");

        claimed[claimant_] = true;

        if (IERC20(botto).transfer(claimant_, claim_) == true) {
            emit AirdropTransfer(claimant_, claim_);
        }

        totalClaimed = totalClaimed.add(claim_);
    }

    /// @notice Verifies valid claim without cost
    /// @param proof_ the merkle tree path from leaf to root
    /// @param claimant_ address of the claimant (can be any valid address, not just msg.sender)
    /// @param claim_ the amount of tokens being claimed
    /// @dev Applications can verify claims before executing
    function verify(
        bytes32[] memory proof_,
        address claimant_,
        uint256 claim_
    ) public view returns (bool) {
        return
            MerkleProof.verify(
                proof_,
                merkleRoot,
                bytes32(keccak256(abi.encodePacked(claimant_, claim_)))
            );
    }

    /// @notice Sweeps unrelated token spam to a specified recipient address
    /// @param token_ ERC20 token address of tokens to be recovered
    /// @param amount_ the amount of tokens to recover
    /// @param recipient_ the address to send the recovered tokens to
    /// @dev Unclaimed BOTTO tokens cannot be recovered through this function, only with end()
    /// @dev Only callable by contract owner
    function recover(
        address token_,
        uint256 amount_,
        address payable recipient_
    ) public onlyOwner {
        require(amount_ > 0, "Invalid amount");
        require(address(botto) != token_, "Recover BOTTO on end");
        _recover(token_, amount_, recipient_);
    }

    /// @notice Ends airdrop functionality
    /// @param recipient_ address where re-claimed BOTTO and ETH should be sent
    /// @dev After the end time, BOTTO tokens are recovered to the given recipient & contract is destroyed
    function end(address payable recipient_) public onlyOwner {
        require(block.timestamp > endsAfter, "Cannot end yet");
        _recover(address(botto), getBalance(), recipient_);
        selfdestruct(recipient_);
    }

    /// @notice Get balance of BOTTO tokens owned by airdrop
    function getBalance() public view returns (uint256) {
        return IERC20(botto).balanceOf(address(this));
    }

    /// @dev internal function to handle recovery of tokens
    function _recover(
        address token_,
        uint256 amount_,
        address payable recipient_
    ) internal {
        if (amount_ > 0) {
            TransferHelper.safeTransfer(token_, recipient_, amount_);
            emit RecoveryTransfer(token_, amount_, recipient_);
        }
    }
}