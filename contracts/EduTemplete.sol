// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import {AccessControlDefaultAdminRules} from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";

//本合约模板的使用场景为教育领域，基于openzeppelin合约库中的AccessControlDefaultAdminRules标准合约模板进行开发
//使用AccessControlDefaultAdminRules标准合约模板的目的在于便捷地对使用场景中的角色进行定义、授权等一系列权限访问控制
//为了尽可能地简化开发流程和降低开发难度，本合约对部分实现细节做了一些简化，实际应用时可根据具体需求对数据结构进行一些调整
contract EduTemplate is AccessControlDefaultAdminRules{

    //以下是角色定义部分，每个角色以32字节作为标识，考虑做成常量，如果有新增角色定义，照着下方代码修改即可
    //管理员角色默认是合约的部署者，在构造函数中被初始化赋值，管理员角色可以给其他账户赋予角色和收回角色权限
    bytes32 public constant STUDENT_ROLE = keccak256("STUDENT");//student
    bytes32 public constant TEACHER_ROLE = keccak256("TEACHER");//teacher
    bytes32 public constant STUDENT_MANAGER_ROLE = keccak256("STUDENT_MANAGE");//student manager
    bytes32 public constant TEACHER_MANAGER_ROLE = keccak256("TEACHER_MANAGER");//teacher manager
    bytes32 public constant FINANCIAL_STUFF_ROLE = keccak256("FINANCIAL_STUFF");//financial stuff
    bytes32 public constant FINANCIAL_REVIEWER_ROLE = keccak256("FINANCIAL_REVIEWER");//financial reviewer
    uint256 public nextRoleId;

    mapping(uint256 => bytes32) roles;
    mapping(address => mapping(uint256 => uint256)) tempRoles;

    constructor()AccessControlDefaultAdminRules(3 days,msg.sender){
        roles[0] = STUDENT_ROLE;
        roles[1] = TEACHER_ROLE;
        roles[2] = STUDENT_MANAGER_ROLE;
        roles[3] = TEACHER_MANAGER_ROLE;
        roles[4] = FINANCIAL_STUFF_ROLE;
        roles[5] = FINANCIAL_REVIEWER_ROLE;
        nextRoleId = 6;
    }

    //修饰器
    modifier roleValidCheck(uint256 _roleId) {
        require(_roleId >= 0 && _roleId < nextRoleId,"Error: Invalid role id.");
        _;
    }

    //以下是和权限管理相关方法，暂不支持级联授权

    //checkRole函数用于检查给定的地址是否拥有某个角色权限
    function checkRole(address _checkAddr,uint256 _roleId) public view onlyRole(DEFAULT_ADMIN_ROLE) roleValidCheck(_roleId) returns(bool) {
        return hasRole(roles[_roleId], _checkAddr);
    }

    function checkTempRole(address _checkAddr,uint256 _roleId,uint256 _currentTimestamp)
    public view onlyRole(DEFAULT_ADMIN_ROLE) roleValidCheck(_roleId) returns (bool) {
        return tempRoles[_checkAddr][_roleId] >= _currentTimestamp;
    }

    //授予权限
    function adminGrantRole(address _toAddr,uint256 _roleId) public onlyRole(DEFAULT_ADMIN_ROLE) roleValidCheck(_roleId) {
        grantRole(roles[_roleId], _toAddr);
    }

    //回收权限
    function adminRevokeRole(address _fromAddr,uint256 _roleId) public onlyRole(DEFAULT_ADMIN_ROLE) roleValidCheck(_roleId){
        require(checkRole(_fromAddr, _roleId) == true,"Error: This address owner hasn't this role");
        revokeRole(roles[_roleId], _fromAddr);
    }

    //临时授予/延长权限，到期自动收回
    function grantTempRole(address _toAddr,uint256 _roleId,uint256 _expireTime) 
    public onlyRole(DEFAULT_ADMIN_ROLE) roleValidCheck(_roleId) {
        require(checkRole(_toAddr, _roleId) == false,"Error: This address owner has already gained this role for long term");
        require(_expireTime > block.timestamp,"Error: Expire time should be larger than current timestamp.");
        uint256 expirationTime = tempRoles[_toAddr][_roleId];
        if(expirationTime < _expireTime) {
            tempRoles[_toAddr][_roleId] = _expireTime;
        }
    }
}