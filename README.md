
# TokenVesting Contract

This repository contains a smart contract for token vesting that can be used with BEP-20 or ERC-20 tokens. The contract provides a mechanism to manage and release tokens over time based on different vesting schedules, which are useful for rewarding team members, investors, or other stakeholders.

The contract is **ownable**, **pausable**, and **upgradeable**, which allows for future security updates and flexibility in managing the contract.

## Key Features

- **Three Vesting Types**:
  1. **Locked for 12 months, then 25% released quarterly**.
  2. **Locked for 12 months, then 50% released quarterly**.
  3. **Custom vesting with configurable cliff, vesting period, release interval, and release percentage**.

- **Vesting Timer Activation**:
  - The vesting timer can be started at any time by the owner.
  - Until activated, the vesting schedule will respect the default 12-month cliff.

- **Public Vesting Information**:
  - All vesting details, including start time, cliff duration, and remaining tokens, are visible to the public.

- **Owner Flexibility**:
  - The owner can pause/unpause the contract, deactivate vesting schedules, and release tokens manually at any time.
  - The owner can stop specific addresses from receiving further tokens once their vesting period has ended.

- **Customizable Start Date**:
  - The first token release date is customizable for each beneficiary to allow synchronization.

- **Bulk Vesting**:
  - The owner can allocate tokens to multiple beneficiaries at once with different amounts and vesting schedules.

## Functions

### `initialize(address _mainToken)`
Initializes the contract with the main token contract address.

- `_mainToken`: Address of the main BEP-20 or ERC-20 token used for vesting.

### `createVestingSchedule(VestingParams calldata params)`
Creates a new vesting schedule for a beneficiary.

- **VestingParams**:
  - `beneficiary`: Address of the recipient.
  - `amount`: Total tokens allocated to the beneficiary.
  - `startTime`: Timestamp when vesting starts.
  - `vestingType`: Type of vesting schedule (QUARTERLY_25, QUARTERLY_50, or CUSTOM).
  - `customCliffDuration`: Duration of the custom cliff (for custom vesting).
  - `customVestingDuration`: Duration of the custom vesting period.
  - `customReleaseInterval`: Release interval for custom vesting.
  - `customPercentPerInterval`: Percent released per interval for custom vesting.

### `activateVesting(address beneficiary)`
Activates the vesting timer for a beneficiary. After activation, tokens will start releasing according to the vesting schedule.

- **beneficiary**: Address of the beneficiary whose vesting timer is being activated.

### `release(address beneficiary)`
Releases tokens to the beneficiary based on their vesting schedule.

- **beneficiary**: Address of the beneficiary to receive the release.

### `getNextReleaseTime(address beneficiary)`
Returns the next release time for the given beneficiary.

- **beneficiary**: Address of the beneficiary.

### `getVestingDetails(address beneficiary)`
Returns details about a beneficiary's vesting schedule.

- **beneficiary**: Address of the beneficiary.

Returns:
- `totalAmount`: Total tokens allocated for the vesting schedule.
- `releasedAmount`: Amount of tokens already released.
- `nextReleaseTime`: Timestamp of the next release.
- `remainingAmount`: Tokens remaining in the vesting schedule.
- `isActive`: Whether the vesting schedule is active.
- `timerActivated`: Whether the vesting timer has been activated.
- `vestingType`: Type of the vesting schedule.

### `deactivateSchedule(address beneficiary)`
Deactivates the vesting schedule for a specific beneficiary.

- **beneficiary**: Address of the beneficiary whose vesting schedule is being deactivated.

### `pause()`
Pauses the contract, preventing any further actions.

### `unpause()`
Unpauses the contract, allowing actions to be performed.

### `getAllBeneficiaries()`
Returns an array of all beneficiaries who have active vesting schedules.

### `_authorizeUpgrade(address newImplementation)`
Ensures that only the owner can upgrade the contract to a new implementation.

## Example Use Case

### 1. Create a vesting schedule

```solidity
VestingParams memory params = VestingParams({
    beneficiary: 0xAddress,
    amount: 1000,
    startTime: block.timestamp + 1 days, // Starts after 1 day
    vestingType: VestingType.QUARTERLY_25, // 25% quarterly after 12 months
    customCliffDuration: 0,
    customVestingDuration: 0,
    customReleaseInterval: 0,
    customPercentPerInterval: 0
});
createVestingSchedule(params);
```

### 2. Activate the vesting schedule

```solidity
activateVesting(0xAddress);
```

### 3. Release tokens

```solidity
release(0xAddress);
```

## Security & Upgradeability

This contract uses **OpenZeppelin's upgradeable contracts**. The contract is fully upgradeable, which allows for future improvements and security fixes without losing the state of the contract.

## Requirements

- **Solidity Version**: ^0.8.19
- **OpenZeppelin Contracts**: Upgradeable contracts, Pausable, Ownable
- **Main Token**: Any ERC-20 or BEP-20 token deployed before initializing this contract.

## Deployment Instructions

1. Deploy the main ERC-20 or BEP-20 token contract.
2. Deploy the `TokenVesting` contract.
3. Call the `initialize` function with the address of the main token contract.
4. The owner can then begin creating vesting schedules for beneficiaries.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

### Instructions for Future Updates

To update the contract, you can deploy a new implementation and upgrade the contract using the UUPS proxy pattern.


