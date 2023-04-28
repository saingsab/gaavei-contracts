// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/base/ERC1155LazyMint.sol";

contract DropAlbum is ERC1155LazyMint {
    struct ClaimRestriction {
        uint256 startTimestamp; // timestamp to start claim
        uint256 maxSupply; // max supply of tokenId
        uint256 supplyClaimed; // supply of tokenId has been claimed
        uint256 quantityLimit; // quantity limit per wallet
        uint256 price; // price per token require to claim
    }

    /// @notice Emitted when claim restriction are created or updated.
    /// @param tokenId tokenId to set claim restriction
    /// @param claimRestriction the parameters of claim restriction
    /// @param resetClaimEligibility need to reset claim eligibility or not
    event ClaimRestrictionUpdated(
        uint256 indexed tokenId,
        ClaimRestriction claimRestriction,
        bool resetClaimEligibility
    );

    /// @notice Emitted when tokens are batch claimed via `batchClaim`.
    /// @param claimer the claimer address
    /// @param receiver the receiver address
    /// @param ids   The array of tokenId of the claimed token.
    /// @param amounts  The array of number of tokens has been claimed.
    event TokensClaimed(address indexed claimer, address indexed receiver, uint256[] ids, uint256[] amounts);

    /// @notice Emitted when balance are withdrawn from the contract
    /// @param receiver the receiver address
    /// @param amount the amount has been withdrawn into the receiver address
    event Withdrawn(address indexed receiver, uint256 amount);

    /// @dev tokenId => active claim restriction.
    mapping(uint256 => ClaimRestriction) public claimRestrictions;

    /// @dev tokenId => active claim restriction's UID.
    mapping(uint256 => bytes32) private restrictionId;

    /// @dev claim restriction's UID => wallet address => supply claimed by this wallet
    mapping(bytes32 => mapping(address => uint256)) private supplyClaimedByWallet;

    constructor(
        string memory _name,
        string memory _symbol,
        address _royaltyRecipient,
        uint128 _royaltyBps
    ) ERC1155LazyMint(_name, _symbol, _royaltyRecipient, _royaltyBps) {}

    /**
     *  @notice          Override this function to add logic for claim verification, based on conditions
     *                   such as allowlist, price, max quantity etc.
     *
     *  @dev             Checks a request to claim NFTs against a custom condition.
     *
     *  @param _claimer   Caller of the claim function.
     *  @param _tokenId   The tokenId of the lazy minted NFT to mint.
     *  @param _quantity  The number of NFTs being claimed.
     */
    function verifyClaim(address _claimer, uint256 _tokenId, uint256 _quantity) public view virtual override {
        ClaimRestriction memory restriction = claimRestrictions[_tokenId];
        require(restriction.startTimestamp != 0, "NotAvailable");

        uint256 claimStart = restriction.startTimestamp;
        uint256 claimMaxSupply = restriction.maxSupply;
        uint256 claimSupplyClaimed = restriction.supplyClaimed;
        uint256 claimLimit = restriction.quantityLimit;
        uint256 supplyClaimedByClaimer = supplyClaimedByWallet[restrictionId[_tokenId]][_claimer];

        if (_quantity == 0 || (_quantity + supplyClaimedByClaimer > claimLimit)) {
            revert("!Qty");
        }

        if (claimSupplyClaimed + _quantity > claimMaxSupply) {
            revert("!MaxSupply");
        }

        if (claimStart > block.timestamp) {
            revert("NotStart");
        }
    }

    /**
     *  @notice          Mints tokens to receiver on claim.
     *                   Any state changes related to `claim` must be applied
     *                   here by overriding this function.
     *
     *  @dev             Override this function to add logic for state updation.
     *                   When overriding, apply any state changes before `_mint`.
     */
    function _transferTokensOnClaim(address _receiver, uint256 _tokenId, uint256 _quantity) internal virtual override {
        ClaimRestriction memory restriction = claimRestrictions[_tokenId];
        uint256 claimPrice = restriction.price;

        uint256 totalPrice = _quantity * claimPrice;
        if (msg.value < totalPrice) {
            revert("!TotalPrice");
        }

        // Update contract state.
        restriction.supplyClaimed += _quantity;
        supplyClaimedByWallet[restrictionId[_tokenId]][msg.sender] += _quantity;
        claimRestrictions[_tokenId] = restriction;

        // transfer totalPrice to contract owner
        // address contractOwner = owner();
        // (bool sent, ) = payable(contractOwner).call{ value: totalPrice }("");
        // require(sent, "Failed to send Ether");

        // check if sender send exceed required amount, refund back
        uint256 refundAmount = msg.value - totalPrice;
        if (refundAmount != 0) {
            (bool refunded, ) = msg.sender.call{ value: refundAmount }("");
            require(refunded, "Failed to refund Ether");
        }

        _mint(_receiver, _tokenId, _quantity, "");
    }

    /**
     *  @notice          Lets an address claim multiple lazy minted NFTs at once to a recipient.
     *                   This function prevents any reentrant calls, and is not allowed to be overridden.
     *
     *                   Contract creators should override `verifyClaim` and `batchTransferTokensOnClaim`
     *                   functions to create custom logic for verification and claiming,
     *                   for e.g. price collection, allowlist, max quantity, etc.
     *
     *  @dev             The logic in `verifyClaim` determines whether the caller is authorized to mint NFTs.
     *                   The logic in `batchTransferTokensOnClaim` does actual minting of tokens,
     *                   can also be used to apply other state changes.
     *
     *  @param _receiver  The recipient of the tokens to mint.
     *  @param _ids   The array of tokenId of the lazy minted NFT to mint.
     *  @param _amounts  The array of number of tokens to mint.
     */
    function batchClaim(
        address _receiver,
        uint256[] memory _ids,
        uint256[] memory _amounts
    ) public payable nonReentrant {
        uint256 _maxTokenId = _ids[0];
        for (uint256 i = 0; i < _ids.length; i++) {
            // Add your claim verification logic by overriding this function.
            verifyClaim(msg.sender, _ids[i], _amounts[i]);
            if (_ids[i] > _maxTokenId) {
                _maxTokenId = _ids[i];
            }
        }
        require(_maxTokenId < nextTokenIdToMint(), "invalid id");

        // Mints tokens. Apply any state updates by overriding this function.
        _batchTransferTokensOnClaim(_receiver, _ids, _amounts);

        emit TokensClaimed(msg.sender, _receiver, _ids, _amounts);
    }

    /**
     *  @notice          Mints tokens to receiver on claim.
     *                   Any state changes related to `batchClaim` must be applied
     *                   here by overriding this function.
     *
     *  @dev             Override this function to add logic for state updation.
     *                   When overriding, apply any state changes before `_mintBatch`.
     */
    function _batchTransferTokensOnClaim(
        address _receiver,
        uint256[] memory _ids,
        uint256[] memory _amounts
    ) internal virtual {
        if (_ids.length != _amounts.length) {
            revert("!ids&amounts");
        }

        uint256 totalPrice = 0;
        for (uint i = 0; i < _ids.length; i++) {
            uint256 _tokenId = _ids[i];
            uint256 _quantity = _amounts[i];

            // get price per tokenId in the active claim restriction.
            ClaimRestriction memory restriction = claimRestrictions[_tokenId];
            uint256 claimPrice = restriction.price;
            uint256 amount = _quantity * claimPrice;
            totalPrice += amount;

            // Update contract state.
            restriction.supplyClaimed += _quantity;
            supplyClaimedByWallet[restrictionId[_tokenId]][msg.sender] += _quantity;
            claimRestrictions[_tokenId] = restriction;
        }

        // transfer totalPrice to contract owner
        // address contractOwner = owner();
        // (bool sent, ) = payable(contractOwner).call{ value: totalPrice }("");
        // require(sent, "Failed to send Ether");

        // check if sender send exceed required amount, refund back
        uint256 refundAmount = msg.value - totalPrice;
        if (refundAmount != 0) {
            (bool refunded, ) = msg.sender.call{ value: refundAmount }("");
            require(refunded, "Failed to refund Ether");
        }

        _mintBatch(_receiver, _ids, _amounts, "");
    }

    /// @dev Lets a contract admin set claim restriction.
    function setClaimRestriction(
        uint256 _tokenId,
        ClaimRestriction calldata _restriction,
        bool _resetClaimEligibility
    ) external {
        if (!_canSetClaimRestrictions()) {
            revert("Not authorized");
        }

        ClaimRestriction memory restriction = claimRestrictions[_tokenId];
        bytes32 targetRestrictionId = restrictionId[_tokenId];

        uint256 supplyClaimed = restriction.supplyClaimed;

        if (targetRestrictionId == bytes32(0) || _resetClaimEligibility) {
            supplyClaimed = 0;
            targetRestrictionId = keccak256(abi.encodePacked(msg.sender, block.number, _tokenId));
        }

        if (supplyClaimed > _restriction.maxSupply) {
            revert("MaxSupplyClaimed");
        }

        ClaimRestriction memory updatedRestriction = ClaimRestriction({
            startTimestamp: _restriction.startTimestamp,
            maxSupply: _restriction.maxSupply,
            supplyClaimed: supplyClaimed,
            quantityLimit: _restriction.quantityLimit,
            price: _restriction.price
        });

        claimRestrictions[_tokenId] = updatedRestriction;
        restrictionId[_tokenId] = targetRestrictionId;

        emit ClaimRestrictionUpdated(_tokenId, _restriction, _resetClaimEligibility);
    }

    /// @dev Returns the supply claimed by claimer for active restrictionId.
    function getSupplyClaimedByWallet(uint256 _tokenId, address _claimer) public view returns (uint256) {
        return supplyClaimedByWallet[restrictionId[_tokenId]][_claimer];
    }

    /// @notice allow contract admin to withdraw balance from drop
    function withdraw(address payable receiver, uint256 amount) external {
        if (!_canWithdraw()) {
            revert("Not authorized");
        }
        uint256 balance = address(this).balance;
        require(amount <= balance, "!Amount");
        (bool sent, ) = receiver.call{ value: amount }("");
        require(sent, "Failed to withdraw");

        emit Withdrawn(receiver, amount);
    }

    function _canSetClaimRestrictions() internal view virtual returns (bool) {
        return msg.sender == owner();
    }

    function _canWithdraw() internal view virtual returns (bool) {
        return msg.sender == owner();
    }
}
