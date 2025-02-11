// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// Interface for the main token contract (BEP-20 or ERC-20)
interface IMainToken {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract TokenVesting is Initializable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    IMainToken public mainToken;

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

    event ScheduleCreated(address indexed beneficiary, uint256 totalAmount, uint256 startTime, VestingType vestingType);
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event ScheduleDeactivated(address indexed beneficiary);
    event VestingActivated(address indexed beneficiary, uint256 activationTime);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _mainToken) public initializer {
        __Pausable_init();
    __Ownable_init(msg.sender); // Pass msg.sender as the initial owner
        __UUPSUpgradeable_init();
        mainToken = IMainToken(_mainToken);
    }

    function createVestingSchedule(VestingParams calldata params) external onlyOwner whenNotPaused {
        require(params.beneficiary != address(0), "Invalid beneficiary");
        require(params.amount > 0, "Amount must be > 0");
        require(params.startTime >= block.timestamp, "Start time must be in the future");
        require(!vestingSchedules[params.beneficiary].isActive, "Schedule already exists");

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
            startTime: params.startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            releaseInterval: releaseInterval,
            percentPerInterval: percentPerInterval,
            isActive: true,
            timerActivated: false,
            vestingType: params.vestingType
        });

        beneficiaries.push(params.beneficiary);
        require(mainToken.transferFrom(msg.sender, address(this), params.amount), "Token transfer failed");

        emit ScheduleCreated(params.beneficiary, params.amount, params.startTime, params.vestingType);
    }

    function activateVesting(address beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.isActive, "No active schedule");
        require(!schedule.timerActivated, "Already activated");

        schedule.startTime = block.timestamp;
        schedule.timerActivated = true;

        emit VestingActivated(beneficiary, block.timestamp);
    }

    function release(address beneficiary) external whenNotPaused {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.isActive, "No active schedule");
        require(schedule.timerActivated, "Vesting not activated");

        uint256 releasableAmount = _calculateReleasableAmount(schedule);
        require(releasableAmount > 0, "No tokens to release");

        schedule.releasedAmount += releasableAmount;
        require(mainToken.transfer(beneficiary, releasableAmount), "Token transfer failed");

        emit TokensReleased(beneficiary, releasableAmount);
    }

    function _calculateReleasableAmount(VestingSchedule memory schedule) internal view returns (uint256) {
        if (!schedule.isActive || !schedule.timerActivated || block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        uint256 elapsedTime = block.timestamp - schedule.startTime;
        uint256 intervalsPassed = elapsedTime / schedule.releaseInterval;

        uint256 vestedAmount = (schedule.totalAmount * schedule.percentPerInterval * intervalsPassed) / 100;
        if (vestedAmount > schedule.totalAmount) {
            vestedAmount = schedule.totalAmount;
        }

        return vestedAmount - schedule.releasedAmount;
    }
function getNextReleaseTime(address beneficiary) public view returns (uint256) {
    VestingSchedule memory schedule = vestingSchedules[beneficiary];
    if (!schedule.isActive || !schedule.timerActivated) return 0;

    uint256 elapsedTime = block.timestamp - schedule.startTime;
    uint256 intervalsPassed = elapsedTime / schedule.releaseInterval;

    // Calculate the next release time (after the current interval)
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
        nextReleaseTime = getNextReleaseTime(beneficiary); // Get the next release time dynamically

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

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
