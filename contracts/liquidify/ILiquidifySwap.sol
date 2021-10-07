pragma solidity ^0.7.0;

interface ILiquidifySwap {

    function swapIn(address token, uint amount) external;

    function swapOut(address token, uint amount) external;

    function getPool(address token) external view returns (uint);

    function synthetizeIn(address token, uint amount) external;

    function synthetizeOut(address token, uint index) external;

    function orderInfo(address token, uint index) external view returns (uint amount, uint latAmount, uint lfyAmount
    , uint rate, uint time, uint8 status, uint interest);

    function getAddress(address token) external view returns (uint, uint);

    function updateStop() external;

    function updateSwapStop() external;

    function getV2Pool() external view returns (address);

    function setV2Pool(address _v2Pool) external;

    function getStopInfo() external view returns (bool,bool);

    function getSwapPool(address token) external returns (uint);

    function getPledgePool(address token) external returns (uint);

    event SwapIn(address indexed _user, address indexed _token, uint _amount, uint _latAmount, uint _lfyAmount, uint _fee);
    event SwapOut(address indexed _user, address indexed _token, uint _amount, uint _latAmount, uint _fee);

    event SynthetizeIn(address indexed _user, address _token, uint _amount, uint _latAmount, uint _lfyAmount, uint _orderId, uint _fee);
    event SynthetizeOut(address indexed _user, address _token, uint _amount, uint _latAmount, uint _lfyAmount, uint _orderId, uint _fee);

    event TransferOwnership(address indexed _user, address _old, address _new);
    event UpdateV2Pool(address indexed _user ,address _old,address _new);
    event UpdateStop(address indexed _user,bool _status);
    event UpdateSwapStop(address indexed _user,bool _status);
}