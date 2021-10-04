// SPDX-License-Identifier: MIT
pragma solidity >=0.4.24 <0.8.0;

import "../1410/ERC1410Standard.sol";

contract LiquidifyToken is ERC1410Standard {
    using SafeMath for uint256;

    event Transfer(address indexed _from, address indexed _to, uint _value);

    constructor() {
        _name = "LiquidifyToken";
        _symbol = "LFY";
        _decimals = 18;
        _defaultPartition = "00000000000000000000000000000001";
        _maxTotalSupply = 45 * 10 ** 24;
        minters[msg.sender] = true;
    }

    function transfer(address _to, uint _value) public {
        require(_to != address(0), "Invalid token receiver");
        transferByPartition(_defaultPartition, _to, _value, '');
        emit Transfer(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint _value) public {
        operatorTransferByPartition(_defaultPartition, _from, _to, _value, '', '');
        emit Transfer(_from, _to, _value);
    }

    function mint(address _account, uint256 _amount) external onlyMinter {
        require(_account != address(0), "ERC20: mint to the zero address");
        if (_totalSupply.add(_amount) > _maxTotalSupply) {
            return;
        }
        issueByPartition(_defaultPartition, _account, _amount, '');
        emit Transfer(address(0), _account, _amount);
    }

    function burn(address _account, uint256 _amount) external onlyMinter {
        require(_account != address(0), "ERC20: burn from the zero address");
        redeemByPartition(_defaultPartition, _account, _amount, '');
        emit Transfer(_account, address(0), _amount);
    }
}
