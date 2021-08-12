// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IERC20.sol";
import "../1410/IERC1410.sol";
import "./ILiquidifyOracle.sol";

interface ILiquidifySwap {

    function swapIn(address token, uint amount) external;

    function swapOut(address token, uint amount) external;

    function getPool(address token) external view returns (uint);

    function synthetizeIn(address token, uint amount) external;

    function synthetizeOut(address token, uint index) external;

    function orderInfo(address token, uint index) external view returns (uint amount, uint latAmount, uint lfyAmount
    , uint rate, uint time, uint8 status, uint interest);

    function getAddress(address token) external view returns (uint, uint);

    event SwapIn(address indexed _user, address indexed _token, uint _amount, uint _latAmount, uint _lfyAmount);
    event SwapOut(address indexed _user, address indexed _token, uint _amount, uint _latAmount);

    event SynthetizeIn(address indexed _user, address _token, uint _amount, uint _latAmount, uint _lfyAmount, uint _orderId);
    event SynthetizeOut(address indexed _user, address _token, uint _amount, uint _latAmount, uint _lfyAmount, uint _orderId);
}

contract LiquidifySwap is ILiquidifySwap {
    using SafeMath for uint256;

    struct pool {
        uint amount;
    }

    struct order {
        address token;
        uint amount;
        uint latAmount;
        uint lfyAmount;
        uint rate;
        uint time;
        uint8 status;//0 on 1off
    }

    struct user {
        uint total;
        mapping(address => uint) tokenIndex;
        mapping(address => mapping(uint => order)) orders;
    }

    ILiquidifyOracle public oracle;
    IERC1410 public LFY;
    IERC20 public LAT;

    mapping(address => pool) pools;
    mapping(address => user) users;

    constructor(address _lfy,address _lat,address _oracle) {
        oracle = ILiquidifyOracle(_oracle);
        LFY = IERC1410(_lfy);
        LAT = IERC20(_lat);
    }

    function swapIn(address token, uint amount) external virtual override {
        require(amount > 0);
        require(oracle.getRating(token) > 0);
        require(LAT.balanceOf(msg.sender) >= oracle.getThreshold(token), "threshold");
        uint[8] memory t = oracle.getToken(token);
        uint scale = t[0];
        uint discount = t[4];
        uint fee = t[6];
        uint latAmount = amount.mul(oracle.getPrice(token)).div(oracle.getPrice(address(LAT)))
        .mul(10 ** LAT.decimals()).div(10 ** oracle.getDecimals(token));
        //send token
        LAT.mint(msg.sender, latAmount.mul(discount).div(10000).sub(latAmount.mul(discount).div(10000).mul(fee).div(10000)));
        LFY.mint(msg.sender, latAmount.mul(discount).div(10000).mul(scale).div(10000));
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        pools[token].amount = pools[token].amount.add(amount);
        emit SwapIn(msg.sender, token, amount, latAmount, latAmount.mul(discount).div(10000).mul(scale).div(10000));
    }

    function swapOut(address token, uint latAmount) external virtual override {
        require(latAmount > 0);
        require(oracle.getRating(token) > 0);
        require(LAT.balanceOf(msg.sender) >= oracle.getThreshold(token), "threshold");
        uint[8] memory t = oracle.getToken(token);
        //send token
        uint fee = latAmount.mul(t[6]).div(10000);
        uint amount = (latAmount.sub(fee)).mul(oracle.getPrice(address(LAT))).div(oracle.getPrice(token))
        .mul(10 ** oracle.getDecimals(token)).div(10 ** LAT.decimals());

        pools[token].amount = pools[token].amount.sub(amount.mul(10000).div(t[4]));
        IERC20(token).transfer(msg.sender, amount.mul(10000).div(t[4]));
        LAT.burn(msg.sender, latAmount);
        emit SwapOut(msg.sender, token, amount.mul(10000).div(t[4]), latAmount);
    }
    function getPool(address token) external view virtual override returns (uint){
        return pools[token].amount;
    }


    function synthetizeIn(address token, uint amount) external virtual override {
        require(amount > 0);
        require(oracle.getRating(token) > 0);
        require(LAT.balanceOf(msg.sender) >= oracle.getThreshold(token), "threshold");
        uint[8] memory t = oracle.getToken(token);
        uint scale = t[0];
        uint discount = t[4];
        uint fee = t[6];
        uint latAmount = amount.mul(oracle.getPrice(token)).div(oracle.getPrice(address(LAT)))
        .mul(10 ** LAT.decimals()).div(10 ** oracle.getDecimals(token));

        order memory o = order({
        token : token,
        amount : amount,
        latAmount : latAmount.mul(discount).div(10000),
        lfyAmount : latAmount.mul(discount).div(10000).mul(scale).div(10000),
        rate : oracle.getRate(token),
        time : block.timestamp,
        status : uint8(0)
        });

        users[msg.sender].total = users[msg.sender].total.add(o.latAmount);
        users[msg.sender].orders[token][users[msg.sender].tokenIndex[token]] = o;
        users[msg.sender].tokenIndex[token] = users[msg.sender].tokenIndex[token].add(uint(1));

        //send token
        LAT.mint(msg.sender, o.latAmount.sub(o.latAmount.mul(fee).div(10000)));
        LFY.mint(msg.sender, o.latAmount.mul(scale).div(10000));
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        emit SynthetizeIn(msg.sender, token, amount, o.latAmount, o.lfyAmount, users[msg.sender].tokenIndex[token]);
    }

    function synthetizeOut(address token, uint index) external virtual override {
        require(oracle.getRating(token) > 0);
        require(users[msg.sender].orders[token][index].status == 0);
        require(LAT.balanceOf(msg.sender) >= oracle.getThreshold(token), "threshold");
        //send token
        order memory o = users[msg.sender].orders[token][index];
        uint d = (block.timestamp - o.time) / (1 days);
        uint interest = o.latAmount.mul(o.rate).mul(d).div(uint(3650000));

        users[msg.sender].orders[token][index].status = uint8(1);
        users[msg.sender].total = users[msg.sender].total.sub(o.latAmount);

        uint fee = o.latAmount.mul(oracle.getFee(token)).div(10000);
        LAT.burn(msg.sender, o.latAmount.add(interest).add(fee));
        LFY.burn(msg.sender, o.lfyAmount);
        IERC20(token).transfer(msg.sender, o.amount);

        emit SynthetizeOut(msg.sender, token, o.amount, o.latAmount, o.lfyAmount, index);
    }

    function orderInfo(address token, uint index) external view virtual override
    returns (uint amount, uint latAmount, uint lfyAmount, uint rate, uint time, uint8 status, uint interest) {
        order memory o = users[msg.sender].orders[token][index];
        uint d = (block.timestamp - o.time) / (1 days);
        uint i = o.latAmount.mul(o.rate).mul(d).div(uint(3650000));
        return (o.amount, o.latAmount, o.lfyAmount, o.rate, o.time, o.status, i);
    }

    function getAddress(address token) external view virtual override returns (uint, uint) {
        return (users[msg.sender].total, users[msg.sender].tokenIndex[token]);
    }
}
