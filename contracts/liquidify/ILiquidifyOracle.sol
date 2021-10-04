pragma solidity ^0.7.0;

interface ILiquidifyOracle {

    function getPrice(address token) external view returns (uint);

    function setPrice(address token, uint price) external;

    function getRating(address token) external view returns (uint);

    function setRating(address token, uint rating) external;

    function getDiscounts(uint ranting) external view returns (uint);

    function setDiscounts(uint ranting, uint discount) external;

    function getSwapDiscount(address token) external returns (uint);

    function setSwapDiscount(address token,uint dis) external;

    function getScale(address token) external view returns (uint);

    function setScale(address token, uint scale) external;

    function getDecimals(address token) external view returns (uint);

    function getToken(address token) external view returns (uint[10] memory);

    function getRate(address token) external view returns (uint);

    function setRate(address token, uint rate) external;

    function getFee(address token) external view returns (uint);

    function setFee(address token, uint fee) external ;

    function getThreshold(address token) external view returns (uint);

    function setThreshold(address token, uint threshold) external;

    function refreshPrice(address token) external;

    function setActivitys(address[]memory tokens, uint[]memory amounts) external;

    function stopActivity() external;

    function stopTokenActivity(address token) external;

    function setActivityAmount(address token,uint amount) external;

    function getActivityInfo(address token) external view returns (bool,bool,uint);

    function addSwap(address _token, uint _decimals, uint _scale, uint _rating
    , uint _price, uint _rate, uint _fee, uint _threshold,uint _limit,uint _pledgeFee,uint _swapDiscount) external;
}
