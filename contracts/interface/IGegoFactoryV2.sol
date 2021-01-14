pragma solidity ^0.5.0;

pragma experimental ABIEncoderV2;


import "../interface/IGegoToken.sol";

interface IGegoFactoryV2 {


    function getGego(uint256 tokenId)
        external view
        returns (
            uint256 grade,
            uint256 quality,
            uint256 amount,
            uint256 resBaseId,
            uint256 tLevel,
            uint256 ruleId,
            uint256 nftType,
            address author,
            address erc20,
            uint256 createdTime,
            uint256 blockNum
        );


    function getGegoStruct(uint256 tokenId)
        external view
        returns (IGegoToken.Gego memory gego);

    function burn(uint256 tokenId) external returns ( bool );
    
    function isRulerProxyContract(address proxy) external view returns ( bool );
}