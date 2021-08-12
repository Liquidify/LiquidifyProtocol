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
    address private owner;
    address public token;

    mapping(address => order) private orders;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    constructor() {
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function setRate(uint _rate) external onlyOwner {
        rate = _rate;
    }

    function setToken(address _token) external onlyOwner {
        token = _token;
    }

    function updateTime(address user) external onlyOwner {
        orders[user].time = orders[user].time - (1 days);
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
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    function release(uint amount) external {
        orders[msg.sender].total = orders[msg.sender].total.sub(amount);
        if (orders[msg.sender].total == 0) {
            orders[msg.sender].time = 0;
        } else {
            orders[msg.sender].time = block.timestamp;
        }
        IERC20(token).transfer(msg.sender, amount);
    }

    function withdrawal() external {
        uint d = (block.timestamp - orders[msg.sender].time) / (1 days);
        require(orders[msg.sender].total.mul(rate).mul(d).div(1000).div(365) > 0);
        orders[msg.sender].time = block.timestamp;
        IERC20(token).transfer(msg.sender, orders[msg.sender].total.mul(rate).mul(d).div(1000).div(365));
    }

    function getIncome() external view returns (uint) {
        uint d = (block.timestamp - orders[msg.sender].time) / (1 days);
        return orders[msg.sender].total.mul(rate).mul(d).div(1000).div(365);
    }

    function getInfo() external view returns (uint, uint) {
        return (orders[msg.sender].total, orders[msg.sender].time);
    }
}
