// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Clones} from "clones/Clones.sol";
import {IPrototype} from "iproto/IPrototype.sol";

/**
 * @title Prototype
 * @notice Base contract for self-cloning minimal proxy implementations.
 * @dev Provides the canonical storage layout and factory dispatch for {IPrototype}.
 * @author Paul Reinholdtsen (reinholdtsen.eth)
 */
abstract contract Prototype is IPrototype {
    /**
     * @inheritdoc IPrototype
     */
    address public immutable proto = address(this);

    /**
     * @inheritdoc IPrototype
     */
    function made(bytes32 argshash, uint256 variant) public view returns (address home, bytes32 salt) {
        salt = argshash ^ bytes32(variant);
        home = Clones.predictDeterministicAddress(proto, salt, proto);
    }

    /**
     * @inheritdoc IPrototype
     */
    function made(bytes calldata args, uint256 variant) public view returns (address home, bytes32 salt) {
        // forge-lint: disable-next-line(asm-keccak256)
        bytes32 argshash = keccak256(abi.encode(args));
        (home, salt) = made(argshash, variant);
    }

    /**
     * @inheritdoc IPrototype
     * @dev
     * On the Prototype:
     *   - Computes salt from args.
     *   - Deploys clone if it does not already exist.
     *   - Calls zzInit(args, variant) on the new clone.
     *
     * On a clone:
     *   - Forwards the request back to the Prototype.
     */
    function make(bytes calldata args, uint256 variant) external returns (address home) {
        if (address(this) == proto) {
            bytes32 salt;
            (home, salt) = made(args, variant);

            if (home.code.length == 0) {
                home = Clones.cloneDeterministic(proto, salt, 0);
                IPrototype(home).zzInit(args, variant);
            }
        } else {
            home = IPrototype(proto).make(args, variant);
        }
    }

    /**
     * @inheritdoc IPrototype
     * @dev Must be implemented by derived classes.
     */
    function zzInit(bytes calldata args, uint256 variant) public virtual onlyProto {}

    /**
     * @notice Restricts calls to the Prototype implementation.
     */
    modifier onlyProto() {
        _onlyProto();
        _;
    }

    /**
     * @dev Reverts if msg.sender is not the Prototype implementation.
     */
    function _onlyProto() internal view {
        if (msg.sender != proto) revert Unauthorized();
    }
}
