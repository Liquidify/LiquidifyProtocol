// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
import "@openzeppelin/contracts/math/SafeMath.sol";

interface Token {

    // @return total amount of tokens
    function totalSupply() external view returns (uint supply);

    // @param _owner The address from which the balance will be retrieved
    // @return The balance
    function balanceOf(address _owner) external view returns (uint balance);

    // @notice send `_value` token to `_to` from `msg.sender`
    // @param _to The address of the recipient
    // @param _value The amount of token to be transferred
    // @return Whether the transfer was successful or not
    function transfer(address _to, uint _value) external  returns (bool success);

    // @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
    // @param _from The address of the sender
    // @param _to The address of the recipient
    // @param _value The amount of token to be transferred
    // @return Whether the transfer was successful or not
    function transferFrom(address _from, address _to, uint _value)  external  returns (bool success);

    // @notice `msg.sender` approves `_addr` to spend `_value` tokens
    // @param _spender The address of the account able to transfer the tokens
    // @param _value The amount of wei to be approved for transfer
    // @return Whether the approval was successful or not
    function approve(address _spender, uint _value) external  returns (bool success);

    // @param _owner The address of the account owning tokens
    // @param _spender The address of the account able to transfer the tokens
    // @return Amount of remaining tokens allowed to spent
    function allowance(address _owner, address _spender) external  view returns (uint remaining);

    event Transfer(address indexed _from, address indexed _to, uint _value);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
}

contract RegularToken is Token {

    using SafeMath for uint256;

    function transfer(address _to, uint _value)  public virtual override  returns (bool) {
        //Default assumes totalSupply can't be over max (2^256 - 1).
        require(balances[msg.sender] >= _value);
        balances[msg.sender] =  balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint _value)  public virtual override returns (bool) {
        require(balances[_from] >= _value);
        require(allowed[_from][msg.sender] >= _value);

        balances[_to] = balances[_to].add(_value);
        balances[_from] = balances[_from].sub(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    function balanceOf(address _owner)  public virtual override view returns (uint) {
        return balances[_owner];
    }

    function approve(address _spender, uint _value) public virtual override returns (bool) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public virtual override view returns (uint) {
        return allowed[_owner][_spender];
    }

    mapping (address => uint) balances;
    mapping (address => mapping (address => uint)) allowed;
    uint public _totalSupply;

    function totalSupply() public virtual override view returns (uint supply) {
        return _totalSupply;
    }
}

contract UnboundedRegularToken is RegularToken {
    using SafeMath for uint256;
    uint constant MAX_UINT = 2**256 - 1;

    // @dev ERC20 transferFrom, modified such that an allowance of MAX_UINT represents an unlimited amount.
    // @param _from Address to transfer from.
    // @param _to Address to transfer to.
    // @param _value Amount to transfer.
    // @return Success of transfer.
    function transferFrom(address _from, address _to, uint _value)
    public virtual override
    returns (bool)
    {
        uint allowance = allowed[_from][msg.sender];

        require(balances[_from] >= _value);
        require(allowance >= _value);

        balances[_to] = balances[_to].add(_value);
        balances[_from] = balances[_from].sub(_value);
        if (allowance < MAX_UINT) {
            allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        }
        emit Transfer(_from, _to, _value);
        return true;
    }
}