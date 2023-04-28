# Solidity API

## DropAlbum

### ClaimRestriction

```solidity
struct ClaimRestriction {
  uint256 startTimestamp;
  uint256 maxSupply;
  uint256 supplyClaimed;
  uint256 quantityLimit;
  uint256 price;
}
```

### ClaimRestrictionUpdated

```solidity
event ClaimRestrictionUpdated(uint256 tokenId, struct DropAlbum.ClaimRestriction claimRestriction, bool resetClaimEligibility)
```

Emitted when claim restriction are created or updated.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | tokenId to set claim restriction |
| claimRestriction | struct DropAlbum.ClaimRestriction | the parameters of claim restriction |
| resetClaimEligibility | bool | need to reset claim eligibility or not |

### TokensClaimed

```solidity
event TokensClaimed(address claimer, address receiver, uint256[] ids, uint256[] amounts)
```

Emitted when tokens are batch claimed via `batchClaim`.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| claimer | address | the claimer address |
| receiver | address | the receiver address |
| ids | uint256[] | The array of tokenId of the claimed token. |
| amounts | uint256[] | The array of number of tokens has been claimed. |

### Withdrawn

```solidity
event Withdrawn(address receiver, uint256 amount)
```

Emitted when balance are withdrawn from the contract

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| receiver | address | the receiver address |
| amount | uint256 | the amount has been withdrawn into the receiver address |

### claimRestrictions

```solidity
mapping(uint256 => struct DropAlbum.ClaimRestriction) claimRestrictions
```

_tokenId => active claim restriction._

### restrictionId

```solidity
mapping(uint256 => bytes32) restrictionId
```

_tokenId => active claim restriction's UID._

### supplyClaimedByWallet

```solidity
mapping(bytes32 => mapping(address => uint256)) supplyClaimedByWallet
```

_claim restriction's UID => wallet address => supply claimed by this wallet_

### constructor

```solidity
constructor(string _name, string _symbol, address _royaltyRecipient, uint128 _royaltyBps) public
```

### verifyClaim

```solidity
function verifyClaim(address _claimer, uint256 _tokenId, uint256 _quantity) public view virtual
```

@notice          Override this function to add logic for claim verification, based on conditions
                  such as allowlist, price, max quantity etc.

 @dev             Checks a request to claim NFTs against a custom condition.

 @param _claimer   Caller of the claim function.
 @param _tokenId   The tokenId of the lazy minted NFT to mint.
 @param _quantity  The number of NFTs being claimed.

### _transferTokensOnClaim

```solidity
function _transferTokensOnClaim(address _receiver, uint256 _tokenId, uint256 _quantity) internal virtual
```

@notice          Mints tokens to receiver on claim.
                  Any state changes related to `claim` must be applied
                  here by overriding this function.

 @dev             Override this function to add logic for state updation.
                  When overriding, apply any state changes before `_mint`.

### batchClaim

```solidity
function batchClaim(address _receiver, uint256[] _ids, uint256[] _amounts) public payable
```

@notice          Lets an address claim multiple lazy minted NFTs at once to a recipient.
                  This function prevents any reentrant calls, and is not allowed to be overridden.

                  Contract creators should override `verifyClaim` and `batchTransferTokensOnClaim`
                  functions to create custom logic for verification and claiming,
                  for e.g. price collection, allowlist, max quantity, etc.

 @dev             The logic in `verifyClaim` determines whether the caller is authorized to mint NFTs.
                  The logic in `batchTransferTokensOnClaim` does actual minting of tokens,
                  can also be used to apply other state changes.

 @param _receiver  The recipient of the tokens to mint.
 @param _ids   The array of tokenId of the lazy minted NFT to mint.
 @param _amounts  The array of number of tokens to mint.

### _batchTransferTokensOnClaim

```solidity
function _batchTransferTokensOnClaim(address _receiver, uint256[] _ids, uint256[] _amounts) internal virtual
```

@notice          Mints tokens to receiver on claim.
                  Any state changes related to `batchClaim` must be applied
                  here by overriding this function.

 @dev             Override this function to add logic for state updation.
                  When overriding, apply any state changes before `_mintBatch`.

### setClaimRestriction

```solidity
function setClaimRestriction(uint256 _tokenId, struct DropAlbum.ClaimRestriction _restriction, bool _resetClaimEligibility) external
```

_Lets a contract admin set claim restriction._

### getSupplyClaimedByWallet

```solidity
function getSupplyClaimedByWallet(uint256 _tokenId, address _claimer) public view returns (uint256)
```

_Returns the supply claimed by claimer for active restrictionId._

### withdraw

```solidity
function withdraw(address payable receiver, uint256 amount) external
```

allow contract admin to withdraw balance from drop

### _canSetClaimRestrictions

```solidity
function _canSetClaimRestrictions() internal view virtual returns (bool)
```

### _canWithdraw

```solidity
function _canWithdraw() internal view virtual returns (bool)
```

