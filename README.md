# TokenVesting Contract

This smart contract allows the creation of customizable vesting schedules for token distributions, designed to be upgradeable, pausable, and ownable. It is intended for the distribution of tokens over time with customizable cliff and vesting durations, with support for both individual and batch vesting schedule creation.

## Features

- **Custom Vesting**: Allows creation of quarterly or custom vesting schedules.
- **Token Deposits**: Tokens can be deposited into the contract and allocated to beneficiaries.
- **Vesting Activation**: Beneficiaries can activate vesting schedules and claim their tokens based on the schedule.
- **Token Revocation**: Vesting schedules can be revoked, and unvested tokens returned to the owner.
- **Upgradable**: The contract is upgradeable through UUPS proxy pattern.
- **Pausable**: The contract can be paused and unpaused by the owner.
- **Reentrancy Protection**: Uses a reentrancy guard to prevent reentrancy attacks.
- **Beneficiary Management**: Supports individual and batch creation of vesting schedules.

## Contract Components

1. **Vesting Schedule Structure**: Defines the vesting details including start time, cliff duration, vesting duration, release intervals, and vesting percentages.
2. **Main Token Interface**: Interacts with the main token that is being vested, implementing balance checks, transfers, and ownership validation.
3. **Owner Control**: Only the owner (token owner) can deposit tokens, create vesting schedules, and manage (pause/unpause, revoke) the contract.

## Contract Structure

### 1. **Vesting Schedule Creation**

- **VestingType**:
  - `QUARTERLY_25` — Vesting occurs quarterly with 25% of the total amount released each quarter.
  - `QUARTERLY_50` — Vesting occurs quarterly with 50% of the total amount released each quarter.
  - `CUSTOM` — Custom vesting schedules where the cliff duration, vesting duration, release intervals, and percentage per interval can be defined.

### 2. **Vesting Activation**

After creating the vesting schedule, the owner must activate it by calling `activateVesting(beneficiary)`. Once activated, the beneficiary can begin claiming tokens based on the release intervals.

### 3. **Token Claiming**

The beneficiary can claim tokens at each release interval by calling the `claim()` function, which calculates how much of the vested tokens can be withdrawn.

### 4. **Vesting Revocation**

The owner can revoke a vesting schedule, returning any unvested tokens to the owner and deactivating the schedule.

### 5. **Batch Vesting Creation**

The owner can create multiple vesting schedules for different beneficiaries at once by calling `createVestingbatch(paramsList)`.

## Functions

### Public Functions

- **`depositTokens()`**: Deposits tokens into the contract.
- **`createVestingSchedule(VestingParams calldata params)`**: Creates a vesting schedule for a beneficiary.
- **`createVestingbatch(VestingParams[] calldata paramsList)`**: Creates multiple vesting schedules in a batch.
- **`activateVesting(address beneficiary)`**: Activates vesting for a specific beneficiary.
- **`claim()`**: Allows beneficiaries to claim vested tokens.
- **`revokeVesting(address _beneficiary)`**: Revokes a vesting schedule and returns unvested tokens to the owner.
- **`release(address beneficiary)`**: Releases vested tokens to the beneficiary on behalf of the owner.
- **`getNextReleaseTime(address beneficiary)`**: Returns the time of the next scheduled release for a beneficiary.
- **`getVestingDetails(address beneficiary)`**: Returns details of a beneficiary's vesting schedule.
- **`withdrawUnallocatedTokens()`**: Allows the owner to withdraw any unallocated tokens.
- **`deactivateSchedule(address beneficiary)`**: Deactivates a vesting schedule for a beneficiary.
- **`pause()`**: Pauses the contract.
- **`unpause()`**: Unpauses the contract.
- **`getAllBeneficiaries()`**: Returns a list of all beneficiaries.
- **`getTotalDeposited()`**: Returns the total amount of tokens deposited into the contract.
- **`getTotalAllocated()`**: Returns the total amount of tokens allocated to beneficiaries.

### Internal Functions

- **`_calculateReleasableAmount()`**: Internal function to calculate the amount of tokens a beneficiary is eligible to claim.
- **`_authorizeUpgrade(address newImplementation)`**: Internal function to authorize upgrades for the contract (for upgradeable contracts).

## How to Use

1. **Deploy the Contract**: Deploy the contract with the address of the main token that will be vested.
2. **Deposit Tokens**: Use the `depositTokens()` function to deposit tokens into the contract.
3. **Create Vesting Schedules**: Call `createVestingSchedule()` for individual beneficiaries or `createVestingbatch()` for multiple beneficiaries.
4. **Activate Vesting**: Use `activateVesting()` to start the vesting process.
5. **Claim Tokens**: Beneficiaries can claim tokens via `claim()`.
6. **Revoke Vesting**: If necessary, revoke vesting using `revokeVesting()`.

## Security Considerations

- Ensure that only the contract owner (the main token owner) has permission to deposit tokens, create schedules, and manage the contract.
- Use a proper mechanism to upgrade the contract using the UUPS proxy pattern to ensure future updates can be made without losing data.
- The contract is pausable to allow emergency halting of operations.

## License

MIT License. See LICENSE for more information.

how to use and deploy contract

#

1. if main token contrat is already deployed
2.  deploy vesting contract while passing token contract as parameter
3.  make sure deploy vesting contract using proxy as it is upgaradbe contarct
4. now your token contarct owner is you vesting contract owner
5. now call deposit funds function to deposit funds to contract
6. now cal create schedule to createvestingschedule
7. now call activate vesting vesting will get activate after this
8. now can keep checking vesting schedule
7. call release to release funds according to vesting release time
note you have to manually tarsnfer vesting amount to the beneficiary
8. account can claim there funds if they want through calling claim

#

for using already deployed vesting contract we have to transfer ownership of main contarct to your address and other steps are same as above
