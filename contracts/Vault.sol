// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import './interfaces/IBooster.sol';
import './interfaces/IBaseRewardPool.sol';

contract Vault is Ownable {

    using SafeERC20 for IERC20;
    
    event Deposit(address indexed user, uint pid, uint amount);
    event Withdraw(address indexed user, uint pid, uint amount);
    event Claim(address indexed user, uint crvReward, uint cvxReward);

    address public constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address public constant CVX = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;
    address public constant BOOSTER = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;
    uint private constant MULTIPLIER = 1e18;

    uint256 public constant maxSupply = 100 * 1000000 * 1e18; // 100mil
    uint256 public constant totalCliffs = 1000;

    uint public immutable pid;
    address public immutable lptoken;
    address public immutable rewardContract;

    /// @dev reward token ->  reward index
    mapping(address => uint) private rewardIndex;
    /// @dev user -> reward token -> reward index
    mapping(address => mapping(address => uint)) private rewardIndexOf;
    /// @dev user -> reward token -> earned reward
    mapping(address => mapping(address => uint)) private earned;
    
    mapping(address => uint) public balanceOf;
    uint public totalSupply;

    constructor(uint _pid) Ownable(msg.sender) {
        pid = _pid;

        (address _lptoken, , , address _rewardContract, , bool _shutdown) = IBooster(BOOSTER).poolInfo(_pid);
        require(_lptoken != address(0), "Invalid pid");
        require(!_shutdown, "shutdown");

        lptoken = _lptoken;
        rewardContract = _rewardContract;
    }

    function updateRewardIndex(address _rewardToken, uint reward) public {
        require(totalSupply > 0, "No staked");
        rewardIndex[_rewardToken] += (reward * MULTIPLIER) / totalSupply;
    }

    function _calculateRewards(address _account, address _rewardToken) private view returns (uint) {
        uint shares = balanceOf[_account];
        return (shares * (rewardIndex[_rewardToken] - rewardIndexOf[_account][_rewardToken])) / MULTIPLIER;
    }

    function calculateRewardsEarned(address account, address _rewardToken) public view returns (uint) {
        return earned[account][_rewardToken] + _calculateRewards(account, _rewardToken);
    }

    function _updateRewards(address _account, address _rewardToken) internal {
        earned[_account][_rewardToken] += _calculateRewards(_account, _rewardToken);
        rewardIndexOf[_account][_rewardToken] = rewardIndex[_rewardToken];
    }

    function deposit(uint _amount) external {
        require(_amount > 0, "Invalid amount");

        _updateRewards(msg.sender, CRV);
        _updateRewards(msg.sender, CVX);

        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;

        IERC20(lptoken).safeTransferFrom(msg.sender, address(this), _amount);

        IERC20(lptoken).approve(BOOSTER, _amount);
        IBooster(BOOSTER).deposit(pid, _amount, true);

        emit Deposit(msg.sender, pid, _amount);
    }

    function withdraw(uint _amount, bool _claim) external {
        require(_amount > 0, "Invalid amount");
        require(balanceOf[msg.sender] >= _amount, "Exceeded amount");

        _updateRewards(msg.sender, CRV);
        _updateRewards(msg.sender, CVX);
        
        IBaseRewardPool(rewardContract).withdrawAndUnwrap(_amount, _claim);

        if (_claim) {
            _claimReward();
        }

        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;

        IERC20(lptoken).safeTransfer(msg.sender, _amount);

        emit Withdraw(msg.sender, pid, _amount);
    }

    function claimReward() external {
        IBaseRewardPool(rewardContract).getReward();
        _claimReward();
    }

    function _claimReward() internal {
        _updateRewards(msg.sender, CRV);
        _updateRewards(msg.sender, CVX);

        uint crvBal = IERC20(CRV).balanceOf(address(this));
        uint cvxBal = IERC20(CVX).balanceOf(address(this));

        updateRewardIndex(CRV, crvBal);
        updateRewardIndex(CVX, cvxBal);

        uint crvReward = earned[msg.sender][CRV];
        uint cvxReward = earned[msg.sender][CVX];

        if (crvReward > 0) {
            earned[msg.sender][CRV] = 0;
            IERC20(CRV).transfer(msg.sender, crvReward);
        }

        if (cvxReward > 0) {
            earned[msg.sender][CVX] = 0;
            IERC20(CVX).transfer(msg.sender, cvxReward);
        }

        emit Claim(msg.sender, crvReward, cvxReward);
    }

    function pendingRewards(
        address _user
    ) external view returns (uint crvRewards, uint cvxRewards) {
        require(totalSupply > 0, "No staked");

        uint totalCrvRewards = IBaseRewardPool(rewardContract).earned(address(this));
        uint crvRewardIndex = rewardIndex[CRV] + (totalCrvRewards * MULTIPLIER) / totalSupply;

        uint totalCVXRewards = calculateCvxReward(totalCrvRewards);
        uint cvxRewardIndex = rewardIndex[CVX] + (totalCVXRewards * MULTIPLIER) / totalSupply;
        crvRewards = (balanceOf[_user] * (crvRewardIndex - rewardIndexOf[_user][CRV])) / MULTIPLIER;
        cvxRewards = (balanceOf[_user] * (cvxRewardIndex - rewardIndexOf[_user][CVX])) / MULTIPLIER;
        crvRewards += earned[_user][CRV];
        cvxRewards += earned[_user][CVX];
    }

    function calculateCvxReward(uint _crvRewards) internal view returns (uint cvxRewards){
        uint reductionPerCliff = maxSupply / totalCliffs;
        uint256 supply = IERC20(CVX).totalSupply();
        if(supply == 0){
            cvxRewards = _crvRewards;
        }
        uint256 cliff = supply / reductionPerCliff;
        if (cliff < totalCliffs) {
            // for reduction% take inverse of current cliff
            uint256 reduction = totalCliffs - cliff;
            // reduce
            cvxRewards = _crvRewards * reduction / totalCliffs;
            // supply cap check
            uint256 amtTillMax = maxSupply - supply;
            if(cvxRewards > amtTillMax){
                cvxRewards = amtTillMax;
            }
        }
    }
}