// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

/*
 * HuckleberryFinance
 * App:             https://huckleberry.finance
 * GitHub:          https://github.com/huckleberryDex
 */

import './interfaces/IHuckleberryFactory.sol';
import './interfaces/IHuckleberryPair.sol';
import './HuckleberryPair.sol';

contract HuckleberryFactory is IHuckleberryFactory {
    address public override feeTo;
    address public override feeToSetter;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external override view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'Huckleberry: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'Huckleberry: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'Huckleberry: PAIR_EXISTS'); // single check is sufficient

        pair = (address)(new HuckleberryPair());
        IHuckleberryPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, 'Huckleberry: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'Huckleberry: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}
