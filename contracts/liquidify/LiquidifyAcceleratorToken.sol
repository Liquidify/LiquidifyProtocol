// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./UnboundedRegularToken.sol";

contract LiquidityAcceleratorToken is UnboundedRegularToken {
    using SafeMath for uint256;
    uint8 constant public decimals = 18;
    string constant public name = "LiquidityAcceleratorToken";
    string constant public symbol = "LAT";

    address public owner;
    address public minter;
    address public v2Pool;
    uint public maxSupply;
    uint public limitIndex;//day

    struct Limit {
        uint day;
        uint limit;
        uint produced;
    }

    mapping(address => bool) minters;
    mapping(address => bool) updaters;
    mapping(uint => Limit) limits;

    event TransferOwnership(address indexed _user, address _old, address _new);
    event UpdateMiner(address indexed _user, bool _status);
    event UpdateUpdater(address indexed _user, bool _status);
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier onlyMinter() {
        require(minters[msg.sender], "Minter: caller is not the minter");
        _;
    }
    modifier onlyUpdater() {
        require(updaters[msg.sender], "Updater: caller is not the updater");
        _;
    }

    constructor(address _v2Pool)  {
        owner = msg.sender;
        v2Pool = _v2Pool;
        maxSupply = 45 * 10 ** 24;
        _mint(msg.sender, 585 * 10 ** 22);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
        emit TransferOwnership(msg.sender, msg.sender, newOwner);
    }

    function updateMiner(address _minter) external onlyOwner {
        minters[_minter] = !minters[_minter];
        emit UpdateMiner(_minter, minters[_minter]);
    }

    function updateUpdater(address _updater) external onlyOwner {
        updaters[_updater] = !updaters[_updater];
        emit UpdateUpdater(_updater, updaters[_updater]);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");
        if (_totalSupply.add(amount) > maxSupply) {
            return;
        }
        _totalSupply = _totalSupply.add(amount);
        balances[account] = balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function release(address account, uint256 amount) external virtual onlyOwner {
        _mint(account, amount);
    }

    function mint(address account, uint256 amount) external virtual onlyMinter {
        require(limits[limitIndex].produced.add(amount) <= limits[limitIndex].limit, "Today's limit exceeded");
        _mint(account, amount);
        limits[limitIndex].produced = limits[limitIndex].produced.add(amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function burn(address account, uint256 amount) external virtual onlyMinter {
        _burn(account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");
        balances[account] = balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function newDay(uint256 amount) external onlyUpdater {
        require(block.timestamp >= limits[limitIndex].day, "");
        Limit memory l = Limit({
        day : limits[limitIndex].day == 0 ? block.timestamp : limits[limitIndex].day + 1 days,
        limit : amount,
        produced : 0
        });
        if (limits[limitIndex].limit.sub(limits[limitIndex].produced) > 0) {
            _mint(v2Pool, limits[limitIndex].limit.sub(limits[limitIndex].produced));
        }
        limitIndex ++;
        limits[limitIndex] = l;
    }

    function getNowDayLimit() external view returns (uint, uint, uint){
        return (limits[limitIndex].day, limits[limitIndex].limit, limits[limitIndex].produced);
    }
}