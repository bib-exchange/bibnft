// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.8.0;

interface IWhiteList {
    function setFeeWhiteList(address account, bool excluded, bool isFrom) external;

    function setMultipleWhiteList(address[] calldata accounts, bool excluded, bool isFrom) external;

    function isFromWhiteList(address account) external view returns(bool);

    function isToWhiteList(address account) external view returns(bool);
}