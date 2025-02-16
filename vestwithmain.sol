// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

interface IMainToken {
    function balanceOf(address account) external view returns (uint256);
    function owner() external view returns (address); // Added this function

}

contract TokenVesting is Initializable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    IMainToken public mainToken;

    modifier onlyMainTokenOwner() {
        require(mainToken.owner() == msg.sender, "Not MainToken owner");
        _;
    }

    enum VestingType { QUARTERLY_25, QUARTERLY_50, CUSTOM }

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
        uint256 releaseInterval;
        uint256 percentPerInterval;
        bool isActive;
        bool timerActivated;
        VestingType vestingType;
    }

    struct VestingParams {
        address beneficiary;
        uint256 amount;
        uint256 startTime;
        VestingType vestingType;
        uint256 customCliffDuration;
        uint256 customVestingDuration;
        uint256 customReleaseInterval;
        uint256 customPercentPerInterval;
    }

    mapping(address => VestingSchedule) public vestingSchedules;
    address[] private beneficiaries;
    
    uint256 private totalDeposited;
    uint256 private totalAllocated;

    event TokensDeposited(address indexed depositor, uint256 amount);
    event ScheduleCreated(address indexed beneficiary, uint256 totalAmount, uint256 startTime, VestingType vestingType);
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event ScheduleDeactivated(address indexed beneficiary);
    event VestingActivated(address indexed beneficiary, uint256 activationTime);
    event TokensWithdrawnByOwner(uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _mainToken) public initializer {
        require(_mainToken != address(0), "Invalid token address");
        __Pausable_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        mainToken = IMainToken(_mainToken);
        totalDeposited = 0;
        totalAllocated = 0;
    }

  

     function depositTokens() external onlyOwner {
    uint256 newBalance = mainToken.balanceOf(address(this));
    require(newBalance > totalDeposited, "No tokens deposited");

    uint256 depositAmount = newBalance - totalDeposited;
    totalDeposited += depositAmount;

    emit TokensDeposited(msg.sender, depositAmount);
}

    function createVestingSchedule(VestingParams calldata params) public  onlyMainTokenOwner whenNotPaused {
        require(params.beneficiary != address(0), "Invalid beneficiary");
        require(params.amount > 0, "Amount must be > 0");
        require(params.startTime >= block.timestamp, "Start time must be in the future");
        require(!vestingSchedules[params.beneficiary].isActive, "Schedule already exists");
        require(totalDeposited - totalAllocated >= params.amount, "Insufficient available balance");

        uint256 cliffDuration;
        uint256 vestingDuration;
        uint256 releaseInterval;
        uint256 percentPerInterval;

        if (params.vestingType == VestingType.QUARTERLY_25) {
            cliffDuration = 365 days;
            vestingDuration = 730 days;
            releaseInterval = 90 days;
             percentPerInterval = 25;
        } else if (params.vestingType == VestingType.QUARTERLY_50) {
           cliffDuration = 365 days;
           vestingDuration = 730 days;
           releaseInterval = 90 days;
            percentPerInterval = 50;
        } else {
            require(params.customCliffDuration > 0, "Invalid cliff duration");
            require(params.customVestingDuration > params.customCliffDuration, "Vesting > cliff duration");
            require(params.customReleaseInterval > 0, "Invalid release interval");
            require(params.customPercentPerInterval > 0 && params.customPercentPerInterval <= 100, "Invalid percent per interval");

            cliffDuration = params.customCliffDuration;
            vestingDuration = params.customVestingDuration;
            releaseInterval = params.customReleaseInterval;
            percentPerInterval = params.customPercentPerInterval;
        }

        vestingSchedules[params.beneficiary] = VestingSchedule({
            totalAmount: params.amount,
            releasedAmount: 0,
            startTime: 0,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            releaseInterval: releaseInterval,
            percentPerInterval: percentPerInterval,
            isActive: true,
            timerActivated: false,
            vestingType: params.vestingType
        });

        beneficiaries.push(params.beneficiary);
        totalAllocated += params.amount;
        emit ScheduleCreated(params.beneficiary, params.amount, params.startTime, params.vestingType);
    }

    function createVestingbatch(VestingParams[] calldata paramsList) external onlyMainTokenOwner whenNotPaused {
    uint256 totalAmountToAllocate = 0;

    // Calculate total amount to allocate to ensure sufficient balance
    for (uint256 i = 0; i < paramsList.length; i++) {
        totalAmountToAllocate += paramsList[i].amount;
    }

    // Check if enough unallocated tokens are available
    require(totalDeposited - totalAllocated >= totalAmountToAllocate, "Insufficient available balance");

    // Create vesting schedules for each beneficiary
    for (uint256 i = 0; i < paramsList.length; i++) {
        createVestingSchedule(paramsList[i]);
        emit ScheduleCreated(paramsList[i].beneficiary, paramsList[i].amount, paramsList[i].startTime, paramsList[i].vestingType);
    }
}

    function activateVesting(address beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.isActive, "No active schedule");
        require(!schedule.timerActivated, "Already activated");

        schedule.startTime = block.timestamp;
        schedule.timerActivated = true;

        emit VestingActivated(beneficiary, block.timestamp);
    }

    function release(address beneficiary) external whenNotPaused nonReentrant onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.isActive, "No active schedule");
        require(schedule.timerActivated, "Vesting not activated");

        uint256 releasableAmount = _calculateReleasableAmount(schedule);
        require(releasableAmount > 0, "No tokens to release");
        
        uint256 contractBalance = mainToken.balanceOf(address(this));
        require(contractBalance >= releasableAmount, "Insufficient contract balance");

        schedule.releasedAmount += releasableAmount;
        totalAllocated -= releasableAmount;

        emit TokensReleased(beneficiary, releasableAmount);
    }

    function _calculateReleasableAmount(VestingSchedule memory schedule) internal view returns (uint256) {
        require(schedule.releaseInterval > 0, "Release interval cannot be zero");

        if (!schedule.isActive || !schedule.timerActivated || block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        uint256 elapsedTime = block.timestamp - schedule.startTime;
        uint256 intervalsPassed = elapsedTime / schedule.releaseInterval;
      require(schedule.releaseInterval > 0, "Release interval cannot be zero");
      require(schedule.percentPerInterval > 0, "Percent per interval cannot be zero");
        uint256 vestedAmount = (schedule.totalAmount * schedule.percentPerInterval * intervalsPassed) / 100;
        if (vestedAmount > schedule.totalAmount) {
            vestedAmount = schedule.totalAmount;
        }

        return vestedAmount - schedule.releasedAmount;
    }

    function getNextReleaseTime(address beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];
        if (!schedule.isActive || !schedule.timerActivated) return 0;

        require(schedule.releaseInterval > 0, "Release interval cannot be zero");
        uint256 elapsedTime = block.timestamp - schedule.startTime;
        uint256 intervalsPassed = elapsedTime / schedule.releaseInterval;

        return schedule.startTime + (intervalsPassed + 1) * schedule.releaseInterval;
    }

    function getVestingDetails(address beneficiary) external view returns (
        uint256 totalAmount,
        uint256 releasedAmount,
        uint256 nextReleaseTime,
        uint256 remainingAmount,
        bool isActive,
        bool timerActivated,
        VestingType vestingType
    ) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];
        nextReleaseTime = getNextReleaseTime(beneficiary);

        return (
            schedule.totalAmount,
            schedule.releasedAmount,
            schedule.startTime + schedule.cliffDuration,
            schedule.totalAmount - schedule.releasedAmount,
            schedule.isActive,
            schedule.timerActivated,
            schedule.vestingType
        );
    }

    function withdrawUnallocatedTokens() external onlyMainTokenOwner {
        uint256 unallocated = totalDeposited - totalAllocated;
        require(unallocated > 0, "No unallocated tokens");
        
        totalDeposited -= unallocated;
        emit TokensWithdrawnByOwner(unallocated);
    }

    function deactivateSchedule(address beneficiary) external onlyOwner {
        require(vestingSchedules[beneficiary].isActive, "No active schedule");
        vestingSchedules[beneficiary].isActive = false;
        emit ScheduleDeactivated(beneficiary);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getAllBeneficiaries() external view returns (address[] memory) {
        return beneficiaries;
    }

    function getTotalDeposited() external view returns (uint256) {
        return totalDeposited;
    }

    function getTotalAllocated() external view returns (uint256) {
        return totalAllocated;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}