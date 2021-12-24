pragma solidity ^0.5.16;

import "./Exponential.sol";
import "./CToken.sol";

interface V1PriceOracleInterface {
    function assetPrices(address asset) external view returns (uint);
}

interface AggregatorV3Interface {

  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData( uint80 _roundId) external view returns (uint80 roundId,int256 answer,uint256 startedAt,uint256 updatedAt,uint80 answeredInRound);

  function latestRoundData() external view returns ( uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

}

// contract Simulate is AggregatorV3Interface{
//   uint8 private  decimals_;
//   int private answer_;

//   constructor(uint8 _decimals,int price)public {
//     decimals_ = _decimals;
//     answer_ = price;
//   }

//   function decimals()
//     external
//     view
//     returns (
//       uint8
//     ){
//       return decimals_;
//     }

//   function description()
//     external
//     view
//     returns (
//       string memory
//     ){
//       return "adfa";
//     }

//   function version()
//     external
//     view
//     returns (
//       uint256
//     ){
//       return 0;
//     }

//   // getRoundData and latestRoundData should both raise "No data present"
//   // if they do not have data to report, instead of returning unset values
//   // which could be misinterpreted as actual reported values.
//   function getRoundData(
//     uint80 _roundId
//   )
//     external
//     view
//     returns (
//       uint80 roundId,
//       int256 answer,
//       uint256 startedAt,
//       uint256 updatedAt,
//       uint80 answeredInRound
//     ){
//       answer= answer_;
//     }

//   function latestRoundData()
//     external
//     view
//     returns (
//       uint80 roundId,
//       int256 answer,
//       uint256 startedAt,
//       uint256 updatedAt,
//       uint80 answeredInRound
//     ){
//       answer= answer_;
//     }
// }

contract ChainLinkAdaptImplement is Exponential, V1PriceOracleInterface {

    address public admin;
    
    mapping(address => AggregatorV3Interface) public cTokenToChanlinkMapping;

    address public pendingAdmin;


    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);
    event NewAdmin(address oldAdmin, address newAdmin);

    constructor() public {
        admin = msg.sender;
    }

    function() payable external {
        revert();
    }

    function _setPendingAdmin(address newPendingAdmin) public {

        require(msg.sender == admin ,"only admin can set pendingadmin");
        require(msg.sender != address(0x0),"bad pendingadmin");

        address oldPendingAdmin = pendingAdmin;

        pendingAdmin = newPendingAdmin;

        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);
    }

    /**
      * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
      * @dev Admin function for pending admin to accept role and update admin
      */
    function _acceptAdmin() public returns (uint) {
        // Check caller is pendingAdmin and pendingAdmin ≠ address(0)
        require(msg.sender == pendingAdmin && msg.sender != address(0),"only pendingadmin can accept");

        // Save current values for inclusion in log
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
    }

    function addToken(address cToken, AggregatorV3Interface consumer) public {
        require(msg.sender == admin,"no authorized when addToken");
        require(address(cTokenToChanlinkMapping[cToken]) == address(0x0),"duplicated ctoken");

        //check the consumer is valiad
        consumer.latestRoundData();
        consumer.decimals();

        cTokenToChanlinkMapping[cToken] = consumer;
    }
  

    /**
      * @notice retrieves price of an asset
      * @dev function to get price for an asset
      * @param cToken cToken for which to get the price
      * @return uint mantissa of asset price (scaled by 1e18) or zero if unset or contract paused
      */
    function assetPrices(address cToken) public view returns (uint) {
        AggregatorV3Interface consumer = cTokenToChanlinkMapping[cToken];

        if(address(consumer) == address(0x0)) {
            return 0;
        }

        
        (,int price,,,) = consumer.latestRoundData();

        if(price <= 0){
            return 0;
        }
        
        uint decimals = consumer.decimals();

        CToken ct = CToken(cToken);
        uint underlying_decimals = 18;
        
        if(keccak256(abi.encodePacked(ct.symbol())) != keccak256("hbMOVR")) {
            CErc20Storage cerc20 = CErc20Storage(cToken);
            EIP20Interface erc20 = EIP20Interface(cerc20.underlying());
            underlying_decimals = erc20.decimals();
        }

        Exp memory invertedVal;
        MathError error;
        uint256 scale;
        if(decimals + underlying_decimals > 36) {
            scale = 10**(decimals + underlying_decimals - 36);

            (error, invertedVal) = divScalar(Exp({mantissa: uint(price)}), scale);
            if (error != MathError.NO_ERROR) {return 0;}

        }
        else {
            scale = 10**(36 - decimals - underlying_decimals);

            (error, invertedVal) = mulScalar(Exp({mantissa: uint(price)}), scale);
            if (error != MathError.NO_ERROR) {return 0;}

        }
        
        (error, invertedVal) = getExp(invertedVal.mantissa, uint256(1e18));
            
        if (error != MathError.NO_ERROR) {return 0;}

        return invertedVal.mantissa;
    }

    function test(AggregatorV3Interface consumer) public view returns (int) { 
      (,int price,,,) = consumer.latestRoundData();
      return price;
    }

}
