// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IERC20.sol";
import "../1410/IERC1410.sol";
import "./ILiquidifyOracle.sol";
import "./ILiquidifySwap.sol";

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
        uint8 status;//1 on 2off
    }

    struct user {
        uint total;
        mapping(address => uint) tokenIndex;
        mapping(address => mapping(uint => order)) orders;
    }

    ILiquidifyOracle public oracle;
    IERC1410 public LFY;
    IERC20 public LAT;
    address public v2Pool;
    address private  owner;
    bool public stop;//true
    bool public swapStop;//true

    mapping(address => pool) pools;
    mapping(address => pool) pledgePools;
    mapping(address => user) users;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier stopAction {
        require(!stop);
        _;
    }
    modifier stopSwap {
        require(!swapStop);
        _;
    }

    constructor(address _lfy, address _lat, address _oracle, address _v2Pool) {
        oracle = ILiquidifyOracle(_oracle);
        LFY = IERC1410(_lfy);
        LAT = IERC20(_lat);
        v2Pool = _v2Pool;
    }

    function getV2Pool() external view virtual override returns (address){
        return v2Pool;
    }

    function setV2Pool(address _v2Pool) external virtual override onlyOwner {
        emit UpdateV2Pool(msg.sender, v2Pool, _v2Pool);
        v2Pool = _v2Pool;
    }

    function updateStop() external virtual override onlyOwner {
        stop = !stop;
        emit UpdateStop(msg.sender, stop);
    }

    function updateSwapStop() external virtual override onlyOwner {
        swapStop = !swapStop;
        emit UpdateSwapStop(msg.sender, swapStop);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
        emit TransferOwnership(msg.sender, msg.sender, newOwner);
    }

    function swapIn(address token, uint amount) external virtual override stopSwap {
        require(amount > 0);
        require(oracle.getRating(token) > 0);
        require(LAT.balanceOf(msg.sender) >= oracle.getThreshold(token), "threshold");
        uint[10] memory t = oracle.getToken(token);
        uint scale = t[0];
        uint discount = t[9];

        uint latAmount = amount.mul(oracle.getPrice(token)).div(oracle.getPrice(address(LAT)))
        .mul(10 ** LAT.decimals()).div(10 ** oracle.getDecimals(token));
        uint fee = latAmount.mul(discount).mul(t[6]).div(10000).div(10000);
        //send token
        LAT.mint(msg.sender, latAmount.mul(discount).div(10000).sub(fee));
        LAT.mint(v2Pool, fee);
        //activity
        uint lfyAmount = activityEx(token, latAmount.mul(discount).mul(scale).div(10000).div(10000));
        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        require(success, "Sending the token is abnormal");
        pools[token].amount = pools[token].amount.add(amount);

        emit SwapIn(msg.sender, token, amount, latAmount.mul(discount).div(10000).sub(fee)
        , lfyAmount, fee);
    }

    function activityEx(address token, uint lfyAmount) private returns (uint) {
        (bool activityStop,bool start,uint total) = oracle.getActivityInfo(token);
        if (!activityStop && start && total >= lfyAmount) {
            LFY.mint(msg.sender, lfyAmount);
            oracle.setActivityAmount(token, total.sub(lfyAmount));
            return lfyAmount;
        }
        return 0;
    }

    function swapOut(address token, uint latAmount) external virtual override stopSwap {
        require(latAmount > 0);
        require(oracle.getRating(token) > 0);
        require(LAT.balanceOf(msg.sender) >= oracle.getThreshold(token), "threshold");
        uint[10] memory t = oracle.getToken(token);
        //send token
        uint fee = latAmount.mul(t[6]).div(10000);
        uint amount = (latAmount).mul(oracle.getPrice(address(LAT))).div(oracle.getPrice(token))
        .mul(10 ** oracle.getDecimals(token)).div(10 ** LAT.decimals());
        require(pools[token].amount >= amount.mul(10000).div(t[9]), "Insufficient tokens in the pool");
        pools[token].amount = pools[token].amount.sub(amount.mul(10000).div(t[9]));
        bool success = IERC20(token).transfer(msg.sender, amount.mul(10000).div(t[9]));
        require(success, "Sending the token is abnormal");
        //LAT.burn(msg.sender, latAmount);
        //to v2 pool
        bool latSuccess = LAT.transferFrom(msg.sender, v2Pool, latAmount.add(fee));
        require(latSuccess, "Sending the token is abnormal");
        emit SwapOut(msg.sender, token, amount.mul(10000).div(t[9]), latAmount.add(fee), fee);
    }

    function getPool(address token) external view virtual override returns (uint){
        return pools[token].amount.add(pledgePools[token].amount);
    }

    function getSwapPool(address token) external view virtual override returns (uint){
        return pools[token].amount;
    }

    function getPledgePool(address token) external view virtual override returns (uint){
        return pledgePools[token].amount;
    }

    function synthetizeIn(address token, uint amount) external virtual override stopAction {
        require(amount > 0);
        require(oracle.getRating(token) > 0);
        require(LAT.balanceOf(msg.sender) >= oracle.getThreshold(token), "threshold");
        uint[10] memory t = oracle.getToken(token);
        uint scale = t[0];
        uint discount = t[4];
        uint fee = t[8];
        uint latAmount = amount.mul(oracle.getPrice(token)).div(oracle.getPrice(address(LAT)))
        .mul(10 ** LAT.decimals()).div(10 ** oracle.getDecimals(token));

        order memory o = order({
        token : token,
        amount : amount,
        latAmount : latAmount.mul(discount).div(10000),
        lfyAmount : latAmount.mul(discount).mul(scale).div(10000).div(10000),
        rate : oracle.getRate(token),
        time : block.timestamp,
        status : uint8(1)
        });

        users[msg.sender].total = users[msg.sender].total.add(o.latAmount);
        users[msg.sender].orders[token][users[msg.sender].tokenIndex[token]] = o;
        users[msg.sender].tokenIndex[token] = users[msg.sender].tokenIndex[token].add(uint(1));
        pledgePools[token].amount = pledgePools[token].amount.add(amount);
        //send token
        LAT.mint(msg.sender, o.latAmount.sub(o.latAmount.mul(fee).div(10000)));
        LAT.mint(v2Pool, o.latAmount.mul(fee).div(10000));
        LFY.mint(msg.sender, o.latAmount.mul(scale).div(10000));
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Sending the token is abnormal");
        emit SynthetizeIn(msg.sender, token, amount, o.latAmount.sub(o.latAmount.mul(fee).div(10000))
        , o.lfyAmount, users[msg.sender].tokenIndex[token], o.latAmount.mul(fee).div(10000));
    }

    function synthetizeOut(address token, uint index) external virtual override stopAction {
        require(oracle.getRating(token) > 0);
        require(users[msg.sender].orders[token][index].status == 1);
        require(LAT.balanceOf(msg.sender) >= oracle.getThreshold(token), "threshold");
        //send token
        order memory o = users[msg.sender].orders[token][index];
        uint d = (block.timestamp - o.time) / (1 days);
        uint interest = o.latAmount.mul(o.rate).mul(d).div(uint(3650000));

        users[msg.sender].orders[token][index].status = uint8(2);
        users[msg.sender].total = users[msg.sender].total.sub(o.latAmount);

        uint fee = o.latAmount.mul(oracle.getFee(token)).div(10000);
        //to v2 pool
        bool success = LAT.transferFrom(msg.sender, v2Pool, o.latAmount.add(interest).add(fee));
        require(success, "Sending the token is abnormal");
        LFY.burn(msg.sender, o.lfyAmount);
        bool TSuccess = IERC20(token).transfer(msg.sender, o.amount);
        require(TSuccess, "Sending the token is abnormal");
        pledgePools[token].amount = pledgePools[token].amount.sub(o.amount);
        emit SynthetizeOut(msg.sender, token, o.amount, o.latAmount.add(interest).add(fee), o.lfyAmount, index, fee);
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

    function getStopInfo() external view virtual override returns (bool, bool){
        return (stop, swapStop);
    }
}
