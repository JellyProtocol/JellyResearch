// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./Interfaces.sol";
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';


contract CrvDepositor{
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public constant crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address public constant escrow = address(0x5f3b5DfEb7B28CDbD7FAba78963EE202a494e2A2);
    uint256 private constant MAXTIME = 4 * 364 * 86400;
    uint256 private constant WEEK = 7 * 86400;

    uint256 public lockIncentive = 10; //incentive to users who spend gas to lock crv
    uint256 public constant FEE_DENOMINATOR = 10000;

    address public feeManager;
    address public immutable staker;
    address public immutable minter;
    uint256 public incentiveCrv = 0;
    uint256 public unlockTime;

    constructor(address _staker, address _minter) public {
        staker = _staker;
        minter = _minter;
        feeManager = msg.sender;
    }

    function setFeeManager(address _feeManager) external {
        require(msg.sender == feeManager, "!auth");
        feeManager = _feeManager;
    }

    function setFees(uint256 _lockIncentive) external{
        require(msg.sender==feeManager, "!auth");

        if(_lockIncentive >= 0 && _lockIncentive <= 30){
            lockIncentive = _lockIncentive;
       }
    }

    function initialLock() external{
        require(msg.sender==feeManager, "!auth");

        uint256 vecrv = IERC20(escrow).balanceOf(staker);
        if(vecrv == 0){
            uint256 unlockAt = block.timestamp + MAXTIME;
            uint256 unlockInWeeks = (unlockAt/WEEK)*WEEK;

            //release old lock if exists
            IStaker(staker).release();
            //create new lock
            uint256 crvBalanceStaker = IERC20(crv).balanceOf(staker);
            IStaker(staker).createLock(crvBalanceStaker, unlockAt);
            unlockTime = unlockInWeeks;
        }
    }

    //lock curve
    function _lockCurve() internal {
        uint256 crvBalance = IERC20(crv).balanceOf(address(this));
        if(crvBalance > 0){
            IERC20(crv).safeTransfer(staker, crvBalance);
        }
        
        //increase ammount
        uint256 crvBalanceStaker = IERC20(crv).balanceOf(staker);
        if(crvBalanceStaker == 0){
            return;
        }
        
        //increase amount
        IStaker(staker).increaseAmount(crvBalanceStaker);
        

        uint256 unlockAt = block.timestamp + MAXTIME;
        uint256 unlockInWeeks = (unlockAt/WEEK)*WEEK;

        //increase time too if over 2 week buffer
        if(unlockInWeeks.sub(unlockTime) > 2){
            IStaker(staker).increaseTime(unlockAt);
            unlockTime = unlockInWeeks;
        }
    }

    function lockCurve() external {
        _lockCurve();

        //mint incentives
        if(incentiveCrv > 0){
            ITokenMinter(minter).mint(msg.sender,incentiveCrv);
            incentiveCrv = 0;
        }
    }

    //deposit crv for cvxCrv
    //can locking immediately or defer locking to someone else by paying a fee.
    //while users can choose to lock or defer, this is mostly in place so that
    //the cvx reward contract isnt costly to claim rewards
    function deposit(uint256 _amount, bool _lock, address _stakeAddress) public {
        require(_amount > 0,"!>0");
        
        if(_lock){
            //lock immediately, transfer directly to staker to skip an erc20 transfer
            IERC20(crv).safeTransferFrom(msg.sender, staker, _amount);
            _lockCurve();
            if(incentiveCrv > 0){
                //add the incentive tokens here so they can be staked together
                _amount = _amount.add(incentiveCrv);
                incentiveCrv = 0;
            }
        }else{
            //move tokens here
            IERC20(crv).safeTransferFrom(msg.sender, address(this), _amount);
            //defer lock cost to another user
            uint256 callIncentive = _amount.mul(lockIncentive).div(FEE_DENOMINATOR);
            _amount = _amount.sub(callIncentive);

            //add to a pool for lock caller
            incentiveCrv = incentiveCrv.add(callIncentive);
        }

        bool depositOnly = _stakeAddress == address(0);
        if(depositOnly){
            //mint for msg.sender
            ITokenMinter(minter).mint(msg.sender,_amount);
        }else{
            //mint here 
            ITokenMinter(minter).mint(address(this),_amount);
            //stake for msg.sender
            IERC20(minter).safeApprove(_stakeAddress,0);
            IERC20(minter).safeApprove(_stakeAddress,_amount);
            IRewards(_stakeAddress).stakeFor(msg.sender,_amount);
        }
    }

    function deposit(uint256 _amount, bool _lock) external {
        deposit(_amount,_lock,address(0));
    }

    function depositAll(bool _lock, address _stakeAddress) external{
        uint256 crvBal = IERC20(crv).balanceOf(msg.sender);
        deposit(crvBal,_lock,_stakeAddress);
    }
}