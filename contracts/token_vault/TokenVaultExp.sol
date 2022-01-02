pragma solidity ^0.8.6;

import "../../interfaces/IJellyVault.sol";
import "../OpenZeppelin/token/ERC20/utils/SafeERC20.sol";
import "../OpenZeppelin/utils/structs/EnumerableSet.sol";
import "../../interfaces/IERC20.sol";
import "../OpenZeppelin/utils/math/SafeMath.sol";

contract TokenVault  {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;
 
    struct ItemLock {
        uint256 lockDate;
        uint256 unlockDate;
        uint256 amount;
        address owner;
        uint256 lockId;
        bool isClaimable;
    }

    struct LockerInfo {
        EnumerableSet.AddressSet lockedItems; // records all tokens the user has locked
        mapping(address => uint256[]) locksForItems; // map erc20 address to lock id for that token
    }


    mapping(address => LockerInfo) private users;
    mapping(address => ItemLock[]) public itemLocks;
    EnumerableSet.AddressSet private tokensInVault;

    mapping(address => bool) public contractWithdrawable;
    mapping(address => address) public tokenWithdrawer;
    event onWithdraw(address tokenAddress, uint256 amount);
    event onLock(address token, address user, uint256 amount, uint256 lockDate, uint256 unlockDate);


    function lockTokens(address _tokenAddress, uint256 _amount, uint256 _unlockDate,address payable _withdrawer) external override {
        require(_unlockDate < 10000000000, 'TIMESTAMP INVALID'); // prevents errors when timestamp entered in milliseconds
        require(_amount > 0, 'INSUFFICIENT');
        
        IERC20 token = IERC20(address(_tokenAddress));
        //MKZ: Add fees?
        token.transferFrom(
            msg.sender,
            address(this),
            _amount
        );

        ItemLock memory item_lock;
        item_lock.lockDate = block.timestamp;
        item_lock.amount = _amount;
        item_lock.unlockDate = _unlockDate;
        item_lock.lockId = itemLocks[_tokenAddress].length;
        item_lock.owner = _withdrawer;
        

        itemLocks[_tokenAddress].push(item_lock);
        tokensInVault.add(_tokenAddress);

        LockerInfo storage user = users[_withdrawer];
        user.lockedItems.add(_tokenAddress);
        uint256[] storage user_locks = user.locksForItems[_tokenAddress];
        user_locks.push(item_lock.lockId);
        //reward jelly
        
        emit onLock(_tokenAddress, msg.sender, item_lock.amount, item_lock.lockDate, item_lock.unlockDate);
        
    }
    /// @dev have the owner of the locked tokens transfer the claim to a new owner
    /// @dev for example, before it ends, the dev might need to set the owner to claim
    function setWithdrawer(address _tokenAddress, uint256 _index, uint256 _lockId, address payable _withdrawer) external override {
    
    }
    function contractWithdraw(address _tokenAddress, address _user, uint256 _amount,uint256 _lockId, uint256 _index) external{
        uint256 lockId = users[_user].locksForItems[_tokenAddress][_index];
        require(contractWithdrawable[msg.sender] && lockId == _lockId, "This Contract cannot withdraw");
        _withdraw(_tokenAddress, _user, _amount, _lockId, _index);
    }

    function userWithdraw(address _tokenAddress,  uint256 _amount, uint256 _lockId, uint256 _index) public {
        uint256 lockId = users[msg.sender].locksForItems[_tokenAddress][_index];
        ItemLock memory userLock = itemLocks[_tokenAddress][_lockId];
        require(lockId == _lockId && userLock.owner == msg.sender && userLock.isClaimable == true, 'LOCK MISMATCH');
        _withdraw(_tokenAddress, msg.sender, _amount, _lockId, _index);
    }

    function _withdraw(address _tokenAddress, address _user, uint256 _amount, uint256 _lockId, uint256 _index) internal {
        require(_amount > 0, 'ZERO WITHDRAWAL');
        ItemLock storage userLock = itemLocks[_tokenAddress][_lockId];
        userLock.amount = userLock.amount.sub(_amount);
        
        if (userLock.amount == 0) {
            uint256[] storage userLocks = users[_user].locksForItems[_tokenAddress];
            userLocks[_index] = userLocks[userLocks.length - 1];
            userLocks.pop();
            if(userLocks.length == 0){
                users[_user].lockedItems.remove(_tokenAddress);
            }
        }
        
        IERC20 token = IERC20(address(_tokenAddress));
        token.safeTransferFrom(
            address(this),
            msg.sender,
            _amount
        );
        emit onWithdraw(_tokenAddress, _amount);
    }


    /// @dev extend a lock with a new unlock date
    function relock(address _tokenAddress, uint256 _index,uint256 _unlockDate) external override {}


    

}