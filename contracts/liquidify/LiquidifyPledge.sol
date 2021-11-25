// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LiquidifyPledge {

    using SafeMath for uint256;

    struct order {
        uint total;
        uint time;
    }

    uint public rate;//0.3 3000
    address public owner;
    address public token;

    mapping(address => order) private orders;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    event TransferOwnership(address indexed _user, address _old, address _new);
    event SetRate(address indexed _user, uint _old, uint _new);
    event SetToken(address indexed _user, address _old, address _new);

    constructor() {
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
        emit TransferOwnership(msg.sender, msg.sender, newOwner);
    }

    function setRate(uint _rate) external onlyOwner {
        emit SetRate(msg.sender, rate, _rate);
        rate = _rate;
    }

    function setToken(address _token) external onlyOwner {
        emit SetToken(msg.sender, token, _token);
        token = _token;
    }

    function updateTime(address user) external onlyOwner {
        orders[user].time = orders[user].time.sub(1 days);
    }

    function pledge(uint amount) external {

        if (orders[msg.sender].time == 0) {
            order memory o = order({
            total : amount,
            time : block.timestamp
            });
            orders[msg.sender] = o;
        } else {
            //
            uint d = (block.timestamp - orders[msg.sender].time) / (1 days);
            if (orders[msg.sender].total.mul(rate).mul(d).div(1000).div(365) > 0) {
                orders[msg.sender].time = block.timestamp;
                IERC20(token).transfer(msg.sender, orders[msg.sender].total.mul(rate).mul(d).div(1000).div(365));
            }
            orders[msg.sender].total = orders[msg.sender].total.add(amount);
        }
        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        require(success, "Sending the token is abnormal");
    }

    function release(uint amount) external {
        withdrawal();
        orders[msg.sender].total = orders[msg.sender].total.sub(amount);
        if (orders[msg.sender].total == 0) {
            orders[msg.sender].time = 0;
        } else {
            orders[msg.sender].time = block.timestamp;
        }
        bool success = IERC20(token).transfer(msg.sender, amount);
        require(success, "Sending the token is abnormal");
    }

    function withdrawal() public {
        uint d = (block.timestamp - orders[msg.sender].time) / (1 days);
        if (orders[msg.sender].total.mul(rate).mul(d).div(1000).div(365) > 0) {
            orders[msg.sender].time = block.timestamp;
            bool success = IERC20(token).transfer(msg.sender, orders[msg.sender].total.mul(rate).mul(d).div(1000).div(365));
            require(success, "Sending the token is abnormal");
        }
    }

    function getIncome() external view returns (uint) {
        uint d = (block.timestamp - orders[msg.sender].time) / (1 days);
        return orders[msg.sender].total.mul(rate).mul(d).div(1000).div(365);
    }

    function getInfo() external view returns (uint, uint) {
        return (orders[msg.sender].total, orders[msg.sender].time);
    }
}
