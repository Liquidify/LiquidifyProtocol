// SPDX-License-Identifier: MIT
pragma solidity >=0.4.24 <0.8.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../math/KindMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC1410Basic is Ownable {

    using SafeMath for uint256;

    // Represents a fungible set of tokens.
    struct Partition {
        uint256 amount;
        bytes32 partition;
    }

    uint256 _totalSupply;

    uint256 _maxTotalSupply;

    string  _name;

    string _symbol;

    uint8 _decimals;

    bytes32 _defaultPartition;

    // Mapping from investor to aggregated balance across all investor token sets
    mapping(address => uint256) balances;

    // Mapping from investor to their partitions
    mapping(address => Partition[]) partitions;

    mapping(address => bool) minters;

    // Mapping from (investor, partition) to index of corresponding partition in partitions
    // @dev Stored value is always greater by 1 to avoid the 0 value of every index
    mapping(address => mapping(bytes32 => uint256)) partitionToIndex;

    event TransferByPartition(
        bytes32 indexed _fromPartition,
        address _operator,
        address indexed _from,
        address indexed _to,
        uint256 _value,
        bytes _data,
        bytes _operatorData
    );

    modifier onlyMinter() {
        require(minters[msg.sender], "Minter: caller is not the minter");
        _;
    }
    /**
     * @dev Total number of tokens in existence
     */
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    // @return default for `_tranche`
    function defaultPartition() external view returns (bytes32) {
        return _defaultPartition;
    }

    // @notice default tranche
    function setDefaultPartition(bytes32 _partition) external onlyOwner {
        _defaultPartition = _partition;
    }

    function updateMiner(address _minter) external onlyOwner {
        minters[_minter] = !minters[_minter];
    }

    /// @notice Counts the sum of all partitions balances assigned to an owner
    /// @param _tokenHolder An address for whom to query the balance
    /// @return The number of tokens owned by `_tokenHolder`, possibly zero
    function balanceOf(address _tokenHolder) external view returns (uint256) {
        return balances[_tokenHolder];
    }

    /// @notice Counts the balance associated with a specific partition assigned to an tokenHolder
    /// @param _partition The partition for which to query the balance
    /// @param _tokenHolder An address for whom to query the balance
    /// @return The number of tokens owned by `_tokenHolder` with the metadata associated with `_partition`, possibly zero
    function balanceOfByPartition(bytes32 _partition, address _tokenHolder) external view returns (uint256) {
        if (_validPartition(_partition, _tokenHolder))
            return partitions[_tokenHolder][partitionToIndex[_tokenHolder][_partition] - 1].amount;
        else
            return 0;
    }

    /// @notice Use to get the list of partitions `_tokenHolder` is associated with
    /// @param _tokenHolder An address corresponds whom partition list is queried
    /// @return List of partitions
    function partitionsOf(address _tokenHolder) external view returns (bytes32[] memory) {
        bytes32[] memory partitionsList = new bytes32[](partitions[_tokenHolder].length);
        for (uint256 i = 0; i < partitions[_tokenHolder].length; i++) {
            partitionsList[i] = partitions[_tokenHolder][i].partition;
        }
        return partitionsList;
    }

    /// @notice Transfers the ownership of tokens from a specified partition from one address to another address
    /// @param _partition The partition from which to transfer tokens
    /// @param _to The address to which to transfer tokens to
    /// @param _value The amount of tokens to transfer from `_partition`
    /// @param _data Additional data attached to the transfer of tokens
    function transferByPartition(bytes32 _partition, address _to, uint256 _value, bytes memory _data) public {
        // Add a function to verify the `_data` parameter
        // TODO: Need to create the bytes division of the `_partition` so it can be easily findout in which receiver's partition
        // token will transfered. For current implementation we are assuming that the receiver's partition will be same as sender's
        // as well as it also pass the `_validPartition()` check. In this particular case we are also assuming that reciever has the
        // some tokens of the same partition as well (To avoid the array index out of bound error).
        // Note- There is no operator used for the execution of this call so `_operator` value in
        // in event is address(0) same for the `_operatorData`
        _transferByPartition(msg.sender, _to, _value, _partition, _data, address(0), "");
    }

    /// @notice The standard provides an on-chain function to determine whether a transfer will succeed,
    /// and return details indicating the reason if the transfer is not valid.
    /// @param _from The address from whom the tokens get transferred.
    /// @param _to The address to which to transfer tokens to.
    /// @param _partition The partition from which to transfer tokens
    /// @param _value The amount of tokens to transfer from `_partition`
    /// @param _data Additional data attached to the transfer of tokens
    /// @return ESC (Ethereum Status Code) following the EIP-1066 standard
    /// @return Application specific reason codes with additional details
    /// @return The partition to which the transferred tokens were allocated for the _to address
    function canTransferByPartition(address _from, address _to, bytes32 _partition, uint256 _value, bytes memory _data) external view returns (byte, bytes32, bytes32) {
        // TODO: Applied the check over the `_data` parameter
        if (!_validPartition(_partition, _from))
            return (0x50, "Partition not exists", bytes32(""));
        else if (partitions[_from][partitionToIndex[_from][_partition]].amount < _value)
            return (0x52, "Insufficent balance", bytes32(""));
        else if (_to == address(0))
            return (0x57, "Invalid receiver", bytes32(""));
        else if (!KindMath.checkSub(balances[_from], _value) || !KindMath.checkAdd(balances[_to], _value))
            return (0x50, "Overflow", bytes32(""));

        // Call function to get the receiver's partition. For current implementation returning the same as sender's
        return (0x51, "Success", _partition);
    }

    function _transferByPartition(address _from, address _to, uint256 _value, bytes32 _partition, bytes memory _data, address _operator, bytes memory _operatorData) internal {
        require(_validPartition(_partition, _from), "Invalid partition");
        require(partitions[_from][partitionToIndex[_from][_partition] - 1].amount >= _value, "Insufficient balance");
        require(_to != address(0), "0x address not allowed");
        uint256 _fromIndex = partitionToIndex[_from][_partition] - 1;

        if (!_validPartitionForReceiver(_partition, _to)) {
            partitions[_to].push(Partition(0, _partition));
            partitionToIndex[_to][_partition] = partitions[_to].length;
        }
        uint256 _toIndex = partitionToIndex[_to][_partition] - 1;

        // Changing the state values
        partitions[_from][_fromIndex].amount = partitions[_from][_fromIndex].amount.sub(_value);
        balances[_from] = balances[_from].sub(_value);
        partitions[_to][_toIndex].amount = partitions[_to][_toIndex].amount.add(_value);
        balances[_to] = balances[_to].add(_value);
        // Emit transfer event.
        emit TransferByPartition(_partition, _operator, _from, _to, _value, _data, _operatorData);
    }

    function _validPartition(bytes32 _partition, address _holder) internal view returns (bool) {
        if (partitions[_holder].length < partitionToIndex[_holder][_partition] || partitionToIndex[_holder][_partition] == 0)
            return false;
        else
            return true;
    }

    function _validPartitionForReceiver(bytes32 _partition, address _to) public view returns (bool) {
        for (uint256 i = 0; i < partitions[_to].length; i++) {
            if (partitions[_to][i].partition == _partition) {
                return true;
            }
        }

        return false;
    }
}