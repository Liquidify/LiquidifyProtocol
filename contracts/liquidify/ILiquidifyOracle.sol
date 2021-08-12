pragma solidity ^0.7.0;

interface ILiquidifyOracle {

    function getPrice(address token) external view returns (uint);

    function setPrice(address token, uint price) external;

    function getRating(address token) external view returns (uint);

    function setRating(address token, uint rating) external;

    function getDiscounts(uint ranting) external view returns (uint);

    function setDiscounts(uint ranting, uint discount) external;

    function getScale(address token) external view returns (uint);

    function getDecimals(address token) external view returns (uint);

    function getToken(address token) external view returns (uint[8] memory);

    function getRate(address token) external view returns (uint);

    function setRate(address token, uint rate) external;

    function getFee(address token) external view returns (uint);

    function setFee(address token, uint fee) external ;

    function getThreshold(address token) external view returns (uint);

    function setThreshold(address token, uint threshold) external;
}
