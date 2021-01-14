pragma solidity ^0.5.0;

interface IGegoFactoryV1 {
    function getGego(uint256 tokenId)
        external view
        returns (
            uint256 grade,
            uint256 quality,
            uint256 degoAmount,
            uint256 createdTime,
            uint256 blockNum,
            uint256 resId,
            address author
        );

    function burn(uint256 tokenId) external returns ( bool );


    function getQualityBase() external view 
        returns (uint256 );
}